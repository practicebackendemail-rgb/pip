import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task_model.dart';
import '../../widgets/pip_companion.dart';

/// Pip's Android home-screen widgets (small 2×1 and medium 4×2).
///
/// The app writes Pip's mood, its current line and the next three open tasks;
/// Kotlin providers draw them. Pip itself is rendered from the real painter
/// into an image whenever the mood changes. Tapping a task ticks it off in
/// the background ([pipWidgetCallback]); the mic opens Pip already listening.
class PipHomeWidgetService {
  PipHomeWidgetService._();

  static const String smallProvider = 'PipAppWidgetProvider';
  static const String mediumProvider = 'PipAppWidgetMediumProvider';

  /// Deep links the widgets send.
  static const String listenUri = 'pip://listen';
  static const String taskDoneHost = 'task';

  static String? _lastRenderedMood;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> init() async {
    if (!_supported) return;
    await HomeWidget.registerInteractivityCallback(pipWidgetCallback);
  }

  static Future<void> updateWidget({
    required String mood,
    required String line,
    required List<TaskItem> tasks,
  }) async {
    if (!_supported) return;
    try {
      if (mood != _lastRenderedMood) {
        _lastRenderedMood = mood;
        await _renderPip(mood);
      }
      await HomeWidget.saveWidgetData<String>('pip_mood', _moodLabel(mood));
      await HomeWidget.saveWidgetData<String>('pip_status', line.isEmpty ? 'Tap to talk to Pip' : line);
      await writeTasks(tasks);
      await refresh();
    } catch (e) {
      debugPrint('PipHomeWidgetService update error: $e');
    }
  }

  static Future<void> refresh() async {
    await HomeWidget.updateWidget(name: smallProvider, androidName: smallProvider);
    await HomeWidget.updateWidget(name: mediumProvider, androidName: mediumProvider);
  }

  /// Open tasks, soonest due first; undated ones after.
  @visibleForTesting
  static List<TaskItem> upcoming(List<TaskItem> tasks) {
    final open = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return a.createdAt.compareTo(b.createdAt);
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    return open;
  }

  @visibleForTesting
  static String whenLabel(DateTime? due, {DateTime? now}) {
    if (due == null) return '';
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    final hasTime = due.hour != 0 || due.minute != 0;
    if (diff < 0) return 'overdue';
    if (diff == 0) return hasTime ? DateFormat.Hm().format(due) : 'today';
    if (diff == 1) return 'tomorrow';
    return DateFormat.MMMd().format(due);
  }

  static Future<void> writeTasks(List<TaskItem> tasks) async {
    final next = upcoming(tasks);
    await HomeWidget.saveWidgetData<int>('pip_pending_tasks', next.length);
    final first = next.isEmpty ? null : next.first;
    await HomeWidget.saveWidgetData<String>(
      'pip_next',
      first == null ? 'Nothing on your plate' : 'Next: ${first.title} ${whenLabel(first.dueDate)}'.trim(),
    );
    for (var i = 0; i < 3; i++) {
      final t = i < next.length ? next[i] : null;
      await HomeWidget.saveWidgetData<String>('pip_task_${i}_id', t?.id);
      await HomeWidget.saveWidgetData<String>('pip_task_${i}_title', t?.title);
      await HomeWidget.saveWidgetData<String>('pip_task_${i}_when', t == null ? null : whenLabel(t.dueDate));
    }
  }

  static Future<void> _renderPip(String mood) async {
    final m = PipMood.values.asNameMap()[mood] ?? PipMood.idle;
    final path = await HomeWidget.renderFlutterWidget(
      SizedBox(width: 120, height: 90, child: PipDeskCompanion(mood: m, width: 120, height: 90)),
      key: 'pip_face',
      logicalSize: const Size(120, 90),
    );
    await HomeWidget.saveWidgetData<String>('pip_face', path);
  }

  static String _moodLabel(String mood) => switch (mood) {
        'talking' => 'chatting',
        'listening' => 'listening',
        'thinking' => 'thinking',
        'sleepy' => 'sleepy',
        'unsure' => 'puzzled',
        'excited' => 'excited',
        'happy' => 'happy',
        _ => 'here',
      };
}

/// Runs in a background isolate when a task row on the widget is tapped:
/// marks it done in the same store TaskProvider uses, then redraws.
@pragma('vm:entry-point')
Future<void> pipWidgetCallback(Uri? uri) async {
  if (uri == null || uri.host != PipHomeWidgetService.taskDoneHost) return;
  final id = uri.queryParameters['id'];
  if (id == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('saved_tasks');
  if (raw == null) return;
  final tasks = [for (final j in jsonDecode(raw) as List) TaskItem.fromJson(j as Map<String, dynamic>)];
  final i = tasks.indexWhere((t) => t.id == id);
  if (i < 0 || tasks[i].isCompleted) return;
  tasks[i] = tasks[i].copyWith(isCompleted: true);
  await prefs.setString('saved_tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
  await prefs.setInt('completed_today_count', (prefs.getInt('completed_today_count') ?? 0) + 1);
  await PipHomeWidgetService.writeTasks(tasks);
  await PipHomeWidgetService.refresh();
}
