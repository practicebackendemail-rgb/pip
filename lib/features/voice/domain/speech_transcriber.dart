import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Result of turning a recorded utterance into text: either [text] or an
/// [error] fit to show the user. Never throws across the domain boundary.
class TranscriptResult extends Equatable {
  final String? text;
  final String? error;

  const TranscriptResult.success(String this.text) : error = null;
  const TranscriptResult.failure(String this.error) : text = null;

  bool get isSuccess => text != null && text!.trim().isNotEmpty;

  @override
  List<Object?> get props => [text, error];
}

/// Turns a WAV clip into text (cloud or local implementation).
abstract interface class SpeechTranscriber {
  Future<TranscriptResult> transcribe(Uint8List wav);
}

/// How Pip hears you.
enum SpeechEngine {
  /// The phone's own recogniser: instant live words, free, offline-capable.
  onDevice,

  /// Record the clip and let Gemini transcribe it: more accurate, uses quota.
  geminiAudio,
}
