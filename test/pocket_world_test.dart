import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/domain/pip_idle_brain.dart';
import 'package:personal_assistant/widgets/pip_companion.dart';
import 'package:personal_assistant/widgets/pocket_world/pip_pocket_world.dart';
import 'package:personal_assistant/widgets/pocket_world/pocket_sky_painter.dart';

void main() {
  group('Idle brain', () {
    test('never naps after a short quiet spell', () {
      final brain = PipIdleBrain(math.Random(1));
      for (var i = 0; i < 300; i++) {
        final a = brain.next(currentX: .5, idleFor: const Duration(seconds: 30), hour: 2);
        expect(a.kind, isNot(PipIdleKind.nap));
      }
    });

    test('naps eventually after a long quiet spell at night', () {
      final brain = PipIdleBrain(math.Random(2));
      final kinds = List.generate(60, (_) => brain.next(currentX: .5, idleFor: const Duration(minutes: 5), hour: 23).kind);
      expect(kinds, contains(PipIdleKind.nap));
    });

    test('does not repeat the same act twice in a row, except rolling around', () {
      final brain = PipIdleBrain(math.Random(3));
      PipIdleKind? last;
      for (var i = 0; i < 400; i++) {
        final k = brain.next(currentX: .5, idleFor: const Duration(minutes: 5), hour: 14).kind;
        if (k != PipIdleKind.wander) expect(k, isNot(last));
        last = k;
      }
    });

    test('wandering stays on the island and actually goes somewhere', () {
      final brain = PipIdleBrain(math.Random(4));
      var x = .5, y = .5;
      for (var i = 0; i < 300; i++) {
        final a = brain.next(currentX: x, currentY: y, idleFor: Duration.zero, hour: 12);
        expect(a.targetX, inInclusiveRange(.05, .95));
        if (a.kind == PipIdleKind.wander) {
          // Distance counts both left-right and front-back travel.
          expect((a.targetX - x).abs() + (a.targetY - y).abs(), greaterThanOrEqualTo(.2));
          x = a.targetX;
          y = a.targetY;
        }
      }
    });
  });

  group('Sky', () {
    test('noon is day, midnight is night', () {
      expect(PocketSkyPainter.nightness(12), 0);
      expect(PocketSkyPainter.nightness(0), greaterThan(.9));
      final (noonTop, _) = PocketSkyPainter.skyAt(12);
      final (nightTop, _) = PocketSkyPainter.skyAt(0);
      expect(noonTop.b, greaterThan(nightTop.b));
    });

    test('birds fly by day only, and only part of each cycle', () {
      expect(PocketSkyPainter.birdAt(2, const Size(1, 1), 12), isNotNull);
      expect(PocketSkyPainter.birdAt(20, const Size(1, 1), 12), isNull);
      expect(PocketSkyPainter.birdAt(2, const Size(1, 1), 1), isNull);
    });
  });

  testWidgets('pocket world renders and Pip lives on it without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PipPocketSky(child: Center(child: PipPocketIsland(mood: PipMood.idle))),
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(PipDeskCompanion), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PipPocketSky(child: Center(child: PipPocketIsland(mood: PipMood.thinking)))),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
