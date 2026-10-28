import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/widgets/pip_text_switcher.dart';

void main() {
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
