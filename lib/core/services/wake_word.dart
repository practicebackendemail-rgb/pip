/// Recognising "Pip" / "Hey Pip" in on-device speech results, including the
/// words recognisers commonly mishear it as.
abstract final class WakeWord {
  static const Set<String> _names = {
    'pip', 'pipp', 'peep', 'pepe', 'tip', 'tipp', 'pit', 'pitt',
    'pete', 'papp', 'bib', 'bip', 'babe', 'baby', 'bob', 'beep', 'deep',
  };
  static const Set<String> _greetings = {'hey', 'hi', 'hello', 'ok', 'okay', 'yo'};

  /// True if [text] addresses Pip ("pip, …", "hey pip", "ok peep").
  static bool matches(String text) {
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (clean.isEmpty) return false;
    final tokens = clean.split(RegExp(r'\s+'));
    if (tokens.any(_names.contains)) return true;
    for (var i = 0; i < tokens.length - 1; i++) {
      final next = tokens[i + 1];
      if (_greetings.contains(tokens[i]) && (_names.contains(next) || next.startsWith('p') || next.startsWith('b'))) {
        return true;
      }
    }
    return false;
  }

  /// The command after the wake word: "hey pip, set a timer" → "set a timer".
  static String followUp(String raw) {
    final pattern = RegExp(
      r'^\s*(hey|hi|hello|ok|okay|yo)?\s*(pip|babe|baby|peep|tip|pete|beep|bip|bib)\s*[,:\.\-]?\s*',
      caseSensitive: false,
    );
    return raw.replaceAll(pattern, '').trim();
  }
}
