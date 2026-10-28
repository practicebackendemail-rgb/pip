import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/pip_desktop_window_manager.dart';
import 'package:personal_assistant/core/services/pip_home_widget_service.dart';
import 'package:personal_assistant/features/outside/desktop_sizes.dart';
import 'package:personal_assistant/models/task_model.dart';
import 'package:personal_assistant/widgets/companion/pip_overlay_widget.dart';

TaskItem task(String title, {DateTime? due, bool done = false, int ageMins = 0}) => TaskItem(
      id: title,
      title: title,
      project: 'General',
      dueDate: due,
      priority: TaskPriority.values[1],
      isCompleted: done,
      createdAt: DateTime(2026, 10, 28).subtract(Duration(minutes: ageMins)),
    );

void main() {
  group('Home widget', () {
    test('lists open tasks soonest first, undated last', () {
      final list = PipHomeWidgetService.upcoming([
        task('Gym', due: DateTime(2026, 10, 28, 18)),
        task('Someday'),
        task('Done', due: DateTime(2026, 10, 28, 8), done: true),
        task('Standup', due: DateTime(2026, 10, 28, 9, 45)),
      ]);
      expect(list.map((t) => t.title), ['Standup', 'Gym', 'Someday']);
    });

    test('due labels read like the mockup', () {
      final now = DateTime(2026, 10, 28, 9);
      expect(PipHomeWidgetService.whenLabel(DateTime(2026, 10, 28, 9, 45), now: now), '09:45');
      expect(PipHomeWidgetService.whenLabel(DateTime(2026, 10, 28), now: now), 'today');
      expect(PipHomeWidgetService.whenLabel(DateTime(2026, 10, 29, 7), now: now), 'tomorrow');
      expect(PipHomeWidgetService.whenLabel(DateTime(2026, 10, 27), now: now), 'overdue');
      expect(PipHomeWidgetService.whenLabel(null, now: now), '');
    });
  });

  test('the bubble grows from docked to capsule and has a size for every state', () {
    final s = PipOverlayWidget.sizes;
    expect(s.keys.toSet(), BubbleState.values.toSet());
    expect(s[BubbleState.docked]!.width, lessThan(s[BubbleState.resting]!.width));
    expect(s[BubbleState.talking]!.width, greaterThan(s[BubbleState.resting]!.width));
  });

  testWidgets('at Full the desktop switch shows the app itself', (tester) async {
    expect(PipDesktopWindowManager.size.value, DesktopSize.full);
    await tester.pumpWidget(const MaterialApp(home: DesktopSizeSwitch(child: Text('the app'))));
    expect(find.text('the app'), findsOneWidget);
  });
}
