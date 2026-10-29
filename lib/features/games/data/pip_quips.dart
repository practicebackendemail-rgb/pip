import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/domain/llm_provider.dart';
import '../../../core/services/llm_registry_service.dart';
import '../../brains/data/pip_brains.dart';
import '../../brains/domain/brain_routing.dart';
import '../domain/pip_banter.dart';
import 'game_scores.dart';

/// Pip's game voice: a written line straight away, then (at moments that
/// matter) a fresh AI line about the actual game if one arrives quickly.
class PipGameHost {
  final String game;
  final VoidCallback onChange;
  final PipBanter banter;

  /// Asks the model; swappable in tests.
  final Future<String?> Function(String prompt) ask;

  Reaction reaction;
  int id = 0;

  PipGameHost({
    required this.game,
    required this.onChange,
    required Reaction opening,
    PipBanter? banter,
    Future<String?> Function(String prompt)? ask,
  })  : banter = banter ?? PipBanter(),
        ask = ask ?? _askBrain,
        reaction = opening;

  static const Duration patience = Duration(seconds: 3);

  /// Events worth a fresh line; ordinary moves stay written.
  static const Set<GameEvent> worthAsking = {
    GameEvent.youThreaten,
    GameEvent.pipBlocks,
    GameEvent.pipThreatens,
    GameEvent.youWin,
    GameEvent.pipWins,
    GameEvent.draw,
    GameEvent.roundYouWin,
    GameEvent.roundPipWins,
    GameEvent.roundTie,
    GameEvent.youCheck,
    GameEvent.pipChecks,
    GameEvent.youCapture,
    GameEvent.pipCaptures,
  };

  /// Reacts to [e] now; [situation] describes the game for the model.
  Reaction react(GameEvent e, {String? situation}) {
    final r = banter.react(e);
    say(r, situation: worthAsking.contains(e) ? situation : null);
    return r;
  }

  /// Shows [r]; with a [situation] it may be replaced by an AI line.
  void say(Reaction r, {String? situation}) {
    reaction = r;
    id++;
    onChange();
    if (situation != null) _upgrade(id, r, situation);
  }

  Future<void> _upgrade(int forId, Reaction r, String situation) async {
    if (!await GameScores.smartBanter()) return;
    String? line;
    try {
      line = await ask(prompt(game, situation, r.line)).timeout(patience);
    } catch (_) {
      return;
    }
    line = clean(line);
    if (line == null || forId != id) return;
    reaction = Reaction(r.mood, line, PipSoundCue.none);
    onChange();
  }

  @visibleForTesting
  static String prompt(String game, String situation, String fallback) =>
      'You are Pip, a playful, cheeky little desk robot playing $game against the user. '
      'What just happened: $situation\n'
      'Say ONE short line in character (at most 14 words), reacting to exactly this. '
      'Friendly trash talk is fine. No emojis, no quotes, no hashtags. '
      'For tone, something like: "$fallback"';

  /// First line, without quotes or labels; null if empty or too long.
  @visibleForTesting
  static String? clean(String? raw) {
    if (raw == null) return null;
    var s = raw.trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
    s = s.replaceFirst(RegExp(r'^(pip|assistant)\s*:\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp('^["\'“”]+|["\'“”]+\$'), '').trim();
    if (s.isEmpty || s.length > 120 || s.startsWith('{')) return null;
    return s;
  }

  static Future<String?> _askBrain(String prompt) async {
    final provider = PipBrains.instance.providerFor(BrainJob.commands, getIt<LlmRegistryService>());
    final reply = await provider.chat([LlmMessage(role: 'user', content: prompt)]);
    return reply.text;
  }
}
