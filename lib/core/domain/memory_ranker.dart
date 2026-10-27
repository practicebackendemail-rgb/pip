import 'dart:math' as math;
import 'embedding_tags.dart';
import 'memory_models.dart';

/// Lowercased, whitespace-collapsed text used for duplicate detection.
String normalizeMemoryText(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Pure Dart utility for memory scoring and ranking.
/// Keeps memory scoring completely testable without requiring SQLite or SQLCipher.
class MemoryRanker {
  /// Computes cosine similarity between two double vectors.
  /// Returns 0.0 if vectors have mismatched lengths, zero norm, or are empty.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Calculates a combined relevance score between 0.0 and 1.0.
  /// Formula: 75% cosine similarity + 25% memory importance.
  static double computeScore(double similarity, double importance) {
    return (similarity * 0.75) + (importance * 0.25);
  }

  /// Ranks memories by embedding similarity.
  /// If [queryEmbedding] is provided and matches [targetEmbeddingModel], filters by model and computes cosine score.
  /// If [queryEmbedding] is empty or no embeddings match, falls back to keyword overlap + importance ranking.
  static List<MemoryItem> rankMemories({
    required List<MemoryItem> memories,
    required List<double> queryEmbedding,
    String? queryText,
    String targetEmbeddingModel = EmbeddingTags.none,
    int limit = 5,
    double minSimilarity = 0.35,
  }) {
    final activeMemories = memories.where((m) => !m.isDeleted).toList();
    if (activeMemories.isEmpty) return [];

    // Path 1: Semantic Vector Ranking
    final vectorHits = <MemoryItem>[];
    if (queryEmbedding.isNotEmpty) {
      final scored = <MapEntry<MemoryItem, double>>[];
      for (final m in activeMemories) {
        if (m.embedding == null || m.embedding!.isEmpty) continue;
        // Strictly require embedding model match to prevent dimension mismatch or semantic distortion
        if (m.embeddingModel != targetEmbeddingModel) continue;
        if (m.embedding!.length != queryEmbedding.length) continue;

        final sim = cosineSimilarity(queryEmbedding, m.embedding!);
        if (sim < minSimilarity) continue;

        final totalScore = computeScore(sim, m.importance);
        scored.add(MapEntry(m, totalScore));
      }

      scored.sort((a, b) => b.value.compareTo(a.value));
      vectorHits.addAll(scored.take(limit).map((e) => e.key));
      if (vectorHits.length >= limit) return vectorHits;
    }

    // Path 2: Keyword overlap + importance. Fills whatever the vector path left
    // short, so memories from other models or without vectors stay reachable.
    final queryWords = (queryText ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();

    // When topping up vector hits, only add memories that share a query word,
    // so the fill never pads the prompt with unrelated items.
    final hitIds = vectorHits.map((m) => m.id).toSet();
    final requireOverlap = vectorHits.isNotEmpty && queryWords.isNotEmpty;
    final fallbackScored = <MapEntry<MemoryItem, double>>[];
    for (final m in activeMemories) {
      if (hitIds.contains(m.id)) continue;
      double score = m.importance * 0.4;
      if (queryWords.isNotEmpty) {
        final textLower = m.text.toLowerCase();
        final matchCount = queryWords.where((w) => textLower.contains(w)).length;
        if (requireOverlap && matchCount == 0) continue;
        score += (matchCount / queryWords.length) * 0.6;
      } else if (vectorHits.isNotEmpty) {
        continue;
      }
      fallbackScored.add(MapEntry(m, score));
    }

    fallbackScored.sort((a, b) => b.value.compareTo(a.value));
    return [
      ...vectorHits,
      ...fallbackScored.take(limit - vectorHits.length).map((e) => e.key),
    ];
  }
}
