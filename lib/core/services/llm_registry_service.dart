import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/llm_provider.dart';
import 'anthropic_llm_adapter.dart';
import 'gemini_llm_adapter.dart';
import 'groq_llm_adapter.dart';
import 'openai_compatible_llm_adapter.dart';

enum LlmRole { mainChat, fastSpeech, nightlyReflection }

class ModelProfile {
  final String providerType; // 'gemini', 'openai', 'ollama', 'anthropic'
  final String label;
  final String baseUrl;
  final String modelName;

  const ModelProfile({
    required this.providerType,
    required this.label,
    required this.baseUrl,
    required this.modelName,
  });
}

/// Registry managing multi-model adapters, custom endpoints, and role routing (Phase 2.5)
class LlmRegistryService extends ChangeNotifier {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  final Completer<void> _initCompleter = Completer<void>();
  String _activeProviderId = 'gemini';
  String _embeddingProviderId = 'gemini';
  String _geminiKey = '';
  String _openAiKey = '';
  String _anthropicKey = '';
  String _ollamaBaseUrl = 'http://localhost:11434/v1';

  String _groqKey = '';

  /// Chat model per provider, chosen by the user; falls back to these defaults.
  static const Map<String, String> defaultModels = {
    'gemini': 'gemini-flash-latest',
    'openai': 'gpt-4o-mini',
    'anthropic': 'claude-3-5-sonnet-20241022',
    'groq': 'llama-3.3-70b-versatile',
    'ollama': 'qwen2.5-coder:7b',
  };
  final Map<String, String> _chatModels = {};

  String chatModel(String providerId) => _chatModels[providerId] ?? defaultModels[providerId] ?? '';

  Future<void> setChatModel(String providerId, String model) async {
    _chatModels[providerId] = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_model_$providerId', model);
    notifyListeners();
  }

  Future<void> get initialized => _initCompleter.future;

  String get activeProviderId => _activeProviderId;
  String get embeddingProviderId => _embeddingProviderId;
  String get geminiKey => _geminiKey;
  String get openAiKey => _openAiKey;
  String get anthropicKey => _anthropicKey;
  String get groqKey => _groqKey;
  String get ollamaBaseUrl => _ollamaBaseUrl;

  LlmRegistryService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeProviderId = prefs.getString('llm_active_provider') ?? 'gemini';
      _embeddingProviderId = prefs.getString('llm_embedding_provider') ?? 'gemini';
      _ollamaBaseUrl = prefs.getString('llm_ollama_base') ?? 'http://localhost:11434/v1';
      for (final id in defaultModels.keys) {
        final saved = prefs.getString('llm_model_$id');
        if (saved != null && saved.isNotEmpty) _chatModels[id] = saved;
      }

      // One-time migration: migrate legacy plain-text keys from SharedPreferences to FlutterSecureStorage
      await _migrateLegacyKeys(prefs);

      // Read exclusively from secure storage
      _geminiKey = (await _secure.read(key: 'key_gemini')) ?? '';
      _openAiKey = (await _secure.read(key: 'key_openai')) ?? '';
      _anthropicKey = (await _secure.read(key: 'key_anthropic')) ?? '';
      _groqKey = (await _secure.read(key: 'key_groq')) ?? '';
      notifyListeners();
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    const keyMap = {
      'gemini_api_key': 'key_gemini',
      'openai_api_key': 'key_openai',
      'anthropic_api_key': 'key_anthropic',
      'groq_api_key': 'key_groq',
    };

    for (final entry in keyMap.entries) {
      final legacyVal = prefs.getString(entry.key);
      if (legacyVal != null && legacyVal.isNotEmpty) {
        final existingSecure = await _secure.read(key: entry.value);
        if (existingSecure == null || existingSecure.isEmpty) {
          await _secure.write(key: entry.value, value: legacyVal);
          // Verify write succeeded before deleting legacy preference
          final verified = await _secure.read(key: entry.value);
          if (verified == legacyVal) {
            await prefs.remove(entry.key);
          }
        } else {
          // Already present in secure storage, safe to remove unencrypted legacy key
          await prefs.remove(entry.key);
        }
      }
    }
  }

  Future<void> setActiveProvider(String providerId) async {
    _activeProviderId = providerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_active_provider', providerId);
    notifyListeners();
  }

  Future<void> setEmbeddingProvider(String providerId) async {
    _embeddingProviderId = providerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_embedding_provider', providerId);
    notifyListeners();
  }

  Future<void> setKey(String providerId, String key) async {
    if (providerId == 'gemini') {
      _geminiKey = key;
      await _secure.write(key: 'key_gemini', value: key);
    } else if (providerId == 'openai') {
      _openAiKey = key;
      await _secure.write(key: 'key_openai', value: key);
    } else if (providerId == 'anthropic') {
      _anthropicKey = key;
      await _secure.write(key: 'key_anthropic', value: key);
    } else if (providerId == 'groq') {
      _groqKey = key;
      await _secure.write(key: 'key_groq', value: key);
    }
    notifyListeners();
  }

  Future<void> setOllamaBaseUrl(String url) async {
    _ollamaBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_ollama_base', url);
    notifyListeners();
  }

  LlmProvider getActiveProvider() {
    return _buildProvider(_activeProviderId);
  }

  LlmProvider getEmbeddingProvider() {
    // If selected embedding provider supports embeddings, use it; otherwise fallback to gemini
    final provider = _buildProvider(_embeddingProviderId);
    if (provider.capabilities.supportsEmbeddings) {
      return provider;
    }
    return _buildProvider('gemini');
  }

  LlmProvider _buildProvider(String id) {
    switch (id) {
      case 'openai':
        return OpenAiCompatibleLlmAdapter(
          providerId: 'openai',
          label: 'OpenAI (GPT-4o)',
          baseUrl: 'https://api.openai.com/v1',
          getApiKey: () => _openAiKey,
          modelName: chatModel('openai'),
        );
      case 'ollama':
        return OpenAiCompatibleLlmAdapter(
          providerId: 'ollama',
          label: 'Local Ollama',
          baseUrl: _ollamaBaseUrl,
          getApiKey: () => '',
          modelName: chatModel('ollama'),
        );
      case 'groq':
        return GroqLlmAdapter(
          apiKey: _groqKey,
          modelName: chatModel('groq'),
        );
      case 'anthropic':
        return AnthropicLlmAdapter(
          getApiKey: () => _anthropicKey,
          modelName: chatModel('anthropic'),
        );
      case 'gemini':
      default:
        return GeminiLlmAdapter(
          getApiKey: () => _geminiKey,
          activeModel: chatModel('gemini'),
        );
    }
  }
}
