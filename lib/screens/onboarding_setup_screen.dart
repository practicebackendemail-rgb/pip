import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/email_service.dart';
import '../../core/services/llm_registry_service.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../core/services/sync/pip_cloud_sync_coordinator.dart';
import '../../core/theme/apple_theme.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../widgets/glass_container.dart';

class OnboardingSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingSetupScreen({super.key, required this.onComplete});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedProvider = 'gemini';
  String _selectedEmailService = 'gmail';
  bool _isManualEmail = false;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _syncPassController = TextEditingController();
  final TextEditingController _emailServerController = TextEditingController();
  final TextEditingController _emailUserController = TextEditingController();
  final TextEditingController _emailPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final llm = getIt<LlmRegistryService>();
    _selectedProvider = llm.activeProviderId;
    _updateControllersForProvider(_selectedProvider);
    _autoFillEmailHost(_selectedEmailService);
  }

  void _updateControllersForProvider(String provider) {
    final llm = getIt<LlmRegistryService>();
    if (provider == 'gemini') {
      _apiKeyController.text = llm.geminiKey;
    } else if (provider == 'openai') {
      _apiKeyController.text = llm.openAiKey;
    } else if (provider == 'anthropic') {
      _apiKeyController.text = llm.anthropicKey;
    } else if (provider == 'groq') {
      _apiKeyController.text = llm.groqKey;
    } else if (provider == 'ollama') {
      _endpointController.text = llm.ollamaBaseUrl;
    }
  }

  void _autoFillEmailHost(String service) {
    if (service == 'gmail') {
      _emailServerController.text = 'imap.gmail.com';
    } else if (service == 'outlook') {
      _emailServerController.text = 'outlook.office365.com';
    } else if (service == 'yahoo') {
      _emailServerController.text = 'imap.mail.yahoo.com';
    } else if (service == 'icloud') {
      _emailServerController.text = 'imap.mail.me.com';
    }
  }

  void _detectProviderFromEmail(String email) {
    final domain = email.contains('@') ? email.split('@').last.toLowerCase().trim() : '';
    if (domain == 'gmail.com' || domain == 'googlemail.com') {
      setState(() {
        _selectedEmailService = 'gmail';
        _emailServerController.text = 'imap.gmail.com';
      });
    } else if (domain == 'outlook.com' || domain == 'hotmail.com' || domain == 'live.com' || domain == 'msn.com') {
      setState(() {
        _selectedEmailService = 'outlook';
        _emailServerController.text = 'outlook.office365.com';
      });
    } else if (domain == 'yahoo.com' || domain == 'ymail.com') {
      setState(() {
        _selectedEmailService = 'yahoo';
        _emailServerController.text = 'imap.mail.yahoo.com';
      });
    } else if (domain == 'icloud.com' || domain == 'me.com' || domain == 'mac.com') {
      setState(() {
        _selectedEmailService = 'icloud';
        _emailServerController.text = 'imap.mail.me.com';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    _endpointController.dispose();
    _syncPassController.dispose();
    _emailServerController.dispose();
    _emailUserController.dispose();
    _emailPassController.dispose();
    super.dispose();
  }

  void _nextPage() {
    PipSfxService.chirp();
    if (_currentPage < 3) {
      _pageController.nextPage(duration: AppMotionTokens.fast, curve: Curves.easeInOut);
    } else {
      _saveAllAndFinish();
    }
  }

  Future<void> _saveAllAndFinish() async {
    PipSfxService.happy();
    final llm = getIt<LlmRegistryService>();
    await llm.setActiveProvider(_selectedProvider);

    if (_selectedProvider == 'ollama') {
      if (_endpointController.text.trim().isNotEmpty) {
        await llm.setOllamaBaseUrl(_endpointController.text.trim());
      }
    } else {
      if (_apiKeyController.text.trim().isNotEmpty) {
        await llm.setKey(_selectedProvider, _apiKeyController.text.trim());
      }
    }

    if (_syncPassController.text.trim().isNotEmpty) {
      final sync = getIt<PipCloudSyncCoordinator>();
      await sync.setSyncPassphrase(_syncPassController.text.trim());
    }
    if (_emailServerController.text.trim().isNotEmpty && _emailUserController.text.trim().isNotEmpty) {
      final email = getIt<EmailService>();
      await email.saveAndTestConfig(
        server: _emailServerController.text.trim(),
        port: 993,
        user: _emailUserController.text.trim(),
        pass: _emailPassController.text.trim(),
      );
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Step ${_currentPage + 1} of 4", style: const TextStyle(color: Color(0xFFE2A826), fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _saveAllAndFinish, child: const Text("Skip All", style: TextStyle(color: AppleTheme.textTertiary))),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomeStep(),
                  _buildModelStep(),
                  _buildSyncStep(),
                  _buildEmailStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2A826),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _nextPage,
                  child: Text(_currentPage == 3 ? "Complete Setup & Launch Pip" : "Continue", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🤖", style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text("Meet Pip, Your Desk Companion", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text("Pip is local-first, privacy-respecting, and fully configurable. Let's calibrate your AI, cloud sync, and email.", textAlign: TextAlign.center, style: TextStyle(color: AppleTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildModelStep() {
    final providers = [
      {'id': 'gemini', 'label': 'Google Gemini', 'icon': '✨'},
      {'id': 'groq', 'label': 'Groq (Sub-250ms LPU)', 'icon': '⚡'},
      {'id': 'openai', 'label': 'OpenAI (GPT-4o)', 'icon': '🤖'},
      {'id': 'anthropic', 'label': 'Claude 3.5 Sonnet', 'icon': '🧠'},
      {'id': 'ollama', 'label': 'Local Ollama / LM Studio', 'icon': '💻'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 16),
          const Text("🧠 Model Intelligence Provider", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text("Select your preferred AI engine and configure its authentication credentials:", style: TextStyle(color: AppleTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          // Provider Choice Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: providers.map((p) {
              final isSel = _selectedProvider == p['id'];
              return ChoiceChip(
                selectedColor: const Color(0xFFE2A826),
                backgroundColor: const Color(0xFF1E202B),
                label: Text("${p['icon']} ${p['label']}"),
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : Colors.white,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                selected: isSel,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedProvider = p['id'] as String;
                      _updateControllersForProvider(_selectedProvider);
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_selectedProvider == 'ollama')
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 16,
              child: TextField(
                controller: _endpointController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Local Endpoint URL",
                  hintText: "http://localhost:11434/v1",
                  labelStyle: TextStyle(color: AppleTheme.textTertiary),
                  border: InputBorder.none,
                ),
              ),
            )
          else
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 16,
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "$_selectedProvider API Key",
                  hintText: "Enter your private $_selectedProvider secret key",
                  labelStyle: const TextStyle(color: AppleTheme.textTertiary),
                  border: InputBorder.none,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            _selectedProvider == 'ollama'
                ? "Connects directly to your local workstation. Zero cloud transmission."
                : "Stored securely in hardware-backed Keystore/Keychain and synced via shared preferences.",
            style: const TextStyle(color: AppleTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 16),
          const Text("🔒 Private Backup Password", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
            "Pip keeps all your memories, habits, and tasks 100% private to you.\n\n"
            "Create a personal password below. Pip will use this to lock and protect your backups so that only you can ever unlock them on another phone or computer.",
            style: TextStyle(color: AppleTheme.textSecondary, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 16,
            child: TextField(
              controller: _syncPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Backup Password (Optional)",
                hintText: "Choose a password to protect your data",
                labelStyle: TextStyle(color: AppleTheme.textTertiary),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2A826).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2A826).withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("💡 ", style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    "You don't need to understand encryption. Just remember this password—it is the master key to restore your companion if you switch devices.",
                    style: TextStyle(color: Color(0xFFE2A826), fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    final emailPresets = [
      {'id': 'gmail', 'label': 'Gmail', 'host': 'imap.gmail.com'},
      {'id': 'outlook', 'label': 'Outlook / Hotmail', 'host': 'outlook.office365.com'},
      {'id': 'yahoo', 'label': 'Yahoo Mail', 'host': 'imap.mail.yahoo.com'},
      {'id': 'icloud', 'label': 'iCloud', 'host': 'imap.mail.me.com'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 16),
          const Text("📬 Morning Email Briefings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
            "Pip can summarize your important unread emails so you can start your day with total clarity.\n"
            "Select your provider below, or just type your email and we'll detect it automatically.",
            style: TextStyle(color: AppleTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Email Service Quick Select Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emailPresets.map((p) {
              final isSel = !_isManualEmail && _selectedEmailService == p['id'];
              return ChoiceChip(
                selectedColor: const Color(0xFFE2A826),
                backgroundColor: const Color(0xFF1E202B),
                label: Text(p['label'] as String),
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : Colors.white,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                selected: isSel,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _isManualEmail = false;
                      _selectedEmailService = p['id'] as String;
                      _autoFillEmailHost(_selectedEmailService);
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            borderRadius: 16,
            child: TextField(
              controller: _emailUserController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email Address",
                hintText: "yourname@gmail.com",
                labelStyle: TextStyle(color: AppleTheme.textTertiary),
                border: InputBorder.none,
              ),
              onChanged: _detectProviderFromEmail,
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            borderRadius: 16,
            child: TextField(
              controller: _emailPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "App Password",
                hintText: "Generated app-specific password",
                labelStyle: TextStyle(color: AppleTheme.textTertiary),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isManualEmail = !_isManualEmail),
                child: Text(
                  _isManualEmail ? "Hide Custom Server" : "Custom Server Settings",
                  style: const TextStyle(color: Color(0xFFE2A826), fontSize: 13),
                ),
              ),
            ],
          ),
          if (_isManualEmail) ...[
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              borderRadius: 16,
              child: TextField(
                controller: _emailServerController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "IMAP Host Server",
                  hintText: "imap.yourserver.com",
                  labelStyle: TextStyle(color: AppleTheme.textTertiary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ℹ️ ", style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    "For Gmail and Outlook, generate an 'App Password' from your Google or Microsoft security settings so you don't share your master account password.",
                    style: TextStyle(color: AppleTheme.textSecondary, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
