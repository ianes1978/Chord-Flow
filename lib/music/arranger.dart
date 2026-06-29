import '../models/chord.dart';
import 'theory.dart';
import 'voicing.dart';

/// Trasforma un giro di accordi in una lista di [VoicedChord] pronti per la UI:
/// sceglie i voicing con l'ottimizzatore ciclico, assegna la diteggiatura e
/// calcola lo stato di ogni dito confrontando ogni accordo col precedente nel
/// ciclo (il primo si confronta con l'ultimo).
List<VoicedChord> arrange(List<Chord> chords) {
  if (chords.isEmpty) return [];

  final voicings = optimize(chords);
  final n = chords.length;
  final result = <VoicedChord>[];

  for (int i = 0; i < n; i++) {
    final chord = chords[i];
    final v = voicings[i];
    final fingers = fingersFor(v.length);

    // Confronto ciclico: il precedente del primo accordo è l'ultimo del giro.
    final prevIndex = i > 0 ? i - 1 : n - 1;
    final prev = voicings[prevIndex];

    final voices = <VoiceState>[];
    for (int k = 0; k < v.length; k++) {
      final hasPrev = k < prev.length;
      final isStay = hasPrev && prev[k] == v[k];
      final delta = hasPrev ? v[k] - prev[k] : 0;
      voices.add(VoiceState(
        midi: v[k],
        finger: k < fingers.length ? fingers[k] : fingers.last,
        motion: isStay ? FingerMotion.stay : FingerMotion.move,
        delta: isStay ? 0 : delta,
      ));
    }

    result.add(VoicedChord(
      symbol: chord.symbol,
      inversionName: invName(chord, v),
      notes: v,
      voices: voices,
      prevSymbol: chords[prevIndex].symbol,
      isFirst: i == 0,
    ));
  }

  return result;
}
