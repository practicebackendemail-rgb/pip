import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/services/llm_error_messages.dart';
import '../domain/speech_transcriber.dart';

/// Sends a recorded clip to Gemini (the user's own key and chosen model) and
/// asks for an exact transcript. Gemini accepts audio inline up to ~20 MB,
/// far more than a spoken command.
class GeminiAudioTranscriber implements SpeechTranscriber {
  final String Function() apiKey;
  final String Function() model;

  /// Who is speaking and where: the user's name and the phone's locale
  /// (e.g. "en_IN"), so names and regional accents transcribe correctly.
  final Future<String> Function()? speakerName;
  final String Function()? locale;
  final http.Client _client;

  static const Duration timeout = Duration(seconds: 20);

  GeminiAudioTranscriber({
    required this.apiKey,
    required this.model,
    this.speakerName,
    this.locale,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// The words of the instruction matter: no reply, no commentary, just
  /// text. The context tells Gemini what kind of speech to expect.
  static String promptFor({String name = '', String locale = ''}) {
    final who = name.isEmpty ? 'The speaker' : 'The speaker, $name,';
    final where = locale.isEmpty ? '' : ' Their language setting is $locale, so expect that accent.';
    return 'This is a short voice command to a desk assistant named "Pip" '
        '(tasks, reminders, alarms, email, calendar, questions). '
        '$who is talking to it.$where '
        'Transcribe the audio exactly as spoken, in the language spoken. '
        'Spell the assistant\'s name as "Pip". Write times like "6:30 am" and numbers as digits. '
        'Output only the transcript text, with normal punctuation. '
        'If there is no speech, output nothing.';
  }

  @override
  Future<TranscriptResult> transcribe(Uint8List wav) async {
    final key = apiKey();
    if (key.isEmpty) return const TranscriptResult.failure('Add a Gemini key in Settings to use accurate voice.');
    final name = await speakerName?.call() ?? '';
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${model()}:generateContent');
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptFor(name: name, locale: locale?.call() ?? '')},
            {
              'inline_data': {'mime_type': 'audio/wav', 'data': base64Encode(wav)},
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0},
    });
    try {
      final res = await _client
          .post(uri, headers: {'Content-Type': 'application/json', 'x-goog-api-key': key}, body: body)
          .timeout(timeout);
      if (res.statusCode != 200) {
        return TranscriptResult.failure(describeLlmError(Exception('HTTP ${res.statusCode}: ${res.body}')));
      }
      return TranscriptResult.success(textFrom(res.body));
    } catch (e) {
      return TranscriptResult.failure(describeLlmError(e));
    }
  }

  /// Joins the text parts of the first candidate.
  static String textFrom(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final parts = ((data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?) ?? const [];
    return parts.map((p) => p['text'] ?? '').join().trim();
  }
}
