import 'dart:math';
import 'game_kind.dart';

/// Noughts and crosses on a 3×3 board. Cells: 0 empty, 1 you (X), 2 Pip (O).
class TicTacToe {
  static const you = 1;
  static const pip = 2;
  final List<int> cells;

  TicTacToe() : cells = List.filled(9, 0);
  TicTacToe._(this.cells);
  TicTacToe copy() => TicTacToe._([...cells]);

  static const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], //
    [0, 3, 6], [1, 4, 7], [2, 5, 8], //
    [0, 4, 8], [2, 4, 6],
  ];

  List<int> get open => [for (var i = 0; i < 9; i++) if (cells[i] == 0) i];
  bool get isFull => open.isEmpty;

  bool place(int i, int who) {
    if (i < 0 || i > 8 || cells[i] != 0) return false;
    cells[i] = who;
    return true;
  }

  List<int>? winningLine() {
    for (final l in lines) {
      final v = cells[l[0]];
      if (v != 0 && v == cells[l[1]] && v == cells[l[2]]) return l;
    }
    return null;
  }

  int? get winner {
    final l = winningLine();
    return l == null ? null : cells[l.first];
  }

  /// Squares where [who] would complete a line.
  List<int> winningMoves(int who) => [for (final i in open) if ((copy()..place(i, who)).winner == who) i];

  int _minimax(bool pipTurn, int depth) {
    final w = winner;
    if (w == pip) return 10 - depth;
    if (w == you) return depth - 10;
    if (isFull) return 0;
    var best = pipTurn ? -100 : 100;
    for (final i in open) {
      cells[i] = pipTurn ? pip : you;
      final s = _minimax(!pipTurn, depth + 1);
      cells[i] = 0;
      best = pipTurn ? max(best, s) : min(best, s);
    }
    return best;
  }

  /// Easy plays loosely, Fair plays well most of the time, Tough never loses.
  int pipMove(GameDifficulty level, {Random? random}) {
    final rnd = random ?? Random();
    final squares = open;
    final sloppy = switch (level) { GameDifficulty.easy => .6, GameDifficulty.fair => .2, GameDifficulty.tough => 0.0 };
    if (rnd.nextDouble() < sloppy) {
      final win = winningMoves(pip);
      if (win.isNotEmpty && rnd.nextBool()) return win.first;
      return squares[rnd.nextInt(squares.length)];
    }
    var best = squares.first, bestScore = -1000;
    for (final i in squares..shuffle(rnd)) {
      cells[i] = pip;
      final s = _minimax(false, 0);
      cells[i] = 0;
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }
}
