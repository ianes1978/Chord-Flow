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
/// poche colonne attorno all'accordo, coi tasti da premere colorati **e col
/// nome scritto sopra**, più il contorno (e il nome) sui tasti di riferimento
/// (Do, Mi, La♭).
class MiniStradellaPainter extends CustomPainter {
  final StradellaHint h;
  final bool useLetters;
  final bool triangle;

  MiniStradellaPainter(this.h, {required this.useLetters, this.triangle = false});

  static const _refPcs = {0, 4, 8};

  @override
  void paint(Canvas canvas, Size size) {
    final f0 = stradellaFifths(h.rootPc);
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
    // I tasti da premere sono più grandi, così ci sta il nome.
    final big = math.min(math.min(colW, rowH * 1.5) * 0.5, radius * 1.6);

    double cx(int f, int row) =>
        labelW + (0.2 + (f - minF + 0.5) + (rows - 1 - row) * slant) * colW;
    double cy(int row) => (row + 0.5) * rowH;

    final colLabels = useLetters ? stradColLabels : stradColLabelsIt;
    // Nome della nota della colonna [f] (coi bemolle come sullo strumento).
    String colName(int f) => colLabels[((f + 5) % 12 + 12) % 12];

    final basePaint = Paint()..color = const Color(0x1AF2E7D6);
    final baseOutline = Paint()
      ..color = const Color(0x2AF2E7D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Griglia + contorno e nome sui tasti di riferimento (fila basso).
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
          _label(canvas, colName(f), c, radius * 1.7,
              color: const Color(0xCCF2E7D6), maxSize: 8);
        }
      }
    }

    // Etichette file a sinistra.
    for (int r = 0; r < rows; r++) {
      _label(canvas, stradRowShort[r], Offset(labelW / 2, cy(r)), labelW,
          color: const Color(0x99F2E7D6), maxSize: 8, bold: false);
    }

    final bassRow = StradRow.bass.index;
    final bassC = Offset(cx(f0, bassRow), cy(bassRow));
    final chordC = Offset(cx(f0, h.row.index), cy(h.row.index));
    final rootName = colName(f0);

    void button(Offset c, Gradient g, String name, Color textColor) {
      canvas.drawCircle(
          c,
          big,
          Paint()
            ..shader = g.createShader(Rect.fromCircle(center: c, radius: big)));
      _label(canvas, name, c, big * 1.75, color: textColor, maxSize: 11);
    }

    if (triangle) {
      final ff = f0 + 1; // la quinta è la colonna subito a destra
      final fifthC = Offset(cx(ff, bassRow), cy(bassRow));
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
      button(fifthC, AppColors.stayGradient, colName(ff), AppColors.blackKey);
    } else {
      // Contrabbasso (3ª) come basso alternato: tenue, ma col nome.
      final cbRow = StradRow.counterbass.index;
      final cbC = Offset(cx(f0, cbRow), cy(cbRow));
      canvas.drawCircle(cbC, big * 0.9, Paint()..color = const Color(0x55C9A24B));
      final names = useLetters ? noteNames : noteNamesIt;
      _label(canvas, names[h.counterBassPc % 12], cbC, big * 1.6,
          color: AppColors.cream, maxSize: 9);
    }

    button(bassC, AppColors.stayGradient, rootName, AppColors.blackKey);
    button(
        chordC,
        h.exact ? AppColors.stayGradient : AppColors.moveGradient,
        '$rootName${stradRowShort[h.row.index]}',
        h.exact ? AppColors.blackKey : Colors.white);
    if (!h.exact) {
      canvas.drawCircle(
          chordC,
          big + 1.5,
          Paint()
            ..color = AppColors.moveA
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  /// Scrive [s] centrato in [c], rimpicciolendo il carattere finché non sta
  /// in [maxWidth] (minimo 5px).
  void _label(Canvas canvas, String s, Offset c, double maxWidth,
      {required Color color, double maxSize = 10, bool bold = true}) {
    var size = maxSize;
    late TextPainter tp;
    while (true) {
      tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
              color: color,
              fontSize: size,
              height: 1.0,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width <= maxWidth || size <= 5) break;
      size -= 0.5;
    }
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MiniStradellaPainter oldDelegate) =>
      oldDelegate.h.symbol != h.symbol ||
      oldDelegate.h.rootPc != h.rootPc ||
      oldDelegate.h.row != h.row ||
      oldDelegate.triangle != triangle ||
      oldDelegate.useLetters != useLetters;
}
