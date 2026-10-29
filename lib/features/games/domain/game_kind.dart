/// The games Pip can play. Moves are decided by code, never the model,
/// except 20 questions, which needs it.
enum GameKind {
  fourInRow('four-in-row'),
  rockPaperScissors('rps'),
  twentyQuestions('20q'),
  ticTacToe('tic-tac-toe'),
  chess('chess');

  final String slug;
  const GameKind(this.slug);

  static GameKind? fromSlug(String? s) => values.where((k) => k.slug == s).firstOrNull;

  /// Whether this game needs an AI model (cloud or on-device).
  bool get needsBrain => this == twentyQuestions;
}

/// How hard Pip tries.
enum GameDifficulty { easy, fair, tough }
