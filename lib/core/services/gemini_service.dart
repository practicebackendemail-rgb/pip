import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task_model.dart';

class GeminiAssistantService extends ChangeNotifier {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  String _apiKey = '';
  String _activeModel = 'gemini-1.5-flash';
  AssistantPersona _currentPersona = AssistantPersona.presets.first;
  final List<Map<String, dynamic>> _messages = [];
  List<String> _availableModels = [];

  String get apiKey => _apiKey;
  String get activeModel => _activeModel;
  AssistantPersona get currentPersona => _currentPersona;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  List<String> get availableModels => List.unmodifiable(_availableModels);
  bool get isConfigured => _apiKey.isNotEmpty;

  GeminiAssistantService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // One-time migration: check if legacy SharedPreferences has gemini_api_key
    final legacyKey = prefs.getString('gemini_api_key');
    if (legacyKey != null && legacyKey.isNotEmpty) {
      final existingSecure = await _secure.read(key: 'key_gemini');
      if (existingSecure == null || existingSecure.isEmpty) {
        await _secure.write(key: 'key_gemini', value: legacyKey);
      }
      await prefs.remove('gemini_api_key');
    }

    // Read exclusively from secure storage
    _apiKey = (await _secure.read(key: 'key_gemini')) ?? '';
    _activeModel = prefs.getString('gemini_model_name') ?? 'gemini-flash-latest';
    final personaId = prefs.getString('current_persona_id') ?? 'pip';
    _currentPersona = AssistantPersona.presets.firstWhere(
      (p) => p.id == personaId,
      orElse: () => AssistantPersona.presets.first,
    );
    notifyListeners();
    // Fetch models in background — do NOT await this, it should never block startup
    if (_apiKey.isNotEmpty) {
      fetchSupportedModels(); // fire-and-forget
    }
  }

  Future<void> updateApiKey(String key) async {
    _apiKey = key.trim();
    await _secure.write(key: 'key_gemini', value: _apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gemini_api_key');
    if (_apiKey.isNotEmpty) {
      await fetchSupportedModels();
    }
    notifyListeners();
  }

  Future<void> updatePersona(AssistantPersona persona) async {
    _currentPersona = persona;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_persona_id', persona.id);
    notifyListeners();
  }

  /// Queries Google's ModelService.ListModels endpoint directly with the user's API key
  Future<List<String>> fetchSupportedModels() async {
    if (_apiKey.isEmpty) return [];
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
      final res = await http.get(
        url,
        headers: {
          'x-goog-api-key': _apiKey,
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> modelsList = data['models'] ?? [];
        _availableModels = modelsList
            .where((m) {
              final supportedMethods = List<String>.from(m['supportedGenerationMethods'] ?? []);
              final name = (m['name'] as String).toLowerCase();
              // Exclude audio-only TTS models, embedders, and vision-only models
              final isTextModel = !name.contains('tts') && !name.contains('embedding') && !name.contains('imagen');
              return supportedMethods.contains('generateContent') && isTextModel;
            })
            .map((m) => (m['name'] as String).replaceFirst('models/', ''))
            .toList();

        // Lock in the fastest text chat model immediately based on the key's available models
        if (_availableModels.contains('gemini-flash-latest')) {
          _activeModel = 'gemini-flash-latest';
        } else if (_availableModels.contains('gemini-3.8-flash')) {
          _activeModel = 'gemini-3.8-flash';
        } else if (_availableModels.contains('gemini-3.7-flash')) {
          _activeModel = 'gemini-3.7-flash';
        } else if (_availableModels.contains('gemini-3.6-flash')) {
          _activeModel = 'gemini-3.6-flash';
        } else if (_availableModels.contains('gemini-2.5-flash-lite')) {
          _activeModel = 'gemini-2.5-flash-lite';
        } else if (_availableModels.contains('gemini-pro-latest')) {
          _activeModel = 'gemini-pro-latest';
        } else if (_availableModels.isNotEmpty) {
          _activeModel = _availableModels.first;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gemini_model_name', _activeModel);
        debugPrint("Available Gemini models for key: $_availableModels (Selected: $_activeModel)");
        notifyListeners();
        return _availableModels;
      } else {
        debugPrint("ListModels failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Error fetching supported models: $e");
    }
    return [];
  }

  Future<String> _callGeminiApi(String prompt) async {
    // Build candidate list immediately — don't block waiting for model list
    final candidateModels = {
      if (_activeModel.isNotEmpty) _activeModel,
      'gemini-flash-latest',
      'gemini-3.8-flash',
      'gemini-3.7-flash',
      'gemini-3.6-flash',
      'gemini-2.5-flash-lite',
      'gemini-pro-latest',
      ..._availableModels,
    }.where((m) => !m.contains('tts') && !m.contains('embedding') && !m.contains('image')).toList();

    String lastErr = '';
    for (final modelId in candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent',
        );

        final systemPrompt = '''
${_currentPersona.systemPrompt}

CRITICAL INSTRUCTIONS:
- You are ${_currentPersona.name}. Speak directly to the user in the first person.
- NEVER output roleplay emotes or stage directions like *chirps*, *wiggles*, *laughs*, *beeps*, etc.
- NEVER output thoughts, scratchpads, analysis of the user message, or meta-notes.
- Respond immediately and naturally with only what you are saying to the user.
- Keep responses concise (2-4 sentences for simple queries).
- Use clean markdown (bold for emphasis, short bullet points only when listing 3+ items).

TASK ACTION EXECUTION INSTRUCTIONS:
Whenever the user wants to add, finish, mark done, delete, remove, or complete tasks (single or bulk), you MUST output the corresponding machine action tag at the very end of your reply on its own line:
- Add a new task: `[ACTION:ADD_TASK|title|project|priority]` (e.g. `[ACTION:ADD_TASK|Buy milk|Personal|medium]`)
- Complete/finish a single task: `[ACTION:COMPLETE_TASK|keyword]` (e.g. `[ACTION:COMPLETE_TASK|quarterly goals]`)
- Complete/finish ALL tasks: `[ACTION:COMPLETE_ALL_TASKS]`
- Delete/remove a single task: `[ACTION:DELETE_TASK|keyword]` (e.g. `[ACTION:DELETE_TASK|workout]`)
- Delete/clear all completed tasks: `[ACTION:DELETE_COMPLETED_TASKS]`
- Priority must be one of: low, medium, high, urgent. Default project is Work or Personal.
CRITICAL: Even if the user uses informal language like "scratch that off", "done with everything", "all tasks are completed and ready to be marked done", "nuke the gym task", you MUST generate the right [ACTION:...] tag. Never skip the tag! Respond with friendly Pip excitement first, then the tag at the end.
''';

        final body = {
          "system_instruction": {
            "parts": [
              {"text": systemPrompt}
            ]
          },
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 12), onTimeout: () {
          throw Exception('Request timed out after 12s');
        });

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final candidates = resData['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = candidates[0]['content']['parts'][0]['text'] as String?;
            _activeModel = modelId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('gemini_model_name', _activeModel);
            return text ?? "Request processed.";
          }
        } else {
          lastErr = "${response.statusCode}: ${response.body}";
          debugPrint("Calling $modelId failed ($lastErr), trying next...");
        }
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr);
  }

  Future<String> sendMessage(String text, {List<TaskItem>? currentTasks}) async {
    if (_apiKey.isEmpty) {
      return "Please enter your free Gemini API Key in Settings to activate ${_currentPersona.name}.";
    }

    _messages.add({'role': 'user', 'text': text, 'time': DateTime.now()});
    notifyListeners();

    String contextEnrichedPrompt = text;
    if (currentTasks != null && currentTasks.isNotEmpty) {
      final taskSummary = currentTasks
          .map((t) => "- [${t.project}] ${t.title} (${t.priority.name}, completed: ${t.isCompleted})")
          .join('\n');
      contextEnrichedPrompt = "[Background User Tasks: $taskSummary]\n$text";
    }

    try {
      final reply = await _callGeminiApi(contextEnrichedPrompt);
      _messages.add({'role': 'assistant', 'text': reply, 'time': DateTime.now()});
      notifyListeners();
      return reply;
    } catch (e) {
      final errorMsg = "Error connecting with Gemini: $e";
      _messages.add({'role': 'assistant', 'text': errorMsg, 'time': DateTime.now()});
      notifyListeners();
      return errorMsg;
    }
  }

  Future<String> generateDailyBriefing({
    required List<TaskItem> tasks,
    List<String>? recentEmails,
  }) async {
    if (_apiKey.isEmpty) return "Add your Gemini API key in Settings to generate smart daily briefings.";

    final prompt = '''
You are ${_currentPersona.name}, speaking directly to the user in the first person. Deliver their daily morning briefing right now.
DO NOT output thoughts, instructions, or meta-notes. Speak directly to me like an executive assistant.

Here is my current agenda:
Tasks:
${tasks.map((t) => "- [${t.priority.name.toUpperCase()}] ${t.title} (${t.project})").join('\n')}

Email digest:
${recentEmails?.isNotEmpty == true ? recentEmails!.join('\n') : 'Inbox clear, no high-priority flags.'}

Format:
☀️ Morning Priorities
(Briefly highlight the 2-3 most critical items)

⚡ Quick Wins
(1-2 easy action items to build momentum)

📬 Communications
(Summary of emails/follow-ups)
''';

    try {
      return await _callGeminiApi(prompt);
    } catch (e) {
      return "Unable to generate briefing: $e";
    }
  }
}
