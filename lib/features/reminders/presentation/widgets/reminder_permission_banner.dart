import 'package:flutter/material.dart';
import '../../../../core/theme/pip_theme.dart';
import '../../domain/reminder_repository.dart';

/// Explains what's missing when notifications or exact alarms are off.
class ReminderPermissionBanner extends StatelessWidget {
  final ReminderPermissions permissions;
  final VoidCallback onFix;

  const ReminderPermissionBanner({super.key, required this.permissions, required this.onFix});

  String get _message {
    if (!permissions.notifications) return "Notifications are off for Pip, so alarms and reminders can't appear.";
    return 'Exact alarms are off, so Android may deliver these a few minutes late.';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: PipColors.warn.withValues(alpha: 0.12),
      margin: const EdgeInsets.only(top: PipSpace.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PipSpace.lg, PipSpace.sm, PipSpace.sm, PipSpace.sm),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: PipColors.warn),
            const SizedBox(width: PipSpace.md),
            Expanded(child: Text(_message, style: Theme.of(context).textTheme.bodyMedium)),
            TextButton(onPressed: onFix, child: const Text('Allow')),
          ],
        ),
      ),
    );
  }
}
