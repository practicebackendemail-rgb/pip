import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/games/data/game_scores.dart';
import 'package:personal_assistant/features/games/data/pip_quips.dart';
import 'package:personal_assistant/features/games/domain/pip_banter.dart';
import 'package:personal_assistant/widgets/pip_params.dart';
import 'package:shared_preferences/shared_preferences.dart';

const opening = Reaction(PipMood.idle, 'Hi', PipSoundCue.none);

PipGameHost host(Future<String?> Function(String) ask, {void Function()? onChange}) =>
    PipGameHost(game: 'Four in a row', onChange: onChange ?? () {}, opening: opening, ask: ask);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a quick AI line replaces the written one, keeping the face', () async {
    final h = host((_) async => '"Blocked again? You make this too easy!"');
    final written = h.react(GameEvent.pipBlocks, situation: 'Pip blocked the user.');
    expect(h.reaction.line, written.line);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.reaction.line, 'Blocked again? You make this too easy!');
    expect(h.reaction.mood, written.mood);
  });

  test('ordinary moves never ask the model', () async {
    var asked = 0;
    final h = host((_) async {
      asked++;
      return 'x';
    });
    h.react(GameEvent.yourMove, situation: 'The user moved.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(asked, 0);
  });

  test('a late line is dropped if something newer happened', () async {
    final h = host((_) => Future.delayed(const Duration(milliseconds: 50), () => 'Too late!'));
    h.react(GameEvent.pipThreatens, situation: 'Pip is one away.');
    h.react(GameEvent.yourMove);
    final current = h.reaction.line;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(h.reaction.line, current);
  });

  test('failures and Smart banter off keep the written line', () async {
    final failing = host((_) async => throw Exception('offline'));
    final w = failing.react(GameEvent.youWin, situation: 'The user won.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(failing.reaction.line, w.line);

    await GameScores.setSmartBanter(false);
    final off = host((_) async => 'Nope');
    final w2 = off.react(GameEvent.pipWins, situation: 'Pip won.');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(off.reaction.line, w2.line);
  });

  test('model replies are cleaned up', () {
    expect(PipGameHost.clean('Pip: "Ha! Gotcha."\nmore text'), 'Ha! Gotcha.');
    expect(PipGameHost.clean('{"text":"x"}'), isNull);
    expect(PipGameHost.clean('   '), isNull);
    expect(PipGameHost.clean('a' * 200), isNull);
    expect(PipGameHost.prompt('Chess', 'You won.', 'Yay'), contains('What just happened: You won.'));
  });

  test('the last thing that stumped Pip is remembered', () async {
    await GameScores.setLastStumped('a toaster');
    expect(await GameScores.lastStumped(), 'a toaster');
  });
}
