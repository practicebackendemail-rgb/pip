import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../../../core/theme/pip_theme.dart';
import '../../../widgets/pip_params.dart';
import '../onboarding_flow.dart';

class BackupStep extends StatefulWidget {
  final ValueChanged<PipStepState> onState;

  const BackupStep({super.key, required this.onState});

  @override
  State<BackupStep> createState() => _BackupPipStepState();
}

class _BackupPipStepState extends State<BackupStep> implements OnboardingStepController {
  static const int minLength = 8;
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _problem {
    final p = _pass.text;
    if (p.isEmpty && _confirm.text.isEmpty) return null;
    if (p.length < minLength) return 'Use at least $minLength characters.';
    if (_confirm.text != p) return "The two passwords don't match yet.";
    return null;
  }

  void _changed(String _) {
    setState(() {});
    final problem = _problem;
    if (_pass.text.isEmpty) {
      widget.onState(const PipStepState('Want a backup password? It locks your backups so only you can open them.'));
    } else if (problem != null) {
      widget.onState(PipStepState(problem, mood: PipMood.unsure, canContinue: false));
    } else {
      widget.onState(const PipStepState("Locked tight. Don't forget it: nobody, not even me, can recover it.",
          mood: PipMood.happy));
    }
  }

  @override
  Future<bool> commit() async {
    if (_problem != null) return false;
    if (_pass.text.isNotEmpty) await getIt<PipCloudSyncCoordinator>().setSyncPassphrase(_pass.text);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return ListView(
      padding: const EdgeInsets.all(PipSpace.xl),
      children: [
        TextField(
          controller: _pass,
          obscureText: !_show,
          onChanged: _changed,
          decoration: InputDecoration(
            labelText: 'Backup password',
            suffixIcon: IconButton(
              tooltip: _show ? 'Hide password' : 'Show password',
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: PipSpace.md),
        TextField(
          controller: _confirm,
          obscureText: !_show,
          onChanged: _changed,
          decoration: InputDecoration(labelText: 'Type it again', errorText: _confirm.text.isEmpty ? null : problem),
        ),
        const SizedBox(height: PipSpace.lg),
        Container(
          padding: const EdgeInsets.all(PipSpace.md),
          decoration: BoxDecoration(
            color: PipColors.amber.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(PipSpace.radius),
            border: Border.all(color: PipColors.amber.withValues(alpha: .35)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.key_outlined, color: PipColors.amber, size: 20),
              SizedBox(width: PipSpace.sm),
              Expanded(
                child: Text(
                  'Backups are encrypted on this device before they go anywhere. '
                  'There is no reset: if you forget this password, the backups cannot be opened. '
                  'Leave it blank to skip; you can set it later in Settings.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: PipColors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
