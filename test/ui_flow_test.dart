import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/email_provider_preset.dart';
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
