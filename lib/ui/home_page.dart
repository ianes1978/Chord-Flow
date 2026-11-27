import 'package:flutter/material.dart';

import '../audio/synth.dart';
import '../models/chord.dart';
import '../music/arranger.dart';
import '../music/rhythm.dart';
import '../music/stradella.dart';
import '../music/theory.dart';
import '../music/voicing.dart';
import 'chord_card.dart';
import 'stradella_painter.dart';
import 'theme.dart';

/// Schermata principale di Chord Flow.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller =
      TextEditingController(text: 'D A Bm G');
  final Synth _synth = Synth();

  List<Chord> _chords = []; // accordi validi del giro corrente
  List<VoicedChord> _voiced = [];
  List<String> _unknown = [];
  final Map<int, List<int>> _locked = {}; // indice accordo → voicing bloccato
  int? _highlighted; // indice della card evidenziata durante la riproduzione
  bool _playing = false;
  bool _useLetters = false; // false = solfeggio (Do Re Mi), true = lettere (A B C)
  bool _compact = false; // true = forza 2 accordi per riga (vista compatta)
  bool _buttons = false; // true = bottoniera fisarmonica, false = pianoforte
  bool _stradella = false; // true = mostra i bassi Stradella (mano sinistra)
  int _rhythm = 0; // indice del ritmo selezionato

  @override
  void initState() {
    super.initState();
    _synth.init();
    _compute(); // calcola subito sul valore iniziale
  }

  @override
  void dispose() {
    _controller.dispose();
    _synth.dispose();
    super.dispose();
  }

  /// Esegue parsing + arrangiamento del giro corrente.
  void _compute() {
    final results = parseProgression(_controller.text);
    final chords = <Chord>[];
    final unknown = <String>[];
    for (final r in results) {
      if (r.isValid) {
        chords.add(r.chord!);
      } else {
        unknown.add(r.raw);
      }
    }
    setState(() {
      _chords = chords;
      _unknown = unknown;
      _locked.clear(); // il giro è cambiato: azzera i vincoli
      _voiced = arrange(chords, buttons: _buttons);
    });
  }

  /// Ricalcola solo i voicing (senza riparsare), usando la metrica adatta al
  /// tipo di tastiera scelto e rispettando gli accordi bloccati.
  void _rearrange() {
    setState(() => _voiced = arrange(_chords,
        buttons: _buttons, locks: _locked.isEmpty ? null : _locked));
  }

  /// Blocca/sblocca l'accordo [i]: da bloccato usa il voicing corrente come
  /// vincolo per l'ottimizzatore.
  void _toggleLock(int i) {
    if (_locked.containsKey(i)) {
      _locked.remove(i);
    } else if (i < _voiced.length) {
      _locked[i] = List<int>.from(_voiced[i].notes);
    }
    _rearrange();
  }

  /// Mostra le varianti (altri voicing) dell'accordo [i] e permette di
  /// sceglierne uno, bloccandolo come vincolo.
  Future<void> _showAlternatives(int i) async {
    if (i >= _chords.length) return;
    final chord = _chords[i];
    // Tutti i candidati in posizione chiusa, ordinati dal più grave.
    final cands = candidates(chord)..sort((a, b) => a.first.compareTo(b.first));
    final current = i < _voiced.length ? _voiced[i].notes : const <int>[];

    final chosen = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppColors.bgBottom,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AlternativesSheet(
        chord: chord,
        candidates: cands,
        current: current,
        useLetters: _useLetters,
      ),
    );

    if (chosen != null) {
      setState(() => _locked[i] = List<int>.from(chosen));
      _rearrange();
    }
  }

  Future<void> _playAll() async {
    if (_playing || _voiced.isEmpty) return;
    setState(() => _playing = true);
    await _synth.playProgression(
      _voiced.map((v) => v.notes).toList(),
      onStep: (i) => setState(() => _highlighted = i),
      onDone: () => setState(() {
        _highlighted = null;
        _playing = false;
      }),
    );
  }

  Future<void> _playOne(int index) async {
    setState(() => _highlighted = index);
    await _synth.playChord(_voiced[index].notes);
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted && !_playing) setState(() => _highlighted = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 660;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 18),
                        _legend(),
                        const SizedBox(height: 12),
                        _toggles(),
                        const SizedBox(height: 18),
                        _inputRow(),
                        if (_unknown.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _unknownBanner(),
                        ],
                        const SizedBox(height: 22),
                        _grid(twoCols),
                        if (_stradella && _chords.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _stradellaPanel(),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOICING & RIVOLTI PER FISARMONICA',
          style: AppText.ui(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.brass.withOpacity(0.9)),
        ),
        const SizedBox(height: 6),
        // Titolo "Chord Flow" con la parola "Flow" in corsivo ottone.
        RichText(
          text: TextSpan(children: [
            TextSpan(text: 'Chord ', style: AppText.display(size: 46)),
            TextSpan(
              text: 'Flow',
              style: AppText.display(
                  size: 46,
                  style: FontStyle.italic,
                  color: AppColors.brass,
                  weight: FontWeight.w600),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          'Inserisci un giro di accordi: l\'app sceglie i rivolti che si '
          'concatenano col minimo spostamento della mano destra. Il giro è un '
          'ciclo — il primo accordo si confronta con l\'ultimo.',
          style: AppText.ui(size: 14, color: const Color(0xCCF2E7D6)),
        ),
      ],
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('①…⑤ = dito (① pollice → ⑤ mignolo)',
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        _legendDot(AppColors.stayGradient, 'dito fermo'),
        _legendDot(AppColors.moveGradient, 'dito in movimento'),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.tune, size: 15, color: Color(0xAAF2E7D6)),
          const SizedBox(width: 4),
          Text('varianti',
              style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
          const SizedBox(width: 12),
          const Icon(Icons.lock, size: 15, color: AppColors.brass),
          const SizedBox(width: 4),
          Text('blocca la scelta',
              style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        ]),
      ],
    );
  }

  /// Riga con gli switch di visualizzazione (vanno a capo se stretti).
  Widget _toggles() {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _notationToggle(),
        _keyboardToggle(),
        _compactToggle(),
        _stradellaToggle(),
      ],
    );
  }

  /// Switch per mostrare i bassi Stradella (mano sinistra) per il giro.
  Widget _stradellaToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bassi Stradella',
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        const SizedBox(width: 4),
        Switch(
          value: _stradella,
          onChanged: (v) => setState(() => _stradella = v),
          activeColor: AppColors.brass,
          activeTrackColor: const Color(0x55C9A24B),
          inactiveThumbColor: AppColors.brass,
          inactiveTrackColor: const Color(0x33C9A24B),
        ),
      ],
    );
  }

  /// Switch per il tipo di tastiera: pianoforte o bottoniera della fisarmonica.
  Widget _keyboardToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tastiera:',
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        const SizedBox(width: 8),
        _notationLabel('Piano', !_buttons),
        Switch(
          value: _buttons,
          onChanged: (v) {
            _buttons = v;
            _rearrange(); // ricalcola i voicing con la metrica giusta
          },
          activeColor: AppColors.brass,
          activeTrackColor: const Color(0x55C9A24B),
          inactiveThumbColor: AppColors.brass,
          inactiveTrackColor: const Color(0x33C9A24B),
        ),
        _notationLabel('Bottoni', _buttons),
      ],
    );
  }

  /// Switch per la vista compatta: forza 2 accordi per riga anche su schermo
  /// stretto.
  Widget _compactToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Compatta · 2 per riga',
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        const SizedBox(width: 4),
        Switch(
          value: _compact,
          onChanged: (v) => setState(() => _compact = v),
          activeColor: AppColors.brass,
          activeTrackColor: const Color(0x55C9A24B),
          inactiveThumbColor: AppColors.brass,
          inactiveTrackColor: const Color(0x33C9A24B),
        ),
      ],
    );
  }

  /// Switch per scegliere la notazione delle note: solfeggio (Do Re Mi) o
  /// lettere (A B C). Il nome degli accordi resta sempre con le lettere.
  Widget _notationToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Note:',
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
        const SizedBox(width: 8),
        _notationLabel('Do Re Mi', !_useLetters),
        Switch(
          value: _useLetters,
          onChanged: (v) => setState(() => _useLetters = v),
          activeColor: AppColors.brass,
          activeTrackColor: const Color(0x55C9A24B),
          inactiveThumbColor: AppColors.brass,
          inactiveTrackColor: const Color(0x33C9A24B),
        ),
        _notationLabel('A B C', _useLetters),
      ],
    );
  }

  Widget _notationLabel(String text, bool active) {
    return Text(
      text,
      style: AppText.ui(
        size: 13,
        weight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? AppColors.brass : const Color(0x88F2E7D6),
      ),
    );
  }

  Widget _legendDot(LinearGradient g, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
              gradient: g, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
      ],
    );
  }

  Widget _inputRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _compute(),
            style: AppText.ui(size: 16, color: AppColors.cream),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x14F2E7D6),
              hintText: 'es. D A Bm G',
              hintStyle:
                  AppText.ui(size: 15, color: const Color(0x66F2E7D6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x33C9A24B)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brass, width: 2),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: _compute,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brass,
            foregroundColor: AppColors.bgBottom,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: Text('Trova i rivolti',
              style: AppText.ui(size: 15, weight: FontWeight.w700)),
        ),
        OutlinedButton(
          onPressed: _playing ? null : _playAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.cream,
            side: const BorderSide(color: Color(0x55C9A24B)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: Text(_playing ? '▶ In riproduzione…' : '▶ Suona',
              style: AppText.ui(size: 15, weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _unknownBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22E2853F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55E2853F)),
      ),
      child: Text(
        'Sigle non riconosciute: ${_unknown.join('  ')}',
        style: AppText.ui(size: 13, color: const Color(0xFFF3D9C2)),
      ),
    );
  }

  /// Pannello dei bassi Stradella: tastiera a pulsanti col giro evidenziato,
  /// più la legenda (basso + fila, con eventuali sostituzioni).
  Widget _stradellaPanel() {
    final hints = _chords.map(stradellaFor).toList();
    final names = _useLetters ? noteNames : noteNamesIt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14F2E7D6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33C9A24B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bassi Stradella · mano sinistra',
              style: AppText.display(size: 20)),
          const SizedBox(height: 2),
          Text(
            'File: 3ª (contrabbasso) · B (basso) · M · m · 7 · ° . '
            'Numero = ordine nel giro; arancio = accordo approssimato.',
            style: AppText.ui(size: 12, color: const Color(0x99F2E7D6)),
          ),
          const SizedBox(height: 12),
          // Board completa FR-1x (12 colonne): scroll orizzontale se stretta.
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth < 560.0 ? 560.0 : c.maxWidth;
              final board = SizedBox(
                height: 180,
                width: w,
                child: CustomPaint(
                  painter: StradellaPainter(hints, useLetters: _useLetters),
                ),
              );
              return c.maxWidth < 560.0
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal, child: board)
                  : board;
            },
          ),
          const SizedBox(height: 14),
          _rhythmSection(),
          const SizedBox(height: 16),
          _accompanimentGuide(hints, rhythms[_rhythm], names),
        ],
      ),
    );
  }

  /// Guida concreta: per ogni accordo del giro, la sequenza reale di pulsanti
  /// (basso e accordo) da premere secondo il ritmo scelto.
  Widget _accompanimentGuide(
      List<StradellaHint> hints, Rhythm r, List<String> names) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Come accompagnare — ${r.name} (${r.meter})',
            style: AppText.display(size: 17)),
        const SizedBox(height: 2),
        Text(
          'Con la sinistra alterni un pulsante basso e un pulsante accordo, a '
          'tempo. Per ogni accordo del giro premi in sequenza:',
          style: AppText.ui(size: 12, color: const Color(0x99F2E7D6)),
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < hints.length; i++)
          _chordAccompRow(i, hints[i], r, names),
      ],
    );
  }

  Widget _chordAccompRow(
      int i, StradellaHint h, Rhythm r, List<String> names) {
    final rowGlyph = stradRowShort[h.row.index]; // M / m / 7 / °
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${i + 1}. ',
                  style: AppText.ui(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.brass)),
              Text(h.symbol,
                  style: AppText.ui(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.cream)),
              if (!h.exact) ...[
                const SizedBox(width: 8),
                Text('≈ approssimato',
                    style: AppText.ui(size: 11, color: AppColors.moveA)),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (int k = 0; k < r.pattern.length; k++) ...[
                if (k > 0)
                  const Icon(Icons.chevron_right,
                      size: 16, color: Color(0x66F2E7D6)),
                _accompChip(r.pattern[k], h, rowGlyph, names),
              ],
            ],
          ),
          if (!h.exact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '(${h.symbol}: ${h.why}'
                '${h.addNotePc >= 0 ? ' — fai ${names[h.addNotePc]} con la destra' : ''})',
                style: AppText.ui(size: 11, color: const Color(0x99F2E7D6)),
              ),
            ),
        ],
      ),
    );
  }

  /// Chip di un singolo colpo della sequenza, con il nome reale del pulsante.
  Widget _accompChip(
      LhHit hit, StradellaHint h, String rowGlyph, List<String> names) {
    late String label;
    late Color bg, fg;
    switch (hit) {
      case LhHit.bass:
        label = '${names[h.rootPc % 12]} (basso)';
        bg = const Color(0x33C9A24B);
        fg = AppColors.brass;
        break;
      case LhHit.counter:
        label = '${names[h.counterBassPc % 12]} (3ª)';
        bg = const Color(0x22C9A24B);
        fg = AppColors.brass;
        break;
      case LhHit.chord:
        label = '${names[h.rootPc % 12]} $rowGlyph';
        bg = const Color(0x33E2853F);
        fg = AppColors.moveA;
        break;
      case LhHit.rest:
        label = '·';
        bg = const Color(0x11F2E7D6);
        fg = const Color(0x66F2E7D6);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33C9A24B)),
      ),
      child: Text(label,
          style: AppText.ui(size: 13, weight: FontWeight.w700, color: fg)),
    );
  }

  /// Selettore di ritmo + striscia del pattern basso/accordo della sinistra.
  Widget _rhythmSection() {
    final r = rhythms[_rhythm];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ritmo mano sinistra:',
                style: AppText.ui(size: 13, color: const Color(0xCCF2E7D6))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0x14F2E7D6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33C9A24B)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _rhythm,
                  dropdownColor: AppColors.bgBottom,
                  isDense: true,
                  style: AppText.ui(size: 14, color: AppColors.cream),
                  items: [
                    for (int i = 0; i < rhythms.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${rhythms[i].name}  ·  ${rhythms[i].meter}'
                          '${rhythms[i].forro ? '  (forró)' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _rhythm = v ?? 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _beatStrip(r),
        const SizedBox(height: 6),
        Text(
          'B = basso · C = contrabbasso (3ª) · A = accordo · · = pausa. '
          'Pattern indicativo: alterna i pulsanti a tempo.',
          style: AppText.ui(size: 11, color: const Color(0x99F2E7D6)),
        ),
      ],
    );
  }

  Widget _beatStrip(Rhythm r) {
    Color bg(LhHit h) {
      switch (h) {
        case LhHit.bass:
          return const Color(0x33C9A24B);
        case LhHit.counter:
          return const Color(0x22C9A24B);
        case LhHit.chord:
          return const Color(0x33E2853F);
        case LhHit.rest:
          return const Color(0x11F2E7D6);
      }
    }

    Color fg(LhHit h) => h == LhHit.chord
        ? AppColors.moveA
        : (h == LhHit.rest ? const Color(0x66F2E7D6) : AppColors.brass);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final h in r.pattern)
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg(h),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33C9A24B)),
            ),
            child: Text(h.glyph,
                style: AppText.ui(
                    size: 15, weight: FontWeight.w700, color: fg(h))),
          ),
      ],
    );
  }

  Widget _grid(bool twoCols) {
    // La vista compatta forza due colonne anche su schermo stretto.
    final two = twoCols || _compact;
    if (_voiced.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('Nessun accordo valido da mostrare.',
            style: AppText.ui(size: 15, color: const Color(0x99F2E7D6))),
      );
    }

    // Card compatte quando lo switch forza due colonne su schermo stretto.
    final cardsCompact = _compact && !twoCols;
    final cards = <Widget>[
      for (int i = 0; i < _voiced.length; i++)
        ChordCard(
          voiced: _voiced[i],
          index: i,
          total: _voiced.length,
          highlighted: _highlighted == i,
          useLetters: _useLetters,
          compact: cardsCompact,
          buttons: _buttons,
          locked: _locked.containsKey(i),
          onTap: () => _playOne(i),
          onToggleLock: () => _toggleLock(i),
          onShowAlternatives: () => _showAlternatives(i),
        ),
    ];

    if (!two) {
      return Column(
        children: [
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ],
      );
    }

    // Due colonne (da ~660px in su, o forzate dalla vista compatta).
    final gap = cardsCompact ? 10.0 : 16.0;
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += 2) {
      final left = cards[i];
      final right = i + 1 < cards.length ? cards[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: gap),
            Expanded(child: right ?? const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Foglio modale con le varianti (voicing) di un accordo. Tappando una riga la
/// si sceglie: viene restituita e bloccata come vincolo dell'ottimizzatore.
class _AlternativesSheet extends StatelessWidget {
  final Chord chord;
  final List<List<int>> candidates;
  final List<int> current;
  final bool useLetters;

  const _AlternativesSheet({
    required this.chord,
    required this.candidates,
    required this.current,
    required this.useLetters,
  });

  bool _sameAs(List<int> v) =>
      v.length == current.length &&
      List.generate(v.length, (i) => v[i] == current[i]).every((x) => x);

  String _fingered(List<int> v) {
    final f = fingersFor(v.length);
    final names = useLetters ? noteNames : noteNamesIt;
    return List.generate(
      v.length,
      (i) => '${circledFinger(i < f.length ? f[i] : f.last)}'
          '${names[v[i] % 12]}',
    ).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0x55F2E7D6),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Varianti per ${chord.symbol}',
                style: AppText.display(size: 22)),
            const SizedBox(height: 2),
            Text('Tocca una variante per bloccarla come vincolo del calcolo.',
                style: AppText.ui(size: 12, color: const Color(0x99F2E7D6))),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final v = candidates[idx];
                  final isCurrent = _sameAs(v);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x14F2E7D6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isCurrent
                                ? AppColors.brass
                                : const Color(0x33C9A24B),
                            width: isCurrent ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x22C9A24B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(invName(chord, v),
                                style: AppText.ui(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: AppColors.brass)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_fingered(v),
                                style: AppText.ui(
                                    size: 15, color: AppColors.cream)),
                          ),
                          if (isCurrent)
                            const Icon(Icons.check_circle,
                                color: AppColors.brass, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
