/// Modello di un accordo riconosciuto dal parser.
///
/// Lavoriamo sempre con i numeri MIDI (Do centrale C4 = 60); la *pitch class*
/// di una nota è `midi % 12`.
class Chord {
  /// Pitch class della fondamentale (0..11, dove 0 = C).
  final int root;

  /// Intervalli in semitoni dalla fondamentale (es. triade maggiore `[0,4,7]`).
  final List<int> intervals;

  /// Sigla originale così come scritta dall'utente (es. `Bm`, `Dmaj7`).
  final String symbol;

  const Chord({
    required this.root,
    required this.intervals,
    required this.symbol,
  });

  /// Pitch class di tutte le note dell'accordo (fondamentale + intervalli).
  List<int> get pitchClasses =>
      intervals.map((i) => (root + i) % 12).toList(growable: false);

  @override
  String toString() => 'Chord($symbol, root=$root, intervals=$intervals)';
}

/// Esito del parsing di una sigla: o un [Chord] valido, oppure la sigla grezza
/// segnalata come non riconosciuta (così non blocchiamo le altre).
class ParseResult {
  /// Sigla originale digitata dall'utente.
  final String raw;

  /// Accordo riconosciuto, oppure `null` se la sigla non è valida.
  final Chord? chord;

  const ParseResult(this.raw, this.chord);

  bool get isValid => chord != null;
}
