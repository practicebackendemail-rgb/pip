import 'package:flutter/material.dart';
import '../domain/pip_silent_reaction.dart';
import '../services/pip_sfx_service.dart';
import '../../widgets/pip_params.dart';

/// Translates a PipSilentReaction payload into concrete physical screen parameters,
/// foley audio cues, and LED lighting states without spoken speech.
class PipPhysicalReactionDispatcher {
  PipPhysicalReactionDispatcher._();

  static void dispatchReaction(
    PipSilentReaction reaction, {
    required void Function(PipMood mood, Color ledColor, String thought) onApply,
  }) {
    // 1. Trigger Foley Audio Cue
    switch (reaction.sfxCue) {
      case 'happy':
        PipSfxService.happy();
        break;
      case 'thinking':
        PipSfxService.thinking();
        break;
      case 'blip':
        PipSfxService.blip();
        break;
      case 'sleep':
        PipSfxService.sleep();
        break;
      case 'chirp':
      default:
        PipSfxService.chirp();
        break;
    }

    // 2. Resolve Screen Expression & Servo Posture
    PipMood resolvedMood = PipMood.idle;
    switch (reaction.screenExpression) {
      case 'excited_eyes':
        resolvedMood = PipMood.excited;
        break;
      case 'thinking_look':
        resolvedMood = PipMood.thinking;
        break;
      case 'caring_eyes':
        resolvedMood = PipMood.happy;
        break;
      case 'sleepy_droop':
        resolvedMood = PipMood.sleepy;
        break;
      case 'calm_gaze':
      default:
        resolvedMood = reaction.detectedMood == 'frustrated' ? PipMood.unsure : PipMood.idle;
        break;
    }

    onApply(resolvedMood, reaction.ledColor, reaction.thoughtBubble);
  }
}
