import 'package:flutter_test/flutter_test.dart';
import 'package:chord_flow/data/song_library.dart';

void main() {
  test('backup/ripristino conserva anche le scelte bloccate', () {
    const song = Song('Oh chuva', 'Dm A# A7 Dm', locks: {
      0: [62, 65, 69],
      3: [62, 65, 69],
    });
    final json = SongLibrary.exportJson([song]);
    final back = SongLibrary.parseImport(json);
    expect(back.single.name, 'Oh chuva');
    expect(back.single.chords, 'Dm A# A7 Dm');
    expect(back.single.locks[0], [62, 65, 69]);
    expect(back.single.locks[3], [62, 65, 69]);
  });

  test('i backup vecchi senza scelte si importano comunque', () {
    final back = SongLibrary.parseImport(
        '{"songs":[{"name":"Giro","chords":"C G Am F"}]}');
    expect(back.single.locks, isEmpty);
  });
}
