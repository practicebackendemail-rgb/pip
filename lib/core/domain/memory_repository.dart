import 'package:flutter/foundation.dart';
import 'encrypted_memory_db.dart';
import 'event_log.dart';
import 'memory_models.dart';
import 'memory_ranker.dart';

/// Repository interface handling Pip's long-term episodic memory,
/// profile facts, learned rules, and semantic memory search.
abstract class MemoryRepository {
  Future<void> logEvent(PipEvent event);
  Future<List<PipEvent>> getEvents({int limit = 200, DateTime? since});
  Future<void> pruneEvents(DateTime threshold);
  Future<void> recordMemory(String text, {List<double>? embedding, String embeddingModel = 'text-embedding-004', double importance = 0.5});
  Future<List<MemoryItem>> searchMemories(
    List<double> queryEmbedding, {
    int limit = 5,
    String? queryText,
    String targetEmbeddingModel = 'text-embedding-004',
    double minSimilarity = 0.35,
  });
  Future<List<MemoryItem>> getAllMemoriesIncludingDeleted();
  Future<void> importMemory(MemoryItem memory);
  Future<void> deleteMemory(String id);

  Future<List<ProfileFact>> getProfile();
  Future<List<ProfileFact>> getAllFactsIncludingDeleted();
  Future<void> upsertFact(String key, String value, {double confidence = 0.6});
  Future<void> setFactConfidence(String key, double confidence);
  Future<void> importFact(ProfileFact fact);
  Future<void> deleteFact(String key);

  Future<List<PipRule>> getActiveRules();
  Future<List<PipRule>> getAllRulesIncludingDeleted();
  Future<void> addRule(String instruction, {String scope = 'general', String source = 'user_explicit'});
  Future<void> importRule(PipRule rule);
  Future<void> deleteRule(String id);

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
  Future<void> recordMemory(
    String text, {
    List<double>? embedding,
    String embeddingModel = 'text-embedding-004',
    double importance = 0.5,
  }) async {
    final now = DateTime.now();
    final memory = MemoryItem(
      id: 'mem_${now.millisecondsSinceEpoch}',
      text: text,
      embedding: embedding,
      embeddingModel: embeddingModel,
      importance: importance,
      createdAt: now,
      lastUsedAt: now,
      updatedAt: now,
    );
    await _db.upsertMemory(memory);
    notifyListeners();
  }

  @override
  Future<List<MemoryItem>> searchMemories(
    List<double> queryEmbedding, {
    int limit = 5,
    String? queryText,
    String targetEmbeddingModel = 'text-embedding-004',
    double minSimilarity = 0.35,
  }) async {
    final all = await _db.getAllMemories(includeDeleted: false);
    return MemoryRanker.rankMemories(
      memories: all,
      queryEmbedding: queryEmbedding,
      queryText: queryText,
      targetEmbeddingModel: targetEmbeddingModel,
      limit: limit,
      minSimilarity: minSimilarity,
    );
  }

  @override
  Future<List<MemoryItem>> getAllMemoriesIncludingDeleted() async {
    return await _db.getAllMemories(includeDeleted: true);
  }

  @override
  Future<void> importMemory(MemoryItem memory) async {
    final existing = await _db.getAllMemories(includeDeleted: true);
    final match = existing.cast<MemoryItem?>().firstWhere((m) => m?.id == memory.id, orElse: () => null);
    if (match == null || memory.updatedAt.isAfter(match.updatedAt)) {
      await _db.upsertMemory(memory);
      notifyListeners();
    }
  }

  @override
  Future<void> deleteMemory(String id) async {
    await _db.deleteMemory(id);
    notifyListeners();
  }

  @override
  Future<List<ProfileFact>> getProfile() async {
    return await _db.getAllFacts(includeDeleted: false);
  }

  @override
  Future<List<ProfileFact>> getAllFactsIncludingDeleted() async {
    return await _db.getAllFacts(includeDeleted: true);
  }

  @override
  Future<void> upsertFact(String key, String value, {double confidence = 0.6}) async {
    final now = DateTime.now();
    final existingList = await _db.getAllFacts(includeDeleted: false);
    final existing = existingList.cast<ProfileFact?>().firstWhere((f) => f?.key == key, orElse: () => null);

    if (existing != null && existing.value == value) {
      final updatedConfidence = (existing.confidence + 0.05).clamp(0.0, 0.95);
      final reinforced = ProfileFact(
        key: key,
        value: value,
        confidence: updatedConfidence,
        evidenceCount: existing.evidenceCount + 1,
        updatedAt: now,
        lastReinforcedAt: now,
      );
      await _db.upsertFact(reinforced);
      notifyListeners();
      return;
    }

    final newFact = ProfileFact(
      key: key,
      value: value,
      confidence: confidence,
      evidenceCount: 1,
      updatedAt: now,
      lastReinforcedAt: now,
    );
    await _db.upsertFact(newFact);
    notifyListeners();
  }

  @override
  Future<void> setFactConfidence(String key, double confidence) async {
    await _db.setFactConfidence(key, confidence);
    notifyListeners();
  }

  @override
  Future<void> importFact(ProfileFact fact) async {
    final existingList = await _db.getAllFacts(includeDeleted: true);
    final existing = existingList.cast<ProfileFact?>().firstWhere((f) => f?.key == fact.key, orElse: () => null);
    if (existing == null || fact.updatedAt.isAfter(existing.updatedAt)) {
      await _db.upsertFact(fact);
      notifyListeners();
    }
  }

  @override
  Future<void> deleteFact(String key) async {
    await _db.deleteFact(key);
    notifyListeners();
  }

  @override
  Future<List<PipRule>> getActiveRules() async {
    return await _db.getAllRules(includeDeleted: false);
  }

  @override
  Future<List<PipRule>> getAllRulesIncludingDeleted() async {
    return await _db.getAllRules(includeDeleted: true);
  }

  @override
  Future<void> addRule(String instruction, {String scope = 'general', String source = 'user_explicit'}) async {
    final existingRules = await _db.getAllRules(includeDeleted: false);
    final normalized = instruction.trim().toLowerCase();
    final isDuplicate = existingRules.any((r) => r.instruction.trim().toLowerCase() == normalized);
    if (isDuplicate) return;

    final rule = PipRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      scope: scope,
      instruction: instruction.trim(),
      source: source,
      active: true,
      updatedAt: DateTime.now(),
    );
    await _db.upsertRule(rule);
    notifyListeners();
  }

  @override
  Future<void> importRule(PipRule rule) async {
    final existingList = await _db.getAllRules(includeDeleted: true);
    final existing = existingList.cast<PipRule?>().firstWhere((r) => r?.id == rule.id, orElse: () => null);
    if (existing == null || rule.updatedAt.isAfter(existing.updatedAt)) {
      await _db.upsertRule(rule);
      notifyListeners();
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    await _db.deleteRule(id);
    notifyListeners();
  }

  @override
  Future<void> forgetEverything() async {
    await _db.forgetEverything();
    notifyListeners();
  }
}
