import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/task_provider.dart';
import '../../core/theme/apple_theme.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../glass_container.dart';

/// Objectives card displaying active tasks, streaks, and completion controls.
class ObjectivesOverlayCard extends StatelessWidget {
  final TaskProvider taskProv;
  final VoidCallback onAddTask;

  const ObjectivesOverlayCard({
    super.key,
    required this.taskProv,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final pending = taskProv.allTasks.where((t) => !t.isCompleted).toList();
    final reduceMotion = AppMotionTokens.shouldReduceMotion(context);

    Widget card = GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.check_mark_circled_solid, color: AppleTheme.accentTeal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Objectives (${pending.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppleTheme.textPrimary),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2A826).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2A826).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("🔥", style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          "${taskProv.streakDays}d streak",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE2A826),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(CupertinoIcons.plus_circle_fill, color: AppleTheme.accentBlue, size: 24),
                    onPressed: onAddTask,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: pending.isEmpty
                ? const Center(
                    child: Text("All tasks cleared! Pip is proud of you! ✨", style: TextStyle(color: AppleTheme.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: pending.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (ctx, i) {
                      final task = pending[i];
                      return Dismissible(
                        key: ValueKey(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppleTheme.accentRed.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          taskProv.deleteTask(task.id);
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: IconButton(
                            icon: const Icon(CupertinoIcons.circle, color: AppleTheme.textTertiary),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              taskProv.toggleTask(task.id);
                            },
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            "${task.project} • ${task.priority.name.toUpperCase()}",
                            style: const TextStyle(color: AppleTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(CupertinoIcons.trash, color: AppleTheme.textTertiary, size: 16),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              taskProv.deleteTask(task.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;
    return card.animate().fadeIn(duration: AppMotionTokens.fast).slideY(begin: 0.08, end: 0);
  }
}
