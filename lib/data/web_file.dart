import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Export/import di file su **web** (download e selezione file).
bool get fileSupported => true;

/// Scarica [text] come file [filename].
void downloadText(String filename, String text) {
  final bytes = Uint8List.fromList(utf8.encode(text));
  final parts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

/// Apre un selettore file e restituisce il testo del file scelto (o null).
Future<String?> pickTextFile() {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';
  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      final res = reader.result;
      completer.complete(res.isA<JSString>() ? (res as JSString).toDart : null);
    }).toJS;
    reader.onerror = ((web.Event _) => completer.complete(null)).toJS;
    reader.readAsText(files.item(0)!);
  }).toJS;
  input.click();
  return completer.future;
}
