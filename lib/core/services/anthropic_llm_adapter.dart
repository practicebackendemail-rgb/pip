import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/llm_provider.dart';

/// Anthropic Claude native Messages API adapter (Phase 2.2)
class AnthropicLlmAdapter implements LlmProvider {
  final String Function() getApiKey;
  final String modelName;

  @override
  String get id => 'anthropic';

  @override
  String get displayName => 'Anthropic Claude';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(
        supportsTools: true,
        supportsJsonSchema: true,
        supportsStreaming: false,
        supportsVision: true,
        supportsEmbeddings: false,
        maxContextTokens: 200000,
      );

  AnthropicLlmAdapter({
    required this.getApiKey,
    this.modelName = 'claude-3-5-sonnet-20241022',
  });

  /// Maps non-system messages to Messages API format: `tool_use` blocks on the
  /// assistant turn and `tool_result` blocks in a user turn. Consecutive
  /// same-role turns are merged so roles alternate as the API requires.
  static List<Map<String, dynamic>> buildMessages(List<LlmMessage> messages) {
    final out = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == 'system') continue;
      final role = m.role == 'assistant' ? 'assistant' : 'user';
      final blocks = <Map<String, dynamic>>[];
      if (m.role == 'tool') {
        blocks.add({'type': 'tool_result', 'tool_use_id': m.toolCallId, 'content': m.content});
      } else {
        if (m.content.isNotEmpty) blocks.add({'type': 'text', 'text': m.content});
        for (final c in m.toolCalls) {
          blocks.add({'type': 'tool_use', 'id': c.id, 'name': c.toolName, 'input': c.arguments});
        }
      }
      if (blocks.isEmpty) continue;
      if (out.isNotEmpty && out.last['role'] == role) {
        (out.last['content'] as List).addAll(blocks);
      } else {
        out.add({'role': role, 'content': blocks});
      }
    }
    return out;
  }

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    final apiKey = getApiKey();
    if (apiKey.isEmpty) throw Exception('Anthropic API key is not configured.');

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final systemPrompt = messages.where((m) => m.role == 'system').map((m) => m.content).join('\n\n');
    final chatMessages = buildMessages(messages);

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    };

    final body = <String, dynamic>{
      'model': modelName,
      'max_tokens': 2048,
      if (systemPrompt.isNotEmpty) 'system': systemPrompt,
      'messages': chatMessages,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => {
        'name': t.name,
        'description': t.description,
        'input_schema': t.parameterSchema,
      }).toList();
    }

    final res = await http.post(url, headers: headers, body: jsonEncode(body));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final contentList = data['content'] as List?;
      final textBuf = StringBuffer();
      final toolCalls = <ToolCallRequest>[];

      if (contentList != null) {
        for (final item in contentList) {
          if (item['type'] == 'text') {
            textBuf.write(item['text']);
          } else if (item['type'] == 'tool_use') {
            final args = (item['input'] as Map<String, dynamic>?) ?? {};
            toolCalls.add(ToolCallRequest(toolName: item['name'], arguments: args, id: item['id'] as String?));
          }
        }
      }

      final usage = data['usage'];
      return LlmResponse(
        text: textBuf.toString(),
        toolCalls: toolCalls,
        promptTokens: usage?['input_tokens'] ?? 0,
        completionTokens: usage?['output_tokens'] ?? 0,
      );
    } else {
      throw Exception('Anthropic error (${res.statusCode}): ${res.body}');
    }
  }

  @override
  Stream<String> chatStream(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
  }) async* {
    final response = await chat(messages, tools: tools);
    yield response.text;
  }

  @override
  Future<List<List<double>>> embed(List<String> texts) async => [];
}
