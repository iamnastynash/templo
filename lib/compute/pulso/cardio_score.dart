// Pulso · cardiovascular health score (Hume-inspired, our own formula).
//
// Five components read from series the band already produces, over the last
// [kCardioWindowDays] local days:
//   rhr              resting HR (mean)                 good ≤55, bad ≥70 bpm
//   rhr_consistency  night-to-night SD of resting HR   good ≤2,  bad ≥6 bpm
//   rmssd            nightly HRV (mean)                good ≥60, bad ≤35 ms
//   dip_pct          nocturnal HR dip (mean, %)        good ≥14, bad ≤2 %
//   hrr_bpm          HR recovery after a bout (mean)   good ≥20, bad ≤5 bpm
// Each becomes 0–100 on its anchors; the score is their plain mean.
//
// NEVER FABRICATED (edge invariant 3): a component with too few readings is
// null and does not count; the score is null below [kCardioMinNights] nights
// of resting HR or below [kCardioMinParts] components. SpO2 is deliberately
// absent — the WHOOP 4.0 gives no validated blood-oxygen reading.
//
// Pure: no I/O, no clock. Wellness estimate, not a diagnosis.

import 'dart:math' as math;

const kCardioWindowDays = 14;
const kCardioMinNights = 7;
const kCardioMinParts = 3;

/// The order the components are listed in, everywhere.
const kCardioParts = ['rhr', 'rmssd', 'rhr_consistency', 'dip_pct', 'hrr_bpm'];

/// One reading: epoch seconds and value.
typedef Reading = ({int t, double v});

class CardioPart {
  final String key;

  /// The figure shown beside the component (a mean, or an SD for
  /// consistency). Null when there were too few readings.
  final double? value;

  /// 0–100, or null with [value].
  final double? score;

  /// Readings the component was computed from.
  final int n;

  const CardioPart(this.key, this.value, this.score, this.n);
}

class CardioResult {
  /// 0–100, or null while there is not enough to score.
  final int? score;
  final List<CardioPart> parts;

  /// Nights of resting HR inside the window (the gate's count).
  final int nights;

  /// The previous window's score, for the trend word; null when absent.
  final int? previous;

  const CardioResult(this.score, this.parts, this.nights, this.previous);

  /// +1 improving, -1 falling, 0 stable, null when there is no previous.
  int? get direction {
    final s = score, pr = previous;
    if (s == null || pr == null) return null;
    if (s - pr >= 3) return 1;
    if (pr - s >= 3) return -1;
    return 0;
  }

  /// The scored component with the lowest score, or null.
  CardioPart? get weakest {
    CardioPart? w;
    for (final p in parts) {
      final s = p.score;
      if (s != null && (w == null || s < w.score!)) w = p;
    }
    return w;
  }
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

/// Score 0…1 for one component's [value].
double cardioQuality(String key, double value) => switch (key) {
      'rhr' => _clamp01((70 - value) / 15),
      'rhr_consistency' => _clamp01((6 - value) / 4),
      'rmssd' => _clamp01((value - 35) / 25),
      'dip_pct' => _clamp01((value - 2) / 12),
      'hrr_bpm' => _clamp01((value - 5) / 15),
      _ => throw ArgumentError.value(key, 'key'),
    };

/// Local midnight [days] days before [day]'s midnight, as epoch seconds.
/// Calendar arithmetic, not 86400 s steps, so DST does not shift the edge.
int _midnightSec(DateTime day, int daysBack) =>
    DateTime(day.year, day.month, day.day - daysBack)
        .millisecondsSinceEpoch ~/
    1000;

/// Score the window ending at [today] (inclusive) from [series], keyed by the
/// metric_series names `rhr`, `rmssd`, `dip_pct`, `hrr_bpm`.
CardioResult cardioScore(Map<String, List<Reading>> series, DateTime today) {
  final now = _window(series, today);
  final prev = _window(series,
      DateTime(today.year, today.month, today.day - kCardioWindowDays));
  return CardioResult(now.score, now.parts, now.nights, prev.score);
}

CardioResult _window(Map<String, List<Reading>> series, DateTime end) {
  final from = _midnightSec(end, kCardioWindowDays - 1);
  final to = _midnightSec(end, -1); // exclusive: next local midnight
  List<double> inWin(String k) => [
        for (final r in series[k] ?? const <Reading>[])
          if (r.t >= from && r.t < to && r.v.isFinite) r.v,
      ];

  double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  double sd(List<double> v) {
    final m = mean(v);
    return math.sqrt(
        v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length);
  }

  CardioPart part(String key, List<double> v, int minN, double Function(List<double>) f) {
    if (v.length < minN) return CardioPart(key, null, null, v.length);
    final value = f(v);
    return CardioPart(key, value, cardioQuality(key, value) * 100, v.length);
  }

  final rhr = inWin('rhr');
  final parts = <CardioPart>[
    part('rhr', rhr, 4, mean),
    part('rmssd', inWin('rmssd'), 4, mean),
    part('rhr_consistency', rhr, 4, sd),
    part('dip_pct', inWin('dip_pct'), 4, mean),
    part('hrr_bpm', inWin('hrr_bpm'), 1, mean),
  ];
  final scored = [for (final p in parts) if (p.score != null) p.score!];
  final ok = rhr.length >= kCardioMinNights && scored.length >= kCardioMinParts;
  return CardioResult(
    ok ? (scored.reduce((a, b) => a + b) / scored.length).round() : null,
    parts,
    rhr.length,
    null,
  );
}
