// Pulso · today's Energía, the load split (esfuerzo bueno vs estrés), the
// consejo del día, and Edad del cuerpo.
//
// Read-only over what the app stores; computed by lib/compute/pulso. Missing
// data is said in words. Energía and Edad are estimates and say so.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../compute/pulso/body_age.dart';
import '../../compute/pulso/day_load.dart';
import '../../compute/pulso/focus.dart';
import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../../state/pulso_store.dart';
import '../ui2.dart';
import 'home_screen.dart' show repoOf, hm, go, HomeData;
import 'metric_detail.dart' show detailScaffold;

// ── today's data ────────────────────────────────────────────────────────────

class PulsoDay {
  final double? readiness, rhr, sleepNeedMin, sleepMin;
  final int? age;
  final List<Pt> hr, activity;
  final List<SleepWin> sleep;
  final List<({int start, int end, String name})> workouts;
  final int now;

  const PulsoDay({
    required this.readiness,
    required this.rhr,
    required this.age,
    required this.hr,
    required this.activity,
    required this.sleep,
    required this.workouts,
    required this.now,
    this.sleepNeedMin,
    this.sleepMin,
  });

  /// Tanaka's 208 − 0.7 × age, 190 without an age.
  double get maxHr => age == null ? 190 : 208 - .7 * age!;

  /// Resting HR, or 60 when the night gave none — used ONLY as the zero of
  /// the load scale, never shown as yours.
  double get restZero => rhr ?? 60;

  List<Pt> get energy => energyCurve(
        hr: hr,
        activity: activity,
        rhr: restZero,
        maxHr: maxHr,
        sleep: sleep,
        wakeEnergy: readiness,
        now: now,
      );

  DayLoad get dayLoadOf => dayLoad(
      hr: hr, activity: activity, rhr: restZero, maxHr: maxHr, sleep: sleep);

  double? get base => wakingBase(
        hr: hr,
        moveBy5min: {for (final a in activity) a.t ~/ 300: a.v},
        asleep: (t) => sleep.any((s) => t >= s.onset && t < s.wake),
        rhr: rhr,
      );

  static List<Pt> _pts(Object? raw) => [
        for (final e in (raw as List?) ?? const [])
          if (e is Map && e['t'] is num && e['v'] is num)
            (t: (e['t'] as num).toInt(), v: (e['v'] as num).toDouble()),
      ];

  static Future<PulsoDay> load(LocalRepository repo, {int? now}) async {
    final n = now ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final home = await HomeData.load(repo);
    final profile = await repo.getProfile();
    final tl = await repo.getDayTimeline(todayLabel());
    return PulsoDay(
      readiness: home.readiness.value?.toDouble(),
      rhr: home.rhr.value?.toDouble(),
      sleepMin: home.sleepMin.value?.toDouble(),
      sleepNeedMin: home.sleepNeedMin.value?.toDouble(),
      age: (profile['age'] as num?)?.toInt(),
      hr: _pts(tl['hr']),
      activity: _pts(tl['activity']),
      sleep: [
        for (final s in (tl['sleep'] as List?) ?? const [])
          if (s is Map && s['onset_ts'] is num && s['wake_ts'] is num)
            (onset: (s['onset_ts'] as num).toInt(), wake: (s['wake_ts'] as num).toInt()),
      ],
      workouts: [
        for (final w in (tl['sessions'] as List?) ?? const [])
          if (w is Map && w['start_ts'] is num && w['end_ts'] is num)
            (
              start: (w['start_ts'] as num).toInt(),
              end: (w['end_ts'] as num).toInt(),
              name: (w['title'] ?? w['type'] ?? 'Entreno').toString(),
            ),
      ],
      now: n,
    );
  }
}

String _clock(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t * 1000);
  return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

/// The one-sentence consejo, from today's own numbers.
String consejoDelDia(PulsoDay d) {
  final need = d.sleepNeedMin, slept = d.sleepMin;
  if (need != null && slept != null && need - slept >= 60) {
    return 'Dormiste ${hm(need - slept)} menos de lo que necesitas: hoy toca algo suave y acostarte pronto.';
  }
  final l = d.dayLoadOf;
  if (l.stressMin >= 60) {
    return 'Llevas ${hm(l.stressMin)} de pulso alto sin moverte. Un reseteo de 60 segundos ayuda.';
  }
  final r = d.readiness;
  if (r != null && r >= 75) return 'Recuperaste bien: buen día para entrenar fuerte.';
  if (r != null && r < 40) return 'Recuperación baja: prioriza descansar y dormir pronto esta noche.';
  return 'Acostarte y levantarte a la misma hora es lo que más ayuda a tu recuperación.';
}

// ── shared bits ─────────────────────────────────────────────────────────────

Widget _over(BuildContext c, String s) =>
    Text(s.toUpperCase(), style: F.over.copyWith(color: P.of(c).ink3));
Widget _say(BuildContext c, String s) =>
    Text(s, style: F.body.copyWith(color: P.of(c).ink));
Widget _note(BuildContext c, String s) =>
    Text(s, style: F.cap.copyWith(color: P.of(c).ink3));

Widget _heroNum(BuildContext c, String v, {String? unit}) {
  final p = P.of(c);
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(v, style: F.hero.copyWith(color: p.ink)),
    if (unit != null) ...[
      const SizedBox(width: S.x2),
      Padding(
        padding: const EdgeInsets.only(top: S.x2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
          decoration: BoxDecoration(color: p.card2, borderRadius: R.rPill),
          child: Text(unit, style: F.cap.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
        ),
      ),
    ],
  ]);
}

/// A thin 0–1 bar in one colour, with its glow.
class PulsoBar extends StatelessWidget {
  final double frac;
  final Color color;
  final double height;
  const PulsoBar(this.frac, this.color, {super.key, this.height = 8});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Container(
      height: height,
      decoration: BoxDecoration(color: p.card2, borderRadius: R.rPill),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: frac.clamp(0.02, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: R.rPill,
            boxShadow: [BoxShadow(color: color.withValues(alpha: p.glow), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

Widget _loading(BuildContext c, String title, bool failed) => detailScaffold(c, title, [
      Padding(
        padding: const EdgeInsets.only(top: S.x8),
        child: failed
            ? _note(c, 'No se pudieron leer tus datos. Vuelve a abrir la pantalla.')
            : const Center(child: CircularProgressIndicator()),
      ),
    ]);

/// Loads [PulsoDay] once (or takes it handed in) and builds with it.
class _DayLoader extends StatefulWidget {
  final PulsoDay? data;
  final String title;
  final Widget Function(BuildContext c, PulsoDay d) builder;
  const _DayLoader(this.title, this.builder, {this.data});

  @override
  State<_DayLoader> createState() => _DayLoaderState();
}

class _DayLoaderState extends State<_DayLoader> {
  PulsoDay? _d;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) {
      setState(() => _failed = true);
      return;
    }
    try {
      final d = await PulsoDay.load(repo);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final d = _d;
    return d == null ? _loading(c, widget.title, _failed) : widget.builder(c, d);
  }
}

// ── Hoy: the energy bar, the load link and the consejo ──────────────────────

class PulsoTodayCard extends StatefulWidget {
  final PulsoDay? data;
  const PulsoTodayCard({super.key, this.data});

  @override
  State<PulsoTodayCard> createState() => _PulsoTodayCardState();
}

class _PulsoTodayCardState extends State<PulsoTodayCard> {
  PulsoDay? _d;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (_d == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) return;
    try {
      final d = await PulsoDay.load(repo);
      if (mounted) setState(() => _d = d);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final curve = d.energy;
    final now = curve.isEmpty ? null : curve.last.v;
    final share = d.dayLoadOf.goodShare;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Surface(
        onTap: () => go(c, EnergyScreen(data: d)),
        semanticLabel: now == null ? 'Energía: sin datos' : 'Energía ${now.round()} de 100',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: _over(c, 'Energía')),
            Text(now == null ? '—' : '${now.round()}',
                style: F.head.copyWith(color: p.ink)),
          ]),
          const SizedBox(height: S.x2),
          if (now != null)
            PulsoBar(now / 100, p.qualityOf(now / 100))
          else
            _note(c, 'Aparece cuando la app tenga tu recuperación de hoy.'),
          if (curve.length > 1) ...[
            const SizedBox(height: S.x2),
            Row(children: [
              Expanded(child: _note(c, 'Al despertar ${curve.first.v.round()}')),
              _note(c, '${(now! - curve.first.v).round()} desde las ${_clock(curve.first.t)}'),
            ]),
          ],
        ]),
      ),
      if (share != null) ...[
        const SizedBox(height: S.x2),
        Surface(
          onTap: () => go(c, LoadScreen(data: d)),
          semanticLabel: 'Esfuerzo bueno ${(share * 100).round()} por ciento',
          child: Row(children: [
            Expanded(child: _over(c, 'Esfuerzo bueno')),
            Text('${(share * 100).round()} %',
                style: F.head.copyWith(color: p.on(p.qualityOf(share)))),
          ]),
        ),
      ],
      const SizedBox(height: S.x3),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: S.x1 + 2),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: p.hi,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.hi.withValues(alpha: .4), blurRadius: 6)],
            ),
          ),
        ),
        const SizedBox(width: S.x3),
        Expanded(child: _say(c, consejoDelDia(d))),
      ]),
    ]);
  }
}

// ── Energía ─────────────────────────────────────────────────────────────────

class EnergyScreen extends StatelessWidget {
  final PulsoDay? data;
  const EnergyScreen({super.key, this.data});

  @override
  Widget build(BuildContext c) => _DayLoader('Energía', _build, data: data);

  Widget _build(BuildContext c, PulsoDay d) {
    final p = P.of(c);
    final curve = d.energy;
    if (curve.isEmpty) {
      return detailScaffold(c, 'Energía', [
        const SizedBox(height: S.x4),
        _say(c, 'Todavía no hay energía para hoy.'),
        const SizedBox(height: S.x2),
        _note(c, 'Empieza con tu recuperación al despertar. Aparece cuando la app '
            'haya puntuado tu noche.'),
      ]);
    }
    final now = curve.last.v;
    final events = <({String name, int start, int end})>[
      for (final w in d.workouts) (name: w.name, start: w.start, end: w.end),
      for (final s in PulsoStore.instance.sessions)
        if (s.start >= curve.first.t)
          (
            name: s.kind == FocusKind.trading ? 'Trading' : 'Trabajo',
            start: s.start,
            end: s.end ?? d.now,
          ),
      for (final r in PulsoStore.instance.resets)
        if (r.t >= curve.first.t) (name: 'Reseteo', start: r.t, end: r.t + 60),
    ]..sort((a, b) => a.start.compareTo(b.start));

    return detailScaffold(c, 'Energía', [
      const SizedBox(height: S.x2),
      _heroNum(c, '${now.round()}', unit: 'de 100'),
      const SizedBox(height: S.x3),
      _say(c, now >= 70
          ? 'Tienes energía de sobra para hoy.'
          : now >= 40
              ? 'Te queda para una tarde normal. Evita otra sesión intensa.'
              : 'Vas justo: prioriza descansar.'),
      const SizedBox(height: S.x4),
      GlowLine([for (final x in curve) x.v], quality: (v) => v / 100, height: 120),
      const SizedBox(height: S.x1),
      Row(children: [
        Expanded(child: _note(c, _clock(curve.first.t))),
        _note(c, 'Ahora'),
      ]),
      const SizedBox(height: S.x4),
      _row(c, 'Al despertar · tu recuperación', '${curve.first.v.round()}', p.ink),
      for (final e in events)
        if (energyAt(curve, e.start) case final double a)
          if (energyAt(curve, e.end) case final double b)
            _row(
                c,
                '${e.name} · ${_clock(e.start)}${e.end - e.start > 120 ? ' a ${_clock(e.end)}' : ''}',
                '${b - a >= 0 ? '+' : ''}${(b - a).round()}',
                p.on(p.qualityOf(b - a >= 0 ? 1 : 0))),
      const SizedBox(height: S.x4),
      _note(c, 'Estimación: empieza con tu recuperación y baja con el estrés y el '
          'esfuerzo; sube un poco cuando estás en calma. No es una medida directa.'),
    ]);
  }

  Widget _row(BuildContext c, String k, String v, Color col) {
    final p = P.of(c);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: S.x3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(child: Text(k, style: F.cap.copyWith(color: p.ink))),
        Text(v, style: F.cap.copyWith(color: col, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Esfuerzo bueno vs estrés ────────────────────────────────────────────────

class LoadScreen extends StatelessWidget {
  final PulsoDay? data;
  const LoadScreen({super.key, this.data});

  @override
  Widget build(BuildContext c) => _DayLoader('Carga de hoy', _build, data: data);

  Widget _build(BuildContext c, PulsoDay d) {
    final p = P.of(c);
    final l = d.dayLoadOf;
    final share = l.goodShare;
    final bad = p.qualityOf(0), good = p.qualityOf(1);
    if (share == null) {
      return detailScaffold(c, 'Carga de hoy', [
        const SizedBox(height: S.x4),
        _say(c, 'Todavía no hay minutos con el pulso elevado hoy.'),
        const SizedBox(height: S.x2),
        _note(c, 'Pulso alto moviéndote cuenta como esfuerzo; pulso alto quieto, '
            'como estrés. Se calcula con lo que la banda haya sincronizado.'),
      ]);
    }
    final dayStart = DateTime.fromMillisecondsSinceEpoch(d.now * 1000);
    final start = DateTime(dayStart.year, dayStart.month, dayStart.day)
            .millisecondsSinceEpoch ~/
        1000;
    final end = DateTime(dayStart.year, dayStart.month, dayStart.day + 1)
            .millisecondsSinceEpoch ~/
        1000;
    final runs = [...l.runs]..sort((a, b) => b.minutes.compareTo(a.minutes));
    return detailScaffold(c, 'Carga de hoy', [
      const SizedBox(height: S.x2),
      _heroNum(c, '${(share * 100).round()}', unit: '%'),
      const SizedBox(height: S.x3),
      _say(c, 'fue esfuerzo bueno. El resto, estrés sin moverte.'),
      const SizedBox(height: S.x3),
      ClipRRect(
        borderRadius: R.rPill,
        child: SizedBox(
          height: 14,
          child: Row(children: [
            Expanded(flex: (share * 1000).round(), child: ColoredBox(color: good)),
            const SizedBox(width: 3),
            Expanded(flex: ((1 - share) * 1000).round(), child: ColoredBox(color: bad)),
          ]),
        ),
      ),
      const SizedBox(height: S.x2),
      _legend(c, good, 'Esfuerzo · ${hm(l.effortMin)} · te hace más fuerte'),
      _legend(c, bad, 'Estrés · ${hm(l.stressMin)} · pulso alto sin moverte'),
      const SizedBox(height: S.x5),
      _over(c, 'Tu día'),
      const SizedBox(height: S.x2),
      LayoutBuilder(builder: (c, box) {
        final w = box.maxWidth;
        double x(int t) => (t - start) / (end - start) * w;
        return Container(
          height: 26,
          decoration: BoxDecoration(color: p.card, borderRadius: R.rSm),
          child: Stack(children: [
            for (final r in l.runs)
              Positioned(
                left: x(r.start),
                width: (x(r.end) - x(r.start)).clamp(2.0, w),
                top: 0,
                bottom: 0,
                child: ColoredBox(color: r.stress ? bad : good),
              ),
          ]),
        );
      }),
      const SizedBox(height: S.x1),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final h in const ['0 h', '6', '12', '18', '24 h']) _note(c, h),
      ]),
      const SizedBox(height: S.x4),
      for (final r in runs.take(6))
        Container(
          padding: const EdgeInsets.symmetric(vertical: S.x3),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            Expanded(
                child: Text('${_clock(r.start)} a ${_clock(r.end)} · ${hm(r.minutes)}',
                    style: F.cap.copyWith(color: p.ink))),
            Text(r.stress ? 'estrés' : 'esfuerzo bueno',
                style: F.cap.copyWith(
                    color: p.on(r.stress ? bad : good), fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  Widget _legend(BuildContext c, Color col, String s) => Padding(
        padding: const EdgeInsets.only(top: S.x1),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: col, borderRadius: R.rSm)),
          const SizedBox(width: S.x2),
          Expanded(child: _note(c, s)),
        ]),
      );
}

// ── Edad del cuerpo ─────────────────────────────────────────────────────────

const _ageName = {
  'vo2max': 'VO2max estimado',
  'rhr': 'Pulso en reposo',
  'rmssd': 'HRV',
  'sleep': 'Horas de sueño',
  'regularity': 'Regularidad del sueño',
  'exercise': 'Ejercicio semanal',
  'stress': 'Estrés diario',
};

class BodyAgeScreen extends StatefulWidget {
  final BodyAge? data;
  const BodyAgeScreen({super.key, this.data});

  @override
  State<BodyAgeScreen> createState() => _BodyAgeScreenState();
}

class _BodyAgeScreenState extends State<BodyAgeScreen> {
  BodyAge? _b;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _b = widget.data;
    if (_b == null) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) {
      setState(() => _failed = true);
      return;
    }
    try {
      final b = await loadBodyAge(repo);
      if (mounted) setState(() => _b = b);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final b = _b;
    if (b == null) return _loading(c, 'Edad del cuerpo', _failed);
    final ba = b.bodyAge;
    final factors = [...b.factors]..sort((x, y) => y.years.abs().compareTo(x.years.abs()));
    return detailScaffold(c, 'Edad del cuerpo', [
      const SizedBox(height: S.x2),
      if (ba != null && b.age != null) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ba.round()}', style: F.hero.copyWith(color: p.ink)),
          const SizedBox(width: S.x2),
          Padding(
            padding: const EdgeInsets.only(top: S.x2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
              decoration: BoxDecoration(
                  color: ba <= b.age! ? p.hi : p.wash(C.coral), borderRadius: R.rPill),
              child: Text(
                  '${ba <= b.age! ? '−' : '+'}${(ba - b.age!).abs().toStringAsFixed(1)} años',
                  style: F.cap.copyWith(
                      color: ba <= b.age! ? p.onHi : p.on(C.coral),
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: S.x3),
        _say(c, 'Tienes ${b.age}. Tu cuerpo funciona como el de alguien de ${ba.round()}.'),
        const SizedBox(height: S.x4),
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _over(c, 'Ritmo')),
              Text('${b.pace!.toStringAsFixed(2)} años por año',
                  style: F.cap.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: S.x2),
            PulsoBar(((b.pace! - .5) / 1).clamp(0.0, 1.0),
                p.qualityOf(1 - ((b.pace! - .5) / 1).clamp(0.0, 1.0))),
            const SizedBox(height: S.x1),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _note(c, '0.5'),
              _note(c, '1.0'),
              _note(c, '1.5'),
            ]),
          ]),
        ),
      ] else ...[
        Text('Sin estimación', style: F.t1.copyWith(color: p.ink3)),
        const SizedBox(height: S.x3),
        _say(c, b.age == null
            ? 'Añade tu edad en el perfil para calcularla.'
            : 'Hace falta al menos 3 hábitos con datos de las últimas 4 semanas.'),
      ],
      const SizedBox(height: S.x5),
      _over(c, 'Lo que más mueve tu edad'),
      const SizedBox(height: S.x2),
      if (factors.isEmpty) _note(c, 'Todavía no hay datos suficientes.'),
      for (final f in factors) ...[
        Row(children: [
          Expanded(
              child: Text('${_ageName[f.key]} · ${f.shown}',
                  style: F.cap.copyWith(color: p.ink))),
          Text('${f.years > 0 ? '+' : f.years < 0 ? '−' : ''}${f.years.abs().toStringAsFixed(1)}',
              style: F.cap.copyWith(
                  color: p.on(p.qualityOf(f.years <= 0 ? 1 : 0)),
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: S.x1),
        PulsoBar(f.years.abs() / 3, p.qualityOf(f.years <= 0 ? 1 : 0), height: 5),
        const SizedBox(height: S.x3),
      ],
      const SizedBox(height: S.x2),
      _note(c, 'Estimación con tus últimas 4 semanas, basada en lo que los estudios '
          'relacionan con envejecer mejor. No incluye composición corporal. No es '
          'un diagnóstico.'),
    ]);
  }
}

Future<BodyAge> loadBodyAge(LocalRepository repo) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day - 27).millisecondsSinceEpoch ~/ 1000;
  Future<double?> mean(String metric) async {
    final res = await repo.getChart(metric);
    final v = [
      for (final e in (res['points'] as List?) ?? const [])
        if (e is Map && e['t'] is num && (e['t'] as num) >= from && e['v'] is num)
          (e['v'] as num).toDouble(),
    ];
    return v.length < 4 ? null : v.reduce((a, b) => a + b) / v.length;
  }

  final profile = await repo.getProfile();
  final sessions = await repo.getSessions(
      from: DateTime(now.year, now.month, now.day - 90).millisecondsSinceEpoch ~/ 1000,
      includeDetected: false);
  double? vo2;
  for (final s in sessions) {
    if (s['vo2max_estimate'] case final num v) {
      vo2 = v.toDouble();
      break; // newest first
    }
  }
  final exMin = sessions
      .where((s) => (s['start_ts'] as num?) != null && (s['start_ts'] as num) >= from)
      .fold<double>(0, (a, s) => a + ((s['duration_min'] as num?)?.toDouble() ?? 0));
  final windows = await repo.sleepWindows(days: 28);
  final mids = <double>[
    for (final w in windows)
      if (w['onset_ts'] is num && w['wake_ts'] is num)
        () {
          final mid = ((w['onset_ts'] as num) + (w['wake_ts'] as num)) / 2;
          final d = DateTime.fromMillisecondsSinceEpoch((mid * 1000).round());
          // Hours after 18:00, so a 03:00 midpoint is 9, not 3.
          return ((d.hour + d.minute / 60) - 18 + 24) % 24;
        }(),
  ];
  double? sd;
  if (mids.length >= 7) {
    final m = mids.reduce((a, b) => a + b) / mids.length;
    sd = (mids.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / mids.length);
    sd = sd <= 0 ? 0 : _sqrt(sd);
  }
  final sleepMin = await mean('sleep');
  return bodyAge(
    age: (profile['age'] as num?)?.toInt(),
    rhr: await mean('resting_hr'),
    rmssd: await mean('hrv'),
    vo2max: vo2,
    sleepHours: sleepMin == null ? null : sleepMin / 60,
    sleepMidpointSdHours: sd,
    exerciseMinPerWeek: sessions.isEmpty ? null : exMin / 4,
    stress: await mean('stress'),
  );
}

double _sqrt(double x) {
  var r = x < 1 ? 1.0 : x;
  for (var i = 0; i < 30; i++) {
    r = (r + x / r) / 2;
  }
  return r;
}

/// Health-tab door, with the icon the section uses.
const kBodyAgeIcon = LucideIcons.hourglass;
