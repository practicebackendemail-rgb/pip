import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/apple_theme.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../glass_container.dart';

/// Briefing card displaying Pip's executive morning digest.
class BriefingOverlayCard extends StatelessWidget {
  final String content;
  final VoidCallback onRefresh;

  const BriefingOverlayCard({
    super.key,
    required this.content,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotionTokens.shouldReduceMotion(context);

    Widget card = GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.sparkles, color: Color(0xFFE2A826), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Morning Briefing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppleTheme.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: AppleTheme.textSecondary),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: content.isNotEmpty
                  ? MarkdownBody(
                      data: content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: AppleTheme.textPrimary, fontSize: 14, height: 1.5),
                        h1: const TextStyle(color: Color(0xFFE2A826), fontSize: 18, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Color(0xFFE2A826), fontSize: 16, fontWeight: FontWeight.bold),
                        strong: const TextStyle(color: Color(0xFFE2A826), fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: AppleTheme.accentTeal),
                      ),
                    )
                  : const Text(
                      "Pip is synthesizing your emails and agenda...",
                      style: TextStyle(fontSize: 14, height: 1.5, color: AppleTheme.textPrimary),
                    ),
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;
    return card.animate().fadeIn(duration: AppMotionTokens.fast).slideY(begin: 0.08, end: 0);
  }
}
