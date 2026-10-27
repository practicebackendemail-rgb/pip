import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/email_provider_preset.dart';
import '../../core/services/email_service.dart';
import '../../core/theme/pip_theme.dart';

/// Connect an inbox: pick a provider (or type an address and it is detected),
/// enter an app password, and optionally edit the IMAP and SMTP servers.
/// Saving runs a real IMAP login first. Returns true when connected.
class EmailSetupSheet extends StatefulWidget {
  const EmailSetupSheet({super.key});

  /// Bottom sheet on phones, dialog on wide screens.
  static Future<bool?> show(BuildContext context) {
    if (PipSpace.isWide(context)) {
      return showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: PipColors.surface,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: const EmailSetupSheet()),
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const EmailSetupSheet(),
    );
  }

  @override
  State<EmailSetupSheet> createState() => _EmailSetupSheetState();
}

class _EmailSetupSheetState extends State<EmailSetupSheet> {
  final EmailService _email = getIt<EmailService>();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _imapHost = TextEditingController();
  final _imapPort = TextEditingController(text: '993');
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController(text: '465');
  String _presetId = 'gmail';
  bool _advanced = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = _email.config;
    if (c != null) {
      _address.text = c.username;
      _imapHost.text = c.imapServer;
      _imapPort.text = '${c.imapPort}';
      _smtpHost.text = c.smtpServer;
      _smtpPort.text = '${c.smtpPort}';
      _presetId = EmailProviderPreset.findForEmail(c.username)?.id ?? 'other';
    } else {
      _applyPreset('gmail');
    }
  }

  @override
  void dispose() {
    for (final c in [_address, _password, _imapHost, _imapPort, _smtpHost, _smtpPort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(String id) {
    final p = EmailProviderPreset.byId(id);
    setState(() {
      _presetId = id;
      if (p != null) {
        _imapHost.text = p.imapServer;
        _imapPort.text = '${p.imapPort}';
        _smtpHost.text = p.smtpServer;
        _smtpPort.text = '${p.smtpPort}';
      } else {
        _advanced = true;
      }
    });
  }

  void _onAddress(String value) {
    final p = EmailProviderPreset.findForEmail(value);
    if (p != null && p.id != _presetId) _applyPreset(p.id);
  }

  Future<void> _connect() async {
    final imapPort = int.tryParse(_imapPort.text.trim());
    final smtpPort = int.tryParse(_smtpPort.text.trim());
    if (!_address.text.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email address and app password.');
      return;
    }
    if (_imapHost.text.trim().isEmpty || _smtpHost.text.trim().isEmpty || imapPort == null || smtpPort == null) {
      setState(() {
        _advanced = true;
        _error = 'Fill in the server settings below.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _email.saveAndTestConfig(
      server: _imapHost.text.trim(),
      port: imapPort,
      user: _address.text.trim(),
      pass: _password.text,
      smtpServer: _smtpHost.text.trim(),
      smtpPort: smtpPort,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = "Couldn't sign in. Check the app password and server settings.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preset = EmailProviderPreset.byId(_presetId);
    final smtpPort = int.tryParse(_smtpPort.text) ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(PipSpace.xl, PipSpace.sm, PipSpace.xl, PipSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connect your email', style: text.titleLarge),
            const SizedBox(height: PipSpace.md),
            Wrap(
              spacing: PipSpace.sm,
              runSpacing: PipSpace.sm,
              children: [
                for (final p in EmailProviderPreset.presets)
                  ChoiceChip(label: Text(p.label), selected: _presetId == p.id, onSelected: (_) => _applyPreset(p.id)),
                ChoiceChip(label: const Text('Other'), selected: _presetId == 'other', onSelected: (_) => _applyPreset('other')),
              ],
            ),
            const SizedBox(height: PipSpace.lg),
            TextField(
              controller: _address,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: _onAddress,
              decoration: const InputDecoration(labelText: 'Email address', hintText: 'you@example.com'),
            ),
            const SizedBox(height: PipSpace.md),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'App password'),
            ),
            if (preset?.appPasswordHelp != null) ...[
              const SizedBox(height: PipSpace.sm),
              Text('Create one at ${preset!.appPasswordHelp}. Your normal password usually won\'t work.',
                  style: text.bodySmall),
            ],
            const SizedBox(height: PipSpace.sm),
            TextButton.icon(
              onPressed: () => setState(() => _advanced = !_advanced),
              icon: Icon(_advanced ? Icons.expand_less : Icons.expand_more),
              label: const Text('Server settings'),
            ),
            if (_advanced) ...[
              _HostPort(label: 'Incoming (IMAP)', host: _imapHost, port: _imapPort, onChanged: () => setState(() {})),
              const SizedBox(height: PipSpace.md),
              _HostPort(label: 'Outgoing (SMTP)', host: _smtpHost, port: _smtpPort, onChanged: () => setState(() {})),
              const SizedBox(height: PipSpace.sm),
              Text(
                usesImplicitTls(smtpPort)
                    ? 'Sending uses SSL/TLS from the start (port 465).'
                    : 'Sending upgrades to an encrypted connection with STARTTLS (port $smtpPort). Pip refuses to send unencrypted.',
                style: text.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: PipSpace.md),
              Text(_error!, style: const TextStyle(color: PipColors.danger)),
            ],
            const SizedBox(height: PipSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? 'Signing in…' : 'Connect'),
              ),
            ),
            const SizedBox(height: PipSpace.sm),
            Text('Your password stays in this device\'s secure storage.', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _HostPort extends StatelessWidget {
  final String label;
  final TextEditingController host;
  final TextEditingController port;
  final VoidCallback onChanged;

  const _HostPort({required this.label, required this.host, required this.port, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: host,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: PipSpace.sm),
        SizedBox(
          width: 90,
          child: TextField(
            controller: port,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Port'),
          ),
        ),
      ],
    );
  }
}
