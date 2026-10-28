import 'package:flutter/material.dart';
import '../../features/brains/data/local_brain.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/routes/app_routes.dart';
import '../../core/di/injection.dart';
import '../../core/services/email_service.dart';
import '../../core/services/llm_registry_service.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../../core/theme/pip_theme.dart';
import '../what_pip_knows_screen.dart';

/// Settings grouped by what you're changing. Each row opens a small page;
/// the pages reuse the onboarding steps so setup and settings stay identical.
class PipSettingsScreen extends StatelessWidget {
  const PipSettingsScreen({super.key});

  static Future<void> open(BuildContext context) => context.push(AppRoutes.settings);

  @override
  Widget build(BuildContext context) {
    final llm = getIt<LlmRegistryService>();
    final email = getIt<EmailService>();
    final sync = getIt<PipCloudSyncCoordinator>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: Listenable.merge([llm, email, sync]),
            builder: (context, _) => ListView(
              padding: const EdgeInsets.only(bottom: PipSpace.xxl),
              children: [
                const _Section('Pip'),
                FutureBuilder<String?>(
                  future: PipProfileService.userName(),
                  builder: (context, snap) => _Row(
                    icon: Icons.mood_outlined,
                    title: 'Personality',
                    value: snap.data == null ? 'Humour and your name' : 'Calls you ${snap.data}',
                    onTap: () => context.push(AppRoutes.settingsPersonality),
                  ),
                ),
                const _Section('Brain'),
                ListenableBuilder(
                  listenable: LocalBrain.instance,
                  builder: (context, _) => _Row(
                    icon: Icons.memory_outlined,
                    title: context.l10n.brainsTitle,
                    value: [
                      if (LocalBrain.instance.active != null) LocalBrain.instance.active!.name,
                      _providerLabel(llm.activeProviderId),
                    ].join(' + '),
                    onTap: () => context.push(AppRoutes.settingsBrains),
                  ),
                ),
                _Row(
                  icon: Icons.record_voice_over_outlined,
                  title: context.l10n.voiceSettingsTitle,
                  value: context.l10n.voiceSettingsSubtitle,
                  onTap: () => context.push(AppRoutes.settingsVoice),
                ),
                const _Section('Connections'),
                _Row(
                  icon: Icons.hub_outlined,
                  title: 'Email, calendar, voice and more',
                  value: email.isConfigured ? 'Email connected' : 'Nothing connected',
                  onTap: () => context.push(AppRoutes.settingsConnections),
                ),
                const _Section('Privacy and backup'),
                _Row(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Sync and backup',
                  value: sync.lastSyncTime == null ? 'Never synced' : 'Last ${_ago(sync.lastSyncTime!)}',
                  onTap: () => context.push(AppRoutes.settingsBackup),
                ),
                _Row(
                  icon: Icons.psychology_outlined,
                  title: 'What Pip knows',
                  value: 'Review or forget memories',
                  onTap: () => WhatPipKnowsScreen.show(context),
                ),
                const _Section('About'),
                _Row(
                  icon: Icons.replay_outlined,
                  title: 'Run setup again',
                  value: 'Walk through the first-run steps',
                  onTap: () => context.push(AppRoutes.settingsSetupAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _providerLabel(String id) => switch (id) {
        'gemini' => 'Gemini',
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'groq' => 'Groq',
        'ollama' => 'Local (Ollama)',
        _ => id,
      };

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PipSpace.lg, PipSpace.xl, PipSpace.lg, PipSpace.sm),
      child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _Row({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: PipColors.faint),
      onTap: onTap,
    );
  }
}
