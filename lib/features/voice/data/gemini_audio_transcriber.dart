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
  final http.Client _client;

  static const Duration timeout = Duration(seconds: 20);

  /// The words of the instruction matter: no reply, no commentary, just text.
  static const String prompt =
      'Transcribe this audio exactly as spoken, in the language spoken. '
      'Output only the transcript text, with normal punctuation. '
      'If there is no speech, output nothing.';

  GeminiAudioTranscriber({required this.apiKey, required this.model, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<TranscriptResult> transcribe(Uint8List wav) async {
    final key = apiKey();
    if (key.isEmpty) return const TranscriptResult.failure('Add a Gemini key in Settings to use accurate voice.');
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${model()}:generateContent');
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
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
