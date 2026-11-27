import '../models/chord.dart';

/// File dei bassi Stradella (come sulla Roland FR-1x), dall'esterno verso
/// l'interno: contrabbasso, basso fondamentale, e le 4 file di accordi
/// preconfezionati disponibili (Maggiore, minore, settima, diminuito).
enum StradRow { counterbass, bass, major, minor, seventh, diminished }

/// Etichette brevi per le file (indicizzate per `StradRow.index`).
const List<String> stradRowShort = ['3ª', 'B', 'M', 'm', '7', '°'];

/// Nomi estesi delle file accordo.
const Map<StradRow, String> stradRowName = {
  StradRow.major: 'Maggiore',
  StradRow.minor: 'minore',
  StradRow.seventh: 'settima',
  StradRow.diminished: 'diminuito',
};

/// Suggerimento per la mano sinistra (bassi Stradella) di un accordo.
class StradellaHint {
  /// Sigla dell'accordo (es. `Bm`).
  final String symbol;

  /// Pitch class del basso fondamentale da premere.
  final int rootPc;

  /// Fila dell'accordo da premere (Maggiore/minore/settima/diminuito).
  final StradRow row;

  /// true se l'accordo è disponibile tal quale sullo Stradella; false se è
  /// un'approssimazione (serve completare con la mano destra).
  final bool exact;

  /// Pitch class della nota da aggiungere con la destra (o -1 se nessuna).
  final int addNotePc;

  /// Spiegazione della sostituzione (vuota se [exact]).
  final String why;

  const StradellaHint({
    required this.symbol,
    required this.rootPc,
    required this.row,
    required this.exact,
    this.addNotePc = -1,
    this.why = '',
  });

  /// Contrabbasso (terza maggiore sopra la fondamentale), usato per l'alternanza
  /// basso/accordo.
  int get counterBassPc => (rootPc + 4) % 12;
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Calcola il suggerimento Stradella per un accordo, mappando le qualità sulle
/// 4 file disponibili e proponendo una sostituzione per quelle che non lo sono.
StradellaHint stradellaFor(Chord c) {
  final iv = c.intervals;
  final r = c.root;
  StradellaHint h(StradRow row,
          {bool exact = true, int add = -1, String why = ''}) =>
      StradellaHint(
        symbol: c.symbol,
        rootPc: r,
        row: row,
        exact: exact,
        addNotePc: add,
        why: why,
      );

  // Disponibili tal quali.
  if (_eq(iv, [0, 4, 7])) return h(StradRow.major);
  if (_eq(iv, [0, 3, 7])) return h(StradRow.minor);
  if (_eq(iv, [0, 4, 7, 10])) return h(StradRow.seventh);
  if (_eq(iv, [0, 3, 6]) || _eq(iv, [0, 3, 6, 9])) {
    return h(StradRow.diminished);
  }

  // Approssimazioni (completa con la destra).
  if (_eq(iv, [0, 4, 7, 11])) {
    return h(StradRow.major, exact: false, add: (r + 11) % 12, why: '+ 7ª magg.');
  }
  if (_eq(iv, [0, 3, 7, 10])) {
    return h(StradRow.minor, exact: false, add: (r + 10) % 12, why: '+ 7ª');
  }
  if (_eq(iv, [0, 3, 6, 10])) {
    // Semidiminuito (m7♭5): la fila diminuito è la più vicina.
    return h(StradRow.diminished, exact: false, add: (r + 10) % 12, why: 'semidim. ≈ °');
  }
  if (_eq(iv, [0, 4, 7, 9])) {
    return h(StradRow.major, exact: false, add: (r + 9) % 12, why: '+ 6ª');
  }
  if (_eq(iv, [0, 3, 7, 9])) {
    return h(StradRow.minor, exact: false, add: (r + 9) % 12, why: '+ 6ª');
  }
  if (_eq(iv, [0, 4, 8])) {
    return h(StradRow.major, exact: false, add: (r + 8) % 12, why: '5ª aumentata');
  }
  if (_eq(iv, [0, 5, 7])) {
    return h(StradRow.major, exact: false, add: (r + 5) % 12, why: 'sus4');
  }
  if (_eq(iv, [0, 2, 7])) {
    return h(StradRow.major, exact: false, add: (r + 2) % 12, why: 'sus2');
  }
  return h(StradRow.major, exact: false, why: 'approssimato');
}

/// Posizione nel circolo delle quinte (da C), centrata in −5..6, per disporre
/// le colonne della tastiera Stradella.
int stradellaFifths(int pc) {
  final v = (pc * 7) % 12;
  return ((v + 5) % 12) - 5;
}

/// Pitch class della colonna a distanza [fifths] quinte da C.
int pcFromFifths(int fifths) => ((7 * fifths) % 12 + 12) % 12;
