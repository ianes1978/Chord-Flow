import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Riproduzione audio su **web** tramite la Web Audio API del browser.
///
/// Serve perché `flutter_soloud`, su web, richiede SharedArrayBuffer (header
/// COOP/COEP che GitHub Pages non invia): qui riproduciamo direttamente il WAV
/// generato, senza dipendere da quello.
web.AudioContext? _ctx;

void initWeb() {
  _ctx ??= web.AudioContext();
}

void playWavWeb(Uint8List bytes) {
  final ctx = (_ctx ??= web.AudioContext());
  // L'AudioContext parte "suspended": va ripreso dopo un gesto utente (il tap
  // che innesca la riproduzione lo è).
  ctx.resume();
  final arrayBuffer = bytes.buffer.toJS;
  () async {
    try {
      final decoded = await ctx.decodeAudioData(arrayBuffer).toDart;
      final src = ctx.createBufferSource();
      src.buffer = decoded;
      src.connect(ctx.destination);
      src.start();
    } catch (_) {
      // Audio non disponibile: resta in silenzio.
    }
  }();
}
