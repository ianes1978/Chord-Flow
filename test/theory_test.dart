import 'package:flutter_test/flutter_test.dart';
import 'package:chord_flow/music/theory.dart';
import 'package:chord_flow/music/arranger.dart';
import 'package:chord_flow/music/voicing.dart';

void main() {
  group('parseChord', () {
    test('triade maggiore senza qualità', () {
      final r = parseChord('D');
      expect(r.isValid, isTrue);
      expect(r.chord!.root, 2); // D
      expect(r.chord!.intervals, [0, 4, 7]);
    });

    test('minore', () {
      final r = parseChord('Bm');
      expect(r.isValid, isTrue);
      expect(r.chord!.root, 11); // B
      expect(r.chord!.intervals, [0, 3, 7]);
    });

    test('diesis e bemolle', () {
      expect(parseChord('F#m').chord!.root, 6); // F#
      expect(parseChord('Bb').chord!.root, 10); // Bb
      expect(parseChord('C♯').chord!.root, 1);
      expect(parseChord('D♭').chord!.root, 1);
    });

    test('settime e varianti', () {
      expect(parseChord('Dmaj7').chord!.intervals, [0, 4, 7, 11]);
      expect(parseChord('G7').chord!.intervals, [0, 4, 7, 10]);
      expect(parseChord('Am7').chord!.intervals, [0, 3, 7, 10]);
      expect(parseChord('Bdim').chord!.intervals, [0, 3, 6]);
      expect(parseChord('Csus4').chord!.intervals, [0, 5, 7]);
      expect(parseChord('Cø').chord!.intervals, [0, 3, 6, 10]);
    });

    test('sigla non valida', () {
      expect(parseChord('Hxyz').isValid, isFalse);
      expect(parseChord('').isValid, isFalse);
      expect(parseChord('Dwobble').isValid, isFalse);
    });
  });

  group('candidates', () {
    test('span ≤ 12 e basso = nota dell\'accordo', () {
      final c = parseChord('D').chord!;
      final cands = candidates(c);
      expect(cands, isNotEmpty);
      final pcs = c.pitchClasses.toSet();
      for (final v in cands) {
        // posizione chiusa
        expect(v.last - v.first, lessThanOrEqualTo(12));
        // basso è una nota dell'accordo
        expect(pcs.contains(v.first % 12), isTrue);
        // tutte le note sono note dell'accordo e dentro il range alto
        expect(v.last, lessThanOrEqualTo(kHigh));
        for (final n in v) {
          expect(pcs.contains(n % 12), isTrue);
        }
        // ordinate in salita
        for (int i = 1; i < v.length; i++) {
          expect(v[i], greaterThan(v[i - 1]));
        }
      }
    });

    test('accordo a quattro voci', () {
      final c = parseChord('Dmaj7').chord!;
      final cands = candidates(c);
      expect(cands, isNotEmpty);
      for (final v in cands) {
        expect(v.length, 4);
        expect(v.last - v.first, lessThanOrEqualTo(12));
      }
    });
  });

  group('optimize / arrange — giro D A Bm G come ciclo', () {
    late List<VoicedChord> arr;

    setUp(() {
      final chords = parseProgression('D A Bm G')
          .map((r) => r.chord!)
          .toList();
      arr = arrange(chords);
    });

    String notesIt(VoicedChord vc) => vc.voices
        .map((v) => '${circledFinger(v.finger)}${noteNamesIt[v.midi % 12]}')
        .join(' ');

    test('1 · D fondamentale ①Re ③Fa♯ ⑤La', () {
      final d = arr[0];
      expect(d.symbol, 'D');
      expect(d.inversionName, 'fondamentale');
      expect(notesIt(d), '①Re ③Fa♯ ⑤La');
    });

    test('2 · A 1º rivolto ①Do♯ ③Mi ⑤La', () {
      final a = arr[1];
      expect(a.inversionName, '1º rivolto');
      expect(notesIt(a), '①Do♯ ③Mi ⑤La');
    });

    test('3 · Bm 1º rivolto ①Re ③Fa♯ ⑤Si', () {
      final bm = arr[2];
      expect(bm.inversionName, '1º rivolto');
      expect(notesIt(bm), '①Re ③Fa♯ ⑤Si');
    });

    test('4 · G 2º rivolto ①Re ③Sol ⑤Si', () {
      final g = arr[3];
      expect(g.inversionName, '2º rivolto');
      expect(notesIt(g), '①Re ③Sol ⑤Si');
    });

    test('stato dita ciclico del 1º accordo (↻ da G): ① ferma, ③−1, ⑤−2', () {
      final d = arr[0];
      expect(d.isFirst, isTrue);
      expect(d.prevSymbol, 'G');
      expect(d.voices[0].isStay, isTrue); // ① ferma
      expect(d.voices[1].motion, FingerMotion.move);
      expect(d.voices[1].delta, -1); // ③−1
      expect(d.voices[2].motion, FingerMotion.move);
      expect(d.voices[2].delta, -2); // ⑤−2
    });

    test('A: ⑤ ferma sul La; ①−1, ③−2', () {
      final a = arr[1];
      expect(a.voices[2].isStay, isTrue); // ⑤ ferma
      expect(a.voices[0].delta, -1);
      expect(a.voices[1].delta, -2);
    });

    test('Bm: ①+1, ③+2, ⑤+2', () {
      final bm = arr[2];
      expect(bm.voices[0].delta, 1);
      expect(bm.voices[1].delta, 2);
      expect(bm.voices[2].delta, 2);
    });

    test('G: ① e ⑤ ferme; ③+1', () {
      final g = arr[3];
      expect(g.voices[0].isStay, isTrue);
      expect(g.voices[2].isStay, isTrue);
      expect(g.voices[1].delta, 1);
    });
  });

  group('optimize bottoniera — metrica fisarmonica', () {
    test('produce voicing validi (basso = nota accordo, span ≤ 12)', () {
      final chords =
          parseProgression('D A Bm G').map((r) => r.chord!).toList();
      final vs = optimize(chords, buttons: true);
      expect(vs.length, 4);
      for (int i = 0; i < chords.length; i++) {
        final v = vs[i];
        final pcs = chords[i].pitchClasses.toSet();
        expect(pcs.contains(v.first % 12), isTrue);
        expect(v.last - v.first, lessThanOrEqualTo(12));
        for (final n in v) {
          expect(pcs.contains(n % 12), isTrue);
        }
      }
    });

    test('arrange con buttons:true resta coerente e ciclico', () {
      final chords =
          parseProgression('Dmaj7 G7 C').map((r) => r.chord!).toList();
      final arr = arrange(chords, buttons: true);
      expect(arr.length, 3);
      expect(arr.first.isFirst, isTrue);
      expect(arr.first.prevSymbol, 'C'); // confronto ciclico con l'ultimo
    });
  });

  group('fingersFor', () {
    test('mappa il numero di voci alle dita', () {
      expect(fingersFor(2), [1, 5]);
      expect(fingersFor(3), [1, 3, 5]);
      expect(fingersFor(4), [1, 2, 3, 5]);
      expect(fingersFor(5), [1, 2, 3, 4, 5]);
    });
  });
}
