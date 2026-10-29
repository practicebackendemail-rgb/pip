import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../../../widgets/pip_companion.dart';
import '../../data/game_scores.dart';
import '../../domain/game_kind.dart';
import '../widgets/arcade.dart';

/// Pip's arcade: pick a game and how hard Pip plays.
class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  Map<GameKind, GameScore> _scores = const {};
  GameDifficulty _level = GameDifficulty.fair;
  bool _smart = true;
  String? _stumped;

  @override
  void initState() {
    super.initState();
    PipSfxService.excited();
    _load();
  }

  Future<void> _load() async {
    final scores = await GameScores.loadAll();
    final level = await GameScores.difficulty();
    final smart = await GameScores.smartBanter();
    final stumped = await GameScores.lastStumped();
    if (!mounted) return;
    setState(() {
      _scores = scores;
      _level = level;
      _smart = smart;
      _stumped = stumped;
    });
  }

  String get _greeting {
    final tease = _stumped == null ? '' : ' Still thinking about "$_stumped" from 20 questions…';
    return _scoreGreeting + tease;
  }

  String get _scoreGreeting {
    final total = _scores.values.fold((0, 0), (a, s) => (a.$1 + s.you, a.$2 + s.pip));
    if (total.$1 + total.$2 == 0) return "Game time! Pick one and I'll show you how it works.";
    if (total.$1 > total.$2) return "You're ${total.$1}–${total.$2} up overall. I want revenge!";
    if (total.$2 > total.$1) return "I'm ${total.$2}–${total.$1} up. Feeling brave?";
    return "We're tied at ${total.$1} each. Tiebreaker?";
  }

  static const _cards = <(GameKind, String, String, IconData, Color)>[
    (GameKind.fourInRow, 'Four in a row', 'Drop discs, line up four', Icons.grid_view_rounded, Arcade.amber),
    (GameKind.rockPaperScissors, 'Rock paper scissors', 'Best of five, tap or shout', Icons.back_hand_rounded, Arcade.pink),
    (GameKind.twentyQuestions, '20 questions', 'Think of a thing. Pip guesses.', Icons.psychology_alt_rounded, Arcade.teal),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Arcade.night,
      body: ArcadeBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
                        icon: const Icon(Icons.arrow_back_rounded, color: Arcade.muted),
                      ),
                    ],
                  ),
                  Text('PIP ARCADE', textAlign: TextAlign.center, style: Arcade.title(Arcade.amber, size: 34)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const PipDeskCompanion(mood: PipMood.excited, width: 150, height: 115),
                      Expanded(
                        child: Text(_greeting,
                            style: const TextStyle(color: Arcade.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (i, (kind, name, detail, icon, color)) in _cards.indexed)
                    _EnterAnimation(
                      delay: Duration(milliseconds: 90 * i),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GameCard(
                          name: name,
                          detail: detail,
                          icon: icon,
                          color: color,
                          score: _scores[kind],
                          onTap: () => context.push(AppRoutes.game(kind.slug)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text('PIP PLAYS', textAlign: TextAlign.center, style: Arcade.title(Arcade.muted, size: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final d in GameDifficulty.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: ArcadeButton(
                            label: d.name,
                            fontSize: 13,
                            color: d == _level ? Arcade.amber : Arcade.panel,
                            onPressed: () {
                              setState(() => _level = d);
                              GameScores.setDifficulty(d);
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    toggled: _smart,
                    label: 'Smart banter',
                    child: SwitchListTile(
                      value: _smart,
                      activeThumbColor: Arcade.amber,
                      title: Text('SMART BANTER', style: Arcade.title(Arcade.text, size: 13).copyWith(shadows: const [])),
                      subtitle: const Text(
                        'At big moments Pip asks your AI model for a fresh line. Off: written lines only, never uses your quota.',
                        style: TextStyle(color: Arcade.muted, fontSize: 12),
                      ),
                      onChanged: (on) {
                        setState(() => _smart = on);
                        GameScores.setSmartBanter(on);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String name;
  final String detail;
  final IconData icon;
  final Color color;
  final GameScore? score;
  final VoidCallback onTap;
  const _GameCard({required this.name, required this.detail, required this.icon, required this.color, required this.onTap, this.score});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name. $detail',
      child: GestureDetector(
        onTap: () {
          PipSfxService.chirp();
          onTap();
        },
        child: NeonPanel(
          color: color,
          glow: .7,
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: .6)),
                ),
                child: Icon(icon, color: color, size: 32, shadows: Arcade.glow(color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toUpperCase(), style: Arcade.title(Arcade.text, size: 16).copyWith(shadows: const [])),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: Arcade.muted, fontSize: 13)),
                    if (score != null && score!.played > 0) ...[
                      const SizedBox(height: 4),
                      Text(score!.line, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: color, size: 34, shadows: Arcade.glow(color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides a card up and in after [delay].
class _EnterAnimation extends StatelessWidget {
  final Duration delay;
  final Widget child;
  const _EnterAnimation({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = const Duration(milliseconds: 420) + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = Curves.easeOutBack.transform(((v - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child));
      },
      child: child,
    );
  }
}
