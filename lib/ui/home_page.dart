import 'package:flutter/material.dart';

import '../audio/synth.dart';
import '../models/chord.dart';
import '../music/arranger.dart';
import '../music/theory.dart';
import '../music/voicing.dart';
import 'chord_card.dart';
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
