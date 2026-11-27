import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../music/stradella.dart';
import 'theme.dart';

/// Disegna una porzione della tastiera dei **bassi Stradella** (come sulla
/// Roland FR-1x) e vi evidenzia i pulsanti da premere per il giro di accordi.
///
/// Colonne = radici disposte per quinte (circolo delle quinte); righe, dall'alto
/// in basso = contrabbasso, basso, Maggiore, minore, settima, diminuito.
class StradellaPainter extends CustomPainter {
  final List<StradellaHint> hints;
  final bool useLetters;

  StradellaPainter(this.hints, {required this.useLetters});

  @override
  void paint(Canvas canvas, Size size) {
    // Board completa della FR-1x: 12 colonne (C♯..F♯) per 6 file.
    const minF = stradMinFifths;
    const maxF = stradMaxFifths;
    const nCols = maxF - minF + 1;

    const rows = 6; // counterbass, bass, major, minor, seventh, diminished
    const labelW = 24.0; // etichette file a sinistra
    const colLabelH = 16.0; // nomi radici in basso

    final boardW = size.width - labelW;
    final boardH = size.height - colLabelH;
    final colW = boardW / nCols;
    final rowH = boardH / rows;
    final radius = math.min(colW, rowH) * 0.4;

    double cx(int f) => labelW + (f - minF + 0.5) * colW;
    double cy(int row) => (row + 0.5) * rowH;

    final colLabels = useLetters ? stradColLabels : stradColLabelsIt;

    // Colonne usate dal giro (per i nomi in grassetto).
    final usedCols = <int>{for (final h in hints) stradellaFifths(h.rootPc)};

    // --- Griglia di base (bottoni spenti) ---
    final basePaint = Paint()..color = const Color(0x22F2E7D6);
    final baseOutline = Paint()
      ..color = const Color(0x33F2E7D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int f = minF; f <= maxF; f++) {
      for (int r = 0; r < rows; r++) {
        final c = Offset(cx(f), cy(r));
        canvas.drawCircle(c, radius, basePaint);
        canvas.drawCircle(c, radius, baseOutline);
      }
    }

    // --- Etichette file (a sinistra) ---
    for (int r = 0; r < rows; r++) {
      _text(canvas, stradRowShort[r], Offset(labelW / 2, cy(r)),
          size: 10, color: const Color(0xAAF2E7D6), center: true);
    }

    // --- Nomi radici (in basso) ---
    for (int f = minF; f <= maxF; f++) {
      final used = usedCols.contains(f);
      _text(canvas, colLabels[f + 5], Offset(cx(f), boardH + colLabelH / 2),
          size: 10,
          color: used ? AppColors.brass : const Color(0x66F2E7D6),
          center: true,
          bold: used);
    }

    // --- Pulsanti da premere ---
    for (int i = 0; i < hints.length; i++) {
      final h = hints[i];
      final f = stradellaFifths(h.rootPc);
      final bassC = Offset(cx(f), cy(StradRow.bass.index));
      final chordC = Offset(cx(f), cy(h.row.index));
      final cbC = Offset(cx(f), cy(StradRow.counterbass.index));

      // Connettore basso ↔ accordo.
      canvas.drawLine(
          bassC,
          chordC,
          Paint()
            ..color = const Color(0x55C9A24B)
            ..strokeWidth = 2);

      // Contrabbasso (riferimento, tenue).
      canvas.drawCircle(cbC, radius * 0.9,
          Paint()..color = const Color(0x33C9A24B));

      // Basso fondamentale (ottone).
      _button(canvas, bassC, radius, AppColors.stayGradient, '${i + 1}',
          AppColors.blackKey);

      // Accordo: ottone se esatto, arancio se approssimato (con anello).
      if (h.exact) {
        _button(canvas, chordC, radius, AppColors.stayGradient, '${i + 1}',
            AppColors.blackKey);
      } else {
        _button(canvas, chordC, radius, AppColors.moveGradient, '${i + 1}',
            Colors.white);
        canvas.drawCircle(
            chordC,
            radius + 2,
            Paint()
              ..color = AppColors.moveA
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
  }

  void _button(Canvas canvas, Offset c, double radius, Gradient grad,
      String label, Color textColor) {
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = grad.createShader(Rect.fromCircle(center: c, radius: radius)));
    _text(canvas, label, c,
        size: (radius * 1.1).clamp(9.0, 15.0),
        color: textColor,
        center: true,
        bold: true);
  }

  void _text(Canvas canvas, String s, Offset pos,
      {required double size,
      required Color color,
      bool center = false,
      bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant StradellaPainter oldDelegate) =>
      oldDelegate.hints != hints || oldDelegate.useLetters != useLetters;
}
