import '../music/theory.dart';

/// Risultato del parsing di una cifra (formato ChordPro / CifraClub).
class ParsedSheet {
  final String? title;
  final List<String> tags;

  /// Accordi nell'ordine del brano, senza doppioni consecutivi.
  final List<String> chords;

  const ParsedSheet({this.title, required this.tags, required this.chords});
}

final RegExp _directiveRe = RegExp(
    r'\{\s*(title|t|tag|tags|subtitle|st|artist)\s*:\s*([^}]*)\}',
    caseSensitive: false);
final RegExp _inlineChordRe = RegExp(r'\[([^\]]+)\]');
final RegExp _parenLineRe = RegExp(r'^\((.*)\)$');

/// Interpreta una cifra: estrae titolo, tag e la sequenza di accordi.
///
/// Riconosce gli accordi tra parentesi quadre (`[Dm]`), le righe di soli
/// accordi tra parentesi tonde (`( Dm A# A7 )`) e le direttive `{title:}` /
/// `{tag:}`. Scarta ciò che non è un accordo valido (es. `[Verse]`), e
/// collassa i doppioni consecutivi.
ParsedSheet parseChordSheet(String text) {
  String? title;
  final tags = <String>[];
  for (final m in _directiveRe.allMatches(text)) {
    final key = m.group(1)!.toLowerCase();
    final val = (m.group(2) ?? '').trim();
    if (val.isEmpty) continue;
    if (key == 'title' || key == 't') {
      title = val;
    } else if (key.startsWith('tag')) {
      tags.add(val);
    }
  }

  final raw = <String>[];
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('{')) continue;

    // Riga di soli accordi tra parentesi tonde.
    final paren = _parenLineRe.firstMatch(t);
    if (paren != null) {
      for (final tok in paren.group(1)!.split(RegExp(r'[\s,|]+'))) {
        final c = tok.trim();
        if (c.isNotEmpty && parseChord(c).isValid) raw.add(c);
      }
      continue;
    }

    // Accordi in linea tra parentesi quadre.
    for (final m in _inlineChordRe.allMatches(line)) {
      final c = m.group(1)!.trim();
      if (parseChord(c).isValid) raw.add(c);
    }
  }

  // Collassa i doppioni consecutivi.
  final chords = <String>[];
  for (final c in raw) {
    if (chords.isEmpty || chords.last != c) chords.add(c);
  }

  return ParsedSheet(title: title, tags: tags, chords: chords);
}
