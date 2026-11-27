import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una canzone salvata nella libreria: nome, giro di accordi (testo grezzo) e
/// le scelte fatte (voicing bloccati per posizione nel giro).
class Song {
  final String name;
  final String chords;

  /// Voicing bloccati: indice accordo nel giro → note MIDI.
  final Map<int, List<int>> locks;

  /// Spostamento globale della zona della mano (frecce ◀ ▶), in semitoni.
  final int shift;

  const Song(this.name, this.chords, {this.locks = const {}, this.shift = 0});

  Map<String, dynamic> toJson() => {
        'name': name,
        'chords': chords,
        if (locks.isNotEmpty)
          'locks': {for (final e in locks.entries) '${e.key}': e.value},
        if (shift != 0) 'shift': shift,
      };

  factory Song.fromJson(Map<String, dynamic> j) {
    final locks = <int, List<int>>{};
    final raw = j['locks'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is List) {
          locks[i] = v.map((e) => (e as num).toInt()).toList();
        }
      });
    }
    final shift = j['shift'];
    return Song('${j['name'] ?? ''}', '${j['chords'] ?? ''}',
        locks: locks, shift: shift is num ? shift.toInt() : 0);
  }
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
