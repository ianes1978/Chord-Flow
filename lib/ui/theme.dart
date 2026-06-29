import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token di colore e tipografia di Chord Flow.
///
/// Palette bordeaux/lacca con accenti ottone e madreperla; le dita "ferme"
/// sono ottone, quelle "in movimento" arancio/ruggine.
class AppColors {
  // Sfondo: gradiente radiale bordeaux/lacca.
  static const Color bgTop = Color(0xFF6E1D1E);
  static const Color bgMid = Color(0xFF5A1718);
  static const Color bgBottom = Color(0xFF420F10);

  // Materiali.
  static const Color cream = Color(0xFFF2E7D6); // crema/madreperla
  static const Color brass = Color(0xFFC9A24B); // ottone
  static const Color ivoryKey = Color(0xFFF6EFE2); // tasto avorio
  static const Color blackKey = Color(0xFF231B18); // tasto nero

  // Stato dito fermo (gradiente ottone).
  static const Color stayA = Color(0xFFF0C463);
  static const Color stayB = Color(0xFFCAA043);

  // Stato dito in movimento (gradiente arancio/ruggine).
  static const Color moveA = Color(0xFFE2853F);
  static const Color moveB = Color(0xFFB8481B);

  /// Gradiente radiale di sfondo dell'app.
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(0, -0.5),
    radius: 1.3,
    colors: [bgTop, bgMid, bgBottom],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gradiente per un dito fermo (ottone).
  static const LinearGradient stayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [stayA, stayB],
  );

  /// Gradiente per un dito in movimento (arancio/ruggine).
  static const LinearGradient moveGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [moveA, moveB],
  );
}

/// Tipografia: Fraunces (display serif) per titoli/accordi, Inter per la UI.
/// Caricate con google_fonts; in caso di assenza di rete c'è il fallback di
/// sistema gestito dal pacchetto.
class AppText {
  static TextStyle display(
          {double size = 32,
          FontWeight weight = FontWeight.w600,
          Color color = AppColors.cream,
          FontStyle style = FontStyle.normal}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: style,
        height: 1.05,
      );

  static TextStyle ui(
          {double size = 14,
          FontWeight weight = FontWeight.w400,
          Color color = AppColors.cream}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
