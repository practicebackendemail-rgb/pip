import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/apple_theme.dart';
import '../glass_container.dart';

class PipActionConfirmationBanner extends StatelessWidget {
  final Map<String, dynamic> confirmation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PipActionConfirmationBanner({
    super.key,
    required this.confirmation,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tool = confirmation['tool'] as String? ?? 'Action';
    final args = confirmation['args'] as Map<String, dynamic>? ?? {};
    final level = confirmation['level'] as String? ?? 'level1ConfirmAction';
    final isDangerous = level.contains('level3');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassContainer(
        borderRadius: 18,
        border: Border.all(
          color: isDangerous ? AppleTheme.accentRed : const Color(0xFFE2A826),
          width: 1.5,
        ),
        backgroundColor: const Color(0xFF1E202B),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDangerous ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.bolt_horizontal_circle_fill,
                  color: isDangerous ? AppleTheme.accentRed : const Color(0xFFE2A826),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirm Action: $tool',
                  style: TextStyle(
                    color: isDangerous ? AppleTheme.accentRed : const Color(0xFFE2A826),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              args.entries.map((e) => '${e.key}: "${e.value}"').join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppleTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel', style: TextStyle(color: AppleTheme.textTertiary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDangerous ? AppleTheme.accentRed : const Color(0xFFE2A826),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onConfirm,
                  child: const Text('Execute', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
