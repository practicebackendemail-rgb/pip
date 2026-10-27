import '../domain/llm_provider.dart';
import '../domain/pip_tool.dart';

class PipToolRegistry {
  final Map<String, PipTool> _tools = {};

  PipToolRegistry();

  void registerTool(PipTool tool) {
    _tools[tool.name] = tool;
  }

  void unregisterTool(String name) {
    _tools.remove(name);
  }

  PipTool? getTool(String name) => _tools[name];

  List<PipTool> get allTools => _tools.values.toList();

  List<ToolSpec> toToolSpecs() {
    return _tools.values.map((t) {
      final properties = <String, dynamic>{};
      final requiredProps = <String>[];
      for (final p in t.parameters) {
        properties[p.name] = {
          'type': p.type,
          'description': p.description,
        };
        if (p.isRequired) {
          requiredProps.add(p.name);
        }
      }

      return ToolSpec(
        name: t.name,
        description: t.description,
        isReadOnly: t.isReadOnly,
        requiresConfirmation: t.confirmationLevel != ToolConfirmationLevel.level0ReadOnly &&
            t.confirmationLevel != ToolConfirmationLevel.level2ReportAfter,
        parameterSchema: {
          'type': 'object',
          'properties': properties,
          'required': requiredProps,
        },
      );
    }).toList();
  }

  List<Map<String, dynamic>> exportSchemas() {
    return _tools.values.map((t) => t.toSchema()).toList();
  }

  String buildToolsPromptContext() {
    if (_tools.isEmpty) return 'No tools currently available.';
    final buffer = StringBuffer('Available Tools you can invoke:\n');
    for (final tool in _tools.values) {
      buffer.writeln('- ${tool.name}: ${tool.description}');
      buffer.writeln('  Confirmation Level: ${tool.confirmationLevel.name}');
      if (tool.parameters.isNotEmpty) {
        buffer.writeln('  Parameters:');
        for (final p in tool.parameters) {
          buffer.writeln('    * ${p.name} (${p.type}): ${p.description}');
        }
      }
    }
    return buffer.toString();
  }
}
