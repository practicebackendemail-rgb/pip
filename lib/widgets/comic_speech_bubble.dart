import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/theme/apple_theme.dart';

/// A comic-style speech balloon with a downward-pointing tail pointing at Pip
class ComicSpeechBubble extends StatelessWidget {
  final String text;
  final bool isStreaming;
  final VoidCallback? onDismiss;
  final VoidCallback? onOpenFullLog;

  /// Thumbs feedback; true = helpful. Shown once the reply finishes typing.
  final ValueChanged<bool>? onRate;

  const ComicSpeechBubble({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.onDismiss,
    this.onOpenFullLog,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _ComicBubblePainter(
        color: const Color(0xFF1F222E),
        borderColor: const Color(0xFFE2A826).withValues(alpha: 0.65),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
          maxHeight: 220,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22), // extra bottom padding for tail
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Pip's tag + quick close
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2A826),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "PIP",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (isStreaming) ...[
                  const SizedBox(width: 8),
                  const _ChirpBlinker(),
                ],
                const Spacer(),
                if (onRate != null && !isStreaming) ...[
                  _RateIcon(icon: CupertinoIcons.hand_thumbsup, label: 'Helpful', onTap: () => onRate!(true)),
                  _RateIcon(icon: CupertinoIcons.hand_thumbsdown, label: 'Not helpful', onTap: () => onRate!(false)),
                ],
                if (onOpenFullLog != null)
                  GestureDetector(
                    onTap: onOpenFullLog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        CupertinoIcons.clock_fill,
                        size: 14,
                        color: AppleTheme.textTertiary,
                      ),
                    ),
                  ),
                if (onDismiss != null)
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: AppleTheme.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Speech content (renders clean markdown with typewriter feel)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    strong: const TextStyle(
                      color: Color(0xFFE2A826),
                      fontWeight: FontWeight.w700,
                    ),
                    listBullet: const TextStyle(color: Color(0xFFE2A826)),
                    code: TextStyle(
                      color: const Color(0xFFE2A826),
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comic balloon with downward pointer tail
class _ComicBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _ComicBubblePainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;
    const tailWidth = 16.0;
    const tailHeight = 12.0;

    final bodyHeight = size.height - tailHeight;
    final tailCenterX = size.width * 0.5;

    final path = Path()
      // Top left
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
      // Right edge
      ..lineTo(size.width, bodyHeight - radius)
      ..arcToPoint(Offset(size.width - radius, bodyHeight), radius: const Radius.circular(radius))
      // Bottom edge toward tail
      ..lineTo(tailCenterX + tailWidth / 2, bodyHeight)
      // Downward pointer tail
      ..lineTo(tailCenterX, size.height)
      ..lineTo(tailCenterX - tailWidth / 2, bodyHeight)
      // Left edge
      ..lineTo(radius, bodyHeight)
      ..arcToPoint(Offset(0, bodyHeight - radius), radius: const Radius.circular(radius))
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius))
      ..close();

    // Soft comic shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 10, false);

    // Bubble Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Comic Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ComicBubblePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}

class _ChirpBlinker extends StatefulWidget {
  const _ChirpBlinker();

  @override
  State<_ChirpBlinker> createState() => _ChirpBlinkerState();
}

class _ChirpBlinkerState extends State<_ChirpBlinker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFE2A826),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RateIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RateIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 14, color: AppleTheme.textTertiary),
        ),
      ),
    );
  }
}
