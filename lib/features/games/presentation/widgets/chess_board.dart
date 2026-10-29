import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import '../../domain/chess_ai.dart';
import 'arcade.dart';

/// Solid chess glyphs for both sides (coloured, not outlined), with the
/// text presentation selector so phones don't swap in emoji.
const Map<String, String> _glyph = {
  'k': '♚︎',
  'q': '♛︎',
  'r': '♜︎',
  'b': '♝︎',
  'n': '♞︎',
  'p': '♟︎',
};

/// The neon chess board, white at the bottom.
class ChessBoardView extends StatelessWidget {
  final ch.Chess game;
  final String? selected;
  final Set<String> targets;
  final (String, String)? lastMove;
  final String? checkSquare;
  final ValueChanged<String> onTap;

  const ChessBoardView({
    super.key,
    required this.game,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.checkSquare,
    required this.onTap,
  });

  static const _dark = Color(0xFF1C2C66);
  static const _light = Color(0xFF34488F);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Arcade.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Arcade.violet, width: 2),
          boxShadow: Arcade.boxGlow(Arcade.violet, strength: .8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: [
              for (var rank = 8; rank >= 1; rank--)
                Expanded(
                  child: Row(
                    children: [
                      for (var f = 0; f < 8; f++) Expanded(child: _square('${'abcdefgh'[f]}$rank', f, rank)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _square(String sq, int file, int rank) {
    final piece = game.get(sq);
    final light = (file + rank).isOdd;
    final isLast = lastMove != null && (lastMove!.$1 == sq || lastMove!.$2 == sq);
    final isTarget = targets.contains(sq);
    final isSelected = selected == sq;
    final isCheck = checkSquare == sq;
    var base = light ? _light : _dark;
    if (isLast) base = Color.lerp(base, Arcade.amber, .28)!;
    if (isSelected) base = Color.lerp(base, Arcade.amber, .5)!;
    final name = piece == null ? 'empty' : '${piece.color == ch.Color.WHITE ? 'your' : "Pip's"} ${ChessAi.pieceName(piece.type.name)}';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$sq, $name${isTarget ? ', can move here' : ''}',
      child: GestureDetector(
        onTap: () => onTap(sq),
        child: Container(
          decoration: BoxDecoration(
            color: base,
            gradient: isCheck
                ? const RadialGradient(colors: [Color(0xFFFF4D6D), Color(0x00FF4D6D)], radius: .75)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file == 0) _coord('$rank', Alignment.topLeft, light),
              if (rank == 1) _coord('abcdefgh'[file], Alignment.bottomRight, light),
              if (piece != null)
                _Piece(
                  key: ValueKey('${lastMove?.$2 == sq ? 'moved' : 'still'}-$sq-${piece.type.name}${piece.color.name}'),
                  letter: piece.type.name,
                  white: piece.color == ch.Color.WHITE,
                  animate: lastMove?.$2 == sq,
                ),
              if (isTarget)
                Center(
                  child: FractionallySizedBox(
                    widthFactor: piece == null ? .3 : .9,
                    heightFactor: piece == null ? .3 : .9,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: piece == null ? Arcade.amber.withValues(alpha: .65) : null,
                        border: piece == null ? null : Border.all(color: Arcade.amber, width: 3),
                        boxShadow: Arcade.boxGlow(Arcade.amber, strength: .4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coord(String text, Alignment a, bool light) => Align(
        alignment: a,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: light ? .45 : .3))),
        ),
      );
}

class _Piece extends StatelessWidget {
  final String letter;
  final bool white;
  final bool animate;
  const _Piece({super.key, required this.letter, required this.white, required this.animate});

  @override
  Widget build(BuildContext context) {
    final color = white ? Arcade.amber : Arcade.teal;
    final glyph = LayoutBuilder(
      builder: (context, c) => Center(
        child: Text(
          _glyph[letter]!,
          style: TextStyle(fontSize: c.maxHeight * .78, height: 1, color: color, shadows: [
            const Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 2),
            ...Arcade.glow(color, strength: .5),
          ]),
        ),
      ),
    );
    if (!animate || MediaQuery.disableAnimationsOf(context)) return glyph;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.5, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: glyph,
    );
  }
}

/// Pieces taken so far, smallest first.
class CapturedRow extends StatelessWidget {
  final List<String> pieces;

  /// Colour of the captured pieces (white = yours, taken by Pip).
  final bool white;
  const CapturedRow({super.key, required this.pieces, required this.white});

  @override
  Widget build(BuildContext context) {
    const order = 'pnbrq';
    final sorted = [...pieces]..sort((a, b) => order.indexOf(a) - order.indexOf(b));
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final p in sorted)
            Text(_glyph[p]!, style: TextStyle(fontSize: 18, color: (white ? Arcade.amber : Arcade.teal).withValues(alpha: .8))),
        ],
      ),
    );
  }
}

/// Asks which piece a pawn becomes. Returns 'q', 'r', 'b' or 'n'.
Future<String?> showPromotionPicker(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NeonPanel(
          color: Arcade.amber,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PROMOTE TO', style: Arcade.title(Arcade.amber, size: 18)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final p in ['q', 'r', 'b', 'n'])
                    Semantics(
                      button: true,
                      label: ChessAi.pieceName(p),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(p),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_glyph[p]!, style: TextStyle(fontSize: 42, color: Arcade.amber, shadows: Arcade.glow(Arcade.amber))),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
