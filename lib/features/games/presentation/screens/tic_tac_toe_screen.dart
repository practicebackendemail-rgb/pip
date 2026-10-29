import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/game_scores.dart';
import '../../data/pip_quips.dart';
import '../../domain/game_kind.dart';
import '../../domain/pip_banter.dart';
import '../../domain/tic_tac_toe.dart';
import '../widgets/arcade.dart';
import '../widgets/game_table.dart';
import '../widgets/game_voice.dart';

/// Tic-tac-toe (X-O) against Pip. You're amber X, Pip is teal O; marks
/// draw themselves in with neon strokes and the winning line slashes across.
class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  TicTacToe _board = TicTacToe();
  GameDifficulty _level = GameDifficulty.fair;
  late final PipGameHost _host = PipGameHost(game: 'Tic-tac-toe', onChange: _refresh, opening: PipBanter().react(GameEvent.start));
  int _you = 0, _pip = 0, _round = 1, _confetti = 0;
  bool _pipTurn = false, _over = false;
  List<int>? _winLine;
  String? _scoreLine;

  @override
  void initState() {
    super.initState();
    Arcade.sound(_host.reaction.sound);
    GameScores.difficulty().then((d) => _level = d);
    GameScores.load(GameKind.ticTacToe).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _react(GameEvent e, {String? situation}) => Arcade.sound(_host.react(e, situation: situation).sound);

  String _situation(String what) => '$what Round $_round; rounds won: user $_you, Pip $_pip. Pip plays on ${_level.name}.';

  void _play(int i) {
    if (_pipTurn || _over || !_board.place(i, TicTacToe.you)) return;
    setState(() {});
    if (_finishIfOver()) return;
    _board.winningMoves(TicTacToe.you).isNotEmpty
        ? _react(GameEvent.youThreaten, situation: _situation('The user has two in a row and could win next move.'))
        : _react(GameEvent.yourMove);
    _pipPlays();
  }

  Future<void> _pipPlays() async {
    setState(() => _pipTurn = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _react(GameEvent.pipThinking);
    final blocking = _board.winningMoves(TicTacToe.you);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final i = _board.pipMove(_level);
    _board.place(i, TicTacToe.pip);
    setState(() => _pipTurn = false);
    if (_finishIfOver()) return;
    if (blocking.contains(i)) {
      _react(GameEvent.pipBlocks, situation: _situation('Pip just blocked the user from completing a line.'));
    } else if (_board.winningMoves(TicTacToe.pip).isNotEmpty) {
      _react(GameEvent.pipThreatens, situation: _situation('Pip has two in a row and could win next move.'));
    } else {
      _react(GameEvent.pipMove);
    }
  }

  bool _finishIfOver() {
    final w = _board.winner;
    if (w == null && !_board.isFull) return false;
    setState(() {
      _over = true;
      _winLine = _board.winningLine();
      if (w == TicTacToe.you) {
        _you++;
        _confetti++;
      } else if (w == TicTacToe.pip) {
        _pip++;
      }
    });
    _react(
      w == TicTacToe.you ? GameEvent.youWin : w == TicTacToe.pip ? GameEvent.pipWins : GameEvent.draw,
      situation: _situation(w == TicTacToe.you
          ? 'The user just beat Pip at tic-tac-toe.'
          : w == TicTacToe.pip
              ? 'Pip just won at tic-tac-toe.'
              : 'Cat\'s game: a draw.'),
    );
    GameScores.record(GameKind.ticTacToe, youWon: w == null ? null : w == TicTacToe.you)
        .then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
    return true;
  }

  void _rematch() {
    setState(() {
      _board = TicTacToe();
      _over = false;
      _winLine = null;
      _round++;
    });
    _react(GameEvent.rematch);
    if (_round.isEven) _pipPlays();
  }

  void _heard(String text) {
    final i = parseSquare(text);
    if (i != null) _play(i);
  }

  @override
  Widget build(BuildContext context) {
    return GameTable(
      title: 'Tic-tac-toe',
      accent: Arcade.amber,
      reaction: _host.reaction,
      reactionId: _host.id,
      youScore: _you,
      pipScore: _pip,
      scoreLabel: _scoreLine,
      confetti: _confetti,
      onLeave: () => context.pop(),
      board: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: AspectRatio(
          aspectRatio: 1,
          child: NeonPanel(
            color: Arcade.violet,
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < 9; i++)
                      Semantics(
                        button: _board.cells[i] == 0,
                        label: 'Square ${i + 1}, ${switch (_board.cells[i]) { 1 => 'X', 2 => 'O', _ => 'empty' }}',
                        child: GestureDetector(
                          onTap: () => _play(i),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Arcade.night.withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Arcade.violet.withValues(alpha: .35)),
                            ),
                            child: _board.cells[i] == 0
                                ? null
                                : _Mark(key: ValueKey('$_round-$i'), isX: _board.cells[i] == TicTacToe.you, glow: _winLine?.contains(i) ?? false),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_winLine != null) Positioned.fill(child: IgnorePointer(child: _WinSlash(line: _winLine!))),
              ],
            ),
          ),
        ),
      ),
      controls: [
        if (_over) ArcadeButton(label: 'Rematch', icon: Icons.replay_rounded, onPressed: _rematch),
        if (!_over) GameMicButton(onHeard: _heard, color: Arcade.amber),
      ],
    );
  }
}

/// "top left", "centre", "bottom right", "square 5" → 0..8.
int? parseSquare(String text) {
  final t = text.toLowerCase();
  final n = RegExp(r'\b([1-9])\b').firstMatch(t);
  if (n != null) return int.parse(n.group(1)!) - 1;
  final row = t.contains('top') || t.contains('upper')
      ? 0
      : t.contains('bottom') || t.contains('lower')
          ? 2
          : (t.contains('middle') || t.contains('center') || t.contains('centre')) ? 1 : null;
  final col = t.contains('left') ? 0 : t.contains('right') ? 2 : (row != null ? 1 : null);
  if (row == null && col == null) return null;
  return (row ?? 1) * 3 + (col ?? 1);
}

/// An X or O that draws itself in.
class _Mark extends StatelessWidget {
  final bool isX;
  final bool glow;
  const _Mark({super.key, required this.isX, required this.glow});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(painter: _MarkPainter(isX: isX, t: t, glow: glow)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final bool isX;
  final double t;
  final bool glow;
  _MarkPainter({required this.isX, required this.t, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = isX ? Arcade.amber : Arcade.teal;
    final w = size.shortestSide;
    final pad = w * .24;
    final r = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    for (final (width, alpha, blur) in [(w * .16, glow ? .55 : .3, 8.0), (w * .09, 1.0, 0.0)]) {
      final p = Paint()
        ..color = c.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      if (isX) {
        final a = (t * 2).clamp(0.0, 1.0), b = (t * 2 - 1).clamp(0.0, 1.0);
        canvas.drawLine(r.topLeft, Offset.lerp(r.topLeft, r.bottomRight, a)!, p);
        if (b > 0) canvas.drawLine(r.topRight, Offset.lerp(r.topRight, r.bottomLeft, b)!, p);
      } else {
        canvas.drawArc(r, -1.57, 6.283 * t, false, p);
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.t != t || o.glow != glow;
}

/// The line through the winning three.
class _WinSlash extends StatelessWidget {
  final List<int> line;
  const _WinSlash({required this.line});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 380),
        builder: (context, t, _) => CustomPaint(painter: _SlashPainter(line, t)),
      );
}

class _SlashPainter extends CustomPainter {
  final List<int> line;
  final double t;
  _SlashPainter(this.line, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    Offset centre(int i) => Offset((i % 3 + .5) * size.width / 3, (i ~/ 3 + .5) * size.height / 3);
    final a = centre(line.first), b = centre(line.last);
    final d = (b - a) * .18;
    final from = a - d, to = Offset.lerp(a - d, b + d, t)!;
    canvas.drawLine(from, to,
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(from, to,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SlashPainter o) => o.t != t;
}
