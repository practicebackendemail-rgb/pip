import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../data/game_scores.dart';
import '../../domain/game_kind.dart';
import '../../domain/pip_banter.dart';
import '../../domain/rock_paper_scissors.dart';
import '../widgets/arcade.dart';
import '../widgets/game_table.dart';
import '../widgets/game_voice.dart';

/// Rock paper scissors, first to three. Pick (or say) a hand, Pip counts
/// "rock, paper, scissors, shoot!" and both hands flip up together.
class RpsScreen extends StatefulWidget {
  const RpsScreen({super.key});

  @override
  State<RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<RpsScreen> {
  final _banter = PipBanter();
  RockPaperScissors _game = RockPaperScissors();
  GameDifficulty _level = GameDifficulty.fair;
  late Reaction _reaction = _banter.react(GameEvent.start);
  int _reactionId = 0;
  String? _count;
  Hand? _yours, _pips;
  RoundResult? _result;
  bool _busy = false;
  int _confetti = 0;
  String? _scoreLine;

  static const _icons = {Hand.rock: Icons.sports_mma_rounded, Hand.paper: Icons.back_hand_rounded, Hand.scissors: Icons.content_cut_rounded};

  @override
  void initState() {
    super.initState();
    Arcade.sound(_reaction.sound);
    GameScores.difficulty().then((d) => _level = d);
    GameScores.load(GameKind.rockPaperScissors).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
  }

  void _react(GameEvent e) {
    final r = _banter.react(e);
    Arcade.sound(r.sound);
    setState(() {
      _reaction = r;
      _reactionId++;
    });
  }

  Future<void> _throw(Hand hand) async {
    if (_busy || _game.over) return;
    final pips = _game.pipPick(_level);
    setState(() {
      _busy = true;
      _yours = null;
      _pips = null;
      _result = null;
    });
    for (final word in ['ROCK', 'PAPER', 'SCISSORS', 'SHOOT!']) {
      if (!mounted) return;
      PipSfxService.blip();
      setState(() => _count = word);
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
    if (!mounted) return;
    final result = _game.play(hand, pips);
    setState(() {
      _count = null;
      _yours = hand;
      _pips = pips;
      _result = result;
      _busy = false;
    });
    if (_game.over) {
      final youWon = _game.you > _game.pip;
      if (youWon) setState(() => _confetti++);
      _react(youWon ? GameEvent.youWin : GameEvent.pipWins);
      final s = await GameScores.record(GameKind.rockPaperScissors, youWon: youWon);
      if (mounted) setState(() => _scoreLine = s.line);
    } else {
      _react(switch (result) {
        RoundResult.youWin => GameEvent.roundYouWin,
        RoundResult.pipWins => GameEvent.roundPipWins,
        RoundResult.tie => GameEvent.roundTie,
      });
    }
  }

  void _rematch() {
    setState(() {
      _game = RockPaperScissors();
      _yours = _pips = null;
      _result = null;
    });
    _react(GameEvent.rematch);
  }

  void _heard(String text) {
    final h = Hand.parse(text);
    if (h != null) _throw(h);
  }

  @override
  Widget build(BuildContext context) {
    return GameTable(
      title: 'Rock paper scissors',
      accent: Arcade.pink,
      reaction: _reaction,
      reactionId: _reactionId,
      youScore: _game.you,
      pipScore: _game.pip,
      scoreLabel: _scoreLine == null ? 'First to 3' : 'First to 3 · $_scoreLine',
      confetti: _confetti,
      onLeave: () => context.pop(),
      board: _arena(),
      controls: _game.over
          ? [ArcadeButton(label: 'Rematch', icon: Icons.replay_rounded, color: Arcade.pink, onPressed: _rematch)]
          : [
              for (final h in Hand.values)
                _HandButton(icon: _icons[h]!, label: h.name, onTap: _busy ? null : () => _throw(h)),
              GameMicButton(onHeard: _heard, color: Arcade.pink),
            ],
    );
  }

  Widget _arena() {
    if (_count != null) {
      return TweenAnimationBuilder<double>(
        key: ValueKey(_count),
        tween: Tween(begin: 1.8, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: Text(_count!, style: Arcade.title(_count == 'SHOOT!' ? Arcade.pink : Arcade.amber, size: 44)),
      );
    }
    if (_yours == null) {
      return Text(_game.you + _game.pip == 0 ? 'PICK YOUR HAND' : 'NEXT ROUND', style: Arcade.title(Arcade.muted, size: 22));
    }
    Color glow(bool winner) => winner ? Arcade.amber : Arcade.muted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Reveal(icon: _icons[_yours]!, label: 'YOU', color: glow(_result == RoundResult.youWin), accent: Arcade.amber),
        Text('VS', style: Arcade.title(Arcade.pink, size: 26)),
        _Reveal(icon: _icons[_pips]!, label: 'PIP', color: glow(_result == RoundResult.pipWins), accent: Arcade.teal),
      ],
    );
  }
}

class _HandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _HandButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => ArcadeButton(label: label, icon: icon, color: Arcade.amber, onPressed: onTap);
}

/// A hand that flips up into view.
class _Reveal extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color accent;
  const _Reveal({required this.icon, required this.label, required this.color, required this.accent});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .002)
          ..rotateX((1 - v) * 1.4),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Semantics(
        label: '$label played ${icon == Icons.sports_mma_rounded ? 'rock' : icon == Icons.back_hand_rounded ? 'paper' : 'scissors'}',
        child: NeonPanel(
          color: color == Arcade.muted ? accent.withValues(alpha: .4) : accent,
          glow: color == Arcade.muted ? .2 : 1.2,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: accent, shadows: Arcade.glow(accent)),
              const SizedBox(height: 6),
              Text(label, style: Arcade.title(accent, size: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
