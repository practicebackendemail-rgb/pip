import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../../core/theme/apple_theme.dart';

/// Sync status with Sync now, plus Export / Import backup when the active
/// provider works with backup files. Used by Settings and What Pip Knows.
class PipSyncPanel extends StatelessWidget {
  /// Called after a sync or import changes local data.
  final VoidCallback? onDataChanged;

  const PipSyncPanel({super.key, this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    final sync = getIt<PipCloudSyncCoordinator>();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final last = sync.lastSyncTime;
        final timeStr = last != null
            ? '${last.month}/${last.day} at ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'
            : 'Never';
        final busy = sync.isSyncing;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.cloud_upload, color: AppleTheme.accentTeal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Cloud Sync: Last synced $timeStr",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleTheme.textPrimary),
                    ),
                  ),
                  if (busy) const CupertinoActivityIndicator(radius: 8),
                ],
              ),
              if (sync.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Error: ${sync.lastError}", style: const TextStyle(fontSize: 10, color: AppleTheme.accentRed)),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  _action("Sync Now", busy ? null : () => _run(sync.syncNow(force: true))),
                  if (sync.supportsBackupFiles) ...[
                    _action("Export Backup", busy ? null : () => _run(sync.exportBackup(), refresh: false)),
                    _action("Import Backup", busy ? null : () => _run(sync.importBackup())),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _run(Future<bool> action, {bool refresh = true}) async {
    final ok = await action;
    if (ok && refresh) onDataChanged?.call();
  }

  Widget _action(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppleTheme.accentTeal, fontWeight: FontWeight.bold)),
    );
  }
}
