import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/services/pip_desktop_window_manager.dart';
import '../../core/theme/pip_theme.dart';
import '../../widgets/pip_companion.dart';
import '../companion/presentation/cubit/pip_stage_cubit.dart';
import '../companion/presentation/cubit/pip_stage_state.dart';
import '../companion/presentation/widgets/pip_command_bar.dart';

/// Shows the whole app at Full, and the small Mini card or the Peek eyes
/// when the Windows window is shrunk (tray, or Ctrl+Shift+P from Peek).
class DesktopSizeSwitch extends StatelessWidget {
  final Widget child;
  const DesktopSizeSwitch({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DesktopSize>(
      valueListenable: PipDesktopWindowManager.size,
      builder: (context, size, _) => switch (size) {
        DesktopSize.full => child,
        DesktopSize.mini => const DesktopMiniView(),
        DesktopSize.peek => const DesktopPeekView(),
      },
    );
  }
}

/// Mini: Pip, its current line and the command bar in a small always-on-top
/// card. Drag Pip to move it. If it rose from Peek on hover, it sinks back
/// once the mouse has been away for a while.
class DesktopMiniView extends StatefulWidget {
  const DesktopMiniView({super.key});

  @override
  State<DesktopMiniView> createState() => _DesktopMiniViewState();
}

class _DesktopMiniViewState extends State<DesktopMiniView> {
  Timer? _sink;

  @override
  void dispose() {
    _sink?.cancel();
    super.dispose();
  }

  void _armSink() {
    _sink?.cancel();
    if (!PipDesktopWindowManager.raisedFromPeek) return;
    _sink = Timer(const Duration(seconds: 6), () => PipDesktopWindowManager.setDesktopSize(DesktopSize.peek));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => _sink?.cancel(),
        onExit: (_) => _armSink(),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.colors.surface,
            borderRadius: BorderRadius.circular(t.space.radiusLg),
            border: Border.all(color: t.colors.border),
          ),
          child: BlocBuilder<PipStageCubit, PipStageState>(
            builder: (context, s) => Column(
              children: [
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      PipDeskCompanion(mood: s.currentMood, width: 130, height: 100),
                      Expanded(
                        child: Text(
                          s.speechText.isNotEmpty ? s.speechText : s.statusText,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Column(
                        children: [
                          _WindowButton(
                            icon: Icons.open_in_full,
                            tooltip: 'Full window',
                            onTap: () => PipDesktopWindowManager.setDesktopSize(DesktopSize.full),
                          ),
                          _WindowButton(
                            icon: Icons.visibility_outlined,
                            tooltip: 'Peek',
                            onTap: () => PipDesktopWindowManager.setDesktopSize(DesktopSize.peek),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.space.sm),
                    child: PipCommandBar(hint: context.l10n.commandHint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _WindowButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        onPressed: onTap,
        icon: Icon(icon, color: context.tokens.colors.textMuted),
      );
}

/// Peek: only Pip's eyes above the taskbar, following the mouse. Hovering
/// raises Mini; a click opens it straight away.
class DesktopPeekView extends StatefulWidget {
  const DesktopPeekView({super.key});

  @override
  State<DesktopPeekView> createState() => _DesktopPeekViewState();
}

class _DesktopPeekViewState extends State<DesktopPeekView> {
  Timer? _poll;
  Timer? _hover;
  double _gaze = 0;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 120), (_) => _track());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hover?.cancel();
    super.dispose();
  }

  /// Gaze from where the cursor is on screen relative to Pip.
  Future<void> _track() async {
    try {
      final cursor = await screenRetriever.getCursorScreenPoint();
      final bounds = await windowManager.getBounds();
      final dx = cursor.dx - bounds.center.dx;
      final g = (dx / 600).clamp(-1.0, 1.0);
      if (mounted && (g - _gaze).abs() > .02) setState(() => _gaze = g);
    } catch (_) {}
  }

  void _raise() => PipDesktopWindowManager.raiseFromPeek();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => _hover = Timer(const Duration(milliseconds: 400), _raise),
        onExit: (_) => _hover?.cancel(),
        child: GestureDetector(
          onTap: _raise,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 112,
              child: Semantics(
                label: 'Pip. Hover or click to open',
                child: PipDeskCompanion(mood: PipMood.idle, width: 150, height: 112, gaze: _gaze),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
