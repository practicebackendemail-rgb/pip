import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/task_provider.dart';
import '../../core/theme/apple_theme.dart';
import '../glass_container.dart';

/// Modal bottom sheet allowing manual entry of a new task objective.
class QuickAddTaskModal extends StatelessWidget {
  const QuickAddTaskModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddTaskModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleCtrl = TextEditingController();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        backgroundColor: const Color(0xFF161820).withValues(alpha: 0.96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Objective for Pip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppleTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppleTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Finish project proposal',
                hintStyle: TextStyle(color: AppleTheme.textTertiary),
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2A826),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  context.read<TaskProvider>().addTask(title: titleCtrl.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
