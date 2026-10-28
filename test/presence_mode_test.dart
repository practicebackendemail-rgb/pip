import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/pip_sfx_service.dart';
import 'package:personal_assistant/features/presence/presence_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final p = PresenceSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await p.load();
  });

  test('defaults to casual, where everything is allowed', () {
    expect(p.mode, PresenceMode.casual);
    expect(p.allowSounds && p.allowSpeech && p.allowProactive, isTrue);
  });

  test('focus and briefing stop unprompted chatter but keep replies', () async {
    for (final m in [PresenceMode.focus, PresenceMode.briefing]) {
      await p.setMode(m);
      expect(p.allowProactive, isFalse, reason: m.name);
      expect(p.allowSpeech, isTrue, reason: m.name);
      expect(p.allowSounds, isTrue, reason: m.name);
    }
  });

  test('quiet silences sounds and voice', () async {
    await p.setMode(PresenceMode.quiet);
    expect(p.allowSounds, isFalse);
    expect(p.allowSpeech, isFalse);
    expect(PipSfxService.idleSoundAllowed(12), isFalse);
    expect(await PipSfxService.play(PipSound.chirp), isFalse);
  });

  test('the tray toggle flips quiet on and back to casual', () async {
    expect(await p.toggleQuiet(), PresenceMode.quiet);
    expect(await p.toggleQuiet(), PresenceMode.casual);
  });

  test('the mode survives a restart', () async {
    await p.setMode(PresenceMode.focus);
    await p.load();
    expect(p.mode, PresenceMode.focus);
  });

  test('idle sounds also need casual mode', () async {
    await p.setMode(PresenceMode.focus);
    expect(PipSfxService.idleSoundAllowed(12), isFalse);
    await p.setMode(PresenceMode.casual);
    expect(PipSfxService.idleSoundAllowed(12), PipSfxService.enableAudio && PipSfxService.idleSounds);
  });
}
