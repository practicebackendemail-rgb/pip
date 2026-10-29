/// Recognises requests that must be done with a tool ("remind me…", "wake
/// me at 7", "add a task", "cancel the gym alarm"), as opposed to questions
/// or chat. Small models sometimes answer these with "Done!" without
/// calling any tool; the chat engine uses this to catch that.
abstract final class ActionIntent {
  static final RegExp _contextPrefix = RegExp(r'^\s*\([^)]*\)\s*');

  static final RegExp _command = RegExp(
    r'^(please\s+|can you\s+|could you\s+|pip,?\s+)*'
    r'(remind|set|wake|add|create|make|schedule|cancel|delete|remove|move|reschedule|book|send|email|'
    r'mark|complete|tick|snooze|save|note|put|turn off|switch off|play)\b',
    caseSensitive: false,
  );

  static final RegExp _anywhere = RegExp(
    r'\b(remind me|wake me|set (an |a )?(alarm|reminder|timer)|alarm (for|at)|add (it |this )?to my (list|tasks|calendar)|'
    r"let'?s play|wanna play|want to play|play (a |some )?games?|"
    r'play (chess|tic.?tac.?toe|x.?o|four in a row|rock paper scissors|20 questions))\b',
    caseSensitive: false,
  );

  /// True when [userText] asks Pip to do something.
  static bool isCommand(String userText) {
    final text = userText.replaceFirst(_contextPrefix, '').trim();
    if (text.isEmpty || text.endsWith('?') && !_anywhere.hasMatch(text)) return false;
    return _command.hasMatch(text) || _anywhere.hasMatch(text);
  }

  /// A reply that asks the user something (fine without a tool).
  static bool isQuestion(String reply) => reply.trim().endsWith('?');
}
