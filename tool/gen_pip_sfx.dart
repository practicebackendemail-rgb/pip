// Synthesizes Pip's extra robot sounds as 16-bit mono WAVs.
// Usage: dart run tool/gen_pip_sfx.dart assets/audio
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sr = 22050;

/// A note gliding exponentially from [f0] to [f1] Hz, with optional vibrato
/// and a touch of square wave for the robot buzz.
List<double> tone(double f0, double f1, double dur,
    {double vib = 0, double vibHz = 0, double square = .25, double vol = .8}) {
  final n = (dur * sr).round();
  final out = <double>[];
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sr, p = i / n;
    final f = f0 * pow(f1 / f0, p) + vib * sin(2 * pi * vibHz * t);
    phase += 2 * pi * f / sr;
    final s = (1 - square) * sin(phase) + square * .5 * (sin(phase) >= 0 ? 1 : -1);
    final attack = min(1.0, i / (.006 * sr));
    final release = p > .7 ? (1 - p) / .3 : 1.0;
    out.add(s * attack * release * vol);
  }
  return out;
}

List<double> rest(double dur) => List.filled((dur * sr).round(), 0.0);

List<double> seq(List<List<double>> parts) => [for (final p in parts) ...p];

void write(String path, List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) => s.codeUnits.asMap().forEach((i, c) => data.setUint8(o + i, c));
  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sr, Endian.little);
  data.setUint32(28, sr * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('$path  ${(samples.length / sr * 1000).round()} ms');
}

void main(List<String> args) {
  final dir = args.isEmpty ? '.' : args.first;

  // Droid chuckle (R2-style): a burst of quick, bright whistles leaping
  // around 1.5–3.5 kHz with a fast trill, then a giggly run stepping down.
  write('$dir/pip_laugh.wav', seq([
    for (final (a, b) in [(2600.0, 3400.0), (1900.0, 1500.0), (3100.0, 2400.0), (2200.0, 2900.0)]) ...[
      tone(a, b, .055, vib: 180, vibHz: 38, square: 0, vol: .7),
      rest(.018),
    ],
    rest(.04),
    for (final f in [2900.0, 2650.0, 2400.0, 2150.0, 1900.0]) ...[
      tone(f, f * .9, .045, vib: 220, vibHz: 45, square: 0, vol: .72),
      rest(.03),
    ],
  ]));

  // Droid sad (R2-style): a long pure whistle sinking slowly with a soft
  // wobble, then a low droopy "bwoo" warble.
  write('$dir/pip_sad.wav', seq([
    tone(1850, 620, .9, vib: 35, vibHz: 5.5, square: 0, vol: .7),
    rest(.07),
    tone(520, 300, .45, vib: 40, vibHz: 9, square: .08, vol: .55),
  ]));

  // Excited: a quick rising trill that pops at the top.
  write('$dir/pip_excited.wav', seq([
    for (final f in [700.0, 880.0, 1050.0, 1250.0, 1480.0, 1760.0, 2100.0]) ...[
      tone(f, f * 1.08, .04, vol: .7),
      rest(.012),
    ],
    tone(2300, 3000, .13, vib: 60, vibHz: 28, vol: .75),
  ]));

  // Unsure: "hm?" — a flat low note, then a rising question.
  write('$dir/pip_unsure.wav', seq([
    tone(430, 410, .17, square: .3, vol: .65),
    rest(.05),
    tone(390, 760, .26, vib: 15, vibHz: 7, square: .3, vol: .7),
  ]));

  // Listening: "boop-beep", the mic is open.
  write('$dir/pip_listen.wav', seq([
    tone(620, 900, .075, vol: .6),
    rest(.03),
    tone(1250, 1300, .08, vol: .6),
  ]));
}
