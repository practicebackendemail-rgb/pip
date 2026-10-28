import 'dart:async';

/// Hands what the on-device recognizer heard to Pip exactly once per listen.
///
/// Android often stops with only partial results and never sends a "final"
/// one (after a pause, a timeout or a "no match" error). Without this, those
/// words were thrown away and Pip seemed not to hear. Now a stop waits
/// [grace] for a late final result, then delivers the last partial words.
class ListenDelivery {
  final void Function(String text) onHeard;
  final void Function() onNothing;
  final Duration grace;

  ListenDelivery({required this.onHeard, required this.onNothing, this.grace = const Duration(milliseconds: 300)});

  int _session = 0;
  bool _delivered = true;
  String _words = '';

  /// A new listen started; anything still pending from the last one is void.
  void begin() {
    _session++;
    _delivered = false;
    _words = '';
  }

  /// The recognizer's latest (partial or final) words.
  void heard(String words) => _words = words;

  /// The recognizer stopped: deliver after [grace] unless a final result or
  /// a new listen comes first.
  void stopped() {
    final session = _session;
    Timer(grace, () {
      if (session == _session) deliver();
    });
  }

  /// Delivers now (final result). Does nothing if already delivered.
  void deliver() {
    if (_delivered) return;
    _delivered = true;
    final text = _words.trim();
    text.isEmpty ? onNothing() : onHeard(text);
  }
}
