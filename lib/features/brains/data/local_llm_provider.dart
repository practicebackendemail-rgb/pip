import 'package:flutter_gemma/flutter_gemma.dart';
import '../../../core/domain/llm_provider.dart';

/// [LlmProvider] over the downloaded on-device model. Each call starts a fresh
/// chat (Pip sends full history every time); the loaded model is kept warm.
/// No native tools: Pip's structured-reply format carries tool calls as text.
class LocalLlmProvider implements LlmProvider {
  final String label;
  LocalLlmProvider({required this.label});

  static InferenceModel? _model;
  static Future<InferenceModel>? _loading;

  /// Frees the loaded model, e.g. after switching or deleting it.
  static Future<void> reset() async {
    final m = _model;
    _model = null;
    _loading = null;
    await m?.close();
  }

  static Future<InferenceModel> _get() async {
    if (_model != null) return _model!;
    _loading ??= FlutterGemma.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.gpu)
        .catchError((Object _) => FlutterGemma.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.cpu));
    return _model = await _loading!;
  }

  @override
  String get id => 'local';

  @override
  String get displayName => label;

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(maxContextTokens: 4096);

  Future<InferenceChat> _chatFor(List<LlmMessage> messages) async {
    final model = await _get();
    final system = messages.where((m) => m.role == 'system').map((m) => m.content).join('\n\n');
    final chat = await model.createChat(systemInstruction: system.isEmpty ? null : system, temperature: .6, topK: 40);
    for (final m in flattenToolMessages(messages.where((m) => m.role != 'system').toList())) {
      await chat.addQueryChunk(Message.text(text: m.content, isUser: m.role == 'user'));
    }
    return chat;
  }

  @override
  Future<LlmResponse> chat(List<LlmMessage> messages, {List<ToolSpec>? tools, Map<String, dynamic>? jsonSchema}) async {
    final chat = await _chatFor(messages);
    final buffer = StringBuffer();
    await for (final r in chat.generateChatResponseAsync()) {
      if (r is TextResponse) buffer.write(r.token);
    }
    return LlmResponse(text: buffer.toString().trim());
  }

  @override
  Stream<String> chatStream(List<LlmMessage> messages, {List<ToolSpec>? tools}) async* {
    final chat = await _chatFor(messages);
    await for (final r in chat.generateChatResponseAsync()) {
      if (r is TextResponse) yield r.token;
    }
  }

  @override
  Future<List<List<double>>> embed(List<String> texts) =>
      throw UnsupportedError('The on-device brain does not make embeddings.');
}
