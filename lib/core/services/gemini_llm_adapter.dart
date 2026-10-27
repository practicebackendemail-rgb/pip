import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/llm_provider.dart';

/// Native Gemini implementation of the LlmProvider domain interface.
class GeminiLlmAdapter implements LlmProvider {
  final String Function() getApiKey;
  final String activeModel;

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(
        supportsTools: true,
        supportsJsonSchema: true,
        supportsStreaming: false,
        supportsVision: true,
        supportsEmbeddings: true,
        maxContextTokens: 1048576,
      );

  GeminiLlmAdapter({
    required this.getApiKey,
    this.activeModel = 'gemini-1.5-flash',
  });

  /// Maps messages to Gemini contents: tool calls become functionCall parts
  /// (echoing any thoughtSignature) and results become functionResponse parts.
  /// Consecutive same-role turns are merged, since Gemini expects parallel
  /// function responses in a single user turn.
  static List<Map<String, dynamic>> buildContents(List<LlmMessage> messages) {
    final contents = <Map<String, dynamic>>[];
    final apiIds = <String, String>{};
    for (final m in messages) {
      final role = m.role == 'assistant' ? 'model' : 'user';
      final parts = <Map<String, dynamic>>[];
      if (m.role == 'tool') {
        Map<String, dynamic> response;
        try {
          final decoded = jsonDecode(m.content);
          response = decoded is Map<String, dynamic> ? decoded : {'result': decoded};
        } catch (_) {
          response = {'result': m.content};
        }
        final apiId = apiIds[m.toolCallId];
        parts.add({
          'functionResponse': {
            'name': m.toolName ?? 'tool',
            'id': ?apiId,
            'response': response,
          }
        });
      } else {
        if (m.content.isNotEmpty || !m.hasToolCalls) parts.add({'text': m.content});
        for (final c in m.toolCalls) {
          final apiId = c.providerMeta?['apiId'] as String?;
          if (apiId != null && c.id != null) apiIds[c.id!] = apiId;
          parts.add({
            'functionCall': {
              'name': c.toolName,
              'args': c.arguments,
              'id': ?apiId,
            },
            'thoughtSignature': ?c.providerMeta?['thoughtSignature'],
          });
        }
      }
      if (contents.isNotEmpty && contents.last['role'] == role) {
        (contents.last['parts'] as List).addAll(parts);
      } else {
        contents.add({'role': role, 'parts': parts});
      }
    }
    return contents;
  }

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    final apiKey = getApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured.');
    }

    final contents = buildContents(messages);

    final candidateModels = {
      'gemini-3.8-flash',
      'gemini-2.5-flash',
      'gemini-flash-latest',
      'gemini-3.7-flash',
      'gemini-3.6-flash',
      'gemini-2.5-pro',
      'gemini-2.5-flash-lite',
      activeModel,
    }.where((m) => m.isNotEmpty && m != 'gemini-1.5-flash').toList();

    String lastErr = '';
    for (final modelId in candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent',
        );

        final Map<String, dynamic> body = {
          'contents': contents,
        };

        if (tools != null && tools.isNotEmpty) {
          body['tools'] = [
            {
              'functionDeclarations': tools.map((t) => {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameterSchema,
              }).toList(),
            }
          ];
        }

        if (jsonSchema != null) {
          body['generationConfig'] = {
            'responseMimeType': 'application/json',
            'responseSchema': jsonSchema,
          };
        }

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            String text = '';
            final toolCalls = <ToolCallRequest>[];

            if (parts != null) {
              for (final part in parts) {
                if (part.containsKey('text')) {
                  text += part['text'] as String;
                } else if (part.containsKey('functionCall')) {
                  final fn = part['functionCall'] as Map<String, dynamic>;
                  final name = fn['name'] as String;
                  final args = (fn['args'] as Map<String, dynamic>?) ?? {};
                  final signature = part['thoughtSignature'] as String?;
                  final apiId = fn['id'] as String?;
                  toolCalls.add(ToolCallRequest(
                    toolName: name,
                    arguments: args,
                    id: apiId ?? 'local_${toolCalls.length}_$name',
                    providerMeta: {
                      'thoughtSignature': ?signature,
                      'apiId': ?apiId,
                    },
                  ));
                }
              }
            }
            return LlmResponse(text: text, toolCalls: toolCalls);
          }
        } else {
          lastErr = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception('Gemini failed: $lastErr');
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
    if (apiKey.isEmpty) return [];

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:batchEmbedContents',
    );

    final body = {
      'requests': texts.map((t) => {
        'model': 'models/text-embedding-004',
        'content': {'parts': [{'text': t}]},
      }).toList(),
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final embeddings = data['embeddings'] as List?;
      if (embeddings != null) {
        return embeddings.map<List<double>>((e) {
          final values = e['values'] as List;
          return values.map((v) => (v as num).toDouble()).toList();
        }).toList();
      }
    }
    return [];
  }
}
