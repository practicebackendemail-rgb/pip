import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/domain/pip_action_speech.dart';
import 'package:personal_assistant/features/companion/domain/pip_character_bible.dart';
import 'package:personal_assistant/features/companion/domain/pip_idle_brain.dart';

void main() {
  group('Spoken confirmation', () {
    test('understands yes and no in everyday words', () {
      for (final s in ['Yes', 'yeah sure', 'Okay.', 'go ahead', 'do it please', 'Yes please!']) {
        expect(parseConfirmation(s), ConfirmAnswer.yes, reason: s);
      }
      for (final s in ['No', 'nope', 'cancel that', "don't", 'wait', 'never mind']) {
        expect(parseConfirmation(s), ConfirmAnswer.no, reason: s);
      }
      expect(parseConfirmation('what time is it'), isNull);
      expect(parseConfirmation('nobody told me'), isNull);
    });

    test('email needs a tap, calendar can be confirmed by voice', () {
      expect(needsTapToConfirm('level3DangerousDoubleConfirm'), isTrue);
      expect(needsTapToConfirm('level1ConfirmAction'), isFalse);
    });

    test('asks in plain words instead of tool names', () {
      final now = DateTime(2026, 10, 27, 15, 46);
      final ask = describePendingAction(
        'create_calendar_event',
        {'title': 'Leave', 'start_iso': '2026-10-27T16:00:00', 'duration_minutes': '30'},
        now: now,
      );
      expect(ask, "Add 'Leave' to your calendar today at 4 PM for 30 minutes?");
      expect(describePendingAction('set_reminder', {'title': 'Stretch', 'delay_seconds': 900}, now: now),
          "Remind you about 'Stretch' today at 4:01 PM?");
      expect(describePendingAction('mystery_tool', {}, now: now), 'Go ahead with mystery tool?');
    });
  });

  test('prompt always carries the real date, year and timezone', () {
    final ctx = PipCharacterBible.clockContext(DateTime(2026, 10, 27, 15, 46));
    expect(ctx, contains('Tuesday 27 October 2026'));
    expect(ctx, contains('2026-10-27T15:46:00'));
    final prompt = PipCharacterBible.buildSystemPrompt(emotionContext: '', now: DateTime(2026, 10, 27, 15, 46));
    expect(prompt, contains('2026'));
  });

  test('wandering covers depth as well as left-right, and waving comes forward', () {
    final brain = PipIdleBrain(math.Random(9));
    final depths = <double>[];
    for (var i = 0; i < 300; i++) {
      final a = brain.next(currentX: .5, currentY: .5, idleFor: Duration.zero, hour: 12);
      expect(a.targetY, inInclusiveRange(0, 1));
      if (a.kind == PipIdleKind.wander) depths.add(a.targetY);
      if (a.kind == PipIdleKind.wave) expect(a.targetY, 1);
    }
    expect(depths.reduce(math.min), lessThan(.2));
    expect(depths.reduce(math.max), greaterThan(.8));
  });
}
