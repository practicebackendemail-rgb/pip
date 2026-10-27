import 'dart:convert';
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
    for (final call in calls) {
      final tool = toolRegistry.getTool(call.toolName);
      if (tool == null) continue;

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
      eventLog.log('tool_invoked', {'tool': call.toolName, 'args': call.arguments});
      try {
        final result = await tool.execute(call.arguments);
        eventLog.log('tool_success', {'tool': call.toolName, 'result': result});
        messages.add(LlmMessage(role: 'tool', content: jsonEncode(result)));
      } catch (e) {
        eventLog.log('tool_failure', {'tool': call.toolName, 'error': e.toString()});
        messages.add(LlmMessage(role: 'tool', content: jsonEncode({'error': e.toString()})));
      }
    }
    return const PipToolExecutionResult(requiresConfirmation: false);
  }
}
