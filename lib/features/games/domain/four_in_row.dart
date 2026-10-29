import 'dart:math';
import 'game_kind.dart';

/// Six rows by seven columns; discs fall to the lowest free cell.
/// Cells: 0 empty, 1 you, 2 Pip. Row 0 is the top.
class FourInRow {
  static const rows = 6;
  static const cols = 7;
  static const you = 1;
  static const pip = 2;

  final List<List<int>> cells;
  FourInRow() : cells = List.generate(rows, (_) => List.filled(cols, 0));
  FourInRow._(this.cells);

  FourInRow copy() => FourInRow._([for (final r in cells) [...r]]);

  bool canDrop(int col) => col >= 0 && col < cols && cells[0][col] == 0;
  List<int> get openColumns => [for (var c = 0; c < cols; c++) if (canDrop(c)) c];
  bool get isFull => openColumns.isEmpty;

  /// Drops a disc and returns the row it landed in, or -1.
  int drop(int col, int who) {
    if (!canDrop(col)) return -1;
    for (var r = rows - 1; r >= 0; r--) {
      if (cells[r][col] == 0) {
        cells[r][col] = who;
        return r;
      }
    }
    return -1;
  }

  void undo(int col) {
    for (var r = 0; r < rows; r++) {
      if (cells[r][col] != 0) {
        cells[r][col] = 0;
        return;
      }
    }
  }

  static const _dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];

  /// The four winning cells as (row, col), or null.
  List<(int, int)>? winningLine() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final who = cells[r][c];
        if (who == 0) continue;
        for (final (dr, dc) in _dirs) {
          final line = [for (var i = 0; i < 4; i++) (r + dr * i, c + dc * i)];
          if (line.every((p) => _at(p.$1, p.$2) == who)) return line;
        }
      }
    }
    return null;
  }

  int? get winner {
    final l = winningLine();
    return l == null ? null : cells[l.first.$1][l.first.$2];
  }

  int _at(int r, int c) => r < 0 || r >= rows || c < 0 || c >= cols ? -1 : cells[r][c];

  /// Columns where [who] would win immediately.
  List<int> winningMoves(int who) => [
        for (final c in openColumns)
          if ((copy()..drop(c, who)).winner == who) c
      ];

  /// Static score from Pip's side: centre control and open lines.
  int _score() {
    var s = 0;
    for (var r = 0; r < rows; r++) {
      if (cells[r][3] == pip) s += 3;
      if (cells[r][3] == you) s -= 3;
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final (dr, dc) in _dirs) {
          var mine = 0, theirs = 0, valid = true;
          for (var i = 0; i < 4; i++) {
            final v = _at(r + dr * i, c + dc * i);
            if (v == -1) {
              valid = false;
              break;
            }
            if (v == pip) mine++;
            if (v == you) theirs++;
          }
          if (!valid || (mine > 0 && theirs > 0)) continue;
          s += const [0, 1, 5, 50, 0][mine] - const [0, 1, 6, 60, 0][theirs];
        }
      }
    }
    return s;
  }

  static const _order = [3, 2, 4, 1, 5, 0, 6];

  int _minimax(int depth, int alpha, int beta, bool pipTurn) {
    final w = winner;
    if (w == pip) return 100000 + depth;
    if (w == you) return -100000 - depth;
    if (depth == 0 || isFull) return _score();
    if (pipTurn) {
      var best = -1 << 30;
      for (final c in _order.where(canDrop)) {
        drop(c, pip);
        best = max(best, _minimax(depth - 1, alpha, beta, false));
        undo(c);
        alpha = max(alpha, best);
        if (alpha >= beta) break;
      }
      return best;
    }
    var best = 1 << 30;
    for (final c in _order.where(canDrop)) {
      drop(c, you);
      best = min(best, _minimax(depth - 1, alpha, beta, true));
      undo(c);
      beta = min(beta, best);
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Pip's column. Easy misses things on purpose; Tough looks 6 moves ahead.
  int pipMove(GameDifficulty level, {Random? random}) {
    final rnd = random ?? Random();
    final open = openColumns;
    final win = winningMoves(pip);
    final block = winningMoves(you);
    if (level == GameDifficulty.easy) {
      if (win.isNotEmpty && rnd.nextDouble() < .7) return win.first;
      if (block.isNotEmpty && rnd.nextDouble() < .4) return block.first;
      return open[rnd.nextInt(open.length)];
    }
    if (win.isNotEmpty) return win.first;
    if (block.isNotEmpty) return block.first;
    final depth = level == GameDifficulty.fair ? 3 : 6;
    var best = open.first, bestScore = -1 << 30;
    final b = copy();
    for (final c in _order.where(canDrop)) {
      b.drop(c, pip);
      final s = b._minimax(depth - 1, -1 << 30, 1 << 30, false) + rnd.nextInt(2);
      b.undo(c);
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best;
  }
}
