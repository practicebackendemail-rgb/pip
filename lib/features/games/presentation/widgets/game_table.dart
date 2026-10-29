import 'package:flutter/material.dart';
import '../../../../widgets/pip_companion.dart';
import '../../domain/pip_banter.dart';
import 'arcade.dart';
import 'confetti.dart';

/// The shared game screen: Pip in the opponent's seat at the top with its
/// speech bubble, the score, the board in the middle, controls at the bottom.
class GameTable extends StatelessWidget {
  final String title;
  final Color accent;
  final Reaction reaction;

  /// Bumps when Pip reacts, so the bubble pops and Pip hops.
  final int reactionId;
  final int youScore;
  final int pipScore;
  final String? scoreLabel;
  final Widget board;
  final List<Widget> controls;
  final int confetti;
  final VoidCallback onLeave;

  const GameTable({
    super.key,
    required this.title,
    required this.reaction,
    required this.reactionId,
    required this.youScore,
    required this.pipScore,
    required this.board,
    required this.onLeave,
    this.accent = Arcade.amber,
    this.controls = const [],
    this.confetti = 0,
    this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Arcade.night,
      body: ArcadeBackground(
        tint: accent == Arcade.teal ? Arcade.teal : Arcade.violet,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _TopBar(title: title, accent: accent, onLeave: onLeave),
                      _PipSeat(reaction: reaction, reactionId: reactionId),
                      _Scoreboard(you: youScore, pip: pipScore, label: scoreLabel, accent: accent),
                      const SizedBox(height: 10),
                      Expanded(child: Center(child: board)),
                      if (controls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 10, children: controls),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(child: ConfettiBurst(burst: confetti)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final Color accent;
  final VoidCallback onLeave;
  const _TopBar({required this.title, required this.accent, required this.onLeave});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Leave game',
              onPressed: onLeave,
              icon: const Icon(Icons.close_rounded, color: Arcade.muted),
            ),
            Expanded(
              child: Text(title.toUpperCase(), textAlign: TextAlign.center, style: Arcade.title(accent, size: 20)),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );
}

/// Pip, hopping when it reacts, with a speech bubble that pops in.
class _PipSeat extends StatelessWidget {
  final Reaction reaction;
  final int reactionId;
  const _PipSeat({required this.reaction, required this.reactionId});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(reactionId),
            tween: Tween(begin: still ? 0 : 1, end: 0),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.translate(offset: Offset(0, -14 * v), child: child),
            child: PipDeskCompanion(mood: reaction.mood, width: 170, height: 130),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 260),
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  alignment: Alignment.centerLeft,
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: _Bubble(key: ValueKey(reactionId), text: reaction.line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: 'Pip says $text',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: Arcade.boxGlow(Colors.white, strength: .3),
          ),
          child: Text(text, style: const TextStyle(color: Arcade.night, fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
        ),
      );
}

class _Scoreboard extends StatelessWidget {
  final int you;
  final int pip;
  final String? label;
  final Color accent;
  const _Scoreboard({required this.you, required this.pip, required this.accent, this.label});

  Widget _num(int v, Color c) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
        child: Text('$v', key: ValueKey(v), style: Arcade.title(c, size: 34)),
      );

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Score: you $you, Pip $pip',
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('YOU ', style: Arcade.title(Arcade.amber, size: 14)),
                _num(you, Arcade.amber),
                Text('  :  ', style: Arcade.title(Arcade.muted, size: 22)),
                _num(pip, Arcade.teal),
                Text(' PIP', style: Arcade.title(Arcade.teal, size: 14)),
              ],
            ),
            if (label != null) Text(label!, style: const TextStyle(color: Arcade.muted, fontSize: 12, letterSpacing: 1)),
          ],
        ),
      );
}
