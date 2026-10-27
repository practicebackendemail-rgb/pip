import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Platform bridge for updating the Android/iOS home screen widget with Pip's live status.
class PipHomeWidgetService {
  PipHomeWidgetService._();

  static const String appWidgetProvider = 'PipAppWidgetProvider';

  /// Updates the home screen widget with Pip's current state and active tasks
  static Future<void> updateWidget({
    required String mood,
    required String statusText,
    required int pendingTasksCount,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await HomeWidget.saveWidgetData<String>('pip_mood', mood);
      await HomeWidget.saveWidgetData<String>('pip_status', statusText);
      await HomeWidget.saveWidgetData<int>('pip_pending_tasks', pendingTasksCount);

      await HomeWidget.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
      );
    } catch (e) {
      debugPrint("PipHomeWidgetService update error: $e");
    }
  }
}
