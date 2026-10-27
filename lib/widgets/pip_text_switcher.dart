import 'package:flutter/material.dart';
import '../core/theme/app_motion_tokens.dart';

/// Cross-fades whenever [text] changes. Each change gets its own key, so
/// text that flips A → B → A faster than the fade never puts two children
/// with the same key in the switcher (which throws "Duplicate keys found").
class PipTextSwitcher extends StatefulWidget {
  final String text;
  final Widget Function(BuildContext context, String text) builder;
  final Duration duration;

  const PipTextSwitcher({
    super.key,
    required this.text,
    required this.builder,
    this.duration = AppMotionTokens.fast,
  });

  @override
  State<PipTextSwitcher> createState() => _PipTextSwitcherState();
}

class _PipTextSwitcherState extends State<PipTextSwitcher> {
  int _generation = 0;

  @override
  void didUpdateWidget(PipTextSwitcher old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotionTokens.resolveDuration(context, widget.duration),
      switchInCurve: AppMotionTokens.easeOut,
      child: KeyedSubtree(key: ValueKey(_generation), child: widget.builder(context, widget.text)),
    );
  }
}
