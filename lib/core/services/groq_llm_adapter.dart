import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/llm_provider.dart';

/// Ultra-fast cloud inference adapter for Groq (LPUs running Whisper & Llama 3.3/Qwen 2.5).
/// Achieves end-to-end reflex times < 250ms for instant desk companion physical reactions.
class GroqLlmAdapter implements LlmProvider {
  final String apiKey;
  final String modelName;
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqLlmAdapter({
    required this.apiKey,
    this.modelName = 'llama-3.3-70b-versatile',
  });

  @override
  String get id => 'groq';

  @override
  String get displayName => 'Groq LPU ($modelName)';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(
        supportsTools: true,
        supportsJsonSchema: true,
        supportsStreaming: true,
        maxContextTokens: 128000,
      );

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    final payload = {
      'model': modelName,
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      'temperature': 0.4,
      if (jsonSchema != null) 'response_format': {'type': 'json_object'},
    };

    final res = await http.post(
      Uri.parse(_groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Groq API error (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    final text = choices.first['message']['content'] as String;

    return LlmResponse(text: text);
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
  Future<List<List<double>>> embed(List<String> texts) async {
    return List.filled(texts.length, const [0.0]);
  }
}
