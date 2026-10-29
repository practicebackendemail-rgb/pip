import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/domain/llm_provider.dart';
import '../../../../core/services/llm_error_messages.dart';
import '../../../../core/services/llm_registry_service.dart';
import '../../../../widgets/pip_params.dart';
import '../../../brains/data/pip_brains.dart';
import '../../../brains/domain/brain_routing.dart';
import '../../data/game_scores.dart';
import '../../domain/game_kind.dart';
import '../../domain/pip_banter.dart';
import '../../domain/twenty_questions.dart';
import '../widgets/arcade.dart';
import '../widgets/game_table.dart';
import '../widgets/game_voice.dart';

/// You think of something; Pip asks up to 20 yes/no questions to find it.
/// The questions come from your AI model (cloud or on-device).
class TwentyQuestionsScreen extends StatefulWidget {
  const TwentyQuestionsScreen({super.key});

  @override
  State<TwentyQuestionsScreen> createState() => _TwentyQuestionsScreenState();
}

enum _Phase { intro, asking, thinking, over }

class _TwentyQuestionsScreenState extends State<TwentyQuestionsScreen> {
  final _banter = PipBanter();
  TwentyQuestions _game = TwentyQuestions();
  _Phase _phase = _Phase.intro;
  Reaction _reaction = const Reaction(PipMood.excited, "Think of anything: an animal, an object, a famous person. Don't tell me! Tap Ready.", PipSoundCue.excited);
  int _reactionId = 0;
  int _you = 0, _pip = 0, _confetti = 0;
  String? _scoreLine;

  @override
  void initState() {
    super.initState();
    Arcade.sound(_reaction.sound);
    GameScores.load(GameKind.twentyQuestions).then((s) => mounted ? setState(() => _scoreLine = s.line) : null);
  }

  void _say(Reaction r) {
    Arcade.sound(r.sound);
    setState(() {
      _reaction = r;
      _reactionId++;
    });
  }

  Future<void> _ask() async {
    setState(() => _phase = _Phase.thinking);
    _say(_banter.react(GameEvent.pipThinking));
    try {
      final provider = PipBrains.instance.providerFor(BrainJob.commands, getIt<LlmRegistryService>());
      final reply = await provider.chat([LlmMessage(role: 'user', content: _game.prompt())]).timeout(const Duration(seconds: 40));
      if (!mounted) return;
      _game.readReply(reply.text);
      setState(() => _phase = _Phase.asking);
      _say(Reaction(_game.currentIsGuess ? PipMood.excited : PipMood.thinking, _game.currentQuestion!,
          _game.currentIsGuess ? PipSoundCue.excited : PipSoundCue.chirp));
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.asking);
      _say(Reaction(PipMood.unsure, e is BrainUnavailable ? e.message : describeLlmError(e), PipSoundCue.unsure));
    }
  }

  Future<void> _answer(Answer a) async {
    if (_phase != _Phase.asking || _game.currentQuestion == null) return;
    final wasGuess = _game.currentIsGuess;
    _game.answer(a);
    if (wasGuess && a == Answer.yes) return _end(pipWon: true);
    if (_game.outOfQuestions) return _end(pipWon: false);
    if (wasGuess) _say(const Reaction(PipMood.sad, 'Argh, not that! Let me keep going…', PipSoundCue.sad));
    await _ask();
  }

  Future<void> _end({required bool pipWon}) async {
    setState(() {
      _phase = _Phase.over;
      pipWon ? _pip++ : _you++;
      if (!pipWon) _confetti++;
    });
    _say(pipWon
        ? Reaction(PipMood.laughing, 'Got it in ${_game.asked.length}! My circuits are on fire today.', PipSoundCue.laugh)
        : const Reaction(PipMood.sad, "I'm out of questions. You stumped me! What was it?", PipSoundCue.sad));
    final s = await GameScores.record(GameKind.twentyQuestions, youWon: !pipWon);
    if (mounted) setState(() => _scoreLine = s.line);
  }

  void _restart() {
    setState(() {
      _game = TwentyQuestions();
      _phase = _Phase.intro;
    });
    _say(const Reaction(PipMood.excited, 'Okay, think of something new. Tap Ready when you have it.', PipSoundCue.excited));
  }

  void _heard(String text) {
    final a = TwentyQuestions.parse(text);
    if (a != null) _answer(a);
  }

  @override
  Widget build(BuildContext context) {
    return GameTable(
      title: '20 questions',
      accent: Arcade.teal,
      reaction: _reaction,
      reactionId: _reactionId,
      youScore: _you,
      pipScore: _pip,
      scoreLabel: _scoreLine,
      confetti: _confetti,
      onLeave: () => context.pop(),
      board: _QuestionLights(used: _game.asked.length, current: _phase == _Phase.asking || _phase == _Phase.thinking),
      controls: switch (_phase) {
        _Phase.intro => [ArcadeButton(label: 'Ready', icon: Icons.play_arrow_rounded, color: Arcade.teal, onPressed: _ask)],
        _Phase.thinking => const [],
        _Phase.asking => [
            ArcadeButton(label: 'Yes', color: Arcade.teal, onPressed: () => _answer(Answer.yes)),
            ArcadeButton(label: 'No', color: Arcade.pink, onPressed: () => _answer(Answer.no)),
            ArcadeButton(label: 'Maybe', color: Arcade.violet, onPressed: () => _answer(Answer.maybe)),
            GameMicButton(onHeard: _heard),
          ],
        _Phase.over => [ArcadeButton(label: 'Play again', icon: Icons.replay_rounded, color: Arcade.teal, onPressed: _restart)],
      },
    );
  }
}

/// Twenty lights; used ones dim, the current one glows.
class _QuestionLights extends StatelessWidget {
  final int used;
  final bool current;
  const _QuestionLights({required this.used, required this.current});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$used of ${TwentyQuestions.limit} questions used',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('QUESTION ${(used + 1).clamp(1, TwentyQuestions.limit)} / ${TwentyQuestions.limit}', style: Arcade.title(Arcade.teal, size: 18)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < TwentyQuestions.limit; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < used ? Arcade.muted.withValues(alpha: .35) : (i == used && current ? Arcade.teal : Arcade.panel),
                      border: Border.all(color: Arcade.teal.withValues(alpha: i < used ? .2 : .7)),
                      boxShadow: i == used && current ? Arcade.boxGlow(Arcade.teal) : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
