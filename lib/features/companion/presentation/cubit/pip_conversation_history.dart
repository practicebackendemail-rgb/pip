import '../../../../core/domain/llm_provider.dart';

/// Short in-memory chat history (not persisted). Keeps the last [maxTurns]
/// user/assistant exchanges, dropping the oldest when [maxChars] is exceeded.
class PipConversationHistory {
  final int maxTurns;
  final int maxChars;
  final List<LlmMessage> _messages = [];

  PipConversationHistory({this.maxTurns = 8, this.maxChars = 6000});

  List<LlmMessage> get messages => List.unmodifiable(_messages);

  void addTurn(String userText, String assistantText) {
    if (userText.trim().isEmpty || assistantText.trim().isEmpty) return;
    _messages
      ..add(LlmMessage(role: 'user', content: userText))
      ..add(LlmMessage(role: 'assistant', content: assistantText));
    while (_messages.length > maxTurns * 2) {
      _messages.removeRange(0, 2);
    }
    while (_messages.length > 2 && _chars > maxChars) {
      _messages.removeRange(0, 2);
    }
  }

  void clear() => _messages.clear();

  int get _chars => _messages.fold(0, (sum, m) => sum + m.content.length);
}
