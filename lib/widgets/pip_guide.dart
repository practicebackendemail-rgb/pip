import 'package:flutter/material.dart';
import '../core/theme/pip_theme.dart';
import 'pip_companion.dart';

/// Pip with a speech bubble beside it. Used wherever Pip talks the user
/// through something (onboarding steps, empty states). The bubble text fades
/// between messages and is announced to screen readers.
class PipGuide extends StatelessWidget {
  final String message;
  final PipMood mood;
  final double pipWidth;

  const PipGuide({
    super.key,
    required this.message,
    this.mood = PipMood.idle,
    this.pipWidth = 104,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PipDeskCompanion(mood: mood, width: pipWidth, height: pipWidth * 0.78),
        const SizedBox(width: PipSpace.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: PipSpace.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: PipColors.chip,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.fromBorderSide(BorderSide(color: PipColors.border)),
              ),
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
