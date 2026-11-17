// Pulso · Salud cardiovascular and Tendencia (8 semanas).
//
// Both screens only READ series the app already stores (metric_series via
// getChart) and compute in lib/compute/pulso. Anything missing is "—" with the
// reason; nothing is filled in. Strings are Spanish for now (Pulso fork).
import 'package:flutter/material.dart';

import '../../compute/pulso/cardio_score.dart';
import '../../data/local_repository.dart';
import '../ui2.dart';
import 'home_screen.dart' show repoOf, hm;
import 'metric_detail.dart' show detailScaffold;

/// Every point of one stored series, oldest first.
Future<List<Reading>> _series(LocalRepository repo, String metric) async {
  final res = await repo.getChart(metric);
  final pts = (res['points'] as List?) ?? const [];
  return [
    for (final e in pts)
      if (e is Map && e['t'] is num && e['v'] is num)
        (t: (e['t'] as num).toInt(), v: (e['v'] as num).toDouble()),
  ]..sort((a, b) => a.t.compareTo(b.t));
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

// ── shared pieces ────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String value;
  final String? pill;
  final bool big;

  /// +1 good news (lime), -1 bad news (coral wash), 0 neutral.
  final int tone;
  const _Hero(this.value, {this.pill, this.big = true, this.tone = 1});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: big
                  ? F.hero.copyWith(color: p.ink)
                  : F.heroWord.copyWith(color: p.ink)),
        ),
      ),
      if (pill != null) ...[
        const SizedBox(width: S.x2),
        Padding(
          padding: const EdgeInsets.only(top: S.x2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: S.x2 + 1, vertical: S.x1),
            decoration: BoxDecoration(
                color: switch (tone) {
                  1 => p.hi,
                  -1 => p.wash(C.coral),
                  _ => p.card2,
                },
                borderRadius: R.rPill),
            child: Text(pill!,
                style: F.cap.copyWith(
                    color: switch (tone) {
                      1 => p.onHi,
                      -1 => p.on(C.coral),
                      _ => p.ink,
                    },
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ]);
  }
}

/// A 0–100 bar in its quality colour, with a soft glow.
class _QualityBar extends StatelessWidget {
  final double? score;
  const _QualityBar(this.score);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = score;
    final col = s == null ? p.track : p.qualityOf(s / 100);
    return Container(
      height: 6,
      decoration: BoxDecoration(color: p.card2, borderRadius: R.rPill),
      alignment: Alignment.centerLeft,
      child: s == null
          ? null
          : FractionallySizedBox(
              widthFactor: (s / 100).clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: R.rPill,
                  boxShadow: [
                    BoxShadow(color: col.withValues(alpha: p.glow), blurRadius: 6),
                  ],
                ),
              ),
            ),
    );
  }
}

Widget _over(BuildContext c, String s) =>
    Text(s.toUpperCase(), style: F.over.copyWith(color: P.of(c).ink3));

Widget _say(BuildContext c, String s) =>
    Text(s, style: F.body.copyWith(color: P.of(c).ink));

Widget _note(BuildContext c, String s) =>
    Text(s, style: F.cap.copyWith(color: P.of(c).ink3));

// ── Salud cardiovascular ─────────────────────────────────────────────────────

const _cardioName = {
  'rhr': 'Pulso en reposo',
  'rmssd': 'HRV nocturna',
  'rhr_consistency': 'Consistencia del pulso',
  'dip_pct': 'Caída nocturna',
  'hrr_bpm': 'Recuperación tras esfuerzo',
};

String _cardioValue(CardioPart part) {
  final v = part.value;
  if (v == null) return '—';
  return switch (part.key) {
    'rhr' => '${v.round()} lpm',
    'rmssd' => '${v.round()} ms',
    'rhr_consistency' => '±${v.toStringAsFixed(v < 10 ? 1 : 0)} lpm',
    'dip_pct' => '${v.round()} %',
    'hrr_bpm' => '${v.round()} lpm',
    _ => v.toStringAsFixed(0),
  };
}

String _cardioWhyAbsent(CardioPart part) => part.key == 'hrr_bpm'
    ? 'Sin entrenamientos en los últimos 14 días.'
    : 'Pocas noches medidas (${part.n} de 4).';

class CardioScreen extends StatefulWidget {
  /// Handed series (tests, gallery) instead of reading the repository.
  final Map<String, List<Reading>>? series;
  final DateTime? today;
  const CardioScreen({super.key, this.series, this.today});

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> {
  Map<String, List<Reading>>? _s;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _s = widget.series;
    if (_s == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) {
      setState(() => _s = const {});
      return;
    }
    try {
      final s = {
        'rhr': await _series(repo, 'resting_hr'),
        'rmssd': await _series(repo, 'hrv'),
        'dip_pct': await _series(repo, 'dip_pct'),
        'hrr_bpm': await _series(repo, 'hrr_bpm'),
      };
      if (mounted) setState(() => _s = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = _s;
    if (s == null) {
      return detailScaffold(c, 'Salud cardiovascular', [
        if (_failed)
          Padding(
              padding: const EdgeInsets.only(top: S.x6),
              child: _note(c, 'No se pudieron leer tus datos. Vuelve a abrir la pantalla.'))
        else
          const Padding(
              padding: EdgeInsets.only(top: S.x8),
              child: Center(child: CircularProgressIndicator())),
      ]);
    }
    final today = widget.today ?? _today();
    final r = cardioScore(s, today);

    // The score each week for 12 weeks, oldest first: the trend line.
    final history = <double>[
      for (var w = 11; w >= 0; w--)
        if (cardioScore(s, DateTime(today.year, today.month, today.day - 7 * w))
                .score
            case final int v)
          v.toDouble(),
    ];

    final dir = r.direction;
    final weakest = r.weakest;
    return detailScaffold(c, 'Salud cardiovascular', [
      const SizedBox(height: S.x2),
      if (r.score case final int score) ...[
        _Hero('$score',
            tone: dir ?? 0,
            pill: switch (dir) {
              1 => 'Mejorando',
              -1 => 'Bajando',
              0 => 'Estable',
              _ => null,
            }),
        const SizedBox(height: S.x3),
        _say(c,
            weakest == null || weakest.score! >= 75
                ? 'Tu corazón trabaja eficiente.'
                : 'Lo que más puede mejorar: ${_cardioName[weakest.key]!.toLowerCase()}.'),
      ] else ...[
        Text('Aprendiendo\ntu corazón', style: F.t1.copyWith(color: p.ink3)),
        const SizedBox(height: S.x3),
        Row(children: [
          for (var i = 0; i < kCardioMinNights; i++) ...[
            if (i > 0) const SizedBox(width: S.x1),
            Container(
              width: 18,
              height: 6,
              decoration: BoxDecoration(
                  color: i < r.nights ? p.ink : p.card2, borderRadius: R.rPill),
            ),
          ],
        ]),
        const SizedBox(height: S.x3),
        _say(c,
            r.nights >= kCardioMinNights
                ? 'Faltan componentes con datos suficientes para dar un puntaje.'
                : '${r.nights} de $kCardioMinNights noches. Duerme con la banda '
                    '${kCardioMinNights - r.nights} más y aparece tu puntaje.'),
      ],
      if (history.length >= 2) ...[
        const SizedBox(height: S.x5),
        _over(c, '12 semanas'),
        const SizedBox(height: S.x2),
        GlowLine(history, quality: (v) => (v - 50) / 40, height: 56),
      ],
      const SizedBox(height: S.x5),
      for (final part in r.parts) ...[
        Row(children: [
          Expanded(
              child: Text(_cardioName[part.key]!,
                  style: F.cap.copyWith(color: p.ink3))),
          Text(_cardioValue(part),
              style: F.cap.copyWith(
                  color: part.value == null ? p.ink3 : p.ink,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: S.x1 + 2),
        _QualityBar(part.score),
        if (part.value == null) ...[
          const SizedBox(height: S.x1),
          _note(c, _cardioWhyAbsent(part)),
        ],
        const SizedBox(height: S.x4),
      ],
      _note(c,
          'Últimas $kCardioWindowDays noches. Cada componente se compara con un '
          'rango de referencia y el puntaje es su promedio. Sin oxígeno en '
          'sangre: la WHOOP 4.0 no lo mide de forma fiable. Orientativo, no es '
          'un diagnóstico.'),
    ]);
  }
}

// ── Tendencia · 8 semanas ───────────────────────────────────────────────────

class _TrendSpec {
  final String metric, name, unit;
  final bool lowerIsBetter;

  /// How much the weekly mean must move to count as a change.
  final double minDelta;
  final double Function(double v) quality;
  final String Function(double v) fmt;
  const _TrendSpec(this.metric, this.name, this.unit, this.lowerIsBetter,
      this.minDelta, this.quality, this.fmt);
}

final _trendSpecs = [
  _TrendSpec('resting_hr', 'Pulso en reposo', 'lpm', true, .5,
      (v) => (70 - v) / 15, (v) => '${v.round()}'),
  _TrendSpec('hrv', 'HRV', 'ms', false, .5, (v) => (v - 35) / 25,
      (v) => '${v.round()}'),
  _TrendSpec('sleep', 'Sueño', '', false, 5, (v) => (v / 60 - 6) / 2,
      (v) => hm(v)),
];

/// Trailing mean over up to [n] readings, one output per input.
List<double> _rolling(List<double> v, int n) => [
      for (var i = 0; i < v.length; i++)
        () {
          final from = i - n + 1 < 0 ? 0 : i - n + 1;
          final w = v.sublist(from, i + 1);
          return w.reduce((a, b) => a + b) / w.length;
        }(),
    ];

class TrendScreen extends StatefulWidget {
  final Map<String, List<Reading>>? series;
  final DateTime? today;
  const TrendScreen({super.key, this.series, this.today});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  Map<String, List<Reading>>? _s;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _s = widget.series;
    if (_s == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) {
      setState(() => _s = const {});
      return;
    }
    try {
      final s = {for (final t in _trendSpecs) t.metric: await _series(repo, t.metric)};
      if (mounted) setState(() => _s = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = _s;
    if (s == null) {
      return detailScaffold(c, 'Tendencia', [
        if (_failed)
          Padding(
              padding: const EdgeInsets.only(top: S.x6),
              child: _note(c, 'No se pudieron leer tus datos. Vuelve a abrir la pantalla.'))
        else
          const Padding(
              padding: EdgeInsets.only(top: S.x8),
              child: Center(child: CircularProgressIndicator())),
      ]);
    }
    final today = widget.today ?? _today();
    int mid(int back) =>
        DateTime(today.year, today.month, today.day - back).millisecondsSinceEpoch ~/ 1000;
    final from = mid(55), firstWeekEnd = mid(48), lastWeekStart = mid(6), to = mid(-1);

    final rows = <Widget>[];
    final good = <String>[], bad = <String>[];
    for (final t in _trendSpecs) {
      final win = [
        for (final r in s[t.metric] ?? const <Reading>[])
          if (r.t >= from && r.t < to) r,
      ];
      final a = [for (final r in win) if (r.t < firstWeekEnd) r.v];
      final b = [for (final r in win) if (r.t >= lastWeekStart) r.v];
      double? mean(List<double> v) =>
          v.length < 3 ? null : v.reduce((x, y) => x + y) / v.length;
      final ma = mean(a), mb = mean(b);
      String delta = '—';
      Color deltaCol = p.ink3;
      if (ma != null && mb != null) {
        final d = mb - ma;
        final better = t.lowerIsBetter ? d < -t.minDelta : d > t.minDelta;
        final worse = t.lowerIsBetter ? d > t.minDelta : d < -t.minDelta;
        if (better) good.add(t.name);
        if (worse) bad.add(t.name);
        delta = '${t.fmt(ma)} → ${t.fmt(mb)}${t.unit.isEmpty ? '' : ' ${t.unit}'}';
        deltaCol = p.on(p.qualityOf(t.quality(mb)));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: S.x3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(t.name, style: F.cap.copyWith(color: p.ink))),
            Text(delta,
                style: F.cap.copyWith(color: deltaCol, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: S.x2),
          if (win.length >= 2)
            // A 7-reading rolling mean: eight weeks is about direction, and
            // night-to-night noise would only zig-zag over it.
            GlowLine(_rolling([for (final r in win) r.v], 7),
                quality: t.quality, height: 46)
          else
            _note(c, 'Todavía no hay suficientes noches para dibujarla.'),
        ]),
      ));
      rows.add(Divider(color: p.line, height: 1));
    }
    if (rows.isNotEmpty) rows.removeLast();

    final headline = good.isEmpty && bad.isEmpty
        ? (s.values.every((v) => v.isEmpty) ? 'Faltan datos' : 'Estable')
        : good.length > bad.length
            ? 'Mejorando'
            : bad.length > good.length
                ? 'Bajando'
                : 'Mixto';
    String list(List<String> v) => v
        .map((x) => x == x.toUpperCase() ? x : x.toLowerCase())
        .join(' y ');
    final sentence = [
      if (good.isNotEmpty) 'Va a mejor: ${list(good)}.',
      if (bad.isNotEmpty) 'Va a peor: ${list(bad)}.',
      if (good.isEmpty && bad.isEmpty)
        'Compara tu primera semana de las últimas 8 con la última.',
    ].join(' ');

    return detailScaffold(c, 'Tendencia', [
      const SizedBox(height: S.x2),
      _over(c, 'Últimas 8 semanas'),
      const SizedBox(height: S.x1),
      _Hero(headline,
          big: false),
      const SizedBox(height: S.x3),
      _say(c, sentence),
      const SizedBox(height: S.x3),
      ...rows,
    ]);
  }
}
