import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/game_scores.dart';
import '../../data/pip_quips.dart';
import '../../domain/four_in_row.dart';
import '../../domain/game_kind.dart';
import '../../domain/pip_banter.dart';
import '../widgets/arcade.dart';
import '../widgets/game_table.dart';
import '../widgets/game_voice.dart';

/// Four in a row against Pip. You're amber, Pip is teal. Players take turns
/// starting each round.
class FourInRowScreen extends StatefulWidget {
  const FourInRowScreen({super.key});

  @override
  State<FourInRowScreen> createState() => _FourInRowScreenState();
}

class _FourInRowScreenState extends State<FourInRowScreen> {
  FourInRow _board = FourInRow();
  GameDifficulty _level = GameDifficulty.fair;
  late final PipGameHost _host = PipGameHost(game: 'Four in a row', onChange: _refresh, opening: PipBanter().react(GameEvent.start));
  int _you = 0, _pip = 0, _round = 1;
  (int, int)? _lastDrop;
  List<(int, int)> _winLine = const [];
  bool _pipTurn = false;
  bool _over = false;
  int _confetti = 0;
  String? _scoreLine;

  @override
  void initState() {
    super.initState();
    Arcade.sound(_host.reaction.sound);
    GameScores.difficulty().then((d) => _level = d);
    GameScores.load(GameKind.fourInRow).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _react(GameEvent e, {String? situation}) => Arcade.sound(_host.react(e, situation: situation).sound);

  /// What's going on, for Pip's AI lines.
  String _situation(String what) =>
      '$what Round $_round; rounds won so far: user $_you, Pip $_pip. Pip is playing on ${_level.name}.';

  void _play(int col) {
    if (_pipTurn || _over || !_board.canDrop(col)) return;
    final row = _board.drop(col, FourInRow.you);
    setState(() => _lastDrop = (row, col));
    if (_finishIfOver()) return;
    _board.winningMoves(FourInRow.you).isNotEmpty
        ? _react(GameEvent.youThreaten, situation: _situation('The user just set up a winning move Pip did not see coming.'))
        : _react(GameEvent.yourMove);
    _pipPlays();
  }

  Future<void> _pipPlays() async {
    setState(() => _pipTurn = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    _react(GameEvent.pipThinking);
    final blocking = _board.winningMoves(FourInRow.you);
    // Let the thinking face show; the search itself is quick.
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    final col = _board.pipMove(_level);
    final row = _board.drop(col, FourInRow.pip);
    setState(() {
      _lastDrop = (row, col);
      _pipTurn = false;
    });
    if (_finishIfOver()) return;
    if (blocking.contains(col)) {
      _react(GameEvent.pipBlocks, situation: _situation('Pip just blocked the user from winning.'));
    } else if (_board.winningMoves(FourInRow.pip).isNotEmpty) {
      _react(GameEvent.pipThreatens, situation: _situation('Pip is now one disc away from winning.'));
    } else {
      _react(GameEvent.pipMove);
    }
  }

  bool _finishIfOver() {
    final line = _board.winningLine();
    final w = _board.winner;
    if (w == null && !_board.isFull) return false;
    setState(() {
      _over = true;
      _winLine = line ?? const [];
      if (w == FourInRow.you) {
        _you++;
        _confetti++;
      } else if (w == FourInRow.pip) {
        _pip++;
      }
    });
    final moves = _board.cells.expand((r) => r).where((c) => c != 0).length;
    _react(
      w == FourInRow.you ? GameEvent.youWin : w == FourInRow.pip ? GameEvent.pipWins : GameEvent.draw,
      situation: _situation(w == FourInRow.you
          ? 'The user just beat Pip after $moves discs.'
          : w == FourInRow.pip
              ? 'Pip just won after $moves discs.'
              : 'The board filled up: a draw.'),
    );
    GameScores.record(GameKind.fourInRow, youWon: w == null ? null : w == FourInRow.you)
        .then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
    return true;
  }

  void _rematch() {
    setState(() {
      _board = FourInRow();
      _over = false;
      _winLine = const [];
      _lastDrop = null;
      _round++;
    });
    _react(GameEvent.rematch);
    if (_round.isEven) _pipPlays();
  }

  void _heard(String text) {
    final col = parseColumn(text, FourInRow.cols);
    if (col != null) _play(col);
  }

  @override
  Widget build(BuildContext context) {
    return GameTable(
      title: 'Four in a row',
      reaction: _host.reaction,
      reactionId: _host.id,
      youScore: _you,
      pipScore: _pip,
      scoreLabel: _scoreLine,
      confetti: _confetti,
      onLeave: () => context.pop(),
      board: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _Board(board: _board, lastDrop: _lastDrop, winLine: _winLine, enabled: !_pipTurn && !_over, onColumn: _play),
      ),
      controls: [
        if (_over) ArcadeButton(label: 'Rematch', icon: Icons.replay_rounded, onPressed: _rematch),
        if (!_over) GameMicButton(onHeard: _heard),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  final FourInRow board;
  final (int, int)? lastDrop;
  final List<(int, int)> winLine;
  final bool enabled;
  final ValueChanged<int> onColumn;
  const _Board({required this.board, required this.lastDrop, required this.winLine, required this.enabled, required this.onColumn});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: FourInRow.cols / (FourInRow.rows + .35),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2C66),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Arcade.violet, width: 2),
          boxShadow: Arcade.boxGlow(Arcade.violet, strength: .8),
        ),
        child: Row(
          children: [
            for (var c = 0; c < FourInRow.cols; c++)
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Column ${c + 1}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled && board.canDrop(c) ? () => onColumn(c) : null,
                    child: Column(
                      children: [
                        for (var r = 0; r < FourInRow.rows; r++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _Cell(
                                who: board.cells[r][c],
                                row: r,
                                dropping: lastDrop == (r, c),
                                winning: winLine.contains((r, c)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A hole, or a disc that falls in with a bounce and pulses if it won.
class _Cell extends StatelessWidget {
  final int who;
  final int row;
  final bool dropping;
  final bool winning;
  const _Cell({required this.who, required this.row, required this.dropping, required this.winning});

  @override
  Widget build(BuildContext context) {
    final hole = Container(
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B1230)),
    );
    if (who == 0) return hole;
    final color = who == FourInRow.you ? Arcade.amber : Arcade.teal;
    Widget disc = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, .45)!, color], center: const Alignment(-.3, -.4)),
        boxShadow: winning ? Arcade.boxGlow(color, strength: 1.2) : null,
      ),
    );
    if (winning && !MediaQuery.disableAnimationsOf(context)) disc = _Pulse(child: disc);
    if (dropping && !MediaQuery.disableAnimationsOf(context)) {
      disc = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: Duration(milliseconds: 260 + row * 60),
        curve: Curves.bounceOut,
        builder: (context, v, child) => FractionalTranslation(translation: Offset(0, -(row + 1.0) * v), child: child),
        child: disc,
      );
    }
    return Stack(fit: StackFit.expand, children: [hole, disc]);
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: Tween(begin: .88, end: 1.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}
