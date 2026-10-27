import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/encrypted_memory_db.dart';
import '../domain/event_log.dart';
import '../domain/llm_provider.dart';
import '../domain/embedding_tags.dart';
import '../domain/memory_repository.dart';
import 'llm_registry_service.dart';

/// Nightly Reflection Service (Section 8.2 & Phase 3)
/// Synthesizes unprocessed event logs into profile facts, memories, and rules.
/// Includes 20-hour elapsed guard, atomic batch marking of processed events,
/// stale-free profile facts querying, lastReinforcedAt decay, and rule deduplication.
class NightlyReflectionService extends ChangeNotifier {
  static const int maxLearnedRules = 20;
  static const String _metaLastReflection = 'pip_last_reflection_at';
  final MemoryRepository memoryRepository;
  final EventLogService eventLog;
  final LlmRegistryService llmRegistry;
  final EncryptedMemoryDatabase _db = EncryptedMemoryDatabase.instance;

  bool _isReflecting = false;
  DateTime? _lastReflectionAt;

  bool get isReflecting => _isReflecting;
  DateTime? get lastReflectionAt => _lastReflectionAt;

  NightlyReflectionService({
    required this.memoryRepository,
    required this.eventLog,
    required this.llmRegistry,
  }) {
    _loadLastReflectionTime();
  }

  Future<void> _loadLastReflectionTime() async {
    try {
      final stored = await _db.getMeta(_metaLastReflection);
      if (stored != null) {
        _lastReflectionAt = DateTime.tryParse(stored);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NightlyReflectionService meta load error: $e');
    }
  }

  /// Triggers reflection if at least 20 hours have elapsed since the last run.
  Future<void> runReflectionIfNeeded({bool force = false}) async {
    if (_isReflecting) return;

    final now = DateTime.now();
    if (!force && _lastReflectionAt != null) {
      final elapsedHours = now.difference(_lastReflectionAt!).inHours;
      if (elapsedHours < 20) {
        debugPrint('NightlyReflectionService: Skipping (only $elapsedHours hours since last reflection)');
        return;
      }
    }

    final List<PipEvent> candidates;
    try {
      candidates = await _db.getUnprocessedEvents(limit: 200);
    } catch (e) {
      debugPrint('NightlyReflectionService: events unavailable: $e');
      return;
    }
    if (candidates.isEmpty) return;

    _isReflecting = true;
    notifyListeners();

    try {
      final facts = await memoryRepository.getProfile();
      final rules = await memoryRepository.getActiveRules();
      final provider = llmRegistry.getActiveProvider();

      final recentSlice = candidates
          .map((e) => '- [${e.timestamp.toIso8601String()}] ${e.type}: ${jsonEncode(e.payload)}')
          .join('\n');
      final currentFacts =
          facts.map((f) => '- ${f.key}: ${f.value} (conf: ${f.confidence.toStringAsFixed(2)})').join('\n');
      final currentRules = rules.map((r) => '- [${r.scope}] ${r.instruction}').join('\n');

      final prompt = '''
You are the Cognitive Reflection Engine for Pip, an AI desk companion.
Analyze the recent event logs and synthesize what you have learned about the user's habits, routines, and preferences.

Current Profile Facts:
${currentFacts.isEmpty ? 'None yet.' : currentFacts}

Current Rules:
${currentRules.isEmpty ? 'None yet.' : currentRules}

Recent Events:
$recentSlice

Output pure JSON matching this exact structure:
{
  "new_facts": [
    {"key": "routine_start", "value": "User typically begins coding around 9 AM", "confidence": 0.8}
  ],
  "new_rules": [
    {"scope": "briefing", "instruction": "Keep morning briefings under 3 bullet points"}
  ],
  "new_memories": [
    "User completed the presentation ahead of schedule on Friday"
  ]
}
''';

      var response = await provider.chat([LlmMessage(role: 'user', content: prompt)]);
      Map<String, dynamic>? decoded = _parseReflectionJson(response.text);

      // Fault tolerance: retry once if model produces invalid JSON
      if (decoded == null) {
        response = await provider.chat([
          LlmMessage(role: 'user', content: prompt),
          LlmMessage(role: 'assistant', content: response.text),
          LlmMessage(
            role: 'user',
            content: 'Your previous response was not valid JSON. Please reply with ONLY the raw JSON object.',
          ),
        ]);
        decoded = _parseReflectionJson(response.text);
      }

      if (decoded != null) {
        await _applyReflectionResults(decoded);
        await _db.markEventsProcessed(candidates.map((e) => e.id).toList());

        _lastReflectionAt = now;
        await _db.setMeta(_metaLastReflection, now.toIso8601String());
      }

      // Re-query fresh facts to avoid decay race overwriting newly inserted items
      await _applyFactDecay(now);
    } catch (e) {
      debugPrint('Reflection error: $e');
    } finally {
      _isReflecting = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _parseReflectionJson(String text) {
    try {
      final clean = text.trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start != -1 && end > start) {
        final parsed = jsonDecode(clean.substring(start, end + 1));
        if (parsed is Map<String, dynamic>) return parsed;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _applyReflectionResults(Map<String, dynamic> decoded) async {
    // 1. Ingest Facts with confidence boosting
    final newFacts = decoded['new_facts'];
    if (newFacts is List) {
      for (final f in newFacts) {
        if (f is! Map) continue;
        final k = f['key'] as String?;
        final v = f['value'] as String?;
        var c = (f['confidence'] as num?)?.toDouble() ?? 0.6;
        c = c.clamp(0.1, 1.0);

        // upsertFact reinforces a same-value fact itself; a new value takes c.
        if (k != null && v != null) {
          await memoryRepository.upsertFact(k, v, confidence: c);
        }
      }
    }

    // 2. Ingest Rules (deduplicated by instruction string in repository)
    final newRules = decoded['new_rules'];
    if (newRules is List) {
      for (final r in newRules) {
        if (r is! Map) continue;
        final scope = (r['scope'] as String?) ?? 'general';
        final inst = r['instruction'] as String?;
        if (inst != null && inst.isNotEmpty) {
          await memoryRepository.addRule(inst, scope: scope, source: 'learned');
        }
      }
      await _capLearnedRules();
    }

    // 3. Ingest Memories with embedding
    final newMemories = decoded['new_memories'];
    if (newMemories is List) {
      final embeddingProvider = llmRegistry.getEmbeddingProvider();
      for (final m in newMemories) {
        if (m is String && m.trim().isNotEmpty) {
          List<double>? vector;
          if (embeddingProvider.capabilities.supportsEmbeddings) {
            try {
              final emb = await embeddingProvider.embed([m.trim()]);
              if (emb.isNotEmpty && emb.first.isNotEmpty) {
                vector = emb.first;
              }
            } catch (_) {}
          }
          await memoryRepository.recordMemory(
            m.trim(),
            embedding: vector,
            embeddingModel: vector != null
                ? EmbeddingTags.forProvider(embeddingProvider.id)
                : EmbeddingTags.none,
            importance: 0.7,
          );
        }
      }
    }
  }

  /// Keeps the prompt small: only the newest [maxLearnedRules] learned rules
  /// stay active; older ones are tombstoned. User-written rules are untouched.
  Future<void> _capLearnedRules() async {
    final learned = (await memoryRepository.getActiveRules()).where((r) => r.source == 'learned').toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final rule in learned.skip(maxLearnedRules)) {
      await memoryRepository.deleteRule(rule.id);
    }
  }

  /// Lowers confidence for facts not reinforced within 30 days using lastReinforcedAt
  Future<void> _applyFactDecay(DateTime now) async {
    final freshFacts = await memoryRepository.getProfile();
    for (final fact in freshFacts) {
      final daysSinceReinforcement = now.difference(fact.lastReinforcedAt).inDays;
      if (daysSinceReinforcement >= 30) {
        final decayed = fact.confidence - 0.1;
        if (decayed < 0.2) {
          await memoryRepository.deleteFact(fact.key);
        } else {
          await memoryRepository.setFactConfidence(fact.key, decayed);
        }
      }
    }
  }
}
