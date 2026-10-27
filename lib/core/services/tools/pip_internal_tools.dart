import '../../domain/pip_tool.dart';
import '../../domain/memory_repository.dart';

class LearnFactTool extends PipTool {
  final MemoryRepository memoryRepository;

  const LearnFactTool(this.memoryRepository)
      : super(
          name: 'learn_user_fact',
          description: 'Explicitly stores a user profile fact, preference, routine, or dislike.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(name: 'key', type: 'string', description: 'Fact key or identifier (e.g. coffee_preference, bed_time)'),
            ToolParameterSpec(name: 'value', type: 'string', description: 'Fact content or stated preference'),
            ToolParameterSpec(name: 'confidence', type: 'number', description: 'Confidence between 0.1 and 1.0', isRequired: false),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final key = args['key'] as String? ?? 'general_note';
    final val = args['value'] as String? ?? '';
    final conf = (args['confidence'] as num?)?.toDouble() ?? 0.85;

    await memoryRepository.upsertFact(key, val, confidence: conf);

    return {
      'status': 'learned',
      'key': key,
      'value': val,
      'confidence': conf,
    };
  }
}

class AddRuleTool extends PipTool {
  final MemoryRepository memoryRepository;

  const AddRuleTool(this.memoryRepository)
      : super(
          name: 'add_assistant_rule',
          description: 'Stores a behavioral constraint or rule Pip must follow (e.g., "keep briefings short").',
          confirmationLevel: ToolConfirmationLevel.level1ConfirmAction,
          parameters: const [
            ToolParameterSpec(name: 'instruction', type: 'string', description: 'The behavioral instruction or constraint'),
            ToolParameterSpec(name: 'scope', type: 'string', description: 'Scope such as "briefings", "tone", or "general"', isRequired: false),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final instruction = args['instruction'] as String? ?? '';
    final scope = args['scope'] as String? ?? 'general';

    await memoryRepository.addRule(instruction, scope: scope);

    return {
      'status': 'rule_added',
      'instruction': instruction,
      'scope': scope,
    };
  }
}
