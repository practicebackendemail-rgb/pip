import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/domain/llm_provider.dart';
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

class BrainStep extends StatefulWidget {
  final ValueChanged<PipStepState> onState;

  const BrainStep({super.key, required this.onState});

  @override
  State<BrainStep> createState() => _BrainPipStepState();
}

class _BrainPipStepState extends State<BrainStep> implements OnboardingStepController {
  final LlmRegistryService _llm = getIt<LlmRegistryService>();
  final TextEditingController _key = TextEditingController();
  final TextEditingController _endpoint = TextEditingController();
  String _provider = 'gemini';
  bool _showKey = false;
  bool _verified = false;

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
    _verified = false;
  }

  @override
  void dispose() {
    _key.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  bool get _isLocal => _provider == 'ollama';

  @override
  Future<bool> commit() async {
    await _llm.setActiveProvider(_provider);
    if (_isLocal) {
      if (_endpoint.text.trim().isNotEmpty) await _llm.setOllamaBaseUrl(_endpoint.text.trim());
    } else {
      if (_key.text.trim().isEmpty) {
        widget.onState(const PipStepState("No key yet, that's fine. I'll stay quiet until you add one in Settings."));
        return true;
      }
      await _llm.setKey(_provider, _key.text.trim());
    }
    if (_verified) return true;

    widget.onState(const PipStepState('Let me try saying hello with that…', mood: PipMood.thinking));
    try {
      await _llm
          .getActiveProvider()
          .chat([LlmMessage(role: 'user', content: 'Reply with the single word: ready')])
          .timeout(const Duration(seconds: 20));
      _verified = true;
      widget.onState(const PipStepState('It works! I can think now.', mood: PipMood.excited));
      return true;
    } catch (e) {
      widget.onState(PipStepState(
        "Hmm, that didn't work. ${_shortReason(e)} Check it, or go Back and skip for now.",
        mood: PipMood.unsure,
      ));
      return false;
    }
  }

  String _shortReason(Object e) {
    final s = e.toString();
    if (e is TimeoutException) return 'Nobody answered in 20 seconds.';
    if (s.contains('401') || s.contains('403') || s.toLowerCase().contains('api key')) return 'The key was rejected.';
    if (s.contains('SocketException') || s.contains('Connection refused')) return "I couldn't reach the server.";
    return 'The service said no.';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final option = _options.firstWhere((o) => o.id == _provider, orElse: () => _options.first);

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
            decoration: const InputDecoration(labelText: 'Server address', hintText: 'http://localhost:11434/v1'),
          )
        else
          TextField(
            controller: _key,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => _verified = false,
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
        Text(
          _isLocal
              ? 'Nothing leaves your network.'
              : 'Kept in your device\'s secure storage, never in plain settings or URLs.',
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
