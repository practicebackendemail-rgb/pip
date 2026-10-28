import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../core/services/pip_home_widget_service.dart';
import '../../core/services/task_provider.dart';
import '../companion/presentation/cubit/pip_stage_cubit.dart';

/// Keeps the home-screen widgets in step with Pip (mood, line, tasks) and
/// handles links from them. Updates are debounced so typing and talking
/// don't redraw the widget every frame.
class HomeWidgetSync {
  final PipStageCubit cubit;
  final TaskProvider tasks;

  /// Called when the widget's mic asks Pip to listen.
  final VoidCallback onListen;

  HomeWidgetSync({required this.cubit, required this.tasks, required this.onListen});

  StreamSubscription<void>? _cubitSub;
  StreamSubscription<Uri?>? _clicks;
  Timer? _debounce;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  void start() {
    if (!_supported) return;
    PipHomeWidgetService.init();
    _cubitSub = cubit.stream
        .where((s) => !s.isTypewriting)
        .map((s) => '${s.currentMood.name}|${s.speechText}')
        .distinct()
        .listen((_) => _schedule());
    tasks.addListener(_schedule);
    _clicks = HomeWidget.widgetClicked.listen(_open);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_open);
    _schedule();
  }

  void _open(Uri? uri) {
    if (uri?.toString().startsWith(PipHomeWidgetService.listenUri) == true) onListen();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      final s = cubit.state;
      PipHomeWidgetService.updateWidget(
        mood: s.currentMood.name,
        line: s.speechText.isNotEmpty ? s.speechText : s.statusText,
        tasks: tasks.allTasks,
      );
    });
  }

  void dispose() {
    _debounce?.cancel();
    _cubitSub?.cancel();
    _clicks?.cancel();
    tasks.removeListener(_schedule);
  }
}
