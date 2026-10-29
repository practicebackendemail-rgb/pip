import 'dart:math';
import 'game_kind.dart';

enum Hand {
  rock,
  paper,
  scissors;

  bool beats(Hand o) => (index - o.index) % 3 == 1;
  Hand get beatenBy => Hand.values[(index + 1) % 3];

  static Hand? parse(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(rock|stone)\b').hasMatch(t)) return rock;
    if (RegExp(r'\bpaper\b').hasMatch(t)) return paper;
    if (RegExp(r'\bscissors?\b').hasMatch(t)) return scissors;
    return null;
  }
}

enum RoundResult { youWin, pipWins, tie }

/// Best of five: first to three. On Tough, Pip learns what you tend to play
/// after each hand and counters it.
class RockPaperScissors {
  static const target = 3;
  int you = 0;
  int pip = 0;
  final List<Hand> _history = [];

  bool get over => you >= target || pip >= target;

  RoundResult play(Hand yours, Hand pips) {
    _history.add(yours);
    if (yours == pips) return RoundResult.tie;
    if (yours.beats(pips)) {
      you++;
      return RoundResult.youWin;
    }
    pip++;
    return RoundResult.pipWins;
  }

  Hand pipPick(GameDifficulty level, {Random? random}) {
    final rnd = random ?? Random();
    final guess = Hand.values[rnd.nextInt(3)];
    if (level != GameDifficulty.tough || _history.length < 2 || rnd.nextDouble() < .25) return guess;
    // What did you play after your last hand, most often?
    final last = _history.last;
    final counts = {for (final h in Hand.values) h: 0};
    for (var i = 0; i + 1 < _history.length; i++) {
      if (_history[i] == last) counts[_history[i + 1]] = counts[_history[i + 1]]! + 1;
    }
    final predicted = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return predicted.value == 0 ? guess : predicted.key.beatenBy;
  }
}
