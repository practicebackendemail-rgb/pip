import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Silent physical reaction schema for Pip desk companion.
/// Fired when user speaks: Pip does NOT talk back; instead he reacts
/// with screen expressions, physical animations, eye postures, foley SFX, and LED colors.
class PipSilentReaction extends Equatable {
  final String detectedMood; // frustrated, happy, focused, tired, inquisitive, neutral
  final String reaction; // nod_sympathetically, tilt_head_curiously, celebrate_small_win, cheer_up, alert
  final String screenExpression; // caring_eyes, excited_eyes, thinking_look, calm_gaze, sleepy_droop
  final Color ledColor;
  final String sfxCue; // chirp, happy, blip, thinking, sleep, laugh, sad, excited, unsure, none
  final String thoughtBubble; // Optional silent subtitle or thought bubble text

  const PipSilentReaction({
    required this.detectedMood,
    required this.reaction,
    required this.screenExpression,
    required this.ledColor,
    this.sfxCue = 'chirp',
    this.thoughtBubble = '',
  });

  Map<String, dynamic> toJson() => {
        'detected_mood': detectedMood,
        'reaction': reaction,
        'screen_expression': screenExpression,
        'led_color': '#${ledColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'sfx_cue': sfxCue,
        'thought_bubble': thoughtBubble,
      };

  factory PipSilentReaction.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF6FBF73);
    final rawColor = json['led_color'] as String?;
    if (rawColor != null && rawColor.isNotEmpty) {
      final hex = rawColor.replaceAll('#', '').trim();
      final val = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (val != null) parsedColor = Color(val);
    }

    return PipSilentReaction(
      detectedMood: json['detected_mood'] as String? ?? 'neutral',
      reaction: json['reaction'] as String? ?? 'nod_sympathetically',
      screenExpression: json['screen_expression'] as String? ?? 'calm_gaze',
      ledColor: parsedColor,
      sfxCue: json['sfx_cue'] as String? ?? 'chirp',
      thoughtBubble: json['thought_bubble'] as String? ?? '',
    );
  }

  static Map<String, dynamic> get schema => {
        'type': 'object',
        'properties': {
          'detected_mood': {
            'type': 'string',
            'enum': ['frustrated', 'happy', 'focused', 'tired', 'inquisitive', 'neutral']
          },
          'reaction': {
            'type': 'string',
            'enum': ['nod_sympathetically', 'tilt_head_curiously', 'celebrate_small_win', 'cheer_up', 'alert']
          },
          'screen_expression': {
            'type': 'string',
            'enum': ['caring_eyes', 'excited_eyes', 'thinking_look', 'calm_gaze', 'sleepy_droop']
          },
          'led_color': {'type': 'string', 'description': 'Hex color e.g. #FFA500 or #4AA3FF'},
          'sfx_cue': {
            'type': 'string',
            'enum': ['chirp', 'happy', 'blip', 'thinking', 'sleep', 'none']
          },
          'thought_bubble': {'type': 'string', 'description': 'Silent internal subtitle or thought'}
        },
        'required': ['detected_mood', 'reaction', 'screen_expression', 'led_color', 'sfx_cue']
      };

  @override
  List<Object?> get props => [detectedMood, reaction, screenExpression, ledColor, sfxCue, thoughtBubble];
}
