// Tipi di supporto per descrivere un voicing già ottimizzato e pronto per la UI.

/// Stato di un singolo dito rispetto all'accordo precedente nel ciclo.
enum FingerMotion {
  /// Il dito resta sullo stesso tasto (stessa nota MIDI del voicing precedente).
  stay,

  /// Il dito si sposta: [VoiceState.delta] indica di quanti semitoni (con segno).
  move,
}

/// Stato di una singola voce (nota) del voicing, pronto per essere disegnato.
class VoiceState {
  /// Numero MIDI della nota.
  final int midi;

  /// Dito assegnato (1 = pollice … 5 = mignolo).
  final int finger;

  /// Se il dito è fermo o in movimento rispetto all'accordo precedente.
  final FingerMotion motion;

  /// Spostamento in semitoni rispetto alla voce corrispondente del precedente
  /// (positivo = verso l'acuto, negativo = verso il grave). 0 se [motion] è
  /// [FingerMotion.stay] o se non esiste una voce corrispondente.
  final int delta;

  const VoiceState({
    required this.midi,
    required this.finger,
    required this.motion,
    required this.delta,
  });

  bool get isStay => motion == FingerMotion.stay;
}

/// Voicing completo di un accordo nel giro, con tutte le informazioni derivate
/// necessarie alla card e alla tastiera.
class VoicedChord {
  /// Sigla dell'accordo (es. `Bm`).
  final String symbol;

  /// Nome del rivolto (es. `1º rivolto`).
  final String inversionName;

  /// Note MIDI del voicing, dal basso all'acuto.
  final List<int> notes;

  /// Stato di ogni voce (stesso ordine di [notes]).
  final List<VoiceState> voices;

  /// Sigla dell'accordo precedente nel ciclo (per la riga "↻ dall'ultimo …").
  final String prevSymbol;

  /// Indica se questo è il primo accordo del giro (confronto col ciclo: ↻).
  final bool isFirst;

  const VoicedChord({
    required this.symbol,
    required this.inversionName,
    required this.notes,
    required this.voices,
    required this.prevSymbol,
    required this.isFirst,
  });
}
