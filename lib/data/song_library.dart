import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una canzone salvata nella libreria: nome + giro di accordi (testo grezzo).
class Song {
  final String name;
  final String chords;

  const Song(this.name, this.chords);

  Map<String, dynamic> toJson() => {'name': name, 'chords': chords};

  factory Song.fromJson(Map<String, dynamic> j) =>
      Song('${j['name'] ?? ''}', '${j['chords'] ?? ''}');
}

/// Libreria di canzoni persistente (localStorage su web, native altrove) con
/// export/import JSON per backup e ripristino.
class SongLibrary {
  static const _key = 'chordflow.songs.v1';

  /// Carica le canzoni salvate.
  static Future<List<Song>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva l'intera lista.
  static Future<void> save(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(songs.map((s) => s.toJson()).toList()));
  }

  /// Aggiunge o sostituisce (per nome) una canzone, poi salva.
  static Future<List<Song>> upsert(List<Song> songs, Song song) async {
    final out = List<Song>.from(songs)
      ..removeWhere((s) => s.name.toLowerCase() == song.name.toLowerCase())
      ..add(song);
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await save(out);
    return out;
  }

  /// Rimuove una canzone per nome, poi salva.
  static Future<List<Song>> remove(List<Song> songs, String name) async {
    final out = List<Song>.from(songs)
      ..removeWhere((s) => s.name.toLowerCase() == name.toLowerCase());
    await save(out);
    return out;
  }

  /// Serializza l'intera libreria (backup) in JSON leggibile.
  static String exportJson(List<Song> songs) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'app': 'Chord Flow',
      'version': 1,
      'songs': songs.map((s) => s.toJson()).toList(),
    });
  }

  /// Interpreta un backup JSON e ne estrae le canzoni (ripristino).
  static List<Song> parseImport(String jsonText) {
    final data = jsonDecode(jsonText);
    final list = (data is Map && data['songs'] is List)
        ? data['songs'] as List
        : (data is List ? data : const []);
    return list
        .whereType<Map>()
        .map((e) => Song.fromJson(e.cast<String, dynamic>()))
        .where((s) => s.chords.trim().isNotEmpty)
        .toList();
  }

  /// Unisce le canzoni importate con quelle esistenti (per nome), poi salva.
  static Future<List<Song>> mergeImport(
      List<Song> existing, List<Song> imported) async {
    final byName = <String, Song>{
      for (final s in existing) s.name.toLowerCase(): s,
    };
    for (final s in imported) {
      byName[s.name.toLowerCase()] = s;
    }
    final out = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await save(out);
    return out;
  }
}
