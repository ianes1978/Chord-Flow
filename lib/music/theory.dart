import '../models/chord.dart';

/// Cuore musicale dell'app: costanti, parsing, generazione dei voicing
/// candidati e ottimizzatore ciclico della diteggiatura.
///
/// Convenzioni: numeri MIDI (Do centrale C4 = 60); pitch class = `midi % 12`.

// ---------------------------------------------------------------------------
// Costanti
// ---------------------------------------------------------------------------

/// Nomi delle note (con diesis), indicizzati per pitch class 0..11.
const List<String> noteNames = [
  'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B',
];

/// Nomi italiani delle note (per la UI), indicizzati per pitch class 0..11.
const List<String> noteNamesIt = [
  'Do', 'Do♯', 'Re', 'Re♯', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'La♯', 'Si',
];

/// Lettera della nota → pitch class.
const Map<String, int> letterToPc = {
  'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11,
};

/// Qualità accordo → intervalli (semitoni dalla fondamentale).
///
/// Le chiavi sono normalizzate (vedi [_normalizeQuality]); più varianti possono
/// puntare allo stesso set di intervalli.
const Map<String, List<int>> qualityToIntervals = {
  // Triadi
  '': [0, 4, 7],
  'maj': [0, 4, 7],
  'm': [0, 3, 7],
  'min': [0, 3, 7],
  '-': [0, 3, 7],
  'dim': [0, 3, 6],
  '°': [0, 3, 6],
  'o': [0, 3, 6],
  'aug': [0, 4, 8],
  '+': [0, 4, 8],
  // Settime
  '7': [0, 4, 7, 10],
  'maj7': [0, 4, 7, 11],
  'm7': [0, 3, 7, 10],
  'min7': [0, 3, 7, 10],
  'm7b5': [0, 3, 6, 10],
  'ø': [0, 3, 6, 10],
  'dim7': [0, 3, 6, 9],
  '°7': [0, 3, 6, 9],
  // Seste
  '6': [0, 4, 7, 9],
  'm6': [0, 3, 7, 9],
  // Sospese
  'sus4': [0, 5, 7],
  'sus': [0, 5, 7],
  'sus2': [0, 2, 7],
};

/// Nomi dei rivolti, indicizzati per posizione della fondamentale nel voicing.
const List<String> invNames = [
  'fondamentale', '1º rivolto', '2º rivolto', '3º rivolto',
];

/// Range della tastiera disegnata: C3 .. C6.
const int kLow = 48;
const int kHigh = 84;

/// Range di ricerca dei bassi del voicing.
const int kSearchLo = 52;
const int kSearchHi = 81;

/// Centro comodo della mano destra.
const int kTarget = 64;

// ---------------------------------------------------------------------------
// Parsing della sigla
// ---------------------------------------------------------------------------

final RegExp _chordRe = RegExp(r'^([A-Ga-g])([#b♯♭]?)(.*)$');

/// Normalizza la stringa di qualità per consultare [qualityToIntervals]
/// gestendo varianti maiuscole/minuscole e sinonimi.
String _normalizeQuality(String q) {
  // Simboli unicode e abbreviazioni che la mappa già conosce vengono lasciati.
  // Per il resto normalizziamo i casi noti scritti in modo diverso.
  final t = q.trim();
  switch (t) {
    case 'M':
      return 'maj'; // M maiuscola = maggiore
    case 'MAJ':
    case 'Maj':
      return 'maj';
    case 'M7':
    case 'MAJ7':
    case 'Maj7':
      return 'maj7';
    case 'MIN':
    case 'Min':
      return 'm';
    case 'MIN7':
    case 'Min7':
      return 'm7';
    case 'DIM':
    case 'Dim':
      return 'dim';
    case 'DIM7':
    case 'Dim7':
      return 'dim7';
    case 'AUG':
    case 'Aug':
      return 'aug';
    case 'SUS':
    case 'Sus':
      return 'sus4';
    case 'SUS2':
    case 'Sus2':
      return 'sus2';
    case 'SUS4':
    case 'Sus4':
      return 'sus4';
    default:
      return t;
  }
}

/// Esegue il parsing di una singola sigla accordo.
///
/// Regex: `^([A-Ga-g])([#b♯♭]?)(.*)$`. La lettera dà la pitch class base;
/// `#/♯` la alza di 1, `b/♭` la abbassa di 1 (mod 12). Il resto è la qualità.
/// Restituisce un [ParseResult]: se la sigla non è valida `chord` è `null`.
ParseResult parseChord(String raw) {
  final symbol = raw.trim();
  if (symbol.isEmpty) return ParseResult(raw, null);

  final m = _chordRe.firstMatch(symbol);
  if (m == null) return ParseResult(raw, null);

  final letter = m.group(1)!.toUpperCase();
  final accidental = m.group(2) ?? '';
  final qualityRaw = m.group(3) ?? '';

  int root = letterToPc[letter]!;
  if (accidental == '#' || accidental == '♯') {
    root = (root + 1) % 12;
  } else if (accidental == 'b' || accidental == '♭') {
    root = (root - 1 + 12) % 12;
  }

  // Cerchiamo la qualità prima così com'è, poi normalizzata.
  List<int>? intervals = qualityToIntervals[qualityRaw];
  intervals ??= qualityToIntervals[_normalizeQuality(qualityRaw)];
  if (intervals == null) return ParseResult(raw, null);

  return ParseResult(
    raw,
    Chord(root: root, intervals: intervals, symbol: symbol),
  );
}

/// Esegue il parsing di una riga di accordi separati da spazi o virgole.
List<ParseResult> parseProgression(String input) {
  return input
      .split(RegExp(r'[\s,]+'))
      .where((s) => s.trim().isNotEmpty)
      .map(parseChord)
      .toList();
}

// ---------------------------------------------------------------------------
// Generazione dei voicing candidati
// ---------------------------------------------------------------------------

/// Genera tutti i rivolti in posizione chiusa di [c], su più ottave.
///
/// Il basso deve essere una nota dell'accordo; le altre note salgono in
/// posizione chiusa restando entro l'ottava (span ≤ 12) e sotto [kHigh].
List<List<int>> candidates(Chord c) {
  final pcs = c.pitchClasses;
  final result = <List<int>>[];

  for (int bottom = kSearchLo; bottom <= kSearchHi; bottom++) {
    final bpc = bottom % 12;
    if (!pcs.contains(bpc)) continue; // il basso dev'essere una nota dell'accordo

    // Le altre note, ordinate per distanza ascendente dal basso.
    final altre = pcs.where((p) => p != bpc).toList()
      ..sort((a, b) => ((a - bpc + 12) % 12).compareTo((b - bpc + 12) % 12));

    final notes = <int>[bottom];
    int prev = bottom;
    for (final p in altre) {
      int cand = prev + 1;
      while (cand % 12 != p) {
        cand++;
      }
      notes.add(cand);
      prev = cand;
    }

    final span = notes.last - notes.first;
    if (span > 12) continue; // resta entro l'ottava (posizione chiusa)
    if (notes.last > kHigh) continue;

    result.add(notes);
  }

  return result;
}

// ---------------------------------------------------------------------------
// Funzioni di costo
// ---------------------------------------------------------------------------

/// Centroide (media dei MIDI) di un voicing.
double centroid(List<int> v) {
  if (v.isEmpty) return 0;
  var sum = 0;
  for (final n in v) {
    sum += n;
  }
  return sum / v.length;
}

/// Penalità per allontanarsi dal centro comodo della mano ([kTarget]).
double pen(List<int> v) => (centroid(v) - kTarget).abs() * 0.4;

/// Costo di transizione tra due voicing: somma degli spostamenti voce per voce,
/// più una penalità se cambia il numero di voci.
double trans(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  var cost = 0.0;
  for (int i = 0; i < n; i++) {
    cost += (a[i] - b[i]).abs();
  }
  cost += (a.length - b.length).abs() * 2.5;
  return cost;
}

// --- Metrica per la bottoniera cromatica (sistema C / do-griff) ---
//
// Sul pianoforte la distanza fisica è proporzionale ai semitoni; sulla
// bottoniera no. Modelliamo la posizione di ogni nota sulla griglia a bottoni:
// la fila è `midi % 3` (asse x, 3 file), e lungo ogni fila i bottoni salgono
// per terze minori, quindi la posizione verticale è `midi / 3` (asse y). Così
// una terza minore = un bottone, un'ottava = 4 bottoni sulla stessa fila, e le
// quinte/terze cadono molto vicine — come sullo strumento reale.

double _btnDistance(int a, int b) {
  final dx = (a % 3) - (b % 3); // fila
  final dy = (a / 3.0) - (b / 3.0); // posizione lungo la fila
  return _sqrt(dx * dx + dy * dy);
}

double _sqrt(double x) {
  // Newton, sufficiente e senza import extra in questo file.
  if (x <= 0) return 0;
  var g = x;
  for (int i = 0; i < 20; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}

/// Costo di transizione sulla **bottoniera**: somma delle distanze fisiche
/// bottone-per-bottone, più la penalità per il cambio di numero di voci.
double transButtons(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  var cost = 0.0;
  for (int i = 0; i < n; i++) {
    cost += _btnDistance(a[i], b[i]);
  }
  cost += (a.length - b.length).abs() * 2.0;
  return cost;
}

/// Firma di una funzione di costo di transizione tra due voicing.
typedef TransFn = double Function(List<int> a, List<int> b);

// ---------------------------------------------------------------------------
// Ottimizzatore ciclico (programmazione dinamica)
// ---------------------------------------------------------------------------

/// Sceglie per ogni accordo il voicing che minimizza lo spostamento totale
/// della mano, **incluso il rientro ultimo→primo** (il giro è un ciclo).
///
/// Con [buttons] = true usa la metrica della bottoniera cromatica invece di
/// quella del pianoforte (semitoni).
///
/// [locks] vincola alcuni accordi a un voicing preciso (indice accordo →
/// voicing): quelli restano fissi e l'ottimizzatore lavora sugli altri.
List<List<int>> optimize(
  List<Chord> chords, {
  bool buttons = false,
  Map<int, List<int>>? locks,
}) {
  final tr = buttons ? transButtons : trans;
  final cands = chords.map(candidates).toList();
  // Applica i vincoli: il voicing bloccato diventa l'unico candidato.
  if (locks != null) {
    locks.forEach((k, v) {
      if (k >= 0 && k < cands.length && v.isNotEmpty) cands[k] = [v];
    });
  }
  final n = chords.length;
  if (n == 0) return [];
  if (n == 1) {
    // Singolo accordo: scegliamo il voicing più centrato.
    return [_openDp(cands, tr).first];
  }
  if (n < 2) return _openDp(cands, tr);

  double best = double.infinity;
  List<List<int>>? bestSeq;

  // Proviamo a fissare ogni possibile voicing di partenza del 1º accordo.
  for (int s = 0; s < cands[0].length; s++) {
    // dp[k][i] = costo minimo per arrivare al candidato i dell'accordo k.
    final dp = List.generate(n, (k) => List<double>.filled(cands[k].length, double.infinity));
    // parent[k][i] = indice del candidato scelto al livello k-1.
    final parent = List.generate(n, (k) => List<int>.filled(cands[k].length, -1));

    for (int i = 0; i < cands[0].length; i++) {
      dp[0][i] = (i == s) ? pen(cands[0][i]) : double.infinity;
    }

    for (int k = 1; k < n; k++) {
      for (int j = 0; j < cands[k].length; j++) {
        double bestPrev = double.infinity;
        int bestI = -1;
        for (int i = 0; i < cands[k - 1].length; i++) {
          if (dp[k - 1][i] == double.infinity) continue;
          final cost = dp[k - 1][i] + tr(cands[k - 1][i], cands[k][j]);
          if (cost < bestPrev) {
            bestPrev = cost;
            bestI = i;
          }
        }
        dp[k][j] = bestPrev + pen(cands[k][j]) * 0.18;
        parent[k][j] = bestI;
      }
    }

    // Chiudiamo il giro: rientro dall'ultimo accordo al voicing di partenza.
    for (int i = 0; i < cands[n - 1].length; i++) {
      if (dp[n - 1][i] == double.infinity) continue;
      final total = dp[n - 1][i] + tr(cands[n - 1][i], cands[0][s]);
      if (total < best) {
        best = total;
        // Backtracking per ricostruire la sequenza.
        final seq = List<List<int>>.filled(n, const []);
        int cur = i;
        for (int k = n - 1; k >= 0; k--) {
          seq[k] = cands[k][cur];
          if (k > 0) cur = parent[k][cur];
        }
        bestSeq = seq;
      }
    }
  }

  return bestSeq ?? _openDp(cands, tr);
}

/// DP aperta (senza termine di chiusura ciclica): minimizza lo spostamento
/// scegliendo alla fine il minimo sull'ultimo livello.
List<List<int>> _openDp(List<List<List<int>>> cands, TransFn tr) {
  final n = cands.length;
  if (n == 0) return [];

  final dp = List.generate(n, (k) => List<double>.filled(cands[k].length, double.infinity));
  final parent = List.generate(n, (k) => List<int>.filled(cands[k].length, -1));

  for (int i = 0; i < cands[0].length; i++) {
    dp[0][i] = pen(cands[0][i]);
  }

  for (int k = 1; k < n; k++) {
    for (int j = 0; j < cands[k].length; j++) {
      double bestPrev = double.infinity;
      int bestI = -1;
      for (int i = 0; i < cands[k - 1].length; i++) {
        if (dp[k - 1][i] == double.infinity) continue;
        final cost = dp[k - 1][i] + tr(cands[k - 1][i], cands[k][j]);
        if (cost < bestPrev) {
          bestPrev = cost;
          bestI = i;
        }
      }
      dp[k][j] = bestPrev + pen(cands[k][j]) * 0.18;
      parent[k][j] = bestI;
    }
  }

  // Minimo sull'ultimo livello.
  double best = double.infinity;
  int bestI = 0;
  for (int i = 0; i < cands[n - 1].length; i++) {
    if (dp[n - 1][i] < best) {
      best = dp[n - 1][i];
      bestI = i;
    }
  }

  final seq = List<List<int>>.filled(n, const []);
  int cur = bestI;
  for (int k = n - 1; k >= 0; k--) {
    seq[k] = cands[k][cur];
    if (k > 0) cur = parent[k][cur];
  }
  return seq;
}

// ---------------------------------------------------------------------------
// Nome del rivolto e diteggiatura
// ---------------------------------------------------------------------------

/// Nome del rivolto dato l'accordo e il voicing scelto.
///
/// Trova in `chord.intervals` l'indice dell'intervallo la cui pitch class
/// coincide con quella del basso del voicing, e lo usa come indice in
/// [invNames] (0 = fondamentale, 1 = 1º rivolto, …).
String invName(Chord chord, List<int> voicing) {
  final bassPc = voicing.first % 12;
  for (int i = 0; i < chord.intervals.length; i++) {
    if ((chord.root + chord.intervals[i]) % 12 == bassPc) {
      return i < invNames.length ? invNames[i] : '$iº rivolto';
    }
  }
  return invNames.first;
}

/// Diteggiatura per un voicing di [n] note.
///
/// 2→`[1,5]`, 3→`[1,3,5]`, 4→`[1,2,3,5]`, altrimenti `[1,2,3,4,5]`.
/// Il dito all'indice k è assegnato alla k-esima nota dal basso
/// (1 = pollice … 5 = mignolo).
List<int> fingersFor(int n) {
  switch (n) {
    case 2:
      return const [1, 5];
    case 3:
      return const [1, 3, 5];
    case 4:
      return const [1, 2, 3, 5];
    default:
      return const [1, 2, 3, 4, 5];
  }
}

/// Glifi cerchiati per i numeri delle dita (1..5 → ①..⑤).
const List<String> circledDigits = ['', '①', '②', '③', '④', '⑤'];

/// Restituisce il glifo cerchiato per il dito [finger] (1..5).
String circledFinger(int finger) =>
    (finger >= 1 && finger <= 5) ? circledDigits[finger] : '$finger';
