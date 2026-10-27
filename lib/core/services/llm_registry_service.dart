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
  String _activeProviderId = 'gemini';
  String _embeddingProviderId = 'gemini';
  String _geminiKey = '';
  String _openAiKey = '';
  String _anthropicKey = '';
  String _ollamaBaseUrl = 'http://localhost:11434/v1';

  String _groqKey = '';

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
    final prefs = await SharedPreferences.getInstance();
    _activeProviderId = prefs.getString('llm_active_provider') ?? 'gemini';
    _embeddingProviderId = prefs.getString('llm_embedding_provider') ?? 'gemini';
    _ollamaBaseUrl = prefs.getString('llm_ollama_base') ?? 'http://localhost:11434/v1';

    _geminiKey = (await _secure.read(key: 'key_gemini')) ?? prefs.getString('gemini_api_key') ?? '';
    _openAiKey = (await _secure.read(key: 'key_openai')) ?? prefs.getString('openai_api_key') ?? '';
    _anthropicKey = (await _secure.read(key: 'key_anthropic')) ?? prefs.getString('anthropic_api_key') ?? '';
    _groqKey = (await _secure.read(key: 'key_groq')) ?? prefs.getString('groq_api_key') ?? '';
    notifyListeners();
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
    final prefs = await SharedPreferences.getInstance();
    if (providerId == 'gemini') {
      _geminiKey = key;
      await _secure.write(key: 'key_gemini', value: key);
      await prefs.setString('gemini_api_key', key);
    } else if (providerId == 'openai') {
      _openAiKey = key;
      await _secure.write(key: 'key_openai', value: key);
      await prefs.setString('openai_api_key', key);
    } else if (providerId == 'anthropic') {
      _anthropicKey = key;
      await _secure.write(key: 'key_anthropic', value: key);
      await prefs.setString('anthropic_api_key', key);
    } else if (providerId == 'groq') {
      _groqKey = key;
      await _secure.write(key: 'key_groq', value: key);
      await prefs.setString('groq_api_key', key);
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
          modelName: 'gpt-4o-mini',
        );
      case 'ollama':
        return OpenAiCompatibleLlmAdapter(
          providerId: 'ollama',
          label: 'Local Ollama',
          baseUrl: _ollamaBaseUrl,
          getApiKey: () => '',
          modelName: 'qwen2.5-coder:7b',
        );
      case 'groq':
        return GroqLlmAdapter(
          apiKey: _groqKey,
          modelName: 'llama-3.3-70b-versatile',
        );
      case 'anthropic':
        return AnthropicLlmAdapter(
          getApiKey: () => _anthropicKey,
          modelName: 'claude-3-5-sonnet-20241022',
        );
      case 'gemini':
      default:
        return GeminiLlmAdapter(
          getApiKey: () => _geminiKey,
          activeModel: 'gemini-3.8-flash',
        );
    }
  }
}
