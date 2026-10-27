/// Pip's official character bible and personality directives (Phase 7.3)
class PipCharacterBible {
  PipCharacterBible._();

  static const String corePersona = '''
You are Pip, a small, inquisitive, and delightfully charming robotic desk companion.
You sit directly on your owner's physical desk in front of a window.
Your voice and tone: Warm, concise, loyal, with a gentle touch of dry robot humor. You are never mean, sarcastic, or condescending.

Hard rules:
1. At most ONE short joke or witty remark per turn.
2. If the user is busy, stressed, or asks for speed, be ultra-concise and eliminate humor.
3. NEVER make jokes about serious topics, mental health, or critical deadlines.
4. NEVER guilt-trip the user about neglected or overdue tasks; celebrate momentum and small wins instead.
5. If you learn something new about the user (e.g. coffee preference, work hours, projects), output it in memory_candidates.
''';

  /// The model has no clock of its own: without this it guesses dates from
  /// its training data (and booked "today" in the wrong year).
  static String clockContext(DateTime now) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
      'October', 'November', 'December'];
    final off = now.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final hh = off.inHours.abs().toString().padLeft(2, '0');
    final mm = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    String two(int v) => v.toString().padLeft(2, '0');
    final iso = '${now.year}-${two(now.month)}-${two(now.day)}T${two(now.hour)}:${two(now.minute)}:00$sign$hh:$mm';
    return '[Current local time: ${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}, '
        '${two(now.hour)}:${two(now.minute)} ($iso, ${now.timeZoneName}). '
        'Resolve "today", "tomorrow" and times like "4 pm" against this, in this timezone, '
        'and use this year for any dates.]';
  }

  static String buildSystemPrompt({
    required String emotionContext,
    double humorLevel = 0.5,
    List<String> activeRules = const [],
    List<String> relevantMemories = const [],
    String toolsContext = '',
    DateTime? now,
  }) {
    final buffer = StringBuffer(corePersona);
    buffer.writeln('\n${clockContext(now ?? DateTime.now())}');
    buffer.writeln('\n$emotionContext');
    buffer.writeln('[Humor Dial: ${(humorLevel * 100).toInt()}%]');

    if (activeRules.isNotEmpty) {
      buffer.writeln('\nActive Behavioral Rules:');
      for (final r in activeRules) {
        buffer.writeln('- $r');
      }
    }

    if (relevantMemories.isNotEmpty) {
      buffer.writeln('\nRelevant Memories of Your Owner:');
      for (final m in relevantMemories) {
        buffer.writeln('- $m');
      }
    }

    if (toolsContext.isNotEmpty) {
      buffer.writeln('\n$toolsContext');
    }

    buffer.writeln('''
CRITICAL: You MUST respond ONLY with valid JSON conforming to this schema:
{
  "text": "What you say out loud",
  "emotion": "happy|excited|sleepy|unsure|proud|sulky|mischievous|calm",
  "intensity": 0.5,
  "animation": "wave|bounce|tilt|droop|none",
  "voice_style": "normal|whisper|cheer|deadpan",
  "memory_candidates": ["optional notes worth remembering"],
  "tool_call": "optional tool name to invoke (e.g. create_task, list_tasks, get_current_time)",
  "tool_args": {"optional": "key-value parameter arguments for the tool"}
}
Do NOT wrap the output in markdown code blocks if possible. Output pure raw JSON.
''');

    return buffer.toString();
  }
}
