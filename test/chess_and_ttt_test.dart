import 'dart:math';
import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/tools/game_tools.dart';
import 'package:personal_assistant/features/games/domain/chess_ai.dart';
import 'package:personal_assistant/features/games/domain/game_kind.dart';
import 'package:personal_assistant/features/games/domain/tic_tac_toe.dart';
import 'package:personal_assistant/features/games/presentation/screens/chess_screen.dart';
import 'package:personal_assistant/features/games/presentation/screens/tic_tac_toe_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Tic-tac-toe', () {
    test('lines win and full boards draw', () {
      final b = TicTacToe();
      for (final i in [0, 4, 8]) {
        b.place(i, TicTacToe.you);
      }
      expect(b.winner, TicTacToe.you);
      expect(b.winningLine(), [0, 4, 8]);
      expect(b.place(0, TicTacToe.pip), isFalse);
    });

    test('Tough never loses to random play', () {
      final rnd = Random(7);
      for (var game = 0; game < 40; game++) {
        final b = TicTacToe();
        var youTurn = game.isEven;
        while (b.winner == null && !b.isFull) {
          if (youTurn) {
            final open = b.open;
            b.place(open[rnd.nextInt(open.length)], TicTacToe.you);
          } else {
            b.place(b.pipMove(GameDifficulty.tough, random: rnd), TicTacToe.pip);
          }
          youTurn = !youTurn;
        }
        expect(b.winner, isNot(TicTacToe.you), reason: 'game $game');
      }
    });

    test('squares are heard in speech', () {
      expect(parseSquare('top left'), 0);
      expect(parseSquare('the centre'), 4);
      expect(parseSquare('bottom right please'), 8);
      expect(parseSquare('middle left'), 3);
      expect(parseSquare('square 7'), 6);
      expect(parseSquare('banana'), isNull);
    });
  });

  group('Pip at chess', () {
    test('takes a hanging queen', () {
      // Black to move; white queen on d5 can be taken by the e6 pawn.
      const fen = 'rnb1kbnr/pppp1ppp/4p3/3Q4/8/8/PPPP1PPP/RNB1KBNR b KQkq - 0 3';
      final m = ChessAi.pickMove(fen, GameDifficulty.fair, random: Random(1))!;
      expect(m.toAlgebraic, 'd5');
    });

    test('finds mate in one', () {
      // Back-rank mate: the black rook drops to a1.
      const fen = 'r5k1/8/8/8/8/8/6PP/7K b - - 0 1';
      final m = ChessAi.pickMove(fen, GameDifficulty.fair, random: Random(2))!;
      final g = ch.Chess.fromFEN(fen)..move({'from': m.fromAlgebraic, 'to': m.toAlgebraic});
      expect(g.in_checkmate, isTrue);
    });

    test('every level plays legal moves from the start', () {
      for (final level in GameDifficulty.values) {
        final g = ch.Chess();
        g.move({'from': 'e2', 'to': 'e4'});
        final m = ChessAi.pickMove(g.fen, level, random: Random(3))!;
        expect(g.move({'from': m.fromAlgebraic, 'to': m.toAlgebraic}), isTrue, reason: level.name);
      }
    });

    test('evaluation favours the side with more material', () {
      expect(ChessAi.evaluate(ch.Chess()), 0);
      final upQueen = ch.Chess.fromFEN('rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(ChessAi.evaluate(upQueen), greaterThan(800));
    });
  });

  test('the tool knows chess and X-O', () {
    expect(StartGameTool.kindFor('chess'), GameKind.chess);
    expect(StartGameTool.kindFor('X-O'), GameKind.ticTacToe);
    expect(StartGameTool.kindFor('tic tac toe'), GameKind.ticTacToe);
  });

  Future<void> show(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('tic-tac-toe: your X goes down and Pip answers', (tester) async {
    await show(tester, const TicTacToeScreen());
    await tester.tap(find.bySemanticsLabel('Square 5, empty'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Square 5, X'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel(RegExp(r'Square \d, O')), findsOneWidget);
  });

  testWidgets('chess: tapping a pawn shows where it can go', (tester) async {
    await show(tester, const ChessScreen());
    await tester.tap(find.bySemanticsLabel('e2, your pawn'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('e4, empty, can move here'), findsOneWidget);
    expect(find.bySemanticsLabel('e3, empty, can move here'), findsOneWidget);
  });
}
