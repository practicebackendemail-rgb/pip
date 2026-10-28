import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../pip_companion.dart';

/// What the floating bubble is showing.
enum BubbleState {
  /// Small round Pip after a while without anything happening.
  docked,

  /// Round Pip that blinks and looks around. Drag it; it snaps to an edge.
  resting,

  /// Talk capsule: mic meter while listening, then Pip's one-line answer.
  talking,

  /// Long-press: quick actions fan out.
  actions,
}

/// Pip over other apps (Android). Runs in its own engine, so it only talks
/// to the app through [FlutterOverlayWindow.shareData]; [PipOverlayBridge]
/// on the other side sends mood, speech and listening state back.
class PipOverlayWidget extends StatefulWidget {
  const PipOverlayWidget({super.key});

  /// Window sizes (dp) per state.
  static const Map<BubbleState, Size> sizes = {
    BubbleState.docked: Size(56, 56),
    BubbleState.resting: Size(84, 84),
    BubbleState.talking: Size(300, 92),
    BubbleState.actions: Size(220, 180),
  };

  @override
  State<PipOverlayWidget> createState() => _PipOverlayWidgetState();
}

class _PipOverlayWidgetState extends State<PipOverlayWidget> {
  static const _amber = Color(0xFFE2A826);
  static const _ink = Color(0xFF161C1F);
  static const _line = Color(0xFF3B4A4F);

  PipMood _mood = PipMood.idle;
  String _speech = '';
  bool _listening = false;
  BubbleState _state = BubbleState.resting;
  Timer? _idle;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen(_onData);
    _armIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    try {
      final d = jsonDecode(data);
      if (d is! Map<String, dynamic>) return;
      final wasListening = _listening;
      setState(() {
        _mood = PipMood.values.asNameMap()[d['mood']] ?? _mood;
        _speech = d['speech'] as String? ?? _speech;
        _listening = d['isListening'] as bool? ?? _listening;
      });
      // A new answer (or the mic opening from the app) brings the capsule up.
      if (_listening || (wasListening && _speech.isNotEmpty)) _go(BubbleState.talking);
      _armIdle();
    } catch (_) {}
  }

  /// Collapse back after quiet time: capsule → resting → docked.
  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 8), () {
      if (_listening) return _armIdle();
      _go(_state == BubbleState.resting ? BubbleState.docked : BubbleState.resting);
      if (_state != BubbleState.docked) _armIdle();
    });
  }

  Future<void> _go(BubbleState s) async {
    if (s == _state) return;
    final size = PipOverlayWidget.sizes[s]!;
    await FlutterOverlayWindow.resizeOverlay(size.width.round(), size.height.round(), true);
    if (mounted) setState(() => _state = s);
  }

  void _send(Map<String, Object> msg) => FlutterOverlayWindow.shareData(jsonEncode(msg));

  void _tap() {
    _armIdle();
    if (_state == BubbleState.talking && _listening) return _send({'action': 'stop_listen'});
    _go(BubbleState.talking);
    _send({'action': 'tap_listen'});
  }

  void _quick(String query) {
    _send({'action': 'quick', 'query': query});
    _go(BubbleState.talking);
    _armIdle();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _tap,
        onLongPress: () {
          _go(BubbleState.actions);
          _armIdle();
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_state) {
            BubbleState.docked || BubbleState.resting => _round(),
            BubbleState.talking => _capsule(),
            BubbleState.actions => _actions(),
          },
        ),
      ),
    );
  }

  Widget _pip(double w) => IgnorePointer(child: PipDeskCompanion(mood: _listening ? PipMood.listening : _mood, width: w, height: w * .75));

  Widget _round() {
    final d = PipOverlayWidget.sizes[_state]!.width - 4;
    return Center(
      key: ValueKey(_state),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: .92),
          shape: BoxShape.circle,
          border: Border.all(color: _listening ? _amber : _line, width: 2),
        ),
        alignment: Alignment.center,
        child: Semantics(label: 'Pip. Tap to talk, long-press for actions', child: _pip(d * .85)),
      ),
    );
  }

  Widget _capsule() {
    return Container(
      key: const ValueKey('capsule'),
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(color: _listening ? _amber : _line, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(width: 72, child: _pip(68)),
          const SizedBox(width: 6),
          Expanded(
            child: _listening
                ? const _MicMeter(color: _amber)
                : Text(
                    _speech.isEmpty ? 'Tap to talk' : _speech,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE8ECEB), fontSize: 13, height: 1.25),
                  ),
          ),
          if (_listening)
            IconButton(
              tooltip: 'Stop listening',
              onPressed: () => _send({'action': 'stop_listen'}),
              icon: const Icon(Icons.stop_rounded, color: _amber),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    Widget chip(IconData icon, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: const Color(0xFF232C30),
            shape: const StadiumBorder(side: BorderSide(color: _line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: _amber),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Color(0xFFE8ECEB), fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
    return Row(
      key: const ValueKey('actions'),
      children: [
        SizedBox(width: 72, child: _pip(68)),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chip(Icons.alarm, 'Alarm', () => _quick('Set an alarm')),
              chip(Icons.check, 'Task', () => _quick('Add a task')),
              chip(Icons.wb_sunny_outlined, 'Brief me', () => _quick('Brief me')),
              chip(Icons.close, 'Hide', () => FlutterOverlayWindow.closeOverlay()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bouncing bars while Pip listens.
class _MicMeter extends StatefulWidget {
  final Color color;
  const _MicMeter({required this.color});

  @override
  State<_MicMeter> createState() => _MicMeterState();
}

class _MicMeterState extends State<_MicMeter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Listening',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          children: [
            const Text('Listening…', style: TextStyle(color: Color(0xFFE8ECEB), fontSize: 13)),
            const SizedBox(width: 8),
            for (var i = 0; i < 5; i++)
              Container(
                width: 4,
                height: 6 + 14 * (0.5 + 0.5 * math.sin((_c.value + i * .17) * 2 * math.pi)),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}
