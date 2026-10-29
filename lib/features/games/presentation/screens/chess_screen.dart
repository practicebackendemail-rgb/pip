import 'dart:async';
import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/pip_params.dart';
import '../../data/game_scores.dart';
import '../../data/pip_quips.dart';
import '../../domain/chess_ai.dart';
import '../../domain/game_kind.dart';
import '../../domain/pip_banter.dart';
import '../widgets/arcade.dart';
import '../widgets/chess_board.dart';
import '../widgets/game_table.dart';
import '../widgets/game_voice.dart';

/// Chess against Pip. You're white (amber), Pip is black (teal). Tap a
/// piece to see where it can go, tap a glowing square to move, or say
/// "e2 to e4" / "knight f3".
class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  ch.Chess _game = ch.Chess();
  GameDifficulty _level = GameDifficulty.fair;
  late final PipGameHost _host = PipGameHost(
    game: 'Chess',
    onChange: _refresh,
    opening: const Reaction(PipMood.excited, "Chess! You're white, so you go first. Tap a piece to see its moves.", PipSoundCue.excited),
  );
  int _you = 0, _pip = 0, _confetti = 0;
  String? _selected;
  (String, String)? _lastMove;
  bool _pipTurn = false, _over = false;
  final List<String> _takenByYou = [], _takenByPip = [];
  String? _scoreLine;

  @override
  void initState() {
    super.initState();
    Arcade.sound(_host.reaction.sound);
    GameScores.difficulty().then((d) => _level = d);
    GameScores.load(GameKind.chess).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _react(GameEvent e, {String? situation}) => Arcade.sound(_host.react(e, situation: situation).sound);

  String _material() {
    int sum(List<String> l) => l.fold(0, (a, p) => a + const {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9}[p]!);
    final d = sum(_takenByYou) - sum(_takenByPip);
    return d == 0 ? 'Material is level.' : d > 0 ? 'The user is $d points of material up.' : 'Pip is ${-d} points of material up.';
  }

  /// Squares the selected piece can move to.
  Set<String> get _targets {
    final from = _selected;
    if (from == null) return const {};
    return {
      for (final m in _game.generate_moves())
        if (m.fromAlgebraic == from) m.toAlgebraic
    };
  }

  Future<void> _tap(String square) async {
    if (_pipTurn || _over) return;
    final piece = _game.get(square);
    if (_selected != null && _targets.contains(square)) {
      await _move(_selected!, square);
      return;
    }
    setState(() => _selected = piece != null && piece.color == ch.Color.WHITE ? square : null);
  }

  Future<void> _move(String from, String to) async {
    String? promotion;
    final piece = _game.get(from);
    if (piece?.type == ch.PieceType.PAWN && to.endsWith('8')) {
      promotion = await showPromotionPicker(context);
      if (promotion == null) return;
    }
    final captured = _game.get(to)?.type.name ?? (piece?.type == ch.PieceType.PAWN && from[0] != to[0] ? 'p' : null);
    final ok = _game.move({'from': from, 'to': to, 'promotion': ?promotion});
    if (!ok) return;
    setState(() {
      _selected = null;
      _lastMove = (from, to);
      if (captured != null) _takenByYou.add(captured);
    });
    if (_finishIfOver()) return;
    if (_game.in_check) {
      _react(GameEvent.youCheck, situation: 'The user just put Pip in check with ${ChessAi.pieceName(piece!.type.name)} to $to. ${_material()}');
    } else if (captured != null) {
      final big = captured == 'q' || captured == 'r';
      _react(GameEvent.youCapture,
          situation: big ? 'The user just took Pip\'s ${ChessAi.pieceName(captured)} on $to. ${_material()}' : null);
    } else {
      _react(GameEvent.yourMove);
    }
    await _pipPlays();
  }

  Future<void> _pipPlays() async {
    setState(() => _pipTurn = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _react(GameEvent.pipThinking);
    final started = DateTime.now();
    final pick = await ChessAi.pickInBackground(_game.fen, _level);
    final wait = const Duration(milliseconds: 700) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted || pick == null) return;
    final (from, to, promo) = pick;
    final captured = _game.get(to)?.type.name ?? (_game.get(from)?.type == ch.PieceType.PAWN && from[0] != to[0] ? 'p' : null);
    final mover = _game.get(from)!.type.name;
    _game.move({'from': from, 'to': to, 'promotion': ?promo});
    setState(() {
      _pipTurn = false;
      _lastMove = (from, to);
      if (captured != null) _takenByPip.add(captured);
    });
    if (_finishIfOver()) return;
    if (_game.in_check) {
      _react(GameEvent.pipChecks, situation: 'Pip just put the user in check with its ${ChessAi.pieceName(mover)} on $to. ${_material()}');
    } else if (captured != null) {
      final big = captured == 'q' || captured == 'r';
      _react(GameEvent.pipCaptures,
          situation: big ? 'Pip just took the user\'s ${ChessAi.pieceName(captured)} on $to. ${_material()}' : null);
    } else {
      _react(GameEvent.pipMove);
    }
  }

  bool _finishIfOver() {
    if (!_game.game_over) return false;
    final mate = _game.in_checkmate;
    final youWon = mate && _game.turn == ch.Color.BLACK;
    final pipWon = mate && _game.turn == ch.Color.WHITE;
    setState(() {
      _over = true;
      _selected = null;
      if (youWon) {
        _you++;
        _confetti++;
      } else if (pipWon) {
        _pip++;
      }
    });
    final how = mate ? 'checkmate' : _game.in_stalemate ? 'stalemate' : 'a draw';
    final moves = _game.move_number;
    _react(
      youWon ? GameEvent.youWin : pipWon ? GameEvent.pipWins : GameEvent.draw,
      situation: '${youWon ? 'The user beat Pip' : pipWon ? 'Pip beat the user' : 'The game ended in $how'} by $how on move $moves.',
    );
    GameScores.record(GameKind.chess, youWon: mate ? youWon : null).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
    return true;
  }

  /// Takes back your last move and Pip's reply.
  void _takeBack() {
    if (_pipTurn || _over || _game.history.length < 2) return;
    _game.undo_move();
    _game.undo_move();
    setState(() {
      _selected = null;
      _lastMove = null;
      // Rebuild captured lists from the remaining history.
      _takenByYou.clear();
      _takenByPip.clear();
      for (final st in _game.history) {
        final cap = st.move.captured?.name;
        if (cap != null) (st.move.color == ch.Color.WHITE ? _takenByYou : _takenByPip).add(cap);
      }
    });
    _host.say(const Reaction(PipMood.happy, "Take-back granted. I'm generous like that.", PipSoundCue.chirp));
  }

  void _newGame() {
    setState(() {
      _game = ch.Chess();
      _over = false;
      _selected = null;
      _lastMove = null;
      _takenByYou.clear();
      _takenByPip.clear();
    });
    _react(GameEvent.rematch);
  }

  void _heard(String text) {
    final squares = RegExp(r'\b([a-h])\s?([1-8])\b').allMatches(text.toLowerCase()).map((m) => '${m[1]}${m[2]}').toList();
    if (squares.length >= 2) {
      _move(squares[0], squares[1]);
      return;
    }
    if (squares.length == 1) {
      final to = squares.single;
      final named = RegExp(r'\b(pawn|knight|bishop|rook|queen|king)\b').firstMatch(text.toLowerCase())?.group(1);
      final candidates = _game.generate_moves().where((m) =>
          m.toAlgebraic == to && (named == null ? m.piece.name == 'p' : ChessAi.pieceName(m.piece.name) == named));
      if (candidates.length == 1) _move(candidates.single.fromAlgebraic, to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkSquare = _game.in_check ? ch.Chess.algebraic(_game.kings[_game.turn]) : null;
    return GameTable(
      title: 'Chess',
      accent: Arcade.violet,
      reaction: _host.reaction,
      reactionId: _host.id,
      youScore: _you,
      pipScore: _pip,
      scoreLabel: _scoreLine,
      confetti: _confetti,
      onLeave: () => context.pop(),
      board: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CapturedRow(pieces: _takenByPip, white: true),
            Flexible(
              child: ChessBoardView(
                game: _game,
                selected: _selected,
                targets: _targets,
                lastMove: _lastMove,
                checkSquare: checkSquare,
                onTap: _tap,
              ),
            ),
            CapturedRow(pieces: _takenByYou, white: false),
          ],
        ),
      ),
      controls: [
        if (_over) ArcadeButton(label: 'New game', icon: Icons.replay_rounded, color: Arcade.violet, onPressed: _newGame),
        if (!_over) ...[
          ArcadeButton(label: 'Take back', icon: Icons.undo_rounded, color: Arcade.panel, onPressed: _game.history.length >= 2 && !_pipTurn ? _takeBack : null),
          GameMicButton(onHeard: _heard, color: Arcade.violet),
        ],
      ],
    );
  }
}
