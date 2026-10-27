import 'dart:math' as math;
import 'memory_models.dart';

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
    String targetEmbeddingModel = 'text-embedding-004',
    int limit = 5,
    double minSimilarity = 0.35,
  }) {
    final activeMemories = memories.where((m) => !m.isDeleted).toList();
    if (activeMemories.isEmpty) return [];

    // Path 1: Semantic Vector Ranking
    if (queryEmbedding.isNotEmpty) {
      final scored = <MapEntry<MemoryItem, double>>[];
      for (final m in activeMemories) {
        if (m.embedding == null || m.embedding!.isEmpty) continue;
        // Strictly require embedding model match to prevent dimension mismatch or semantic distortion
        if (m.embeddingModel != targetEmbeddingModel) continue;

        final sim = cosineSimilarity(queryEmbedding, m.embedding!);
        if (sim < minSimilarity) continue;

        final totalScore = computeScore(sim, m.importance);
        scored.add(MapEntry(m, totalScore));
      }

      if (scored.isNotEmpty) {
        scored.sort((a, b) => b.value.compareTo(a.value));
        return scored.take(limit).map((e) => e.key).toList();
      }
    }

    // Path 2: Text Overlap & Recency Fallback (used when query vector is empty OR no memories have embeddings)
    final queryWords = (queryText ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();

    final fallbackScored = activeMemories.map((m) {
      double score = m.importance * 0.4;
      if (queryWords.isNotEmpty) {
        final textLower = m.text.toLowerCase();
        final matchCount = queryWords.where((w) => textLower.contains(w)).length;
        score += (matchCount / queryWords.length) * 0.6;
      }
      return MapEntry(m, score);
    }).toList();

    fallbackScored.sort((a, b) => b.value.compareTo(a.value));
    return fallbackScored.take(limit).map((e) => e.key).toList();
  }
}
