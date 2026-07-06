import 'package:flutter/material.dart';
import '../music/theory.dart';
import '../music/voicing.dart';
import 'keyboard_painter.dart';
import 'theme.dart';

/// Card di un singolo accordo del giro: nome, rivolto, tastiera con diteggiatura
/// colorata per stato, riga note e riga movimento delle dita.
class ChordCard extends StatelessWidget {
  final VoicedChord voiced;
  final int index; // 0-based
  final int total;
  final bool highlighted; // evidenziazione durante la riproduzione
  final bool useLetters; // true = note con lettere (A B C), false = solfeggio
  final bool compact; // true = vista compatta (dimensioni ridotte)
  final bool buttons; // true = bottoniera fisarmonica, false = pianoforte
  final VoidCallback onTap;

  const ChordCard({
    super.key,
    required this.voiced,
    required this.index,
    required this.total,
    required this.highlighted,
    required this.useLetters,
    required this.compact,
    required this.buttons,
    required this.onTap,
  });

  /// Nome della nota secondo la preferenza (lettere o solfeggio).
  String _noteName(int midi) =>
      (useLetters ? noteNames : noteNamesIt)[midi % 12];

  /// Formatta un delta col segno usando il segno meno tipografico (−).
  String _signed(int delta) => delta > 0 ? '+$delta' : '−${delta.abs()}';

  /// Riga "movimento dita" secondo le specifiche.
  String _motionLine() {
    final moves = voiced.voices
        .where((v) => !v.isStay)
        .map((v) => '${circledFinger(v.finger)}${_signed(v.delta)}')
        .join(' ');
    final stays = voiced.voices
        .where((v) => v.isStay)
        .map((v) => circledFinger(v.finger))
        .join(' ');

    final sb = StringBuffer();
    if (voiced.isFirst) {
      sb.write('↻ dall\'ultimo (${voiced.prevSymbol}) · ');
    }
    if (moves.isEmpty) {
      sb.write('mano immobile');
    } else {
      sb.write('si muovono: $moves');
      if (stays.isNotEmpty) sb.write(' · ferme: $stays');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: const Color(0x14F2E7D6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? AppColors.brass : const Color(0x33C9A24B),
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.brass.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  )
                ]
              : const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
        ),
        padding: EdgeInsets.all(compact ? 11 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            SizedBox(height: compact ? 8 : 12),
            _keyboard(),
            SizedBox(height: compact ? 8 : 12),
            _noteRow(),
            SizedBox(height: compact ? 4 : 6),
            Text(
              _motionLine(),
              style: AppText.ui(
                  size: compact ? 11 : 13, color: const Color(0xFFE9D8BE)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          voiced.symbol,
          style: AppText.display(
              size: compact ? 22 : 30, weight: FontWeight.w600),
        ),
        SizedBox(width: compact ? 6 : 10),
        // Badge col nome del rivolto (si accorcia con i puntini se serve).
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x22C9A24B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x55C9A24B)),
            ),
            child: Text(
              voiced.inversionName,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(
                  size: compact ? 10 : 12,
                  weight: FontWeight.w600,
                  color: AppColors.brass),
            ),
          ),
        ),
        SizedBox(width: compact ? 4 : 8),
        Text(
          '${index + 1}/$total',
          style: AppText.ui(
              size: compact ? 11 : 13, color: const Color(0x99F2E7D6)),
        ),
      ],
    );
  }

  Widget _keyboard() {
    // Stessa finestra (C3–C6) per tutte le card: si vede a colpo d'occhio
    // quanto si sposta la mano. Altezza fissa, larghezza responsive.
    final h = compact ? 72.0 : 96.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: h,
          child: CustomPaint(
            painter: buttons
                ? AccordionPainter(voiced.voices)
                : KeyboardPainter(voiced.voices),
            size: Size(constraints.maxWidth, h),
          ),
        );
      },
    );
  }

  Widget _noteRow() {
    final spans = <InlineSpan>[];
    for (int i = 0; i < voiced.voices.length; i++) {
      final v = voiced.voices[i];
      final color = v.isStay ? AppColors.brass : AppColors.moveA;
      spans.add(TextSpan(
        text: circledFinger(v.finger),
        style: AppText.ui(
            size: compact ? 15 : 18, weight: FontWeight.w700, color: color),
      ));
      spans.add(TextSpan(
        text: '${_noteName(v.midi)}  ',
        style: AppText.ui(size: compact ? 13 : 16, color: AppColors.cream),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}
