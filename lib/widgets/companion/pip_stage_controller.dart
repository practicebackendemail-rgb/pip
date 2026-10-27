import '../../core/services/pip_sfx_service.dart';
import '../../core/services/task_provider.dart';
import '../../models/task_model.dart';

/// Controller handling natural language task action parsing and executive briefings.
class PipStageController {
  PipStageController._();

  /// Parses Pip's reply for machine action tags [ACTION:...] and mutates TaskProvider.
  /// Also parses [MOOD:...] emotional signals emitted by Gemini.
  static String executePipActions(String rawReply, TaskProvider taskProv, {void Function(String mood)? onMoodDetected}) {
    String reply = rawReply;

    // Mood extraction [MOOD:happy|sad|laughing|sleepy|sleeping|excited|unsure|idle]
    final moodRegex = RegExp(r'\[MOOD:([^\]]+)\]', caseSensitive: false);
    final moodMatch = moodRegex.firstMatch(rawReply);
    if (moodMatch != null && onMoodDetected != null) {
      final moodKey = (moodMatch.group(1) ?? '').trim().toLowerCase();
      onMoodDetected(moodKey);
      reply = reply.replaceAll(moodRegex, '').trim();
    }

    final actionRegex = RegExp(r'\[ACTION:([^\]]+)\]');
    final matches = actionRegex.allMatches(rawReply);

    for (final match in matches) {
      final payload = match.group(1) ?? '';
      final parts = payload.split('|');
      final actionType = parts[0].trim().toUpperCase();

      if (actionType == 'ADD_TASK' && parts.length >= 2) {
        final title = parts[1].trim();
        final project = (parts.length > 2 && parts[2].trim().isNotEmpty) ? parts[2].trim() : 'Work';
        final priorityStr = (parts.length > 3) ? parts[3].trim().toLowerCase() : 'medium';
        TaskPriority priority = TaskPriority.medium;
        if (priorityStr == 'urgent') priority = TaskPriority.urgent;
        if (priorityStr == 'high') priority = TaskPriority.high;
        if (priorityStr == 'low') priority = TaskPriority.low;

        taskProv.addTask(title: title, project: project, priority: priority);
        PipSfxService.happy();
      } else if (actionType == 'COMPLETE_ALL_TASKS') {
        taskProv.completeAllTasks();
        PipSfxService.happy();
      } else if (actionType == 'DELETE_COMPLETED_TASKS') {
        taskProv.deleteAllCompletedTasks();
        PipSfxService.happy();
      } else if (actionType == 'COMPLETE_TASK' && parts.length >= 2) {
        final target = parts[1].trim();
        if (target.toLowerCase() == 'all') {
          taskProv.completeAllTasks();
        } else {
          final found = taskProv.findTaskByFuzzyTitle(target);
          if (found != null && !found.isCompleted) {
            taskProv.toggleTask(found.id);
          }
        }
        PipSfxService.happy();
      } else if (actionType == 'DELETE_TASK' && parts.length >= 2) {
        final target = parts[1].trim();
        final found = taskProv.findTaskByFuzzyTitle(target);
        if (found != null) {
          taskProv.deleteTask(found.id);
          PipSfxService.happy();
        }
      }
    }
    return reply.replaceAll(actionRegex, '').trim();
  }
}
