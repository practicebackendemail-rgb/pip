import 'dart:convert';
import '../../../widgets/pip_params.dart';

/// Structured response contract conforming to Section 7.2 of the Implementation Guide.
class PipStructuredReply {
  final String text;
  final String emotion; // happy, excited, sleepy, unsure, proud, sulky, mischievous, calm
  final double intensity; // 0.0 to 1.0
  final String animation; // wave, bounce, tilt, droop, none
  final String voiceStyle; // normal, whisper, cheer, deadpan
  final List<String> memoryCandidates;
  final String? toolCallName;
  final Map<String, dynamic>? toolCallArgs;

  /// False when the model answered in plain text instead of the JSON contract,
  /// meaning emotion/animation are defaults rather than the model's choice.
  final bool isStructured;

  const PipStructuredReply({
    required this.text,
    this.emotion = 'calm',
    this.intensity = 0.5,
    this.animation = 'none',
    this.voiceStyle = 'normal',
    this.memoryCandidates = const [],
    this.toolCallName,
    this.toolCallArgs,
    this.isStructured = true,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'emotion': emotion,
        'intensity': intensity,
        'animation': animation,
        'voice_style': voiceStyle,
        'memory_candidates': memoryCandidates,
        if (toolCallName != null) 'tool_call': toolCallName,
        if (toolCallArgs != null) 'tool_args': toolCallArgs,
      };

  factory PipStructuredReply.fromJson(Map<String, dynamic> json) {
    final rawMem = json['memory_candidates'] as List?;
    final mems = rawMem != null ? rawMem.map((e) => e.toString()).toList() : <String>[];

    String? toolName;
    Map<String, dynamic>? toolArgs;

    if (json['tool_call'] is Map) {
      final tc = json['tool_call'] as Map;
      toolName = tc['name'] as String?;
      if (tc['args'] is Map) {
        toolArgs = Map<String, dynamic>.from(tc['args'] as Map);
      }
    } else if (json['tool_call'] is String) {
      toolName = json['tool_call'] as String?;
      if (json['tool_args'] is Map) {
        toolArgs = Map<String, dynamic>.from(json['tool_args'] as Map);
      }
    }

    return PipStructuredReply(
      text: (json['text'] as String?) ?? '',
      emotion: (json['emotion'] as String?)?.toLowerCase() ?? 'calm',
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
      animation: (json['animation'] as String?)?.toLowerCase() ?? 'none',
      voiceStyle: (json['voice_style'] as String?)?.toLowerCase() ?? 'normal',
      memoryCandidates: mems,
      toolCallName: toolName,
      toolCallArgs: toolArgs,
    );
  }

  /// Parses raw LLM text into a PipStructuredReply with resilient JSON extraction and fallback
  factory PipStructuredReply.parseRaw(String raw) {
    final clean = raw.trim();

    // 1. Attempt markdown codeblock JSON extraction
    final codeblock = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = codeblock.firstMatch(clean);
    final jsonCandidate = match != null ? match.group(1)! : clean;

    try {
      final decoded = jsonDecode(jsonCandidate);
      if (decoded is Map<String, dynamic> && decoded.containsKey('text')) {
        return PipStructuredReply.fromJson(decoded);
      }
    } catch (_) {}

    // 2. Attempt bracket extraction
    final startIdx = clean.indexOf('{');
    final endIdx = clean.lastIndexOf('}');
    if (startIdx != -1 && endIdx > startIdx) {
      try {
        final snippet = clean.substring(startIdx, endIdx + 1);
        final decoded = jsonDecode(snippet);
        if (decoded is Map<String, dynamic> && decoded.containsKey('text')) {
          return PipStructuredReply.fromJson(decoded);
        }
      } catch (_) {}
    }

    // 3. Fallback: treat raw text as plain conversational reply with default calm emotion
    return PipStructuredReply(text: clean, isStructured: false);
  }

  /// Resolves the structured emotion and animation into Pip's visual vector posture
  PipMood toPipMood() {
    switch (emotion) {
      case 'happy':
      case 'proud':
        return PipMood.happy;
      case 'excited':
      case 'mischievous':
        return PipMood.excited;
      case 'sleepy':
        return PipMood.sleepy;
      case 'sulky':
        return PipMood.sad;
      case 'unsure':
        return PipMood.unsure;
      case 'calm':
      default:
        return PipMood.idle;
    }
  }

  /// JSON Schema definition used for model-enforced structured generation (Phase 2 & 3)
  static Map<String, dynamic> get jsonSchema => {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'What Pip says to the user'},
          'emotion': {
            'type': 'string',
            'enum': ['happy', 'excited', 'sleepy', 'unsure', 'proud', 'sulky', 'mischievous', 'calm'],
            'description': 'Pip internal emotion for this turn'
          },
          'intensity': {'type': 'number', 'description': 'Emotional intensity 0.0 to 1.0'},
          'animation': {
            'type': 'string',
            'enum': ['wave', 'bounce', 'tilt', 'droop', 'none'],
            'description': 'Physical servo animation trigger'
          },
          'voice_style': {
            'type': 'string',
            'enum': ['normal', 'whisper', 'cheer', 'deadpan'],
            'description': 'Voice style modifier'
          },
          'memory_candidates': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Important user preferences or habits learned in this turn to save in memory'
          }
        },
        'required': ['text', 'emotion', 'intensity', 'animation', 'voice_style']
      };
}
