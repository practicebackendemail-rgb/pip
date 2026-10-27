import '../../domain/memory_repository.dart';
import '../../domain/pip_tool.dart';

/// Notes Save Tool (Step 5.4e)
class SaveNoteTool extends PipTool {
  final MemoryRepository memoryRepository;

  const SaveNoteTool({required this.memoryRepository})
      : super(
          name: 'save_note',
          description: 'Save a personal note, insight, or reference text into Pip long-term memory.',
          confirmationLevel: ToolConfirmationLevel.level2ReportAfter,
          parameters: const [
            ToolParameterSpec(
              name: 'content',
              type: 'string',
              description: 'The note text content to persist.',
              isRequired: true,
            ),
            ToolParameterSpec(
              name: 'importance',
              type: 'number',
              description: 'Optional importance scale from 0.0 to 1.0 (default 0.7).',
              isRequired: false,
            ),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final content = (args['content'] as String?)?.trim() ?? '';
    final imp = (args['importance'] as num?)?.toDouble() ?? 0.7;

    if (content.isEmpty) {
      return {'error': 'Note content cannot be empty.'};
    }

    try {
      await memoryRepository.recordMemory(content, importance: imp);
      return {
        'status': 'saved',
        'content_preview': content.length > 40 ? '${content.substring(0, 40)}...' : content,
        'importance': imp,
      };
    } catch (e) {
      return {'error': 'Failed to save note: $e'};
    }
  }
}

/// Notes Search Tool (Step 5.4e)
class SearchNotesTool extends PipTool {
  final MemoryRepository memoryRepository;

  const SearchNotesTool({required this.memoryRepository})
      : super(
          name: 'search_notes',
          description: 'Search previously saved notes and memories.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(
              name: 'query',
              type: 'string',
              description: 'The search keywords or topic to find.',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return {'error': 'Search query cannot be empty.'};
    }

    try {
      final results = await memoryRepository.searchMemories(
        const [],
        limit: 5,
        queryText: query,
      );
      return {
        'count': results.length,
        'notes': results.map((n) => {'text': n.text, 'importance': n.importance}).toList(),
      };
    } catch (e) {
      return {'error': 'Note search failed: $e'};
    }
  }
}
