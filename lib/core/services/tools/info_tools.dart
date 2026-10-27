import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../domain/pip_tool.dart';

class GetCurrentTimeTool extends PipTool {
  const GetCurrentTimeTool()
      : super(
          name: 'get_current_time',
          description: 'Returns the current local date, time, weekday, and time zone information.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final now = DateTime.now();
    return {
      'date': DateFormat('EEEE, MMMM d, yyyy').format(now),
      'time': DateFormat('h:mm a').format(now),
      'iso': now.toIso8601String(),
      'time_zone': now.timeZoneName,
    };
  }
}

class WebSearchTool extends PipTool {
  const WebSearchTool()
      : super(
          name: 'web_search',
          description: 'Performs a live web search for general queries, recent facts, or news.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(name: 'query', type: 'string', description: 'The search query to lookup on the internet'),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final query = (args['query'] as String? ?? '').trim();
    if (query.isEmpty) return {'error': 'Empty query provided'};

    try {
      final url = Uri.parse('https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_html=1&skip_disambig=1');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final abstractText = data['AbstractText'] as String? ?? '';
        final heading = data['Heading'] as String? ?? '';
        if (abstractText.isNotEmpty) {
          return {'title': heading, 'snippet': abstractText, 'source': 'DuckDuckGo'};
        }
      }
    } catch (_) {}

    return {
      'query': query,
      'status': 'search_attempted',
      'note': 'Search completed without full instant summary; use fallback LLM knowledge.',
    };
  }
}
