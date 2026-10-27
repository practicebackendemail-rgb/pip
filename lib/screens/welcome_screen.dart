import 'package:flutter/material.dart';
import '../core/di/injection.dart';
import '../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../core/theme/pip_theme.dart';
import '../widgets/companion/pip_stage_scenery.dart';
import '../widgets/pip_companion.dart';

/// First-run landing: Pip waves from the desk, three promises, two ways in.
class PipWelcomeScreen extends StatefulWidget {
  final VoidCallback onStart;

  /// Called after a backup was imported, so setup continues with data restored.
  final VoidCallback onRestored;

  const PipWelcomeScreen({super.key, required this.onStart, required this.onRestored});

  @override
  State<PipWelcomeScreen> createState() => _PipWelcomeScreenState();
}

class _PipWelcomeScreenState extends State<PipWelcomeScreen> {
  PipMood _mood = PipMood.happy;
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _mood = PipMood.thinking;
    });
    final sync = getIt<PipCloudSyncCoordinator>();
    final ok = await sync.importBackup();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _mood = ok ? PipMood.excited : PipMood.unsure;
    });
    if (ok) {
      widget.onRestored();
    } else if (sync.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't restore that backup. ${sync.lastError}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wide = PipSpace.isWide(context);

    final scene = ClipRRect(
      borderRadius: BorderRadius.circular(wide ? PipSpace.radiusLg : 0),
      child: PipStageScenery(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: PipDeskCompanion(mood: _mood, width: 220, height: 170, onTap: () => setState(() => _mood = PipMood.excited)),
          ),
        ),
      ),
    );

    final copy = Padding(
      padding: const EdgeInsets.fromLTRB(PipSpace.xl, PipSpace.xl, PipSpace.xl, PipSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Hi, I'm Pip.", style: text.headlineSmall),
          const SizedBox(height: PipSpace.sm),
          Text(
            'A desk buddy who learns how you work and gets real things done.',
            style: text.bodyLarge?.copyWith(color: PipColors.muted),
          ),
          const SizedBox(height: PipSpace.lg),
          const Wrap(
            spacing: PipSpace.sm,
            runSpacing: PipSpace.sm,
            children: [
              _Promise(icon: Icons.auto_awesome_outlined, label: 'Learns your habits'),
              _Promise(icon: Icons.task_alt, label: 'Tasks, mail and reminders'),
              _Promise(icon: Icons.lock_outline, label: 'Your data stays yours'),
            ],
          ),
          const SizedBox(height: PipSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _restoring ? null : widget.onStart, child: const Text('Set me up')),
          ),
          const SizedBox(height: PipSpace.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _restoring ? null : _restore,
              child: Text(_restoring ? 'Restoring…' : 'Restore from backup'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        top: wide,
        child: wide
            ? Padding(
                padding: const EdgeInsets.all(PipSpace.xl),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: scene),
                    Expanded(flex: 2, child: Center(child: SingleChildScrollView(child: copy))),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(child: scene),
                  copy,
                ],
              ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Promise({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PipColors.chip,
        borderRadius: BorderRadius.circular(PipSpace.pill),
        border: Border.all(color: PipColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PipColors.amber),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: PipColors.ink)),
        ],
      ),
    );
  }
}
