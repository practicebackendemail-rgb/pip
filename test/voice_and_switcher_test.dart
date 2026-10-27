import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_voice_output.dart';
import 'package:personal_assistant/widgets/pip_text_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Pip's voice", () {
    test('is on by default', () async {
      expect(await PipVoiceOutput(null).enabled, isTrue);
    });

    test('remembers being turned off', () async {
      await PipVoiceOutput(null).setEnabled(false);
      expect(await PipVoiceOutput(null).enabled, isFalse);
    });

    test('saying something with no TTS engine does nothing and never throws', () async {
      await PipVoiceOutput(null).say('Hello');
    });
  });

  testWidgets('text that flips back before the fade ends does not duplicate keys', (tester) async {
    Widget build(String text) => MaterialApp(
          home: PipTextSwitcher(text: text, builder: (_, t) => Text(t)),
        );
    await tester.pumpWidget(build('Thinking…'));
    await tester.pumpWidget(build('Pip replied'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(build('Thinking…')); // old "Thinking…" is still fading out
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Thinking…'), findsOneWidget);
  });
}
