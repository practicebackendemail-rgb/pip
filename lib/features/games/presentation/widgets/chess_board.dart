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
    final base = light ? _light : _dark;
    // Last move tinted by who made it: amber for you, teal for Pip.
    final mover = isLast ? game.get(lastMove!.$2)?.color : null;
    final tint = isSelected
        ? Arcade.amber.withValues(alpha: .45)
        : mover == null
            ? null
            : (mover == ch.Color.WHITE ? Arcade.amber : Arcade.teal).withValues(alpha: .28);
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
              if (tint != null) ColoredBox(color: tint),
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
      builder: (context, c) => Center(child: ChessGlyph(letter: letter, color: color, size: c.maxHeight * .78, glow: .5)),
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

/// One piece in [color]. The pawn is drawn rather than typed: phones show
/// the pawn character as a grey emoji whatever colour it's given.
class ChessGlyph extends StatelessWidget {
  final String letter;
  final Color color;
  final double size;
  final double glow;
  const ChessGlyph({super.key, required this.letter, required this.color, required this.size, this.glow = 0});

  @override
  Widget build(BuildContext context) {
    if (letter == 'p') {
      return SizedBox.square(dimension: size, child: CustomPaint(painter: _PawnPainter(color, glow)));
    }
    return Text(
      _glyph[letter]!,
      style: TextStyle(fontSize: size, height: 1, color: color, shadows: [
        if (glow > 0) const Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 2),
        if (glow > 0) ...Arcade.glow(color, strength: glow),
      ]),
    );
  }
}

class _PawnPainter extends CustomPainter {
  final Color color;
  final double glow;
  _PawnPainter(this.color, this.glow);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * .5, h * .27), radius: w * .15))
      ..moveTo(w * .36, h * .43)
      ..lineTo(w * .64, h * .43)
      ..lineTo(w * .6, h * .5)
      ..quadraticBezierTo(w * .6, h * .68, w * .72, h * .78)
      ..lineTo(w * .28, h * .78)
      ..quadraticBezierTo(w * .4, h * .68, w * .4, h * .5)
      ..close()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(w * .2, h * .78, w * .8, h * .9), Radius.circular(w * .05)));
    if (glow > 0) {
      canvas.drawPath(path.shift(Offset(0, h * .03)), Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .6 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glow));
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PawnPainter o) => o.color != color || o.glow != glow;
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
            ChessGlyph(letter: p, color: (white ? Arcade.amber : Arcade.teal).withValues(alpha: .8), size: 18),
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
                          child: ChessGlyph(letter: p, color: Arcade.amber, size: 42, glow: 1),
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
