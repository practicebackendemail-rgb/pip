import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chess/chess.dart' as ch;
import 'game_kind.dart';

/// Pip's chess: you play white, Pip plays black. Rules come from the chess
/// package; this is only how Pip picks a move.
///
/// Easy looks one move ahead and is noisy, Fair two, Tough three plus
/// finishing off capture sequences, so it won't hang pieces cheaply.
class ChessAi {
  static const _value = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};

  /// Centre and advance bonuses, from white's side; row 0 is rank 8.
  static const _pawn = [
    0, 0, 0, 0, 0, 0, 0, 0, //
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];
  static const _knight = [
    -50, -40, -30, -30, -30, -30, -40, -50, //
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  static int _centre(int r, int f) => (6 - ((3.5 - r).abs() + (3.5 - f).abs())).round() * 2;

  /// Material plus placement, positive when white is better.
  static int evaluate(ch.Chess g) {
    var score = 0;
    for (var i = 0; i < 128; i++) {
      if (i & 0x88 != 0) continue;
      final p = g.board[i];
      if (p == null) continue;
      final r = i >> 4, f = i & 15;
      final white = p.color == ch.Color.WHITE;
      final idx = (white ? r : 7 - r) * 8 + f;
      var v = _value[p.type.name]!;
      v += switch (p.type.name) {
        'p' => _pawn[idx],
        'n' => _knight[idx],
        'b' || 'q' => _centre(r, f),
        _ => 0,
      };
      score += white ? v : -v;
    }
    return score;
  }

  static int _order(ch.Move m) {
    var s = 0;
    if (m.captured != null) s += 10 * _value[m.captured!.name]! - _value[m.piece.name]! ~/ 10;
    if (m.promotion != null) s += _value[m.promotion!.name]!;
    return -s;
  }

  static int _quiesce(ch.Chess g, int alpha, int beta, int depth) {
    final side = g.turn == ch.Color.WHITE ? 1 : -1;
    final stand = side * evaluate(g);
    if (depth == 0 || stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    final captures = g.generate_moves().where((m) => m.captured != null).toList()..sort((a, b) => _order(a) - _order(b));
    for (final m in captures) {
      g.make_move(m);
      final s = -_quiesce(g, -beta, -alpha, depth - 1);
      g.undo_move();
      if (s >= beta) return s;
      if (s > alpha) alpha = s;
    }
    return alpha;
  }

  static int _search(ch.Chess g, int depth, int alpha, int beta, bool quiesce) {
    final moves = g.generate_moves();
    if (moves.isEmpty) return g.in_check ? -100000 - depth : 0;
    if (depth == 0) return quiesce ? _quiesce(g, alpha, beta, 4) : (g.turn == ch.Color.WHITE ? 1 : -1) * evaluate(g);
    moves.sort((a, b) => _order(a) - _order(b));
    var best = -1 << 30;
    for (final m in moves) {
      g.make_move(m);
      final s = -_search(g, depth - 1, -beta, -alpha, quiesce);
      g.undo_move();
      if (s > best) best = s;
      if (s > alpha) alpha = s;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Pip's move for the side to move in [fen].
  static ch.Move? pickMove(String fen, GameDifficulty level, {Random? random}) {
    final rnd = random ?? Random();
    final g = ch.Chess.fromFEN(fen);
    final moves = g.generate_moves()..sort((a, b) => _order(a) - _order(b));
    if (moves.isEmpty) return null;
    final (depth, noise, quiesce) = switch (level) {
      GameDifficulty.easy => (1, 160, false),
      GameDifficulty.fair => (2, 25, true),
      GameDifficulty.tough => (3, 5, true),
    };
    ch.Move? best;
    var bestScore = -1 << 30;
    for (final m in moves) {
      g.make_move(m);
      final s = -_search(g, depth - 1, -1 << 30, 1 << 30, quiesce) + rnd.nextInt(noise + 1);
      g.undo_move();
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best;
  }

  /// [pickMove] off the UI thread (Tough can take a second or two).
  /// Returns (from, to, promotion) in algebraic form.
  static Future<(String, String, String?)?> pickInBackground(String fen, GameDifficulty level) async {
    (String, String, String?)? run() {
      final m = pickMove(fen, level);
      return m == null ? null : (m.fromAlgebraic, m.toAlgebraic, m.promotion?.name);
    }

    return kIsWeb ? run() : Isolate.run(run);
  }

  /// Plain-English name for a piece letter.
  static String pieceName(String letter) => switch (letter.toLowerCase()) {
        'p' => 'pawn',
        'n' => 'knight',
        'b' => 'bishop',
        'r' => 'rook',
        'q' => 'queen',
        _ => 'king',
      };
}
