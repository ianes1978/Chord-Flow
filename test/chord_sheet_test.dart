import 'package:flutter_test/flutter_test.dart';
import 'package:chord_flow/data/chord_sheet.dart';

void main() {
  group('parseChordSheet', () {
    test('estrae titolo e accordi, collassa i doppioni consecutivi', () {
      const sheet = '''
{title: oh chuva}

[Dm]Você que tem medo [Am]de chuva[Dm], você não é nem d[Am]e papel
Oh [Dm]chuva, eu [A#]peço que ca[A7]ia dev[Dm]agar
( Dm   A#   A7   Dm   A#   A7 )
{tag: Forro}
''';
      final r = parseChordSheet(sheet);
      expect(r.title, 'oh chuva');
      expect(r.tags, contains('Forro'));
      // Nessun doppione consecutivo.
      for (int i = 1; i < r.chords.length; i++) {
        expect(r.chords[i] == r.chords[i - 1], isFalse);
      }
      // Contiene gli accordi del brano.
      expect(r.chords.toSet(), containsAll(<String>{'Dm', 'Am', 'A#', 'A7'}));
      // Inizia con Dm.
      expect(r.chords.first, 'Dm');
    });

    test('scarta i marcatori non-accordo tra parentesi quadre', () {
      final r = parseChordSheet('[Intro] [C] [Verse] [G]');
      expect(r.chords, ['C', 'G']);
    });
  });
}
