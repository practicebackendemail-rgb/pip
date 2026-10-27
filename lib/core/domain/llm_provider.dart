import 'dart:convert';

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
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String content;
  final DateTime timestamp;

  /// Native tool calls requested by the model (assistant messages only).
  final List<ToolCallRequest> toolCalls;

  /// For 'tool' messages: the call this result answers.
  final String? toolCallId;
  final String? toolName;

  LlmMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Assistant turn that carries the model's native tool calls.
  factory LlmMessage.assistantToolCalls(List<ToolCallRequest> calls, {String text = ''}) =>
      LlmMessage(role: 'assistant', content: text, toolCalls: calls);

  /// Result of a native tool call, matched to the call by id and name.
  factory LlmMessage.toolResult({
    required String toolCallId,
    required String toolName,
    required String content,
  }) =>
      LlmMessage(role: 'tool', content: content, toolCallId: toolCallId, toolName: toolName);

  bool get hasToolCalls => toolCalls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Text fallback for providers without native tool messages: tool calls and
/// results become plain assistant/user text so the API never sees role 'tool'.
List<LlmMessage> flattenToolMessages(List<LlmMessage> messages) {
  return messages.map((m) {
    if (m.role == 'tool') {
      return LlmMessage(role: 'user', content: 'Tool result (${m.toolName ?? 'tool'}): ${m.content}');
    }
    if (m.hasToolCalls) {
      final calls = m.toolCalls.map((c) => '${c.toolName}(${jsonEncode(c.arguments)})').join(', ');
      final prefix = m.content.isEmpty ? '' : '${m.content}\n';
      return LlmMessage(role: 'assistant', content: '${prefix}Calling tool: $calls');
    }
    return m;
  }).toList();
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

  /// Provider-issued call id. Null when the call was parsed from reply text
  /// rather than returned natively, in which case the text fallback is used.
  final String? id;

  /// Opaque provider data that must be echoed back (e.g. Gemini thoughtSignature).
  final Map<String, dynamic>? providerMeta;

  const ToolCallRequest({
    required this.toolName,
    required this.arguments,
    this.id,
    this.providerMeta,
  });

  bool get isNative => id != null;
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
