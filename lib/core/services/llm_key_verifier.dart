import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Outcome of checking a provider key, with a message fit to show the user.
class KeyCheckResult {
  final bool ok;
  final String message;

  /// Model ids the key can use for chat, when the provider lists them.
  final List<String> models;

  const KeyCheckResult(this.ok, this.message, {this.models = const []});
}

/// Checks a key with each provider's "list models" endpoint: one quick
/// request that needs no model choice, so a good key is confirmed in about a
/// second and a bad one gets a specific reason instead of a long chat timeout.
class LlmKeyVerifier {
  static const Duration timeout = Duration(seconds: 12);
  final http.Client _client;

  LlmKeyVerifier({http.Client? client}) : _client = client ?? http.Client();

  Future<KeyCheckResult> verify(String providerId, String key, {String? baseUrl}) async {
    final (uri, headers) = switch (providerId) {
      'gemini' => (
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200'),
          {'x-goog-api-key': key},
        ),
      'openai' => (Uri.parse('https://api.openai.com/v1/models'), {'Authorization': 'Bearer $key'}),
      'groq' => (Uri.parse('https://api.groq.com/openai/v1/models'), {'Authorization': 'Bearer $key'}),
      'anthropic' => (
          Uri.parse('https://api.anthropic.com/v1/models'),
          {'x-api-key': key, 'anthropic-version': '2023-06-01'},
        ),
      _ => (Uri.parse('${(baseUrl ?? '').replaceAll(RegExp(r'/+$'), '')}/models'), <String, String>{}),
    };

    try {
      final res = await _client.get(uri, headers: headers).timeout(timeout);
      if (res.statusCode == 200) {
        final models = providerId == 'gemini'
            ? preferredGeminiModels(geminiChatModels(res.body))
            : listedChatModels(providerId, res.body);
        if (models.isEmpty) {
          return KeyCheckResult(
            false,
            providerId == 'ollama'
                ? 'Ollama is running but has no models. Run "ollama pull llama3.2" first.'
                : "The key works, but it can't use any chat models.",
          );
        }
        return KeyCheckResult(true, 'Connected.', models: models);
      }
      return KeyCheckResult(false, describeStatus(res.statusCode, res.body));
    } on TimeoutException {
      return const KeyCheckResult(false, 'No answer in 12 seconds. Check your internet connection.');
    } on SocketException {
      return KeyCheckResult(
        false,
        providerId == 'ollama' ? "I couldn't reach that address. Is Ollama running?" : "I couldn't reach the server. Are you online?",
      );
    } catch (e) {
      return KeyCheckResult(false, 'Something went wrong: ${e.runtimeType}.');
    }
  }

  /// Maps an HTTP failure to a plain sentence.
  static String describeStatus(int status, String body) {
    final lower = body.toLowerCase();
    if (status == 400 && lower.contains('api key not valid')) return "That key isn't valid. Copy it again.";
    if (status == 400 && lower.contains('location')) return "This provider isn't available in your region.";
    if (status == 401 || status == 403) return 'The key was rejected. Check it is copied in full and enabled.';
    if (status == 429) return 'The key works but has hit its rate limit or quota. Try again shortly.';
    if (status >= 500) return 'The service is having trouble right now (error $status). Try again soon.';
    return 'The service refused the key (error $status).';
  }

  /// Model ids from a Gemini models listing that support generateContent.
  static List<String> geminiChatModels(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final models = (data['models'] as List?) ?? const [];
    return [
      for (final m in models)
        if (((m['supportedGenerationMethods'] as List?) ?? const []).contains('generateContent'))
          (m['name'] as String).replaceFirst('models/', ''),
    ];
  }

  /// Chat model ids from an OpenAI-style (`data[].id`) listing, which OpenAI,
  /// Groq, Ollama and Anthropic all return. Non-chat models are dropped.
  static List<String> listedChatModels(String providerId, String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final ids = [for (final m in (data['data'] as List?) ?? const []) m['id'] as String];
    final notChat = RegExp(
        r'embed|whisper|tts|dall-e|davinci|babbage|moderation|audio|realtime|transcribe|image|search|guard|rerank');
    final chat = ids.where((id) => !notChat.hasMatch(id)).toList()..sort();
    if (providerId == 'openai') {
      return chat.where((id) => id.startsWith('gpt-') || RegExp(r'^o\d').hasMatch(id) || id.startsWith('chatgpt')).toList();
    }
    return chat;
  }

  /// Orders [available] Gemini models: stable aliases and flash models first,
  /// skipping embedding, image, audio and experimental variants.
  /// Newest versions come first, so retired older models (which Google may
  /// still list) sink to the bottom. Within a version, flash before lite
  /// before pro.
  static List<String> preferredGeminiModels(List<String> available) {
    bool usable(String m) =>
        m.startsWith('gemini') && !RegExp(r'embedding|image|tts|audio|live|exp|preview|vision').hasMatch(m);
    double version(String m) => double.tryParse(RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(m)?.group(1) ?? '') ?? 0;
    int tier(String m) => m.contains('flash-lite') ? 1 : (m.contains('flash') ? 0 : 2);

    final versioned = available.where((m) => usable(m) && version(m) > 0).toList()
      ..sort((a, b) {
        final byVersion = version(b).compareTo(version(a));
        return byVersion != 0 ? byVersion : tier(a).compareTo(tier(b));
      });
    final aliases = available.where((m) => usable(m) && version(m) == 0).toList()
      ..sort((a, b) => tier(a).compareTo(tier(b)));
    return [...versioned, ...aliases];
  }
}
