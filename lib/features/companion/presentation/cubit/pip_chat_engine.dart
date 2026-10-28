import '../../../../core/domain/llm_provider.dart';
import '../../domain/pip_structured_reply.dart';
import 'pip_conversation_history.dart';
import 'pip_tool_coordinator.dart';

/// Result of one user query: either a final reply or a tool awaiting confirmation.
class PipChatOutcome {
  final PipStructuredReply? reply;
  final PipToolExecutionResult? pendingConfirmation;

  const PipChatOutcome.reply(PipStructuredReply this.reply) : pendingConfirmation = null;
  const PipChatOutcome.confirmation(PipToolExecutionResult this.pendingConfirmation) : reply = null;
}

/// Runs the tool loop for one query. At most [maxToolRounds] tool rounds; the
/// reply always comes from a call with the JSON schema so it carries emotion.
class PipChatEngine {
  static const int maxToolRounds = 5;
  static const Duration callTimeout = Duration(seconds: 45);

  final PipToolCoordinator toolCoordinator;
  final PipConversationHistory history;

  PipChatEngine({required this.toolCoordinator, PipConversationHistory? history})
      : history = history ?? PipConversationHistory();

  Future<PipChatOutcome> run({
    required LlmProvider provider,
    required String systemContext,
    required String userText,
    List<ToolSpec>? toolSpecs,
  }) async {
    final messages = <LlmMessage>[
      LlmMessage(role: 'system', content: systemContext),
      ...history.messages,
      LlmMessage(role: 'user', content: userText),
    ];

    for (var round = 0; round < maxToolRounds; round++) {
      final response = await provider
          .chat(
            messages,
            tools: toolSpecs,
            jsonSchema: toolSpecs == null ? PipStructuredReply.jsonSchema : null,
          )
          .timeout(callTimeout);

      final calls = List<ToolCallRequest>.from(response.toolCalls);
      final parsed = PipStructuredReply.parseRaw(response.text);
      if (calls.isEmpty && parsed.toolCallName?.isNotEmpty == true) {
        calls.add(ToolCallRequest(toolName: parsed.toolCallName!, arguments: parsed.toolCallArgs ?? {}));
      }

      // No tool needed: that's the answer. A plain-text reply (the schema
      // isn't enforced while tools are on) is used as is: a second "make it
      // JSON" call only to recover the emotion doubled the wait.
      if (calls.isEmpty) return _finish(userText, parsed);

      final exec = await toolCoordinator.executeCalls(calls, messages);
      if (exec.requiresConfirmation) return PipChatOutcome.confirmation(exec);
    }

    messages.add(LlmMessage(
      role: 'user',
      content: 'Reply to the user now, without calling tools, as the JSON object described.',
    ));
    final finalResponse = await provider
        .chat(messages, tools: null, jsonSchema: PipStructuredReply.jsonSchema)
        .timeout(callTimeout);
    return _finish(userText, PipStructuredReply.parseRaw(finalResponse.text));
  }

  PipChatOutcome _finish(String userText, PipStructuredReply reply) {
    history.addTurn(userText, reply.text);
    return PipChatOutcome.reply(reply);
  }

  /// Records a turn that ended outside the loop (e.g. an action you
  /// confirmed), so the next question can refer back to it.
  void remember(String userText, String pipText) => history.addTurn(userText, pipText);
}
