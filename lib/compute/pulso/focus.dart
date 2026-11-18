// Pulso · Enfoque — trabajo and trading sessions, trades, the traffic light.
//
// Sessions are NOT workouts: they never count toward strain and are never
// exported to Apple Health. A session stores only its own aggregates (one
// heart-rate mean per 30 s while the screen was open, and per-trade figures),
// never the raw live stream. After the band syncs, the summary prefers the
// band's own per-minute heart rate for the same window.
//
// Pure models + maths; persistence is lib/state/pulso_store.dart.

import 'dart:math' as math;

typedef HrPt = ({int t, double v});

enum FocusKind { trabajo, trading }

class Trade {
  final int start;
  int? end;

  /// 'win' | 'loss' | null (not marked).
  String? result;

  /// Live HR minus the base when the trade was opened, or null with no live HR.
  final double? entryAbove;

  final double? entryBpm;

  Trade(this.start, {this.end, this.result, this.entryAbove, this.entryBpm});

  Map<String, Object?> toJson() =>
      {'s': start, 'e': end, 'r': result, 'a': entryAbove, 'bpm': entryBpm};
  factory Trade.fromJson(Map m) => Trade((m['s'] as num).toInt(),
      end: (m['e'] as num?)?.toInt(),
      result: m['r'] as String?,
      entryAbove: (m['a'] as num?)?.toDouble(),
      entryBpm: (m['bpm'] as num?)?.toDouble());
}

class FocusSession {
  final String id;
  final FocusKind kind;
  int start;
  int? end;
  final List<Trade> trades;

  /// 30-second HR means recorded while the live screen was open.
  final List<HrPt> samples;

  FocusSession(this.id, this.kind, this.start,
      {this.end, List<Trade>? trades, List<HrPt>? samples})
      : trades = trades ?? [],
        samples = samples ?? [];

  bool get open => end == null;
  Trade? get openTrade => trades.isEmpty || trades.last.end != null ? null : trades.last;

  Map<String, Object?> toJson() => {
        'id': id,
        'k': kind.name,
        's': start,
        'e': end,
        't': [for (final t in trades) t.toJson()],
        'h': [for (final p in samples) [p.t, p.v]],
      };

  factory FocusSession.fromJson(Map m) => FocusSession(
        m['id'] as String,
        FocusKind.values.byName(m['k'] as String),
        (m['s'] as num).toInt(),
        end: (m['e'] as num?)?.toInt(),
        trades: [for (final t in (m['t'] as List? ?? const [])) Trade.fromJson(t as Map)],
        samples: [
          for (final p in (m['h'] as List? ?? const []))
            (t: ((p as List)[0] as num).toInt(), v: (p[1] as num).toDouble()),
        ],
      );
}

class ResetResult {
  final int t;
  final double? before, after;
  const ResetResult(this.t, this.before, this.after);
  double? get drop => before == null || after == null ? null : before! - after!;
  Map<String, Object?> toJson() => {'t': t, 'b': before, 'a': after};
  factory ResetResult.fromJson(Map m) => ResetResult((m['t'] as num).toInt(),
      (m['b'] as num?)?.toDouble(), (m['a'] as num?)?.toDouble());
}

// ── the traffic light ───────────────────────────────────────────────────────

enum Light { calma, alerta, acelerado }

/// Focus display thresholds, relative to waking pulse with a minimum per
/// band of the indicator. These are interface settings, not clinical limits.
Light lightFor(double hr, double base) {
  if (hr < math.max(80, base + 12)) return Light.calma;
  if (hr < math.max(95, base + 22)) return Light.alerta;
  return Light.acelerado;
}

/// The waking base: the median HR of still, awake minutes today when there
/// are at least 30 of them; otherwise resting HR + 10 (sitting is ~10 above
/// the night's resting rate). Null with neither.
double? wakingBase({
  required List<HrPt> hr,
  required Map<int, double> moveBy5min,
  required bool Function(int t) asleep,
  required double? rhr,
}) {
  final still = <double>[
    for (final p in hr)
      if (!asleep(p.t) && (moveBy5min[p.t ~/ 300] ?? 1) < .2) p.v,
  ]..sort();
  if (still.length >= 30) return still[still.length ~/ 2];
  return rhr == null ? null : rhr + 10;
}

// ── window statistics ───────────────────────────────────────────────────────

class WindowStats {
  final double? peak, mean;
  final int n;
  const WindowStats(this.peak, this.mean, this.n);
  double? above(double? base) => mean == null || base == null ? null : mean! - base;
}

WindowStats windowStats(List<HrPt> hr, int start, int end) {
  final v = [for (final p in hr) if (p.t >= start && p.t < end) p.v];
  if (v.isEmpty) return const WindowStats(null, null, 0);
  return WindowStats(v.reduce((a, b) => a > b ? a : b),
      v.reduce((a, b) => a + b) / v.length, v.length);
}

/// The band's per-minute HR for the window when it has synced, else the
/// session's own 30 s samples.
List<HrPt> bestHr(List<HrPt> bandMinutes, FocusSession s) {
  final end = s.end ?? (s.samples.isEmpty ? s.start : s.samples.last.t + 30);
  final band = [for (final p in bandMinutes) if (p.t >= s.start && p.t < end) p];
  return band.length >= 5 ? band : [
    for (final p in s.samples) if (p.t >= s.start && p.t <= end) p,
  ];
}

// ── the 20-trade insight ───────────────────────────────────────────────────

const kInsightTrades = 20;

/// Trades with a result AND an entry reading, across every session.
List<Trade> scoredTrades(List<FocusSession> sessions) => [
      for (final s in sessions)
        for (final t in s.trades)
          if (t.result != null && t.entryAbove != null) t,
    ];

/// One sentence once there are [kInsightTrades] scored trades, else null.
String? tradingInsight(List<FocusSession> sessions) {
  final t = scoredTrades(sessions);
  if (t.length < kInsightTrades) return null;
  double? mean(Iterable<double> v) =>
      v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  final w = mean([for (final x in t) if (x.result == 'win') x.entryAbove!]);
  final l = mean([for (final x in t) if (x.result == 'loss') x.entryAbove!]);
  if (w == null || l == null) {
    return 'Marca trades ganados y perdidos para poder compararlos.';
  }
  final d = l - w;
  if (d >= 3) {
    return 'Tus trades perdidos empezaron con ${d.round()} lpm más que los '
        'ganados. La comparación muestra una asociación.';
  }
  if (d <= -3) {
    return 'Tus trades ganados empezaron con ${(-d).round()} lpm más que los '
        'perdidos: la diferencia es descriptiva.';
  }
  return 'Tu pulso al entrar es parecido en trades ganados y perdidos.';
}
