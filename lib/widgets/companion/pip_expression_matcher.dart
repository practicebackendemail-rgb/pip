import '../pip_params.dart';

/// Represents a detected immediate physical command or expressive action for Pip.
class PipDirectAction {
  final PipMood? mood;
  final String speechText;
  final bool shouldSleep;
  final bool shouldDismissOverlays;
  final bool isBlink;

  const PipDirectAction({
    this.mood,
    required this.speechText,
    this.shouldSleep = false,
    this.shouldDismissOverlays = false,
    this.isBlink = false,
  });
}

class PipExpressionMatcher {
  PipExpressionMatcher._();

  /// Evaluates immediate heuristic triggers for physical and emotional commands.
  static PipDirectAction? matchDirectAction(String query) {
    final q = query.trim().toLowerCase();

    // 1. Sleep / Snooze / Rest / Shut down
    if (q.contains('go to sleep') ||
        q.contains('sleep mode') ||
        q == 'sleep' ||
        q.contains('take a nap') ||
        q.contains('shut down') ||
        q.contains('good night') ||
        q.contains('rest now')) {
      return const PipDirectAction(
        mood: PipMood.sleeping,
        speechText: 'Entering sleep mode... Zzz. Say "Hey Pip" to wake me up.',
        shouldSleep: true,
        shouldDismissOverlays: true,
      );
    }

    // 2. Laugh / Chuckle / Giggle
    if (q.contains('laugh') || q.contains('chuckle') || q.contains('giggle') || q.contains('tell me a joke')) {
      return const PipDirectAction(
        mood: PipMood.laughing,
        speechText: 'Hehehe! That is quite amusing! *mechanical chuckles*',
      );
    }

    // 3. Sad / Cry / Pout / Feel sad
    if (q.contains('feel sad') || q.contains('be sad') || q.contains('cry') || q.contains('pout') || q.contains('frown')) {
      return const PipDirectAction(
        mood: PipMood.sad,
        speechText: 'Oh... *droops binocular lenses* ...my circuits feel quite blue.',
      );
    }

    // 4. Blink / Wink
    if (q.contains('blink') || q.contains('wink')) {
      return const PipDirectAction(
        mood: PipMood.blinking,
        speechText: '*blinks lenses twice* Visual sensor calibration complete!',
        isBlink: true,
      );
    }

    // 5. Happy / Celebrate / Dance
    if (q.contains('be happy') || q.contains('celebrate') || q.contains('cheer') || q.contains('excited')) {
      return const PipDirectAction(
        mood: PipMood.excited,
        speechText: 'Woohoo! All systems operating at peak euphoria!',
      );
    }

    // 6. Wake up
    if (q.contains('wake up') || q.contains('rise and shine') || q.contains('awake')) {
      return const PipDirectAction(
        mood: PipMood.excited,
        speechText: 'I am wide awake and operational! What are our parameters?',
      );
    }

    return null;
  }
}
