import 'dart:convert';
import '../../../activity/presentation/activity_cubit.dart';
import '../../../../core/domain/event_log.dart';
import '../../../../core/domain/llm_provider.dart';
import '../../../../core/domain/pip_tool.dart';
import '../../../../core/services/pip_tool_registry.dart';

class PipToolExecutionResult {
  final bool requiresConfirmation;
  final String? pendingToolName;
  final Map<String, dynamic>? pendingArgs;
  final String? pendingDescription;
  final ToolConfirmationLevel? pendingLevel;

  const PipToolExecutionResult({
    this.requiresConfirmation = false,
    this.pendingToolName,
    this.pendingArgs,
    this.pendingDescription,
    this.pendingLevel,
  });
}

/// Coordinates multi-turn LLM tool execution, confirmation gates, and result messages
class PipToolCoordinator {
  final PipToolRegistry toolRegistry;
  final EventLogService eventLog;

  const PipToolCoordinator({
    required this.toolRegistry,
    required this.eventLog,
  });

  /// Executes tools adhering strictly to confirmation levels.
  /// If Level 1 or 3 is encountered, execution halts and yields confirmation details.
  Future<PipToolExecutionResult> executeCalls(
    List<ToolCallRequest> calls,
    List<LlmMessage> messages,
  ) async {
    // Native calls must be echoed as an assistant turn before their results,
    // otherwise OpenAI/Anthropic reject the orphaned tool results.
    final nativeCalls = calls.where((c) => c.isNative).toList();
    if (nativeCalls.isNotEmpty) {
      messages.add(LlmMessage.assistantToolCalls(nativeCalls));
    }

    for (final call in calls) {
      final tool = toolRegistry.getTool(call.toolName);
      if (tool == null) {
        _addResult(messages, call, {'error': 'Unknown tool: ${call.toolName}'});
        continue;
      }

      if (tool.confirmationLevel == ToolConfirmationLevel.level1ConfirmAction ||
          tool.confirmationLevel == ToolConfirmationLevel.level3DangerousDoubleConfirm) {
        return PipToolExecutionResult(
          requiresConfirmation: true,
          pendingToolName: call.toolName,
          pendingArgs: call.arguments,
          pendingDescription: tool.description,
          pendingLevel: tool.confirmationLevel,
        );
      }

      // Level 0 or 2: Execute immediately
      // Log tool names and arg keys only: values and results can hold email
      // bodies, recipients or note text, which must not reach the event log.
      eventLog.log('tool_invoked', {'tool': call.toolName, 'arg_keys': call.arguments.keys.toList()});
      try {
        final result = await tool.execute(call.arguments);
        eventLog.log(result.containsKey('error') ? 'tool_failure' : 'tool_success', {'tool': call.toolName});
        ActivityRecorder.tool(call.toolName, call.arguments, result);
        _addResult(messages, call, result);
      } catch (e) {
        eventLog.log('tool_failure', {'tool': call.toolName, 'exception': e.runtimeType.toString()});
        _addResult(messages, call, {'error': e.toString()});
      }
    }
    return const PipToolExecutionResult(requiresConfirmation: false);
  }

  void _addResult(List<LlmMessage> messages, ToolCallRequest call, Map<String, dynamic> result) {
    if (call.isNative) {
      messages.add(LlmMessage.toolResult(
        toolCallId: call.id!,
        toolName: call.toolName,
        content: jsonEncode(result),
      ));
    } else {
      // Call came from structured reply text: answer in text, not a tool role.
      messages.add(LlmMessage(
        role: 'user',
        content: 'Tool result (${call.toolName}): ${jsonEncode(result)}',
      ));
    }
  }
}
