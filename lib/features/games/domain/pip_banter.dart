import 'dart:math';
import '../../../widgets/pip_params.dart';

/// Things that happen in a game that Pip reacts to.
enum GameEvent {
  start,
  yourMove,
  pipThinking,
  pipMove,

  /// You now have a winning move open (Pip didn't see it coming).
  youThreaten,

  /// Pip blocked your winning move.
  pipBlocks,

  /// Pip has a winning move open.
  pipThreatens,
  youWin,
  pipWins,
  draw,
  roundYouWin,
  roundPipWins,
  roundTie,
  rematch,
}

/// One reaction: Pip's face, a line and a sound.
class Reaction {
  final PipMood mood;
  final String line;
  final PipSoundCue sound;
  const Reaction(this.mood, this.line, this.sound);
}

/// Matches the sounds in PipSfxService; kept here so the domain stays pure.
enum PipSoundCue { none, chirp, blip, thinking, happy, excited, laugh, sad, unsure }

/// Pip's game personality: short lines, never the same one twice in a row.
class PipBanter {
  final Random _rnd;
  final Map<GameEvent, int> _last = {};
  PipBanter({Random? random}) : _rnd = random ?? Random();

  static const Map<GameEvent, (PipMood, PipSoundCue, List<String>)> _table = {
    GameEvent.start: (PipMood.excited, PipSoundCue.excited, [
      "Game on! I've been practising.",
      'Ready when you are. Go easy on me. Or don\'t.',
      "Let's see what you've got!",
    ]),
    GameEvent.yourMove: (PipMood.idle, PipSoundCue.blip, [
      'Ooh, interesting.',
      'Hmm, okay…',
      'I see what you did there.',
      'Bold.',
      'Noted.',
    ]),
    GameEvent.pipThinking: (PipMood.thinking, PipSoundCue.thinking, [
      'Let me think…',
      'Calculating… beep boop.',
      'Hmm, hmm, hmm.',
    ]),
    GameEvent.pipMove: (PipMood.happy, PipSoundCue.chirp, [
      'Your turn!',
      'Take that.',
      'There. Your move.',
      'Try and beat that.',
    ]),
    GameEvent.youThreaten: (PipMood.unsure, PipSoundCue.unsure, [
      'Wait… uh oh.',
      "Hold on, I didn't see that coming.",
      'Hmm. That looks dangerous.',
    ]),
    GameEvent.pipBlocks: (PipMood.laughing, PipSoundCue.laugh, [
      'Nope! Not today.',
      'Blocked! Nice try.',
      'Ha, I saw that one.',
    ]),
    GameEvent.pipThreatens: (PipMood.excited, PipSoundCue.excited, [
      "Careful… I'm one away.",
      'Feeling lucky? Because I am.',
      'Better watch that spot.',
    ]),
    GameEvent.youWin: (PipMood.sad, PipSoundCue.sad, [
      'Aww. You got me. Well played!',
      'No fair… okay, it was fair. Rematch?',
      "I demand a rematch. Respectfully.",
    ]),
    GameEvent.pipWins: (PipMood.laughing, PipSoundCue.laugh, [
      'I win! Victory dance time.',
      'Pip wins! Want revenge?',
      'Yesss! Good game though.',
    ]),
    GameEvent.draw: (PipMood.unsure, PipSoundCue.unsure, [
      'A draw! Evenly matched.',
      "Nobody wins? I'll call that a moral victory.",
    ]),
    GameEvent.roundYouWin: (PipMood.sad, PipSoundCue.sad, [
      "Argh! You read me.",
      'That one\'s yours.',
      'Lucky. Totally lucky.',
    ]),
    GameEvent.roundPipWins: (PipMood.laughing, PipSoundCue.laugh, [
      'Ha! Point to Pip.',
      'Called it!',
      'Too predictable!',
    ]),
    GameEvent.roundTie: (PipMood.unsure, PipSoundCue.blip, [
      'Same! Great minds.',
      'Jinx!',
      'Again!',
    ]),
    GameEvent.rematch: (PipMood.excited, PipSoundCue.excited, [
      'Round two! This time it\'s personal.',
      'Rematch! Here we go.',
    ]),
  };

  Reaction react(GameEvent e) {
    final (mood, sound, lines) = _table[e]!;
    var i = _rnd.nextInt(lines.length);
    if (lines.length > 1 && i == _last[e]) i = (i + 1) % lines.length;
    _last[e] = i;
    return Reaction(mood, lines[i], sound);
  }
}
