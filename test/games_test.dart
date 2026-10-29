import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/tools/game_tools.dart';
import 'package:personal_assistant/features/games/data/game_scores.dart';
import 'package:personal_assistant/features/games/domain/four_in_row.dart';
import 'package:personal_assistant/features/games/domain/game_kind.dart';
import 'package:personal_assistant/features/games/domain/pip_banter.dart';
import 'package:personal_assistant/features/games/domain/rock_paper_scissors.dart';
import 'package:personal_assistant/features/games/domain/twenty_questions.dart';
import 'package:personal_assistant/features/games/presentation/screens/four_in_row_screen.dart';
import 'package:personal_assistant/features/games/presentation/screens/game_hub_screen.dart';
import 'package:personal_assistant/features/games/presentation/screens/rps_screen.dart';
import 'package:personal_assistant/features/games/presentation/widgets/game_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Four in a row', () {
    test('discs stack and four in a line wins', () {
      final b = FourInRow();
      for (var i = 0; i < 4; i++) {
        expect(b.drop(i, FourInRow.you), FourInRow.rows - 1);
      }
      expect(b.winner, FourInRow.you);
      expect(b.winningLine(), hasLength(4));
    });

    test('vertical and diagonal wins count', () {
      final v = FourInRow();
      for (var i = 0; i < 4; i++) {
        v.drop(2, FourInRow.pip);
      }
      expect(v.winner, FourInRow.pip);

      final d = FourInRow();
      // Staircase so "you" gets the rising diagonal from (5,0) to (2,3).
      for (final (col, fill) in [(1, 1), (2, 2), (3, 3)]) {
        for (var i = 0; i < fill; i++) {
          d.drop(col, FourInRow.pip);
        }
      }
      for (var c = 0; c < 4; c++) {
        d.drop(c, FourInRow.you);
      }
      expect(d.winner, FourInRow.you);
    });

    test('a full column refuses more discs', () {
      final b = FourInRow();
      for (var i = 0; i < FourInRow.rows; i++) {
        b.drop(0, i.isEven ? 1 : 2);
      }
      expect(b.canDrop(0), isFalse);
      expect(b.drop(0, 1), -1);
    });

    test('Fair and Tough take a win and block yours', () {
      final win = FourInRow();
      for (var c = 0; c < 3; c++) {
        win.drop(c, FourInRow.pip);
      }
      expect(win.pipMove(GameDifficulty.fair), 3);

      final block = FourInRow();
      for (var c = 1; c < 4; c++) {
        block.drop(c, FourInRow.you);
      }
      expect([0, 4], contains(block.pipMove(GameDifficulty.tough)));
    });

    test('Easy always makes a legal move', () {
      final b = FourInRow();
      final rnd = Random(1);
      for (var i = 0; i < 20 && b.winner == null && !b.isFull; i++) {
        final c = b.pipMove(GameDifficulty.easy, random: rnd);
        expect(b.canDrop(c), isTrue);
        b.drop(c, i.isEven ? 2 : 1);
      }
    });
  });

  group('Rock paper scissors', () {
    test('rules and first to three', () {
      expect(Hand.rock.beats(Hand.scissors), isTrue);
      expect(Hand.paper.beats(Hand.rock), isTrue);
      expect(Hand.scissors.beats(Hand.paper), isTrue);
      expect(Hand.rock.beats(Hand.paper), isFalse);
      final g = RockPaperScissors();
      for (var i = 0; i < 3; i++) {
        expect(g.play(Hand.rock, Hand.scissors), RoundResult.youWin);
      }
      expect(g.over, isTrue);
    });

    test('Tough counters a repeated pattern', () {
      final g = RockPaperScissors();
      for (var i = 0; i < 6; i++) {
        g.play(Hand.rock, Hand.rock);
      }
      // Rock always follows rock, so Pip should usually throw paper.
      final picks = [for (var i = 0; i < 40; i++) g.pipPick(GameDifficulty.tough, random: Random(i))];
      expect(picks.where((h) => h == Hand.paper).length, greaterThan(25));
    });

    test('hands are heard in speech', () {
      expect(Hand.parse('I pick ROCK'), Hand.rock);
      expect(Hand.parse('scissor!'), Hand.scissors);
      expect(Hand.parse('banana'), isNull);
    });
  });

  group('20 questions', () {
    test('reads JSON questions and guesses, and plain text', () {
      final g = TwentyQuestions()..readReply('{"type":"guess","text":"Is it a cat?"}');
      expect(g.currentQuestion, 'Is it a cat?');
      expect(g.currentIsGuess, isTrue);
      g.readReply('Does it live in water?');
      expect(g.currentIsGuess, isFalse);
      g.answer(Answer.no);
      expect(g.asked.single.$2, Answer.no);
      expect(g.prompt(), contains('Does it live in water? -> no'));
    });

    test('answers are heard', () {
      expect(TwentyQuestions.parse('yeah'), Answer.yes);
      expect(TwentyQuestions.parse('nope'), Answer.no);
      expect(TwentyQuestions.parse('kind of'), Answer.maybe);
    });
  });

  test('Pip never repeats the same line twice in a row', () {
    final b = PipBanter(random: Random(3));
    String? last;
    for (var i = 0; i < 20; i++) {
      final r = b.react(GameEvent.yourMove);
      expect(r.line, isNot(last));
      last = r.line;
    }
    for (final e in GameEvent.values) {
      expect(b.react(e).line, isNotEmpty);
    }
  });

  test('columns are heard in speech', () {
    expect(parseColumn('column 5', 7), 4);
    expect(parseColumn('the third one', 7), 2);
    expect(parseColumn('seven', 7), 6);
    expect(parseColumn('column 9', 7), isNull);
  });

  test('scores add up and describe the lead', () async {
    await GameScores.record(GameKind.fourInRow, youWon: true);
    await GameScores.record(GameKind.fourInRow, youWon: true);
    final s = await GameScores.record(GameKind.fourInRow, youWon: false);
    expect((s.you, s.pip), (2, 1));
    expect(s.line, "You're 2–1 up");
  });

  test('the tool maps game names', () {
    expect(StartGameTool.kindFor('Connect four'), GameKind.fourInRow);
    expect(StartGameTool.kindFor('rock_paper_scissors'), GameKind.rockPaperScissors);
    expect(StartGameTool.kindFor('20 questions'), GameKind.twentyQuestions);
    expect(StartGameTool.kindFor(null), isNull);
  });

  Future<void> show(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the arcade lists all three games', (tester) async {
    await show(tester, const GameHubScreen());
    expect(find.text('PIP ARCADE'), findsOneWidget);
    expect(find.text('FOUR IN A ROW'), findsOneWidget);
    expect(find.text('20 QUESTIONS'), findsOneWidget);
  });

  testWidgets('tapping a column drops a disc and Pip answers', (tester) async {
    await show(tester, const FourInRowScreen());
    await tester.tap(find.bySemanticsLabel('Column 4'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('YOU'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('rock paper scissors counts down and reveals', (tester) async {
    await show(tester, const RpsScreen());
    await tester.tap(find.text('ROCK'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ROCK'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('VS'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
