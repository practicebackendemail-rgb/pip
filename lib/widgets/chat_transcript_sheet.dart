import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/theme/apple_theme.dart';

/// Clean slide-up sheet displaying conversation transcript
class ChatTranscriptSheet extends StatelessWidget {
  final List<Map<String, dynamic>> messages;

  const ChatTranscriptSheet({super.key, required this.messages});

  static void show(BuildContext context, List<Map<String, dynamic>> messages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatTranscriptSheet(messages: messages),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF13151C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Color(0xFFE2A826), size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Conversation Transcript",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppleTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      "No past messages yet.\nTalk to Pip using the mic or text input!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppleTheme.textTertiary, fontSize: 13.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppleTheme.accentBlue.withValues(alpha: 0.22)
                                : const Color(0xFF1E212D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUser
                                  ? AppleTheme.accentBlue.withValues(alpha: 0.4)
                                  : const Color(0xFFE2A826).withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? "YOU" : "PIP",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: isUser ? AppleTheme.accentBlue : const Color(0xFFE2A826),
                                ),
                              ),
                              const SizedBox(height: 4),
                              isUser
                                  ? Text(
                                      msg['text'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    )
                                  : MarkdownBody(
                                      data: msg['text'] ?? '',
                                      styleSheet: MarkdownStyleSheet(
                                        p: const TextStyle(
                                          color: AppleTheme.textPrimary,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                        strong: const TextStyle(
                                          color: Color(0xFFE2A826),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        listBullet: const TextStyle(
                                          color: AppleTheme.accentTeal,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
