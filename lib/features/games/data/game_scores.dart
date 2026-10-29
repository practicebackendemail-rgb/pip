import 'package:shared_preferences/shared_preferences.dart';
import '../domain/game_kind.dart';

/// Wins, losses and draws per game, so Pip can say "you're 3–2 up".
class GameScore {
  final int you;
  final int pip;
  final int draws;
  const GameScore({this.you = 0, this.pip = 0, this.draws = 0});

  int get played => you + pip + draws;

  String get line {
    if (played == 0) return 'First game!';
    if (you == pip) return 'All square at $you each';
    return you > pip ? "You're $you–$pip up" : "I'm $pip–$you up";
  }
}

class GameScores {
  GameScores._();

  static String _key(GameKind k, String who) => 'game_${k.slug}_$who';

  static Future<GameScore> load(GameKind k) async {
    final p = await SharedPreferences.getInstance();
    return GameScore(
      you: p.getInt(_key(k, 'you')) ?? 0,
      pip: p.getInt(_key(k, 'pip')) ?? 0,
      draws: p.getInt(_key(k, 'draw')) ?? 0,
    );
  }

  static Future<Map<GameKind, GameScore>> loadAll() async =>
      {for (final k in GameKind.values) k: await load(k)};

  static Future<GameScore> record(GameKind k, {required bool? youWon}) async {
    final p = await SharedPreferences.getInstance();
    final who = youWon == null ? 'draw' : (youWon ? 'you' : 'pip');
    await p.setInt(_key(k, who), (p.getInt(_key(k, who)) ?? 0) + 1);
    return load(k);
  }

  static const _smartKey = 'game_smart_banter';
  static const _stumpedKey = 'game_last_stumped';

  /// Whether Pip may ask the AI model for fresh lines during games.
  static Future<bool> smartBanter() async => (await SharedPreferences.getInstance()).getBool(_smartKey) ?? true;

  static Future<void> setSmartBanter(bool on) async => (await SharedPreferences.getInstance()).setBool(_smartKey, on);

  /// The last thing that stumped Pip in 20 questions.
  static Future<String?> lastStumped() async => (await SharedPreferences.getInstance()).getString(_stumpedKey);

  static Future<void> setLastStumped(String thing) async =>
      (await SharedPreferences.getInstance()).setString(_stumpedKey, thing);

  static const _difficultyKey = 'game_difficulty';

  static Future<GameDifficulty> difficulty() async {
    final p = await SharedPreferences.getInstance();
    return GameDifficulty.values.asNameMap()[p.getString(_difficultyKey)] ?? GameDifficulty.fair;
  }

  static Future<void> setDifficulty(GameDifficulty d) async =>
      (await SharedPreferences.getInstance()).setString(_difficultyKey, d.name);
}
