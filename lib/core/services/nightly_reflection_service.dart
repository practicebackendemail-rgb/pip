import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/event_log.dart';
import '../domain/llm_provider.dart';
import '../domain/memory_models.dart';
import '../domain/memory_repository.dart';
import 'llm_registry_service.dart';

/// Nightly Reflection Service (Section 8.2 & Step 2 of Fix Plan)
/// Synthesizes event logs into profile facts, memories, and rules.
/// Includes 20-hour elapsed guard, chronological event slicing,
/// fault-tolerant output validation, confidence reinforcement, and confidence decay.
class NightlyReflectionService extends ChangeNotifier {
  static const String _prefLastReflection = 'pip_last_reflection_at';
  final MemoryRepository memoryRepository;
  final EventLogService eventLog;
  final LlmRegistryService llmRegistry;

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
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefLastReflection);
      if (stored != null) {
        _lastReflectionAt = DateTime.tryParse(stored);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NightlyReflectionService load error: $e');
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

    final events = eventLog.events;
    if (events.isEmpty) return;

    // Filter events since last reflection (or all if first run), newest-last, capped at 200
    List<PipEvent> candidates;
    if (_lastReflectionAt != null) {
      candidates = events.where((e) => e.timestamp.isAfter(_lastReflectionAt!)).toList();
    } else {
      candidates = List<PipEvent>.from(events);
    }

    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (candidates.length > 200) {
      candidates = candidates.sublist(candidates.length - 200);
    }

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
        await _applyReflectionResults(decoded, facts);

        // Record successful reflection timestamp
        _lastReflectionAt = now;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastReflection, now.toIso8601String());
      }

      // Step 2.8: Decay facts not reinforced within 30 days
      await _applyFactDecay(facts, now);
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

  Future<void> _applyReflectionResults(Map<String, dynamic> decoded, List<ProfileFact> existingFacts) async {
    // 1. Ingest Facts with confidence boosting
    final newFacts = decoded['new_facts'];
    if (newFacts is List) {
      for (final f in newFacts) {
        if (f is! Map) continue;
        final k = f['key'] as String?;
        final v = f['value'] as String?;
        var c = (f['confidence'] as num?)?.toDouble() ?? 0.6;
        c = c.clamp(0.1, 1.0);

        if (k != null && v != null) {
          final existing = existingFacts.where((item) => item.key == k).toList();
          if (existing.isNotEmpty) {
            // Reinforcement: boost confidence up to 0.95
            c = (existing.first.confidence + 0.1).clamp(0.1, 0.95);
          }
          await memoryRepository.upsertFact(k, v, confidence: c);
        }
      }
    }

    // 2. Ingest Rules
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
            importance: 0.7,
          );
        }
      }
    }
  }

  /// Lowers confidence for facts inactive for 30+ days; prunes facts below 0.2.
  Future<void> _applyFactDecay(List<ProfileFact> currentFacts, DateTime now) async {
    for (final fact in currentFacts) {
      final daysSinceUpdate = now.difference(fact.updatedAt).inDays;
      if (daysSinceUpdate >= 30) {
        final decayed = fact.confidence - 0.1;
        if (decayed < 0.2) {
          await memoryRepository.deleteFact(fact.key);
        } else {
          await memoryRepository.upsertFact(fact.key, fact.value, confidence: decayed);
        }
      }
    }
  }
}
