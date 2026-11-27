import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../music/stradella.dart';
import '../music/theory.dart';
import 'theme.dart';

/// Disegna una porzione della tastiera dei **bassi Stradella** (come sulla
/// Roland FR-1x) e vi evidenzia i pulsanti da premere per il giro di accordi.
///
/// Colonne = radici disposte per quinte (circolo delle quinte); righe, dall'alto
/// in basso = contrabbasso, basso, Maggiore, minore, settima, diminuito.
class StradellaPainter extends CustomPainter {
  final List<StradellaHint> hints;
  final bool useLetters;

  /// Vista triangolo: evidenzia, per ogni accordo, il triangolo
  /// basso · quinta · accordo (es. per D: D3 · A3 · DM).
  final bool triangle;

  StradellaPainter(this.hints,
      {required this.useLetters, this.triangle = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Board completa della FR-1x: 12 colonne (C♯..F♯) per 6 file, disposte in
    // diagonale (file traslate) come sullo strumento reale.
    const minF = stradMinFifths;
    const maxF = stradMaxFifths;
    const nCols = maxF - minF + 1;

    const rows = 6; // counterbass, bass, major, minor, seventh, diminished
    const labelW = 24.0; // etichette file a sinistra
    const colLabelH = 16.0; // nomi radici in basso
    const slant = 0.42; // traslazione orizzontale per fila (in colonne)

    final boardH = size.height - colLabelH;
    final colW =
        (size.width - labelW) / (nCols + (rows - 1) * slant + 0.6);
    final rowH = boardH / rows;
    final radius = math.min(colW, rowH) * 0.4;

    // Le file più in basso sono traslate a sinistra (board a parallelogramma).
    double cx(int f, int row) =>
        labelW + (0.3 + (f - minF + 0.5) + (rows - 1 - row) * slant) * colW;
    double cy(int row) => (row + 0.5) * rowH;

    final colLabels = useLetters ? stradColLabels : stradColLabelsIt;
    final usedCols = <int>{for (final h in hints) stradellaFifths(h.rootPc)};

    // Pulsanti di riferimento (col pallino tattile sullo strumento): Do, Mi, La♭.
    const refPcs = {0, 4, 8};

    final basePaint = Paint()..color = const Color(0x22F2E7D6);
    final baseOutline = Paint()
      ..color = const Color(0x33F2E7D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // --- Griglia di base (bottoni spenti) + marcatori di riferimento ---
    for (int f = minF; f <= maxF; f++) {
      final pc = pcFromFifths(f);
      for (int r = 0; r < rows; r++) {
        final c = Offset(cx(f, r), cy(r));
        canvas.drawCircle(c, radius, basePaint);
        canvas.drawCircle(c, radius, baseOutline);
        // Riferimento sui bassi fondamentali Do/Mi/La♭.
        if (r == StradRow.bass.index && refPcs.contains(pc)) {
          canvas.drawCircle(c, radius + 1.5,
              Paint()
                ..color = AppColors.cream
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          canvas.drawCircle(
              c, radius * 0.3, Paint()..color = AppColors.cream);
        }
      }
    }

    // --- Etichette file (a sinistra) ---
    for (int r = 0; r < rows; r++) {
      _text(canvas, stradRowShort[r], Offset(labelW / 2, cy(r)),
          size: 10, color: const Color(0xAAF2E7D6), center: true);
    }

    // --- Nomi radici (in basso, allineati alla fila più bassa) ---
    for (int f = minF; f <= maxF; f++) {
      final used = usedCols.contains(f);
      _text(canvas, colLabels[f + 5],
          Offset(cx(f, rows - 1), boardH + colLabelH / 2),
          size: 10,
          color: used ? AppColors.brass : const Color(0x66F2E7D6),
          center: true,
          bold: used);
    }

    // --- Pulsanti da premere ---
    final names = useLetters ? noteNames : noteNamesIt;
    for (int i = 0; i < hints.length; i++) {
      final h = hints[i];
      final f = stradellaFifths(h.rootPc);
      final bassC = Offset(cx(f, StradRow.bass.index), cy(StradRow.bass.index));
      final chordC = Offset(cx(f, h.row.index), cy(h.row.index));

      if (triangle) {
        // Vertici: basso fondamentale, quinta (basso), accordo.
        final fifthPc = (h.rootPc + 7) % 12;
        final ff = stradellaFifths(fifthPc);
        final fifthC =
            Offset(cx(ff, StradRow.bass.index), cy(StradRow.bass.index));
        final rowGlyph = stradRowShort[h.row.index];

        // Triangolo (riempito tenue + contorno).
        final path = Path()
          ..moveTo(bassC.dx, bassC.dy)
          ..lineTo(fifthC.dx, fifthC.dy)
          ..lineTo(chordC.dx, chordC.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0x22C9A24B));
        canvas.drawPath(
            path,
            Paint()
              ..color = AppColors.brass
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);

        // Vertici con etichetta reale.
        _vertex(canvas, bassC, radius, AppColors.stayGradient,
            names[h.rootPc % 12], AppColors.blackKey);
        _vertex(canvas, fifthC, radius, AppColors.stayGradient,
            names[fifthPc % 12], AppColors.blackKey);
        final chordGrad =
            h.exact ? AppColors.stayGradient : AppColors.moveGradient;
        _vertex(canvas, chordC, radius, chordGrad,
            '${names[h.rootPc % 12]}$rowGlyph',
            h.exact ? AppColors.blackKey : Colors.white);
        continue;
      }

      final cbC = Offset(
          cx(f, StradRow.counterbass.index), cy(StradRow.counterbass.index));

      // Connettore basso ↔ accordo (diagonale, come la mano).
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

  /// Vertice del triangolo: bottone evidenziato con etichetta (nota/accordo).
  void _vertex(Canvas canvas, Offset c, double radius, Gradient grad,
      String label, Color textColor) {
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader =
              grad.createShader(Rect.fromCircle(center: c, radius: radius)));
    _text(canvas, label, c,
        size: (radius * 0.72).clamp(8.0, 12.0),
        color: textColor,
        center: true,
        bold: true);
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

/// Mini-mappa della tastiera sinistra per una singola card: una finestra di
/// poche colonne attorno all'accordo, coi tasti da premere colorati e il
/// contorno sui tasti di riferimento (Do, Mi, La♭).
class MiniStradellaPainter extends CustomPainter {
  final StradellaHint h;
  final bool useLetters;
  final bool triangle;

  MiniStradellaPainter(this.h, {required this.useLetters, this.triangle = false});

  static const _refPcs = {0, 4, 8};

  @override
  void paint(Canvas canvas, Size size) {
    final f0 = stradellaFifths(h.rootPc);
    // Finestra: dalla colonna a sinistra fino alla quinta (a destra) + margine.
    final minF = f0 - 2;
    final maxF = f0 + 2;
    const nCols = 5;
    const rows = 6;
    const labelW = 16.0;
    const slant = 0.3;

    final boardW = size.width - labelW;
    final colW = boardW / (nCols + (rows - 1) * slant + 0.4);
    final rowH = size.height / rows;
    final radius = math.min(colW, rowH) * 0.4;

    double cx(int f, int row) =>
        labelW + (0.2 + (f - minF + 0.5) + (rows - 1 - row) * slant) * colW;
    double cy(int row) => (row + 0.5) * rowH;

    final basePaint = Paint()..color = const Color(0x1AF2E7D6);
    final baseOutline = Paint()
      ..color = const Color(0x2AF2E7D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Griglia + contorno sui tasti di riferimento (fila basso).
    for (int f = minF; f <= maxF; f++) {
      final pc = pcFromFifths(f);
      for (int r = 0; r < rows; r++) {
        final c = Offset(cx(f, r), cy(r));
        canvas.drawCircle(c, radius, basePaint);
        canvas.drawCircle(c, radius, baseOutline);
        if (r == StradRow.bass.index && _refPcs.contains(pc)) {
          canvas.drawCircle(
              c,
              radius + 1,
              Paint()
                ..color = AppColors.cream
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4);
        }
      }
    }

    // Etichette file a sinistra.
    for (int r = 0; r < rows; r++) {
      final tp = TextPainter(
        text: TextSpan(
            text: stradRowShort[r],
            style: const TextStyle(color: Color(0x99F2E7D6), fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelW / 2 - tp.width / 2, cy(r) - tp.height / 2));
    }

    final bassC = Offset(cx(f0, StradRow.bass.index), cy(StradRow.bass.index));
    final chordC = Offset(cx(f0, h.row.index), cy(h.row.index));

    void fill(Offset c, Gradient g) => canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = g.createShader(Rect.fromCircle(center: c, radius: radius)));

    if (triangle) {
      final ff = stradellaFifths((h.rootPc + 7) % 12);
      final fifthC =
          Offset(cx(ff, StradRow.bass.index), cy(StradRow.bass.index));
      final path = Path()
        ..moveTo(bassC.dx, bassC.dy)
        ..lineTo(fifthC.dx, fifthC.dy)
        ..lineTo(chordC.dx, chordC.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0x22C9A24B));
      canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.brass
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      fill(fifthC, AppColors.stayGradient);
    } else {
      // Contrabbasso (3ª) tenue come basso alternato.
      final cbC = Offset(
          cx(f0, StradRow.counterbass.index), cy(StradRow.counterbass.index));
      canvas.drawCircle(
          cbC, radius * 0.85, Paint()..color = const Color(0x33C9A24B));
    }

    fill(bassC, AppColors.stayGradient);
    fill(chordC, h.exact ? AppColors.stayGradient : AppColors.moveGradient);
    if (!h.exact) {
      canvas.drawCircle(
          chordC,
          radius + 1.5,
          Paint()
            ..color = AppColors.moveA
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant MiniStradellaPainter oldDelegate) =>
      oldDelegate.h.symbol != h.symbol ||
      oldDelegate.h.rootPc != h.rootPc ||
      oldDelegate.h.row != h.row ||
      oldDelegate.triangle != triangle ||
      oldDelegate.useLetters != useLetters;
}
