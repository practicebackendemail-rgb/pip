import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/di/injection.dart';
import '../core/services/gemini_service.dart';
import '../core/services/task_provider.dart';
import '../core/services/voice_service.dart';
import '../core/theme/apple_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/pip_companion.dart';
import '../widgets/supreme_intelligence_avatar.dart';

class ChatAssistantScreen extends StatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  State<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() => _isSending = true);

    final gemini = getIt<GeminiAssistantService>();
    final taskProv = getIt<TaskProvider>();
    final voice = getIt<VoiceService>();

    final reply = await gemini.sendMessage(text, currentTasks: taskProv.allTasks);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
      // Speak the assistant's reply out loud
      voice.speak(reply);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gemini = getIt<GeminiAssistantService>();
    final voice = getIt<VoiceService>();

    return ListenableBuilder(
      listenable: Listenable.merge([gemini, voice]),
      builder: (context, _) {
        return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(gemini.currentPersona.avatarEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gemini.currentPersona.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(gemini.currentPersona.role, style: const TextStyle(fontSize: 11, color: AppleTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: gemini.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Builder(
                        builder: (ctx) {
                          final voice = getIt<VoiceService>();
                          final isPip = gemini.currentPersona.id == 'pip';

                          final pipMood = voice.isSpeaking
                              ? PipMood.talking
                              : voice.isListening
                                  ? PipMood.listening
                                  : _isSending
                                      ? PipMood.thinking
                                      : PipMood.idle;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isPip
                                  ? PipDeskCompanion(
                                      width: 280,
                                      height: 200,
                                      mood: pipMood,
                                      onTap: () {
                                        voice.speak("Hi! I'm Pip, your desk companion. How can I help you today?");
                                      },
                                    )
                                  : SupremeIntelligenceCore(
                                      size: 210,
                                      state: _isSending ? AvatarState.thinking : AvatarState.idle,
                                    ),
                              const SizedBox(height: 16),
                              Text(
                                isPip ? "Pip is on your desk" : gemini.currentPersona.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: AppleTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isPip
                                    ? "Tap Pip, talk using the mic, or type an objective below."
                                    : "The Neural Nexus awaits your command. Speak your objectives.",
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                  color: isPip ? const Color(0xFFE2A826) : AppleTheme.accentTeal.withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: gemini.messages.length,
                    itemBuilder: (context, index) {
                      final msg = gemini.messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: GlassContainer(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: 20,
                          backgroundColor: isUser ? AppleTheme.accentBlue.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                          child: Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: isUser ? Colors.white : AppleTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppleTheme.accentBlue),
              ),
            ),
          // Input bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: 26,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppleTheme.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Talk to your assistant...',
                        hintStyle: TextStyle(color: AppleTheme.textTertiary),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      voice.isListening
                          ? CupertinoIcons.mic_fill
                          : CupertinoIcons.mic,
                      color: voice.isListening
                          ? AppleTheme.accentRed
                          : AppleTheme.accentTeal,
                      size: 24,
                    ),
                    onPressed: () {
                      if (voice.isListening) {
                        voice.stopListening();
                      } else {
                        voice.startListening(
                          onResultReceived: (spokenWords) {
                            _textController.text = spokenWords;
                            _sendMessage();
                          },
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: AppleTheme.accentBlue, size: 30),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
