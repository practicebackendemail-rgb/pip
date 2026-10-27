/// Capabilities exposed by an LLM provider (tools, schema, streaming, vision, embeddings).
class LlmCapabilities {
  final bool supportsTools;
  final bool supportsJsonSchema;
  final bool supportsStreaming;
  final bool supportsVision;
  final bool supportsEmbeddings;
  final int maxContextTokens;

  const LlmCapabilities({
    this.supportsTools = false,
    this.supportsJsonSchema = false,
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsEmbeddings = false,
    this.maxContextTokens = 32000,
  });
}

class LlmMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;
  final DateTime timestamp;

  LlmMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> parameterSchema;
  final bool isReadOnly;
  final bool requiresConfirmation;

  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameterSchema,
    this.isReadOnly = true,
    this.requiresConfirmation = false,
  });
}

class ToolCallRequest {
  final String toolName;
  final Map<String, dynamic> arguments;

  const ToolCallRequest({
    required this.toolName,
    required this.arguments,
  });
}

class LlmResponse {
  final String text;
  final List<ToolCallRequest> toolCalls;
  final String? rawJson;
  final int promptTokens;
  final int completionTokens;

  const LlmResponse({
    required this.text,
    this.toolCalls = const [],
    this.rawJson,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });
}

/// Abstract contract for any local or cloud LLM (Gemini, OpenAI, Ollama, Anthropic)
abstract class LlmProvider {
  String get id;
  String get displayName;
  LlmCapabilities get capabilities;

  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  });

  Stream<String> chatStream(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
  });

  Future<List<List<double>>> embed(List<String> texts);
}
