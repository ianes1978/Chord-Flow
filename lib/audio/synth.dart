import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Sintesi audio dal timbro ad ancia.
///
/// Per ogni nota generiamo due oscillatori **sawtooth** leggermente disaccordati
/// (freq e freq×1.004), li passiamo in un **lowpass ~2600 Hz** con inviluppo
/// ADSR morbido, e renderizziamo il tutto in un buffer PCM/WAV riprodotto con
/// `flutter_soloud` (funziona anche su web). Se l'audio non è disponibile,
/// l'app resta perfettamente usabile in silenzio.
class Synth {
  static const int _sampleRate = 44100;
  static const double _duration = 0.9; // secondi
  static const double _attack = 0.02; // 20 ms
  static const double _release = 0.08; // 80 ms
  static const double _sustainGain = 0.16;
  static const double _cutoffHz = 2600;

  bool _available = false;
  bool _initing = false;
  int _counter = 0;

  bool get available => _available;

  /// Inizializza il motore audio. Va chiamata una volta; fallisce con grazia.
  Future<void> init() async {
    if (_available || _initing) return;
    _initing = true;
    try {
      await SoLoud.instance.init();
      _available = true;
    } catch (e) {
      debugPrint('Audio non disponibile: $e');
      _available = false;
    } finally {
      _initing = false;
    }
  }

  /// Frequenza in Hz di una nota MIDI. `mtf(midi) = 440 * 2^((midi-69)/12)`.
  static double mtf(int midi) => 440.0 * math.pow(2, (midi - 69) / 12.0);

  /// Suona un accordo (lista di note MIDI).
  Future<void> playChord(List<int> voicing) async {
    if (!_available || voicing.isEmpty) return;
    try {
      final wav = _renderChordWav(voicing);
      final source = await SoLoud.instance.loadMem('chord_${_counter++}.wav', wav);
      final handle = await SoLoud.instance.play(source);
      // Liberiamo la sorgente quando il suono è finito.
      SoLoud.instance.scheduleStop(
          handle, Duration(milliseconds: (_duration * 1000).round() + 50));
      Future.delayed(
        Duration(milliseconds: (_duration * 1000).round() + 200),
        () => SoLoud.instance.disposeSource(source).catchError((_) {}),
      );
    } catch (e) {
      debugPrint('playChord fallito: $e');
    }
  }

  /// Suona il giro in sequenza (~0.95 s ad accordo), evidenziando la card
  /// corrente via [onStep]; al termine torna al primo per far sentire il ciclo.
  Future<void> playProgression(
    List<List<int>> voicings, {
    required void Function(int index) onStep,
    void Function()? onDone,
  }) async {
    if (voicings.isEmpty) {
      onDone?.call();
      return;
    }
    for (int i = 0; i < voicings.length; i++) {
      onStep(i);
      if (_available) {
        unawaited(playChord(voicings[i]));
      }
      await Future.delayed(const Duration(milliseconds: 950));
    }
    // Chiudiamo tornando al primo accordo per far sentire il ciclo.
    onStep(0);
    if (_available) {
      unawaited(playChord(voicings.first));
    }
    await Future.delayed(const Duration(milliseconds: 600));
    onDone?.call();
  }

  /// Renderizza l'accordo in un buffer WAV (PCM 16-bit mono).
  Uint8List _renderChordWav(List<int> voicing) {
    final total = (_sampleRate * _duration).round();
    final mix = Float64List(total);

    // Stato del lowpass one-pole (RC) e coefficiente.
    const dt = 1.0 / _sampleRate;
    const rc = 1.0 / (2 * math.pi * _cutoffHz);
    const alpha = dt / (rc + dt);

    for (final midi in voicing) {
      final f1 = mtf(midi);
      final f2 = f1 * 1.004; // secondo saw leggermente disaccordato
      var lp = 0.0; // stato del filtro per questa voce
      var ph1 = 0.0;
      var ph2 = 0.0;
      final inc1 = f1 / _sampleRate;
      final inc2 = f2 / _sampleRate;

      for (int n = 0; n < total; n++) {
        // Sawtooth: rampa -1..+1.
        final saw1 = 2.0 * (ph1 - ph1.floorToDouble()) - 1.0;
        final saw2 = 2.0 * (ph2 - ph2.floorToDouble()) - 1.0;
        ph1 += inc1;
        ph2 += inc2;
        var sample = (saw1 + saw2) * 0.5;

        // Lowpass one-pole.
        lp += alpha * (sample - lp);
        sample = lp;

        // Inviluppo ADSR.
        sample *= _envelope(n / _sampleRate);
        mix[n] += sample;
      }
    }

    // Normalizzazione morbida in base al numero di voci.
    final norm = 0.28 / math.max(1, voicing.length);
    final pcm = Int16List(total);
    for (int n = 0; n < total; n++) {
      final s = (mix[n] * norm).clamp(-1.0, 1.0);
      pcm[n] = (s * 32767).round();
    }

    return _wrapWav(pcm);
  }

  /// Inviluppo ADSR morbido: attacco, decay verso il sustain, rilascio finale.
  double _envelope(double t) {
    if (t < _attack) {
      return t / _attack;
    }
    const releaseStart = _duration - _release;
    if (t > releaseStart) {
      final r = (_duration - t) / _release;
      return _sustainGain * r.clamp(0.0, 1.0);
    }
    // Decay esponenziale leggero dall'attacco verso il livello di sustain.
    final decayT = (t - _attack) / (releaseStart - _attack);
    return 1.0 + (_sustainGain - 1.0) * decayT.clamp(0.0, 1.0);
  }

  /// Incapsula i campioni PCM 16-bit in un contenitore WAV mono.
  Uint8List _wrapWav(Int16List pcm) {
    final dataBytes = pcm.buffer.asUint8List();
    const byteRate = _sampleRate * 2; // mono, 16-bit
    final builder = BytesBuilder();

    void writeStr(String s) => builder.add(s.codeUnits);
    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }

    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    writeU32(36 + dataBytes.length);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // dimensione sub-chunk fmt
    writeU16(1); // PCM
    writeU16(1); // canali (mono)
    writeU32(_sampleRate);
    writeU32(byteRate);
    writeU16(2); // block align
    writeU16(16); // bit per campione
    writeStr('data');
    writeU32(dataBytes.length);
    builder.add(dataBytes);

    return builder.toBytes();
  }

  void dispose() {
    if (_available) {
      try {
        SoLoud.instance.deinit();
      } catch (_) {}
    }
  }
}
