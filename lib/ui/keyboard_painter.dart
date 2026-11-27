import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../music/theory.dart';
import '../music/voicing.dart';
import 'theme.dart';

/// Prepara il testo [s] rimpicciolendolo finché non sta in [maxWidth].
/// Restituisce null se non ci sta nemmeno a 5px (meglio niente che illeggibile).
TextPainter? _fitName(String s, double maxWidth, double maxSize, Color color) {
  var size = maxSize;
  while (size >= 5) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            color: color,
            fontSize: size,
            height: 1.0,
            fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (tp.width <= maxWidth) return tp;
    size -= 0.5;
  }
  return null;
}

/// Disegna un pianoforte da [kLow] a [kHigh] (C3–C6) con i tasti dell'accordo
/// evidenziati e il numero del dito stampato su ciascun tasto attivo.
///
/// La finestra è la stessa per tutte le card, così a colpo d'occhio si vede
/// quanto si sposta la mano tra un accordo e l'altro.
class KeyboardPainter extends CustomPainter {
  /// Voci del voicing corrente (con dito e stato fermo/in movimento).
  final List<VoiceState> voices;

  /// true = nomi con le lettere (A B C), false = solfeggio.
  final bool useLetters;

  KeyboardPainter(this.voices, {this.useLetters = false});

  // Pitch class dei tasti bianchi.
  static const Set<int> _whitePcs = {0, 2, 4, 5, 7, 9, 11};

  bool _isWhite(int midi) => _whitePcs.contains(midi % 12);

  /// Numero di tasti bianchi tra [kLow] e [kHigh] inclusi.
  int get _whiteCount {
    var c = 0;
    for (int m = kLow; m <= kHigh; m++) {
      if (_isWhite(m)) c++;
    }
    return c;
  }

  /// Indice progressivo (0-based) del tasto bianco a partire da [kLow].
  int _whiteIndex(int midi) {
    var c = 0;
    for (int m = kLow; m < midi; m++) {
      if (_isWhite(m)) c++;
    }
    return c;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final whiteCount = _whiteCount;
    final whiteW = size.width / whiteCount;
    final height = size.height;
    final blackW = whiteW * 0.62;
    final blackH = height * 0.62;
    final radius = Radius.circular(whiteW * 0.12);

    // Mappa midi → stato voce attiva (se presente).
    final active = <int, VoiceState>{};
    for (final v in voices) {
      active[v.midi] = v;
    }

    final whitePaint = Paint()..color = AppColors.ivoryKey;
    final whiteBorder = Paint()
      ..color = const Color(0x33231B18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final blackPaint = Paint()..color = AppColors.blackKey;

    // --- 1. Tasti bianchi ---
    for (int m = kLow; m <= kHigh; m++) {
      if (!_isWhite(m)) continue;
      final i = _whiteIndex(m);
      final rect = Rect.fromLTWH(i * whiteW, 0, whiteW, height);
      final rrect = RRect.fromRectAndCorners(rect,
          bottomLeft: radius, bottomRight: radius);
      canvas.drawRRect(rrect, whitePaint);

      final v = active[m];
      if (v != null) {
        canvas.drawRRect(rrect, _fillPaint(v));
        _drawFinger(canvas, rect, v, onWhite: true);
      }
      canvas.drawRRect(rrect, whiteBorder);
    }

    // --- 2. Tasti neri (sopra, a cavallo dei bianchi adiacenti) ---
    for (int m = kLow; m <= kHigh; m++) {
      if (_isWhite(m)) continue;
      // Il tasto nero sta tra il bianco precedente e quello successivo.
      final leftWhiteIndex = _whiteIndex(m); // bianchi prima di m
      final centerX = leftWhiteIndex * whiteW;
      final rect = Rect.fromLTWH(centerX - blackW / 2, 0, blackW, blackH);
      final rrect = RRect.fromRectAndCorners(rect,
          bottomLeft: radius, bottomRight: radius);
      canvas.drawRRect(rrect, blackPaint);

      final v = active[m];
      if (v != null) {
        canvas.drawRRect(rrect, _fillPaint(v));
        _drawFinger(canvas, rect, v, onWhite: false);
      }
    }
  }

  /// Riempimento col gradiente dello stato del dito.
  Paint _fillPaint(VoiceState v) {
    final grad = v.isStay ? AppColors.stayGradient : AppColors.moveGradient;
    return Paint()
      ..shader = grad.createShader(const Rect.fromLTWH(0, 0, 40, 120));
  }

  /// Stampa il numero del dito centrato sul tasto attivo.
  /// Testo scuro su ottone (fermo), bianco su arancio (in movimento).
  void _drawFinger(Canvas canvas, Rect keyRect, VoiceState v,
      {required bool onWhite}) {
    final textColor = v.isStay ? AppColors.blackKey : Colors.white;
    final fontSize = keyRect.width * (onWhite ? 0.62 : 0.7);
    final tp = TextPainter(
      text: TextSpan(
        text: '${v.finger}',
        style: TextStyle(
          color: textColor,
          fontSize: fontSize.clamp(9.0, 22.0),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Posizione: in basso sul bianco, in basso sul nero.
    final dy = onWhite
        ? keyRect.bottom - tp.height - keyRect.width * 0.25
        : keyRect.bottom - tp.height - keyRect.width * 0.18;
    final dx = keyRect.left + (keyRect.width - tp.width) / 2;
    tp.paint(canvas, Offset(dx, dy));

    // Nome della nota, piccolo, sopra il numero del dito.
    final names = useLetters ? noteNames : noteNamesIt;
    final name = _fitName(names[v.midi % 12], keyRect.width - 2,
        (keyRect.width * 0.46).clamp(5.0, 10.0), textColor);
    if (name != null) {
      name.paint(
          canvas,
          Offset(keyRect.left + (keyRect.width - name.width) / 2,
              dy - name.height - 1));
    }
  }

  @override
  bool shouldRepaint(covariant KeyboardPainter oldDelegate) =>
      oldDelegate.voices != voices || oldDelegate.useLetters != useLetters;
}

/// Disegna la **bottoniera cromatica** della fisarmonica (sistema C / do-griff)
/// da [kLow] a [kHigh], stessa finestra del pianoforte così il confronto tra
/// card resta immediato.
///
/// Le note salgono cromaticamente a zig-zag su 3 file: la fila è `midi % 3`
/// (fila 0 = Do, Re♯, Fa♯, La; fila 1 = Do♯, Mi, Sol, La♯; fila 2 = Re, Fa,
/// Sol♯, Si). Nella stessa fila i bottoni distano una terza minore (3 semitoni),
/// e le file sono sfalsate in orizzontale per rendere la diagonale cromatica.
class AccordionPainter extends CustomPainter {
  /// Voci del voicing corrente (con dito e stato fermo/in movimento).
  final List<VoiceState> voices;

  /// true = nomi con le lettere (A B C), false = solfeggio.
  final bool useLetters;

  AccordionPainter(this.voices, {this.useLetters = false});

  // Pitch class "naturali" (come i tasti bianchi del piano), per orientarsi.
  static const Set<int> _naturals = {0, 2, 4, 5, 7, 9, 11};

  @override
  void paint(Canvas canvas, Size size) {
    final maxCol = (kHigh - kLow) / 3.0; // colonne per fila
    final unit = size.width / (maxCol + 1.6);
    final rowGap = size.height / 3;
    final radius = math.min(unit * 0.42, rowGap * 0.42);

    // Mappa midi → voce attiva.
    final active = <int, VoiceState>{};
    for (final v in voices) {
      active[v.midi] = v;
    }

    final outline = Paint()
      ..color = const Color(0x44231B18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int m = kLow; m <= kHigh; m++) {
      final pc = m % 12;
      final r = m % 3; // fila 0/1/2
      final colf = (m - kLow) / 3.0; // posizione + sfalsamento diagonale
      final center = Offset((colf + 0.8) * unit, (r + 0.5) * rowGap);

      // Bottone base: chiaro per i naturali, scuro per le alterazioni.
      final natural = _naturals.contains(pc);
      canvas.drawCircle(center, radius,
          Paint()..color = natural ? AppColors.ivoryKey : AppColors.blackKey);

      final v = active[m];
      if (v != null) {
        canvas.drawCircle(center, radius, _fillPaint(v, center, radius));
        _drawFinger(canvas, center, radius, v);
      } else if (pc == 0) {
        // Riferimento visivo sui bottoni Do.
        canvas.drawCircle(center, radius * 0.28,
            Paint()..color = const Color(0x66C9A24B));
      }
      canvas.drawCircle(center, radius, outline);
    }
  }

  Paint _fillPaint(VoiceState v, Offset center, double radius) {
    final grad = v.isStay ? AppColors.stayGradient : AppColors.moveGradient;
    return Paint()
      ..shader =
          grad.createShader(Rect.fromCircle(center: center, radius: radius));
  }

  void _drawFinger(Canvas canvas, Offset center, double radius, VoiceState v) {
    final textColor = v.isStay ? AppColors.blackKey : Colors.white;
    // Nome della nota sotto il numero, se il bottone è abbastanza grande.
    final names = useLetters ? noteNames : noteNamesIt;
    final name = radius >= 8
        ? _fitName(names[v.midi % 12], radius * 1.5, radius * 0.6, textColor)
        : null;
    final tp = TextPainter(
      text: TextSpan(
        text: '${v.finger}',
        style: TextStyle(
          color: textColor,
          fontSize: (radius * (name == null ? 1.15 : 0.9)).clamp(8.0, 18.0),
          height: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (name == null) {
      tp.paint(canvas,
          Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    } else {
      final total = tp.height + name.height;
      final top = center.dy - total / 2;
      tp.paint(canvas, Offset(center.dx - tp.width / 2, top));
      name.paint(
          canvas, Offset(center.dx - name.width / 2, top + tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant AccordionPainter oldDelegate) =>
      oldDelegate.voices != voices || oldDelegate.useLetters != useLetters;
}
