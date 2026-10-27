import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/gemini_service.dart';
import 'package:personal_assistant/core/services/llm_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Secrets Migration Tests', () {
    test('LlmRegistryService migrates legacy SharedPreferences keys to SecureStorage and deletes prefs keys', () async {
      SharedPreferences.setMockInitialValues({
        'gemini_api_key': 'legacy-gemini-secret-123',
        'openai_api_key': 'legacy-openai-secret-456',
        'anthropic_api_key': 'legacy-anthropic-secret-789',
        'groq_api_key': 'legacy-groq-secret-000',
      });

      final registry = LlmRegistryService();
      await registry.initialized;

      // Assert in-memory values loaded
      expect(registry.geminiKey, equals('legacy-gemini-secret-123'));
      expect(registry.openAiKey, equals('legacy-openai-secret-456'));
      expect(registry.anthropicKey, equals('legacy-anthropic-secret-789'));
      expect(registry.groqKey, equals('legacy-groq-secret-000'));

      // Assert SecureStorage values written
      const secure = FlutterSecureStorage();
      expect(await secure.read(key: 'key_gemini'), equals('legacy-gemini-secret-123'));
      expect(await secure.read(key: 'key_openai'), equals('legacy-openai-secret-456'));
      expect(await secure.read(key: 'key_anthropic'), equals('legacy-anthropic-secret-789'));
      expect(await secure.read(key: 'key_groq'), equals('legacy-groq-secret-000'));

      // Assert SharedPreferences keys are completely removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gemini_api_key'), isFalse);
      expect(prefs.containsKey('openai_api_key'), isFalse);
      expect(prefs.containsKey('anthropic_api_key'), isFalse);
      expect(prefs.containsKey('groq_api_key'), isFalse);
    });

    test('Fresh install with no legacy keys initializes cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final registry = LlmRegistryService();
      await registry.initialized;

      expect(registry.geminiKey, isEmpty);
      expect(registry.openAiKey, isEmpty);
      expect(registry.anthropicKey, isEmpty);
      expect(registry.groqKey, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gemini_api_key'), isFalse);
    });

    test('GeminiAssistantService migrates legacy key to SecureStorage and removes it from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'gemini_api_key': 'legacy-gemini-standalone-key',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final geminiService = GeminiAssistantService();
      await geminiService.initialized;

      expect(geminiService.apiKey, equals('legacy-gemini-standalone-key'));

      const secure = FlutterSecureStorage();
      expect(await secure.read(key: 'key_gemini'), equals('legacy-gemini-standalone-key'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gemini_api_key'), isFalse);
    });
  });
}
