import 'dart:async';
import 'package:flutter/material.dart';
import 'package:personal_assistant/core/services/llm_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_assistant/core/services/email_provider_preset.dart';
import 'package:personal_assistant/core/services/llm_key_verifier.dart';
import 'package:personal_assistant/core/services/pip_profile_service.dart';
import 'package:personal_assistant/core/theme/pip_theme.dart';
import 'package:personal_assistant/screens/splash_screen.dart';
import 'package:personal_assistant/widgets/pip_companion.dart';
import 'package:personal_assistant/widgets/pip_emote_painter.dart';
import 'package:personal_assistant/widgets/pip_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(theme: PipTheme.dark, home: Scaffold(body: child));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Email presets and TLS', () {
    test('ports pick the TLS mode', () {
      expect(usesImplicitTls(993), isTrue);
      expect(usesImplicitTls(465), isTrue);
      expect(usesImplicitTls(587), isFalse);
      expect(usesImplicitTls(143), isFalse);
    });

    test('Outlook and iCloud send via STARTTLS on 587 but read over TLS on 993', () {
      for (final address in ['me@outlook.com', 'me@hotmail.com', 'me@icloud.com', 'me@me.com']) {
        final p = EmailProviderPreset.findForEmail(address)!;
        expect(usesImplicitTls(p.imapPort), isTrue, reason: address);
        expect(p.smtpPort, 587, reason: address);
      }
    });

    test('every alias domain resolves', () {
      expect(EmailProviderPreset.findForEmail('a@googlemail.com')!.id, 'gmail');
      expect(EmailProviderPreset.findForEmail('a@live.com')!.id, 'outlook');
      expect(EmailProviderPreset.findForEmail('a@ymail.com')!.id, 'yahoo');
      expect(EmailProviderPreset.findForEmail('a@example.org'), isNull);
    });
  });

  group('Key verifier', () {
    test('Gemini listing keeps chat models, best first', () {
      const body = '{"models":['
          '{"name":"models/gemini-2.5-pro","supportedGenerationMethods":["generateContent"]},'
          '{"name":"models/text-embedding-004","supportedGenerationMethods":["embedContent"]},'
          '{"name":"models/gemini-flash-latest","supportedGenerationMethods":["generateContent"]},'
          '{"name":"models/gemini-2.5-flash-image","supportedGenerationMethods":["generateContent"]}]}';
      final models = LlmKeyVerifier.preferredGeminiModels(LlmKeyVerifier.geminiChatModels(body));
      expect(models, ['gemini-2.5-pro', 'gemini-flash-latest']);
    });

    test('newest Gemini version ranks first, retired older ones last', () {
      final models = LlmKeyVerifier.preferredGeminiModels(
          ['gemini-2.5-flash', 'gemini-3.8-flash', 'gemini-3.8-flash-lite', 'gemini-3.8-pro', 'gemini-flash-latest']);
      expect(models, ['gemini-3.8-flash', 'gemini-3.8-flash-lite', 'gemini-3.8-pro', 'gemini-2.5-flash', 'gemini-flash-latest']);
    });

    test('OpenAI listing drops non-chat models', () {
      const body = '{"data":[{"id":"gpt-4o-mini"},{"id":"text-embedding-3-small"},{"id":"whisper-1"},{"id":"o3-mini"}]}';
      expect(LlmKeyVerifier.listedChatModels('openai', body), ['gpt-4o-mini', 'o3-mini']);
    });

    test('status codes become plain reasons', () {
      expect(LlmKeyVerifier.describeStatus(400, '{"error":{"message":"API key not valid"}}'), contains("isn't valid"));
      expect(LlmKeyVerifier.describeStatus(401, ''), contains('rejected'));
      expect(LlmKeyVerifier.describeStatus(429, ''), contains('quota'));
    });

    test('verify reports success with models, and a timeout clearly', () async {
      final ok = LlmKeyVerifier(
        client: MockClient((_) async => http.Response('{"models":[{"name":"models/gemini-flash-latest",'
            '"supportedGenerationMethods":["generateContent"]}]}', 200)),
      );
      final r = await ok.verify('gemini', 'k');
      expect(r.ok, isTrue);
      expect(r.models, ['gemini-flash-latest']);

      final bad = LlmKeyVerifier(client: MockClient((_) async => http.Response('nope', 403)));
      expect((await bad.verify('openai', 'k')).message, contains('rejected'));
    });
  });

  test('provider errors become plain Pip lines, never raw JSON', () {
    final quota = describeLlmError(Exception('Gemini failed: HTTP 429: {"error":{"code":429,"message":"You exceeded your current quota"}}'));
    expect(quota, contains('usage limit'));
    expect(quota, isNot(contains('{')));
    expect(describeLlmError(Exception('HTTP 429 quota ... limit: 0')), contains('free plan'));
    expect(describeLlmError(Exception('HTTP 401')), contains('rejected'));
    expect(describeLlmError(TimeoutException('x')), contains('too long'));
    expect(describeLlmError(Exception('weird')), contains('Try asking again'));
  });

  group('Profile', () {
    test('greeting follows the hour and uses the name', () {
      expect(PipProfileService.greeting('Sam', now: DateTime(2026, 1, 1, 8)), 'Morning, Sam!');
      expect(PipProfileService.greeting(null, now: DateTime(2026, 1, 1, 19)), 'Evening!');
      expect(PipProfileService.greeting('Sam', now: DateTime(2026, 1, 1, 2)), 'Still up, Sam!');
    });

    test('name, humour and onboarding flag persist', () async {
      await PipProfileService.setUserName('  Sam  ');
      await PipProfileService.setHumor(1.7);
      await PipProfileService.setCompletedOnboarding(true);
      expect(await PipProfileService.userName(), 'Sam');
      expect(await PipProfileService.humor(), 1.0);
      expect(await PipProfileService.hasCompletedOnboarding(), isTrue);
      await PipProfileService.setUserName(' ');
      expect(await PipProfileService.userName(), isNull);
    });
  });

  test('every mood maps to an emote without throwing', () {
    for (final mood in PipMood.values) {
      emoteFor(mood);
    }
    expect(emoteFor(PipMood.thinking), PipEmote.question);
    expect(emoteFor(PipMood.sleeping), PipEmote.sleep);
    expect(emoteFor(PipMood.idle), PipEmote.none);
  });

  testWidgets('splash finishes and calls onDone', (tester) async {
    var done = false;
    await tester.pumpWidget(_app(PipSplashScreen(onDone: () => done = true)));
    expect(find.text('PIP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(done, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pip paints every mood, with emotes, without errors', (tester) async {
    for (final mood in PipMood.values) {
      await tester.pumpWidget(_app(PipDeskCompanion(mood: mood, width: 200, height: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: mood.name);
    }
    await tester.pumpWidget(const SizedBox());
    // Blink and talk use short one-shot timers that check `mounted`; let them drain.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('guide shows Pip and the message', (tester) async {
    await tester.pumpWidget(_app(const PipGuide(message: 'Pick a brain for me.')));
    expect(find.text('Pick a brain for me.'), findsOneWidget);
    expect(find.byType(PipDeskCompanion), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
