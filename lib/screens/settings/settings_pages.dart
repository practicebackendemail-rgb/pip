import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/llm_registry_service.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/theme/pip_theme.dart';
import '../../features/onboarding/onboarding_flow.dart';
import '../../features/onboarding/steps/backup_step.dart';
import '../../features/onboarding/steps/brain_step.dart';
import '../../features/onboarding/steps/connections_step.dart';
import '../../widgets/pip_guide.dart';
import '../../widgets/pip_params.dart';
import '../../widgets/sync/pip_sync_panel.dart';

/// Shared frame for a settings page: Pip comments at the top (reacting to the
/// step's state), the content in a readable column, and an optional Save.
class _SettingsPage extends StatefulWidget {
  final String title;
  final String intro;
  final Widget Function(ValueChanged<PipStepState> onState, GlobalKey key) builder;
  final bool hasSave;
  final Widget? header;

  const _SettingsPage({
    required this.title,
    required this.intro,
    required this.builder,
    this.hasSave = true,
    this.header,
  });

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final GlobalKey _stepKey = GlobalKey();
  late PipStepState _state = PipStepState(widget.intro);
  bool _busy = false;

  Future<void> _save() async {
    final state = _stepKey.currentState;
    if (state is! OnboardingStepController) return;
    final step = state as OnboardingStepController;
    setState(() => _busy = true);
    final ok = await step.commit();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(PipSpace.lg, 0, PipSpace.xl, 0),
                  child: PipGuide(message: _state.message, mood: _busy ? PipMood.thinking : _state.mood, pipWidth: 88),
                ),
                if (widget.header != null) widget.header!,
                Expanded(child: widget.builder((s) => setState(() => _state = s), _stepKey)),
                if (widget.hasSave)
                  Padding(
                    padding: const EdgeInsets.all(PipSpace.xl),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy || !_state.canContinue ? null : _save,
                        child: Text(_busy ? 'Checking…' : 'Save'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AiModelPage extends StatelessWidget {
  const AiModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'AI model',
      intro: 'Which brain should I use? I test new keys before saving.',
      builder: (onState, key) => Column(
        children: [
          Expanded(child: BrainStep(key: key, onState: onState)),
          const _MemorySearchPicker(),
        ],
      ),
    );
  }
}

/// Embeddings are a separate setting from chat (some chat providers can't embed).
class _MemorySearchPicker extends StatelessWidget {
  const _MemorySearchPicker();

  @override
  Widget build(BuildContext context) {
    final llm = getIt<LlmRegistryService>();
    return ListenableBuilder(
      listenable: llm,
      builder: (context, _) => ListTile(
        title: const Text('Memory search'),
        subtitle: Text('Which service turns memories into vectors', style: Theme.of(context).textTheme.bodySmall),
        trailing: DropdownButton<String>(
          value: llm.embeddingProviderId,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
            DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
            DropdownMenuItem(value: 'ollama', child: Text('Local')),
          ],
          onChanged: (v) {
            if (v != null) llm.setEmbeddingProvider(v);
          },
        ),
      ),
    );
  }
}

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Connections',
      intro: 'Tap anything to connect it. I only ask for what each one needs.',
      hasSave: false,
      builder: (onState, key) => ConnectionsStep(key: key, onState: onState),
    );
  }
}

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Sync and backup',
      intro: 'Export a locked backup, or set a new backup password below.',
      header: const Padding(
        padding: EdgeInsets.fromLTRB(PipSpace.xl, PipSpace.sm, PipSpace.xl, 0),
        child: PipSyncPanel(),
      ),
      builder: (onState, key) => BackupStep(key: key, onState: onState),
    );
  }
}

class PersonalityPage extends StatefulWidget {
  const PersonalityPage({super.key});

  @override
  State<PersonalityPage> createState() => _PersonalityPageState();
}

class _PersonalityPageState extends State<PersonalityPage> {
  final TextEditingController _name = TextEditingController();
  double? _humor;

  @override
  void initState() {
    super.initState();
    PipProfileService.userName().then((n) => _name.text = n ?? '');
    PipProfileService.humor().then((h) => setState(() => _humor = h));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  (String, PipMood) get _preview {
    final h = _humor ?? .6;
    if (h < .25) return ('Understood. I will keep it brief and factual.', PipMood.idle);
    if (h < .6) return ('Happy to help. Maybe the odd joke.', PipMood.happy);
    if (h < .85) return ('Ooh, fun mode! Puns may occur.', PipMood.excited);
    return ('MAXIMUM SILLINESS ENGAGED. Beep boop!', PipMood.laughing);
  }

  Future<void> _save() async {
    await PipProfileService.setUserName(_name.text);
    if (_humor != null) await PipProfileService.setHumor(_humor!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final (line, mood) = _preview;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Personality')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(PipSpace.xl),
            children: [
              PipGuide(message: line, mood: mood, pipWidth: 88),
              const SizedBox(height: PipSpace.lg),
              Text('What Pip calls you', style: text.titleMedium),
              const SizedBox(height: PipSpace.sm),
              TextField(controller: _name, textCapitalization: TextCapitalization.words),
              const SizedBox(height: PipSpace.xl),
              Text('Humour', style: text.titleMedium),
              if (_humor != null)
                Slider(
                  value: _humor!,
                  divisions: 4,
                  label: '${(_humor! * 100).round()}%',
                  semanticFormatterCallback: (v) => 'Humour ${(v * 100).round()} percent',
                  onChanged: (v) => setState(() => _humor = v),
                ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Dry', style: TextStyle(color: PipColors.muted)), Text('Silly', style: TextStyle(color: PipColors.muted))],
              ),
              const SizedBox(height: PipSpace.xxl),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
