import 'dart:convert';

enum Answer { yes, no, maybe }

/// Pip guesses what you're thinking of with yes/no questions. The model
/// asks; this keeps the record and parses what it says.
class TwentyQuestions {
  static const limit = 20;
  final List<(String, Answer)> asked = [];
  String? currentQuestion;
  bool currentIsGuess = false;

  /// Number of the question on screen (1-based).
  int get number => asked.length + 1;
  bool get outOfQuestions => asked.length >= limit;

  void answer(Answer a) {
    final q = currentQuestion;
    if (q == null) return;
    asked.add((q, a));
    currentQuestion = null;
  }

  String prompt() {
    final history = asked.isEmpty
        ? 'No questions yet.'
        : [for (final (i, (q, a)) in asked.indexed) '${i + 1}. $q -> ${a.name}'].join('\n');
    final left = limit - asked.length;
    return 'We are playing 20 questions. The user thinks of a thing; you find it with yes/no questions.\n'
        'Questions so far:\n$history\n'
        'You have $left questions left. Ask ONE short yes/no question, or if you are fairly sure '
        '(or this is the last question) make a guess phrased as "Is it ...?".\n'
        'Reply only with JSON: {"type":"question" or "guess","text":"..."}';
  }

  /// Reads the model's reply; plain text counts as a question.
  void readReply(String raw) {
    var text = raw.trim();
    var guess = false;
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (m != null) {
      try {
        final j = jsonDecode(m.group(0)!) as Map<String, dynamic>;
        text = (j['text'] as String? ?? text).trim();
        guess = j['type'] == 'guess';
      } catch (_) {}
    }
    currentQuestion = text.isEmpty ? 'Is it something you can hold?' : text;
    currentIsGuess = guess;
  }

  static final _yes = RegExp(r'\b(yes|yeah|yep|correct|right)\b');
  static final _no = RegExp(r'\b(no|nope|nah|wrong)\b');
  static final _maybe = RegExp(r'\b(maybe|sometimes|sort of|kind of|not sure|unsure)\b');

  static Answer? parse(String text) {
    final t = text.toLowerCase();
    if (_maybe.hasMatch(t)) return Answer.maybe;
    if (_yes.hasMatch(t)) return Answer.yes;
    if (_no.hasMatch(t)) return Answer.no;
    return null;
  }
}
