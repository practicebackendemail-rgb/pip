import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'encrypted_memory_db.dart';
import 'event_log.dart';
import 'memory_models.dart';

/// Repository interface handling Pip's long-term episodic memory,
/// profile facts, learned rules, and semantic memory search.
abstract class MemoryRepository {
  Future<void> logEvent(PipEvent event);
  Future<List<PipEvent>> getEvents({int limit = 200, DateTime? since});
  Future<void> pruneEvents(DateTime threshold);
  Future<void> recordMemory(String text, {List<double>? embedding, double importance});
  Future<List<MemoryItem>> searchMemories(
    List<double> queryEmbedding, {
    int limit = 5,
    String? queryText,
    double minSimilarity = 0.35,
  });
  Future<List<ProfileFact>> getProfile();
  Future<void> upsertFact(String key, String value, {double confidence});
  Future<void> deleteFact(String key);
  Future<List<PipRule>> getActiveRules();
  Future<void> addRule(String instruction, {String scope = 'general', String source = 'user_explicit'});
  Future<void> forgetEverything();
}

class SqlCipherMemoryRepository extends ChangeNotifier implements MemoryRepository {
  final EncryptedMemoryDatabase _db = EncryptedMemoryDatabase.instance;

  @override
  Future<void> logEvent(PipEvent event) async {
    await _db.logEvent(event);
  }

  @override
  Future<List<PipEvent>> getEvents({int limit = 200, DateTime? since}) async {
    return await _db.getEvents(limit: limit, since: since);
  }

  @override
  Future<void> pruneEvents(DateTime threshold) async {
    await _db.pruneEventsOlderThan(threshold);
  }

  @override
  Future<void> recordMemory(String text, {List<double>? embedding, double importance = 0.5}) async {
    final item = MemoryItem(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      embedding: embedding,
      importance: importance,
    );
    await _db.upsertMemory(item);
    notifyListeners();
  }

  @override
  Future<List<MemoryItem>> searchMemories(
    List<double> queryEmbedding, {
    int limit = 5,
    String? queryText,
    double minSimilarity = 0.35,
  }) async {
    final all = await _db.getAllMemories();
    if (all.isEmpty) return [];

    // Fallback path: when query vector is empty, rank by keyword overlap, recency, and importance
    if (queryEmbedding.isEmpty) {
      final queryWords = (queryText ?? '')
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .toSet();

      final fallbackScored = all.map((m) {
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

    final scored = <MapEntry<MemoryItem, double>>[];
    for (final m in all) {
      if (m.embedding == null || m.embedding!.isEmpty) continue;
      final sim = _cosineSimilarity(queryEmbedding, m.embedding!);
      if (sim < minSimilarity) continue; // Step 3.9: enforce similarity threshold
      final totalScore = (sim * 0.75) + (m.importance * 0.25);
      scored.add(MapEntry(m, totalScore));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
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

  @override
  Future<List<ProfileFact>> getProfile() async {
    return await _db.getAllFacts();
  }

  @override
  Future<void> upsertFact(String key, String value, {double confidence = 0.6}) async {
    final existing = (await _db.getAllFacts()).where((f) => f.key == key).toList();
    final evidence = existing.isNotEmpty ? existing.first.evidenceCount + 1 : 1;
    final newFact = ProfileFact(
      key: key,
      value: value,
      confidence: confidence,
      evidenceCount: evidence,
      updatedAt: DateTime.now(),
    );
    await _db.upsertFact(newFact);
    notifyListeners();
  }

  @override
  Future<void> deleteFact(String key) async {
    await _db.deleteFact(key);
    notifyListeners();
  }

  @override
  Future<List<PipRule>> getActiveRules() async {
    return await _db.getAllRules();
  }

  @override
  Future<void> addRule(String instruction, {String scope = 'general', String source = 'user_explicit'}) async {
    final rule = PipRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      scope: scope,
      instruction: instruction,
      source: source,
      active: true,
    );
    await _db.upsertRule(rule);
    notifyListeners();
  }

  @override
  Future<void> forgetEverything() async {
    await _db.forgetEverything();
    notifyListeners();
  }
}
