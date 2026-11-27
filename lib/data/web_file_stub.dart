import 'dart:async';

/// Stub non-web: su mobile/desktop l'export/import avviene via copia/incolla.
bool get fileSupported => false;

void downloadText(String filename, String text) {}

Future<String?> pickTextFile() async => null;
