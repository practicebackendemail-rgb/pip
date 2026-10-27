import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/di/injection.dart';
import '../core/services/email_service.dart';
import '../core/services/gemini_service.dart';
import '../core/theme/apple_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/sync/pip_device_settings_section.dart';

class SettingsPersonaScreen extends StatefulWidget {
  const SettingsPersonaScreen({super.key});

  @override
  State<SettingsPersonaScreen> createState() => _SettingsPersonaScreenState();
}

class _SettingsPersonaScreenState extends State<SettingsPersonaScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '993');
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final gemini = getIt<GeminiAssistantService>();
    final email = getIt<EmailService>();
    _apiKeyController.text = gemini.apiKey;
    if (email.config != null) {
      _serverController.text = email.config!.imapServer;
      _portController.text = email.config!.imapPort.toString();
      _userController.text = email.config!.username;
      _passController.text = email.config!.password;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gemini = getIt<GeminiAssistantService>();
    final email = getIt<EmailService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Pip Desk Companion Status Card
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: 20,
            border: Border.all(color: const Color(0xFFE2A826).withValues(alpha: 0.35)),
            backgroundColor: const Color(0xFFE2A826).withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2A826).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pip (Desk Companion)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppleTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active Model: ${gemini.activeModel}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE2A826)),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFFE2A826), size: 22),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. Gemini API Configuration
          const Text(
            'GEMINI INTELLIGENCE API',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppleTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: const TextStyle(color: AppleTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Paste Google AI Studio Key (AIzaSy...)',
                hintStyle: TextStyle(color: AppleTheme.textTertiary, fontSize: 13.5),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Free key available at aistudio.google.com — powers Pip\'s responses and daily briefings.',
            style: TextStyle(fontSize: 11.5, color: AppleTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE2A826),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              gemini.updateApiKey(_apiKeyController.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gemini API Key updated!')),
              );
            },
            child: const Text('Save API Key', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 32),

          const PipDeviceSettingsSection(),

          // 3. Email Integration for Daily Briefings
          const Row(
            children: [
              Icon(CupertinoIcons.mail_solid, color: AppleTheme.accentTeal, size: 18),
              SizedBox(width: 8),
              Text(
                'EMAIL SERVER (IMAP DIGEST)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppleTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _serverController,
                  style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'IMAP Server Host',
                    hintText: 'e.g. imap.gmail.com',
                    labelStyle: TextStyle(color: AppleTheme.textSecondary),
                    hintStyle: TextStyle(color: AppleTheme.textTertiary),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Port (Usually 993)',
                    labelStyle: TextStyle(color: AppleTheme.textSecondary),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userController,
                  style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Email Address / Username',
                    hintText: 'you@domain.com',
                    labelStyle: TextStyle(color: AppleTheme.textSecondary),
                    hintStyle: TextStyle(color: AppleTheme.textTertiary),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Password or App Password',
                    labelStyle: TextStyle(color: AppleTheme.textSecondary),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          if (email.statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              email.statusMessage!,
              style: TextStyle(
                fontSize: 12,
                color: email.statusMessage!.startsWith('Connected') ? AppleTheme.accentGreen : AppleTheme.accentOrange,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: email.isConnecting
                ? null
                : () async {
                    final port = int.tryParse(_portController.text.trim()) ?? 993;
                    await email.saveAndTestConfig(
                      server: _serverController.text.trim(),
                      port: port,
                      user: _userController.text.trim(),
                      pass: _passController.text.trim(),
                    );
                  },
            child: email.isConnecting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Test & Save Mail Connection', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
