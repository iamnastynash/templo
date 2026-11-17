// Pulso · Enfoque: Trabajo and Trading sessions, trade markers, the traffic
// light, the session summary, and Reseteo (band-guided breathing).
//
// The band never buzzes on its own: every session and every reset is started
// by a tap. Sessions are not workouts (no strain, no Apple Health export).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../compute/pulso/day_load.dart' show Pt;
import '../../compute/pulso/focus.dart';
import '../../state/app_state.dart';
import '../../theme/theme_switcher.dart' show themedRoute;
import '../../state/pulso_store.dart';
import '../../stress/breath_phases.dart';
import '../ui2.dart';
import 'home_screen.dart' show repoOf, hm, go;
import 'metric_detail.dart' show detailScaffold;
import 'pulso_day.dart' show PulsoDay, PulsoBar;

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _clock(int t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t * 1000);
  return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

String _dur(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

AppState? _app(BuildContext c) {
  try {
    return Provider.of<AppState>(c, listen: false);
  } catch (_) {
    return null;
  }
}

Widget _over(BuildContext c, String s) =>
    Text(s.toUpperCase(), style: F.over.copyWith(color: P.of(c).ink3));
Widget _say(BuildContext c, String s) =>
    Text(s, style: F.body.copyWith(color: P.of(c).ink));
Widget _note(BuildContext c, String s) =>
    Text(s, style: F.cap.copyWith(color: P.of(c).ink3));

String _kindName(FocusKind k) => k == FocusKind.trading ? 'Trading' : 'Trabajo';

Color _lightColor(P p, Light l) => switch (l) {
      Light.calma => p.qualityOf(1),
      Light.alerta => p.qualityOf(.45),
      Light.acelerado => p.qualityOf(0),
    };

String _lightName(Light l) => switch (l) {
      Light.calma => 'Calma',
      Light.alerta => 'Alerta',
      Light.acelerado => 'Acelerado',
    };

// ── the Enfoque tab ─────────────────────────────────────────────────────────

class FocusTab extends StatelessWidget {
  const FocusTab({super.key});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return ListenableBuilder(
      listenable: PulsoStore.instance,
      builder: (c, _) {
        final store = PulsoStore.instance;
        final active = store.active;
        final now = _nowSec();
        final weekAgo = now - 7 * 24 * 3600;
        final week = [for (final s in store.sessions) if (s.start >= weekAgo) s];
        FocusSession? last(FocusKind k) {
          for (final s in store.sessions.reversed) {
            if (s.kind == k && !s.open) return s;
          }
          return null;
        }

        String lastLine(FocusKind k) {
          final s = last(k);
          if (s == null) return 'Aún no has hecho ninguna.';
          final d = (s.end! - s.start);
          return k == FocusKind.trading
              ? 'Última: ${_clock(s.start)} · ${s.trades.length} trades · ${hm(d / 60)}'
              : 'Última: ${_clock(s.start)} · ${hm(d / 60)}';
        }

        final resetsWeek = [for (final r in store.resets) if (r.t >= weekAgo) r];
        final drops = [for (final r in resetsWeek) if (r.drop != null) r.drop!];
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(S.x4, S.x4, S.x4, S.x16),
            children: [
              Text('Enfoque', style: F.t1.copyWith(color: p.ink, letterSpacing: -1.1)),
              const SizedBox(height: S.x1),
              _note(c, 'Mide cómo te afecta lo que haces, sin contar como ejercicio.'),
              const SizedBox(height: S.x4),
              if (active != null) ...[
                Surface(
                  onTap: () => go(c, FocusLiveScreen(active)),
                  semanticLabel: '${_kindName(active.kind)} en curso',
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: p.on(C.coral), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: S.x3),
                    Expanded(
                        child: Text('${_kindName(active.kind)} en curso · desde ${_clock(active.start)}',
                            style: F.head.copyWith(color: p.ink))),
                    Icon(LucideIcons.chevronRight, size: 18, color: p.ink3),
                  ]),
                ),
                const SizedBox(height: S.x3),
              ],
              _card(c, 'Trabajo', lastLine(FocusKind.trabajo), 'Empezar',
                  active != null ? null : () => _start(c, FocusKind.trabajo)),
              const SizedBox(height: S.x2),
              _card(c, 'Trading', lastLine(FocusKind.trading), 'Empezar',
                  active != null ? null : () => _start(c, FocusKind.trading)),
              const SizedBox(height: S.x2),
              _card(c, 'Reseteo', 'Respiración guiada · inhala 4 s, exhala 6 s', '60 s',
                  () => go(c, const ResetScreen())),
              const SizedBox(height: S.x6),
              _over(c, 'Esta semana'),
              const SizedBox(height: S.x2),
              _weekRow(c, 'Trabajo', _weeklyDuration(week, FocusKind.trabajo)),
              _weekRow(c, 'Trading',
                  _weeklyDuration(week, FocusKind.trading)),
              _weekRow(
                  c,
                  'Reseteos',
                  drops.isEmpty
                      ? '${resetsWeek.length}'
                      : '${resetsWeek.length} · −${(drops.reduce((a, b) => a + b) / drops.length).round()} lpm de media'),
              const SizedBox(height: S.x4),
              if (store.sessions.any((s) => !s.open)) ...[
                _over(c, 'Sesiones'),
                const SizedBox(height: S.x2),
                for (final s in store.sessions.reversed.where((s) => !s.open).take(10))
                  Pressable(
                    onTap: () => go(c, FocusSummaryScreen(s)),
                    semanticLabel: '${_kindName(s.kind)} ${_clock(s.start)}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: S.x3),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${_kindName(s.kind)} · ${_dayShort(s.start)} ${_clock(s.start)}',
                                style: F.cap.copyWith(color: p.ink))),
                        _note(c, hm((s.end! - s.start) / 60)),
                        const SizedBox(width: S.x2),
                        Icon(LucideIcons.chevronRight, size: 16, color: p.ink3),
                      ]),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _weeklyDuration(List<FocusSession> week, FocusKind kind) {
    final sessions = week.where((s) => s.kind == kind && !s.open);
    if (sessions.isEmpty) return '—';
    final duration = sessions.fold<int>(0, (total, s) => total + s.end! - s.start);
    final trades = sessions.fold<int>(0, (total, s) => total + s.trades.length);
    return kind == FocusKind.trading
        ? '${hm(duration / 60)} · $trades trades'
        : hm(duration / 60);
  }

  static String _dayShort(int t) {
    final d = DateTime.fromMillisecondsSinceEpoch(t * 1000);
    return '${d.day}/${d.month}';
  }

  void _start(BuildContext c, FocusKind k) {
    final s = PulsoStore.instance.start(k, _nowSec());
    go(c, FocusLiveScreen(s));
  }

  Widget _card(BuildContext c, String title, String sub, String action, VoidCallback? onTap) {
    final p = P.of(c);
    return Surface(
      onTap: onTap,
      semanticLabel: '$title. $sub. $action',
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: F.head.copyWith(color: p.ink)),
            const SizedBox(height: S.x1),
            _note(c, sub),
          ]),
        ),
        const SizedBox(width: S.x2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
          decoration: BoxDecoration(
            color: onTap == null ? p.card2 : p.hi,
            borderRadius: R.rPill,
          ),
          child: Text(action, style: F.cap.copyWith(
              color: onTap == null ? p.ink3 : p.onHi, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _weekRow(BuildContext c, String k, String v) {
    final p = P.of(c);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: S.x3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(child: Text(k, style: F.cap.copyWith(color: p.ink))),
        Text(v, style: F.cap.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── a running session ───────────────────────────────────────────────────────

class FocusLiveScreen extends StatefulWidget {
  final FocusSession session;
  const FocusLiveScreen(this.session, {super.key});

  @override
  State<FocusLiveScreen> createState() => _FocusLiveScreenState();
}

class _FocusLiveScreenState extends State<FocusLiveScreen> {
  Timer? _tick;
  AppState? _owner;
  double? _base;
  int? _hr;
  final _bucket = <int>[];
  int _bucketStart = _nowSec();

  FocusSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _owner = _app(context)?..retainLiveHrView();
      final repo = repoOf(context);
      if (repo != null) {
        try {
          final d = await PulsoDay.load(repo);
          if (mounted) setState(() => _base = d.base);
        } catch (_) {}
      }
    });
    _tick = Timer.periodic(Motion.tick, (_) => _onTick());
  }

  void _onTick() {
    if (!mounted || !s.open) return;
    final hr = _owner?.liveHr;
    final now = _nowSec();
    if (hr != null) _bucket.add(hr);
    if (now - _bucketStart >= 30) {
      if (_bucket.isNotEmpty) {
        PulsoStore.instance.addSample(
            s, _bucketStart, _bucket.reduce((a, b) => a + b) / _bucket.length);
      }
      _bucket.clear();
      _bucketStart = now;
    }
    setState(() => _hr = hr);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _owner?.releaseLiveHrView();
    super.dispose();
  }

  void _finish() {
    PulsoStore.instance.end(s, _nowSec());
    Navigator.of(context).pushReplacement(
        themedRoute((_) => FocusSummaryScreen(s), name: 'FocusSummaryScreen'));
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final now = _nowSec();
    final hr = _hr, base = _base;
    final light = hr == null || base == null ? null : lightFor(hr.toDouble(), base);
    final open = s.openTrade;
    final lastClosed = s.trades.isEmpty || s.trades.last.end == null ? null : s.trades.last;
    return detailScaffold(
      c,
      _kindName(s.kind),
      sub: 'En curso · ${_dur(now - s.start)}',
      trailing: Pressable(
        onTap: _finish,
        semanticLabel: 'Terminar sesión',
        child: Text('Terminar', style: F.cap.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
      ),
      [
        const SizedBox(height: S.x3),
        _over(c, 'Tu estado ahora'),
        const SizedBox(height: S.x3),
        Row(children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: light == null ? p.card2 : _lightColor(p, light),
              boxShadow: light == null
                  ? null
                  : [BoxShadow(color: _lightColor(p, light).withValues(alpha: p.glow), blurRadius: 18)],
            ),
            child: Text(hr == null ? '—' : '$hr',
                style: F.n34.copyWith(color: light == null ? p.ink3 : C.carbon)),
          ),
          const SizedBox(width: S.x4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(light == null ? 'Sin pulso en vivo' : _lightName(light),
                  style: F.t2.copyWith(color: light == null ? p.ink3 : p.ink)),
              const SizedBox(height: S.x1),
              _note(
                  c,
                  hr == null
                      ? 'Ponte la banda y mantenla conectada.'
                      : base == null
                          ? 'Calculando tu base…'
                          : '${hr - base >= 0 ? '+' : ''}${(hr - base).round()} lpm sobre tu base (${base.round()})'),
              const SizedBox(height: S.x2),
              Row(children: [
                for (final zone in Light.values)
                  Padding(
                    padding: const EdgeInsets.only(right: S.x1),
                    child: Container(width: 22, height: 5, decoration: BoxDecoration(
                      color: zone == light ? _lightColor(p, zone) : p.card2,
                      borderRadius: R.rPill,
                    )),
                  ),
              ]),
            ]),
          ),
        ]),
        if (s.kind == FocusKind.trading) ...[
          const SizedBox(height: S.x6),
          if (open != null) ...[
            Surface(
              child: Row(children: [
                Expanded(child: _over(c, 'En trade #${s.trades.length}')),
                Text(_dur(now - open.start), style: F.head.copyWith(color: p.ink)),
              ]),
            ),
            const SizedBox(height: S.x3),
            BigButton('Salí del trade',
                color: C.carbon,
                onTap: () => setState(() => PulsoStore.instance.closeTrade(s, _nowSec()))),
          ] else ...[
            BigButton('Entré en un trade',
                color: C.carbon,
                onTap: () => setState(() => PulsoStore.instance.openTrade(
                    s, _nowSec(), hr == null || base == null ? null : hr - base))),
            if (lastClosed != null) ...[
              const SizedBox(height: S.x3),
              _note(c, '¿Cómo salió el trade #${s.trades.length}?'),
              const SizedBox(height: S.x2),
              Row(children: [
                Expanded(child: _resultButton(c, lastClosed, 'win', 'Ganada')),
                const SizedBox(width: S.x2),
                Expanded(child: _resultButton(c, lastClosed, 'loss', 'Perdida')),
              ]),
            ],
          ],
          const SizedBox(height: S.x4),
          for (final t in s.trades.reversed.where((t) => t.end != null))
            _tradeRow(c, s.trades.indexOf(t) + 1, t, null),
        ],
        const SizedBox(height: S.x6),
        _note(c, 'La banda no vibra durante la sesión. Al terminar verás tu pulso '
            'en cada momento${s.kind == FocusKind.trading ? ' y en cada trade' : ''}.'),
      ],
    );
  }

  Widget _resultButton(BuildContext c, Trade t, String r, String label) {
    final p = P.of(c);
    final on = t.result == r;
    return Pressable(
      onTap: () => setState(() => PulsoStore.instance.markResult(t, r)),
      semanticLabel: label,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.qualityOf(r == 'win' ? 1 : 0) : p.card,
          borderRadius: R.rPill,
        ),
        child: Text(label,
            style: F.cap.copyWith(color: on ? C.carbon : p.ink, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

Widget _tradeRow(BuildContext c, int n, Trade t, WindowStats? st) {
  final p = P.of(c);
  final res = t.result == 'win'
      ? 'ganada'
      : t.result == 'loss'
          ? 'perdida'
          : 'sin marcar';
  final peak = st?.peak;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: S.x3),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
    child: Row(children: [
      Expanded(
          child: Text('#$n · ${_clock(t.start)} · $res',
              style: F.cap.copyWith(color: p.ink))),
      Text(
          peak == null
              ? (t.end == null ? '' : _dur(t.end! - t.start))
              : 'pico ${peak.round()}',
          style: F.cap.copyWith(
              color: t.result == 'loss' ? p.on(p.qualityOf(0)) : p.ink,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── the summary ─────────────────────────────────────────────────────────────

class FocusSummaryScreen extends StatefulWidget {
  final FocusSession session;

  /// Handed in (tests); otherwise read from the day's band data.
  final PulsoDay? day;
  const FocusSummaryScreen(this.session, {super.key, this.day});

  @override
  State<FocusSummaryScreen> createState() => _FocusSummaryScreenState();
}

class _FocusSummaryScreenState extends State<FocusSummaryScreen> {
  PulsoDay? _d;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _d = widget.day;
    _done = _d != null;
    if (!_done) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    PulsoDay? d;
    if (repo != null) {
      try {
        d = await PulsoDay.load(repo);
      } catch (_) {}
    }
    if (mounted) setState(() => (_d = d, _done = true));
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = widget.session;
    final title = 'Sesión de ${_kindName(s.kind).toLowerCase()}';
    if (!_done) {
      return detailScaffold(c, title, const [
        Padding(padding: EdgeInsets.only(top: S.x8), child: Center(child: CircularProgressIndicator())),
      ]);
    }
    final d = _d;
    final hr = bestHr(d?.hr ?? const <Pt>[], s);
    final base = d?.base;
    final end = s.end ?? _nowSec();
    final all = windowStats(hr, s.start, end + 1);
    final above = all.above(base);
    final tradeStats = [for (final t in s.trades) windowStats(hr, t.start, (t.end ?? end) + 1)];
    int? tenseIdx;
    for (var i = 0; i < tradeStats.length; i++) {
      final pk = tradeStats[i].mean;
      if (pk != null && (tenseIdx == null || pk > tradeStats[tenseIdx].mean!)) tenseIdx = i;
    }
    final insight = s.kind == FocusKind.trading ? tradingInsight(PulsoStore.instance.sessions) : null;
    final scored = scoredTrades(PulsoStore.instance.sessions).length;

    return detailScaffold(c, title, sub: '${_clock(s.start)} a ${_clock(end)} · ${hm((end - s.start) / 60)}', [
      const SizedBox(height: S.x2),
      if (above != null) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${above >= 0 ? '+' : ''}${above.round()}', style: F.hero.copyWith(color: p.ink)),
          const SizedBox(width: S.x2),
          Padding(
            padding: const EdgeInsets.only(top: S.x2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
              decoration: BoxDecoration(color: p.hi, borderRadius: R.rPill),
              child: Text('lpm', style: F.cap.copyWith(color: p.onHi, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        const SizedBox(height: S.x3),
        _say(
            c,
            'Pulso medio sobre tu base.'
            '${tenseIdx != null && s.trades.length > 1 ? ' El trade #${tenseIdx + 1} fue el más tenso.' : ''}'),
      ] else ...[
        Text('Sin pulso', style: F.t1.copyWith(color: p.ink3)),
        const SizedBox(height: S.x3),
        _say(c, hr.isEmpty
            ? 'No hay pulso de esta sesión todavía. Sincroniza la banda y vuelve a abrirla.'
            : 'Falta tu base para comparar: aparece cuando la banda haya medido tu noche.'),
      ],
      if (hr.length >= 2) ...[
        const SizedBox(height: S.x4),
        GlowLine([for (final x in hr) x.v],
            quality: base == null ? null : (v) => 1 - (v - base) / 24, height: 96),
        if (all.peak != null) ...[
          const SizedBox(height: S.x1),
          _note(c, 'Pico ${all.peak!.round()} lpm · media ${all.mean!.round()} lpm'),
        ],
      ],
      if (s.kind == FocusKind.trading) ...[
        const SizedBox(height: S.x5),
        _over(c, 'Trades'),
        if (s.trades.isEmpty) ...[
          const SizedBox(height: S.x2),
          _note(c, 'No marcaste trades en esta sesión.'),
        ],
        for (var i = 0; i < s.trades.length; i++) _tradeRow(c, i + 1, s.trades[i], tradeStats[i]),
        const SizedBox(height: S.x4),
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (insight != null)
              _say(c, insight)
            else ...[
              Row(children: [
                Icon(LucideIcons.lock, size: 16, color: p.ink3),
                const SizedBox(width: S.x2),
                Expanded(child: _note(c, 'Con $kInsightTrades trades marcados verás en qué estado operas mejor.')),
              ]),
              const SizedBox(height: S.x2),
              PulsoBar(scored / kInsightTrades, p.ink, height: 5),
              const SizedBox(height: S.x1),
              _note(c, '$scored de $kInsightTrades'),
            ],
          ]),
        ),
      ],
    ]);
  }
}

// ── Reseteo ─────────────────────────────────────────────────────────────────

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key});

  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  Timer? _tick;
  AppState? _owner;
  bool _running = false;
  int _elapsed = 0;
  bool _inhale = true;
  final _hr = <({int s, int v})>[];
  ResetResult? _result;

  int get _total => Motion.resetLength.inSeconds;
  int get _in => Motion.resetIn.inSeconds;
  int get _cycle => _in + Motion.resetOut.inSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _owner = _app(context)?..retainLiveHrView();
    });
    final r = PulsoStore.instance.resets;
    _result = r.isEmpty ? null : r.last;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _owner?.releaseLiveHrView();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _elapsed = 0;
      _inhale = true;
      _hr.clear();
    });
    _owner?.buzzBreathPhase(BreathPhaseKind.inhale);
    _tick = Timer.periodic(Motion.tick, (_) {
      if (!mounted) return;
      final e = _elapsed + 1;
      final hr = _owner?.liveHr;
      if (hr != null) _hr.add((s: e, v: hr));
      if (e >= _total) {
        _finish();
        return;
      }
      final phase = e % _cycle;
      if (phase == 0) _owner?.buzzBreathPhase(BreathPhaseKind.inhale);
      if (phase == _in) _owner?.buzzBreathPhase(BreathPhaseKind.exhale);
      setState(() {
        _elapsed = e;
        _inhale = phase < _in;
      });
    });
  }

  void _finish() {
    _tick?.cancel();
    _owner?.buzzSessionComplete();
    double? mean(Iterable<int> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    final before = mean([for (final x in _hr) if (x.s <= 8) x.v]);
    final after = mean([for (final x in _hr) if (x.s > _total - 10) x.v]);
    final r = ResetResult(_nowSec() - _total, before, after);
    PulsoStore.instance.addReset(r);
    setState(() {
      _running = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final r = _result;
    final drop = r?.drop;
    return detailScaffold(c, 'Reseteo', sub: '${_total ~/ 60 == 1 ? '60 s' : '$_total s'} · 4 s inhalar, 6 s exhalar', [
      const SizedBox(height: S.x6),
      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: p.line, width: 1.5)),
            ),
            AnimatedScale(
              scale: !_running ? .62 : (_inhale ? 1 : .62),
              duration: motion(c, _inhale ? Motion.resetIn : Motion.resetOut),
              curve: Curves.easeInOut,
              child: Container(
                width: 172,
                height: 172,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.hi,
                  boxShadow: [BoxShadow(color: p.hi.withValues(alpha: p.glow), blurRadius: 24)],
                ),
              ),
            ),
            Text(!_running ? 'Listo' : (_inhale ? 'Inhala' : 'Exhala'),
                style: F.t2.copyWith(color: C.carbon)),
          ]),
        ),
      ),
      const SizedBox(height: S.x4),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: S.x4,
        runSpacing: S.x1,
        children: [
          for (final (w, label) in const [(28.0, 'larga: inhala'), (10.0, 'corta: exhala')])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: w, height: 6, decoration: BoxDecoration(color: p.ink, borderRadius: R.rPill)),
              const SizedBox(width: S.x2),
              _note(c, label),
            ]),
        ],
      ),
      const SizedBox(height: S.x4),
      Center(
        child: Text(
            _running
                ? '${_total - _elapsed} s'
                : 'La banda te guía con vibraciones suaves. Puedes cerrar los ojos.',
            textAlign: TextAlign.center,
            style: F.body.copyWith(color: p.ink)),
      ),
      const SizedBox(height: S.x5),
      if (!_running)
        BigButton('Empezar reseteo', color: C.carbon, onTap: _start)
      else
        BigButton('Parar', soft: true, color: C.carbon, onTap: () {
          _tick?.cancel();
          setState(() => _running = false);
        }),
      if (r != null) ...[
        const SizedBox(height: S.x4),
        Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _over(c, 'Último reseteo · ${_clock(r.t)}'),
            const SizedBox(height: S.x2),
            Row(children: [
              Expanded(
                  child: Text(
                      r.before == null || r.after == null
                          ? 'Sin pulso en vivo durante el reseteo'
                          : 'Pulso ${r.before!.round()} → ${r.after!.round()}',
                      style: F.body.copyWith(color: p.ink))),
              if (drop != null)
                Text('${drop >= 0 ? '−' : '+'}${drop.abs().round()} lpm',
                    style: F.head.copyWith(color: p.on(p.qualityOf(drop >= 0 ? 1 : 0)))),
            ]),
          ]),
        ),
      ],
    ]);
  }
}
