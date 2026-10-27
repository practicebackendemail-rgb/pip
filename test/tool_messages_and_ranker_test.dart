import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_ranker.dart';
import 'package:personal_assistant/core/domain/pip_tool.dart';
import 'package:personal_assistant/core/services/anthropic_llm_adapter.dart';
import 'package:personal_assistant/core/services/gemini_llm_adapter.dart';
import 'package:personal_assistant/core/services/openai_compatible_llm_adapter.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_tool_coordinator.dart';

class _EchoTool extends PipTool {
  const _EchoTool()
      : super(
          name: 'echo',
          description: 'Echoes args',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async => {'echo': args['x']};
}

class _FakeEventLog implements EventLogService {
  @override
  Future<void> log(String type, [Map<String, dynamic>? payload]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PipToolCoordinator _coordinator() {
  final registry = PipToolRegistry()..registerTool(const _EchoTool());
  return PipToolCoordinator(toolRegistry: registry, eventLog: _FakeEventLog());
}

void main() {
  group('Tool messages', () {
    test('native call is echoed as assistant tool call followed by matching result', () async {
      final messages = <LlmMessage>[LlmMessage(role: 'user', content: 'hi')];
      await _coordinator().executeCalls(
        [const ToolCallRequest(toolName: 'echo', arguments: {'x': 1}, id: 'call_abc')],
        messages,
      );

      expect(messages, hasLength(3));
      expect(messages[1].role, 'assistant');
      expect(messages[1].toolCalls.single.id, 'call_abc');
      expect(messages[2].role, 'tool');
      expect(messages[2].toolCallId, 'call_abc');
      expect(messages[2].toolName, 'echo');
      expect(jsonDecode(messages[2].content), {'echo': 1});
    });

    test('text-parsed call (no id) uses text fallback, never role tool', () async {
      final messages = <LlmMessage>[];
      await _coordinator().executeCalls(
        [const ToolCallRequest(toolName: 'echo', arguments: {'x': 2})],
        messages,
      );
      expect(messages.single.role, 'user');
      expect(messages.single.content, contains('Tool result (echo)'));
    });

    test('unknown tool still answers the call so the API sees a result', () async {
      final messages = <LlmMessage>[];
      await _coordinator().executeCalls(
        [const ToolCallRequest(toolName: 'nope', arguments: {}, id: 'c1')],
        messages,
      );
      expect(messages.last.role, 'tool');
      expect(messages.last.content, contains('Unknown tool'));
    });

    final convo = [
      LlmMessage(role: 'system', content: 'sys'),
      LlmMessage(role: 'user', content: 'weather?'),
      LlmMessage.assistantToolCalls([
        const ToolCallRequest(
          toolName: 'echo',
          arguments: {'x': 1},
          id: 'id1',
          providerMeta: {'thoughtSignature': 'sig', 'apiId': 'g1'},
        ),
        const ToolCallRequest(toolName: 'echo', arguments: {'x': 2}, id: 'id2'),
      ]),
      LlmMessage.toolResult(toolCallId: 'id1', toolName: 'echo', content: '{"echo":1}'),
      LlmMessage.toolResult(toolCallId: 'id2', toolName: 'echo', content: '{"echo":2}'),
    ];

    test('OpenAI mapping uses tool_calls and tool_call_id', () {
      final out = OpenAiCompatibleLlmAdapter.buildMessages(convo);
      expect(out[2]['role'], 'assistant');
      final calls = out[2]['tool_calls'] as List;
      expect(calls[0]['id'], 'id1');
      expect(calls[0]['function']['arguments'], '{"x":1}');
      expect(out[3], {'role': 'tool', 'tool_call_id': 'id1', 'content': '{"echo":1}'});
      expect(out[4]['tool_call_id'], 'id2');
    });

    test('Anthropic mapping uses tool_use and merges tool_result into one user turn', () {
      final out = AnthropicLlmAdapter.buildMessages(convo);
      expect(out.map((m) => m['role']), ['user', 'assistant', 'user']);
      final uses = out[1]['content'] as List;
      expect(uses.map((b) => b['type']), ['tool_use', 'tool_use']);
      final results = out[2]['content'] as List;
      expect(results.map((b) => b['tool_use_id']), ['id1', 'id2']);
      expect(results.every((b) => b['type'] == 'tool_result'), isTrue);
    });

    test('Gemini mapping uses functionCall/functionResponse and echoes thoughtSignature', () {
      final out = GeminiLlmAdapter.buildContents(convo);
      // system + user merge into one user turn, then model, then user responses
      expect(out.map((c) => c['role']), ['user', 'model', 'user']);
      final callParts = out[1]['parts'] as List;
      expect(callParts[0]['functionCall']['name'], 'echo');
      expect(callParts[0]['functionCall']['id'], 'g1');
      expect(callParts[0]['thoughtSignature'], 'sig');
      expect(callParts[1].containsKey('thoughtSignature'), isFalse);
      final respParts = out[2]['parts'] as List;
      expect(respParts[0]['functionResponse']['id'], 'g1');
      expect(respParts[0]['functionResponse']['response'], {'echo': 1});
      expect(respParts[1]['functionResponse'].containsKey('id'), isFalse);
    });

    test('flattenToolMessages removes tool roles for text-only providers', () {
      final out = flattenToolMessages(convo);
      expect(out.any((m) => m.role == 'tool' || m.hasToolCalls), isFalse);
    });
  });

  group('MemoryRanker keyword fill', () {
    final now = DateTime(2026, 10, 27);
    MemoryItem mem(String id, String text, {List<double>? vec, String model = 'gemini:a'}) =>
        MemoryItem(id: id, text: text, embedding: vec, embeddingModel: model, createdAt: now);

    test('fills short vector results with keyword matches from other models', () {
      final memories = [
        mem('v1', 'likes coffee', vec: [1, 0]),
        mem('old', 'coffee every morning', model: 'none'),
        mem('other', 'coffee from ollama', vec: [0, 1, 0], model: 'ollama:b'),
        mem('noise', 'unrelated item', model: 'none'),
      ];
      final out = MemoryRanker.rankMemories(
        memories: memories,
        queryEmbedding: [1, 0],
        queryText: 'coffee',
        targetEmbeddingModel: 'gemini:a',
        limit: 5,
      );
      expect(out.first.id, 'v1');
      expect(out.map((m) => m.id).toSet(), {'v1', 'old', 'other'});
    });

    test('vector hits filling the limit are returned alone', () {
      final out = MemoryRanker.rankMemories(
        memories: [mem('v1', 'a', vec: [1, 0]), mem('k', 'a keyword')],
        queryEmbedding: [1, 0],
        queryText: 'keyword',
        targetEmbeddingModel: 'gemini:a',
        limit: 1,
      );
      expect(out.map((m) => m.id), ['v1']);
    });

    test('same model but different vector length is not compared', () {
      final out = MemoryRanker.rankMemories(
        memories: [mem('bad', 'zzz', vec: [1, 0, 0])],
        queryEmbedding: [1, 0],
        queryText: 'qqq',
        targetEmbeddingModel: 'gemini:a',
      );
      // Reached via the keyword path only (no vector hits), not via cosine.
      expect(out.single.id, 'bad');
    });
  });
}
