import 'package:flutter/material.dart';
import '../music/theory.dart';
import '../music/voicing.dart';
import 'theme.dart';

/// Disegna un pianoforte da [kLow] a [kHigh] (C3–C6) con i tasti dell'accordo
/// evidenziati e il numero del dito stampato su ciascun tasto attivo.
///
/// La finestra è la stessa per tutte le card, così a colpo d'occhio si vede
/// quanto si sposta la mano tra un accordo e l'altro.
class KeyboardPainter extends CustomPainter {
  /// Voci del voicing corrente (con dito e stato fermo/in movimento).
  final List<VoiceState> voices;

  KeyboardPainter(this.voices);

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
  }

  @override
  bool shouldRepaint(covariant KeyboardPainter oldDelegate) =>
      oldDelegate.voices != voices;
}
