// Ritmi di accompagnamento per la mano sinistra (bassi Stradella).
//
// Ogni ritmo è una sequenza di "colpi" su una battuta: Basso (fondamentale),
// Contrabbasso (3ª, per il basso alternato), Accordo, o pausa. I pattern dei
// forró sono versioni semplificate/indicative della mano sinistra.

enum LhHit { bass, counter, chord, rest }

extension LhHitGlyph on LhHit {
  /// Simbolo breve per la striscia ritmica.
  String get glyph {
    switch (this) {
      case LhHit.bass:
        return 'B';
      case LhHit.counter:
        return 'C';
      case LhHit.chord:
        return 'A';
      case LhHit.rest:
        return '·';
    }
  }
}

class Rhythm {
  final String name;
  final String meter; // es. "2/4", "3/4", "6/8"
  final List<LhHit> pattern; // una battuta
  final bool forro;

  const Rhythm(this.name, this.meter, this.pattern, {this.forro = false});
}

const List<Rhythm> rhythms = [
  // Classici
  Rhythm('Valzer', '3/4', [LhHit.bass, LhHit.chord, LhHit.chord]),
  Rhythm('Marcia / Polca', '2/4',
      [LhHit.bass, LhHit.chord, LhHit.counter, LhHit.chord]),
  Rhythm('Mazurca', '3/4', [LhHit.bass, LhHit.chord, LhHit.chord]),
  Rhythm('Tango', '4/4',
      [LhHit.bass, LhHit.chord, LhHit.counter, LhHit.chord]),
  // Forró (Brasile)
  Rhythm('Baião', '2/4', [LhHit.bass, LhHit.chord, LhHit.rest, LhHit.chord],
      forro: true),
  Rhythm('Xote', '2/4',
      [LhHit.bass, LhHit.chord, LhHit.counter, LhHit.chord],
      forro: true),
  Rhythm(
      'Arrasta-pé',
      '6/8',
      [
        LhHit.bass,
        LhHit.chord,
        LhHit.chord,
        LhHit.counter,
        LhHit.chord,
        LhHit.chord
      ],
      forro: true),
  Rhythm('Xaxado', '2/4', [LhHit.bass, LhHit.chord, LhHit.bass, LhHit.chord],
      forro: true),
];
