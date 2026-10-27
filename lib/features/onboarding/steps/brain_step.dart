import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/llm_key_verifier.dart';
import '../../../core/services/llm_registry_service.dart';
import '../../../core/theme/pip_theme.dart';
import '../../../widgets/pip_params.dart';
import '../onboarding_flow.dart';

class _ProviderOption {
  final String id;
  final String label;
  final String detail;
  final String keyHint;

  const _ProviderOption(this.id, this.label, this.detail, this.keyHint);
}

const _options = [
  _ProviderOption('gemini', 'Gemini', 'Recommended. Free tier available.', 'AIza…'),
  _ProviderOption('openai', 'OpenAI', 'GPT models with your own key.', 'sk-…'),
  _ProviderOption('anthropic', 'Anthropic', 'Claude models with your own key.', 'sk-ant-…'),
  _ProviderOption('groq', 'Groq', 'Very fast replies.', 'gsk_…'),
  _ProviderOption('ollama', 'Local (Ollama)', 'Runs on your own computer. No key.', ''),
];

/// Pick a provider, check the key (one quick "list models" call), then pick
/// a model from the ones that key can actually use.
class BrainStep extends StatefulWidget {
  final ValueChanged<PipStepState> onState;

  /// Shown as "Skip for now" during onboarding; null hides it (settings).
  final VoidCallback? onSkip;

  const BrainStep({super.key, required this.onState, this.onSkip});

  @override
  State<BrainStep> createState() => _BrainStepState();
}

class _BrainStepState extends State<BrainStep> implements OnboardingStepController {
  final LlmRegistryService _llm = getIt<LlmRegistryService>();
  final LlmKeyVerifier _verifier = LlmKeyVerifier();
  final TextEditingController _key = TextEditingController();
  final TextEditingController _endpoint = TextEditingController();
  String _provider = 'gemini';
  bool _showKey = false;
  bool _checking = false;
  KeyCheckResult? _result;
  String? _model;

  @override
  void initState() {
    super.initState();
    _provider = _llm.activeProviderId;
    _load();
  }

  void _load() {
    _key.text = switch (_provider) {
      'gemini' => _llm.geminiKey,
      'openai' => _llm.openAiKey,
      'anthropic' => _llm.anthropicKey,
      'groq' => _llm.groqKey,
      _ => '',
    };
    _endpoint.text = _llm.ollamaBaseUrl;
    _result = null;
    _model = null;
  }

  @override
  void dispose() {
    _key.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  bool get _isLocal => _provider == 'ollama';
  String get _secret => _isLocal ? '' : _key.text.trim();

  void _invalidate() {
    if (_result != null) setState(() => _result = null);
  }

  Future<bool> _check() async {
    if (!_isLocal && _secret.isEmpty) {
      widget.onState(const PipStepState('Paste a key first, or skip for now.', mood: PipMood.unsure));
      return false;
    }
    setState(() => _checking = true);
    widget.onState(const PipStepState('Checking that key…', mood: PipMood.thinking));
    final result = await _verifier.verify(_provider, _secret, baseUrl: _endpoint.text.trim());
    if (!mounted) return false;
    final saved = _llm.chatModel(_provider);
    setState(() {
      _checking = false;
      _result = result;
      _model = result.models.contains(saved) ? saved : (result.models.isEmpty ? null : result.models.first);
    });
    widget.onState(result.ok
        ? PipStepState('It works! Pick which model I should think with.', mood: PipMood.excited)
        : PipStepState('Hmm. ${result.message}', mood: PipMood.unsure));
    return result.ok;
  }

  @override
  Future<bool> commit() async {
    if (!_isLocal && _secret.isEmpty) {
      widget.onState(const PipStepState("No key yet, that's fine. I'll stay quiet until you add one in Settings."));
      await _llm.setActiveProvider(_provider);
      return true;
    }
    if (_result?.ok != true && !await _check()) return false;
    await _llm.setActiveProvider(_provider);
    if (_isLocal) {
      await _llm.setOllamaBaseUrl(_endpoint.text.trim());
    } else {
      await _llm.setKey(_provider, _secret);
    }
    if (_model != null) await _llm.setChatModel(_provider, _model!);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final option = _options.firstWhere((o) => o.id == _provider, orElse: () => _options.first);
    final result = _result;

    return ListView(
      padding: const EdgeInsets.all(PipSpace.xl),
      children: [
        RadioGroup<String>(
          groupValue: _provider,
          onChanged: (v) => setState(() {
            _provider = v ?? _provider;
            _load();
          }),
          child: Column(
            children: [
              for (final o in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: PipSpace.sm),
                  child: _ProviderTile(option: o, selected: o.id == _provider),
                ),
            ],
          ),
        ),
        const SizedBox(height: PipSpace.sm),
        if (_isLocal)
          TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            onChanged: (_) => _invalidate(),
            decoration: const InputDecoration(labelText: 'Server address', hintText: 'http://localhost:11434/v1'),
          )
        else
          TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => _invalidate(),
            decoration: InputDecoration(
              labelText: '${option.label} API key',
              hintText: option.keyHint,
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Hide key' : 'Show key',
                icon: Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ),
        const SizedBox(height: PipSpace.sm),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(result?.ok == true ? Icons.check_circle : Icons.wifi_tethering, size: 18,
                      color: result?.ok == true ? PipColors.ok : null),
              label: Text(_checking ? 'Checking…' : (result?.ok == true ? 'Key works' : 'Check key')),
            ),
            const Spacer(),
            if (widget.onSkip != null)
              TextButton(onPressed: _checking ? null : widget.onSkip, child: const Text('Skip for now')),
          ],
        ),
        if (result != null && !result.ok) ...[
          const SizedBox(height: PipSpace.sm),
          Text(result.message, style: const TextStyle(color: PipColors.danger)),
        ],
        if (result?.ok == true && result!.models.isNotEmpty) ...[
          const SizedBox(height: PipSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _model,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Model',
              helperText: '${result.models.length} available with this key. The first is my pick.',
            ),
            items: [
              for (final m in result.models)
                DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (m) => setState(() => _model = m),
          ),
        ],
        const SizedBox(height: PipSpace.md),
        Text(
          _isLocal ? 'Nothing leaves your network.' : "Kept in your device's secure storage, never in plain settings or URLs.",
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final _ProviderOption option;
  final bool selected;

  const _ProviderTile({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? PipColors.chip : PipColors.card,
        borderRadius: BorderRadius.circular(PipSpace.radius),
        border: Border.all(color: selected ? PipColors.amber : PipColors.border, width: selected ? 1.5 : 1),
      ),
      child: RadioListTile<String>(
        value: option.id,
        activeColor: PipColors.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PipSpace.radius)),
        title: Text(option.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(option.detail, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
