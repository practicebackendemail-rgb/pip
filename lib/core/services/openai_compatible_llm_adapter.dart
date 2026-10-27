import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/llm_provider.dart';

/// Universal adapter for any OpenAI-compatible API endpoint:
/// - Local Ollama (http://localhost:11434/v1)
/// - LM Studio / LocalAI
/// - OpenRouter
/// - Groq / Mistral / DeepSeek
/// - Official OpenAI (https://api.openai.com/v1)
class OpenAiCompatibleLlmAdapter implements LlmProvider {
  final String providerId;
  final String label;
  final String baseUrl;
  final String Function() getApiKey;
  final String modelName;

  @override
  String get id => providerId;

  @override
  String get displayName => label;

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(
        supportsTools: true,
        supportsJsonSchema: true,
        supportsStreaming: true,
        supportsVision: false,
        supportsEmbeddings: true,
        maxContextTokens: 65536,
      );

  OpenAiCompatibleLlmAdapter({
    required this.providerId,
    required this.label,
    required this.baseUrl,
    required this.getApiKey,
    required this.modelName,
  });

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = Uri.parse('$cleanBase/chat/completions');
    final apiKey = getApiKey();

    final headers = {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };

    final body = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      'temperature': 0.7,
    };

    if (jsonSchema != null) {
      body['response_format'] = {
        'type': 'json_schema',
        'json_schema': {
          'name': 'response',
          'strict': true,
          'schema': jsonSchema,
        }
      };
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => {
        'type': 'function',
        'function': {
          'name': t.name,
          'description': t.description,
          'parameters': t.parameterSchema,
        }
      }).toList();
    }

    final res = await http.post(url, headers: headers, body: jsonEncode(body));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final choice = data['choices']?[0];
      final message = choice?['message'];
      final content = (message?['content'] as String?) ?? '';

      final toolCalls = <ToolCallRequest>[];
      final rawCalls = message?['tool_calls'] as List?;
      if (rawCalls != null) {
        for (final call in rawCalls) {
          final fn = call['function'];
          if (fn != null) {
            final args = fn['arguments'] is String
                ? jsonDecode(fn['arguments']) as Map<String, dynamic>
                : (fn['arguments'] as Map<String, dynamic>?) ?? {};
            toolCalls.add(ToolCallRequest(toolName: fn['name'], arguments: args));
          }
        }
      }

      final usage = data['usage'];
      return LlmResponse(
        text: content,
        toolCalls: toolCalls,
        promptTokens: usage?['prompt_tokens'] ?? 0,
        completionTokens: usage?['completion_tokens'] ?? 0,
      );
    } else {
      throw Exception('OpenAI provider error (${res.statusCode}): ${res.body}');
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
  Future<List<List<double>>> embed(List<String> texts) async {
    final apiKey = getApiKey();
    final url = Uri.parse('$baseUrl/embeddings');
    final isOllama = providerId == 'ollama';

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      };

      final body = {
        'input': texts,
        'model': isOllama ? 'nomic-embed-text' : 'text-embedding-3-small',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List?;
        if (list != null) {
          return list.map<List<double>>((item) {
            final emb = item['embedding'] as List;
            return emb.map((v) => (v as num).toDouble()).toList();
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('OpenAiCompatible embed error: $e');
    }
    return [];
  }
}
