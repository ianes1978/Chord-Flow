# Chord Flow

**Voicing & rivolti per fisarmonica, con la mano ferma.**

Chord Flow è uno strumento per **Android e web** dedicato ai
fisarmonicisti: inserisci un giro di accordi e l'app propone i **rivolti**
(voicing in posizione chiusa) che si concatenano col **minimo spostamento della
mano destra**, indicando per ogni accordo la **diteggiatura** (① pollice → ⑤
mignolo) e **quali dita si muovono** rispetto all'accordo precedente.

Il giro è trattato come un **ciclo**: il primo accordo si confronta con
l'ultimo, così la mano resta comoda anche quando il giro si ripete.

## Come funziona (logica musicale)

Si lavora con i numeri MIDI (Do centrale C4 = 60); la *pitch class* è
`midi % 12`. Il cuore dell'app è in `lib/music/theory.dart`:

- **`parseChord`** — riconosce la sigla (`D`, `Bm`, `Dmaj7`, `F#m`, `Csus4`, …).
- **`candidates`** — genera tutti i rivolti in posizione chiusa (span ≤ 12) su
  più ottave, col basso vincolato a essere una nota dell'accordo.
- **`optimize`** — programmazione dinamica **ciclica** che minimizza lo
  spostamento totale della mano, *incluso il rientro ultimo → primo*.
- **`invName` / `fingersFor`** — nome del rivolto e diteggiatura.
- **`arrange`** (`lib/music/arranger.dart`) — assembla i `VoicedChord` per la UI
  e calcola lo stato di ogni dito (fermo / in movimento) col confronto ciclico.

L'audio (`lib/audio/synth.dart`) sintetizza un timbro ad ancia: per ogni nota due
oscillatori *sawtooth* leggermente disaccordati, lowpass ~2600 Hz e inviluppo
ADSR morbido, renderizzati in PCM e riprodotti con
[`flutter_soloud`](https://pub.dev/packages/flutter_soloud). Se l'audio non è
disponibile, l'app resta pienamente usabile in silenzio.

## Struttura dei file

```
lib/
  main.dart                 // entry point e MaterialApp
  models/chord.dart         // modello Chord + esito del parsing
  music/theory.dart         // costanti, parse, candidates, optimize, invName, fingersFor
  music/voicing.dart        // tipi di supporto (VoiceState, VoicedChord, FingerMotion)
  music/arranger.dart       // dal giro di accordi ai VoicedChord pronti per la UI
  audio/synth.dart          // sintesi PCM del timbro ad ancia (flutter_soloud)
  ui/theme.dart             // token colore/tipografia
  ui/home_page.dart         // schermata principale
  ui/chord_card.dart        // card del singolo accordo
  ui/keyboard_painter.dart  // tastiera C3–C6 con diteggiatura (CustomPainter)
test/
  theory_test.dart          // test su parseChord, candidates, optimize/arrange
```

## Come lanciarla

Serve [Flutter](https://docs.flutter.dev/get-started/install) (testato con
**3.24.5**, Dart 3.5.4).

```bash
flutter pub get
flutter run                 # device/emulatore collegato
flutter run -d chrome       # nel browser
flutter test                # esegue i test unitari
```

Esempio iniziale: il giro `D A Bm G` (trattato come ciclo) produce
`D` fondamentale, `A` 1º rivolto, `Bm` 1º rivolto, `G` 2º rivolto — con la mano
che resta praticamente ferma a ogni cambio.

## Build & pubblicazione (GitHub Actions)

Nella cartella `.github/workflows/` ci sono due workflow:

- **`pages.yml`** — a ogni push compila la build web e la pubblica su **GitHub
  Pages** col flusso ufficiale (`actions/deploy-pages`), URL
  `https://<utente>.github.io/<repo>/`. Richiede *Settings → Pages → Source:
  **GitHub Actions***.
- **`release-apk.yml`** — spingendo un tag `v*` (es. `v1.0.0`), o lanciandolo a
  mano, compila l'**APK di release** e lo allega a una GitHub Release (oltre a
  caricarlo come artifact del build).

```bash
git tag v1.0.0 && git push origin v1.0.0   # innesca la release APK
```
