import 'dart:math' as math;

import '../../gps/route_models.dart';
import '../../gps/route_math.dart' show isImplausibleSegment;
import 'focus.dart';

double? median(Iterable<num> values) {
  final sorted =
      values.where((v) => v.isFinite).map((v) => v.toDouble()).toList()..sort();
  if (sorted.isEmpty) return null;
  final i = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
}

typedef TradeReview = ({double? entry, double? peak, int? recoverySeconds});

/// Age out gaps instead of interpolating recovery where the sensor went quiet.
/// The median uses only samples before entry. Two readings at least 10 s
/// apart must corroborate a return within 5 bpm of that baseline.
TradeReview reviewTrade(
  Trade trade,
  List<HrPt> samples, {
  required bool Function(int epochSeconds) still,
  int? nextTradeStart,
}) {
  final start = trade.start;
  final end = trade.end;
  final before = [
    for (final point in samples)
      if (point.t >= start - 60 && point.t < start && still(point.t)) point.v,
  ];
  final entry = before.length < 20 ? null : median(before);
  final peak = end == null ? null : windowStats(samples, start, end + 1).peak;
  int? recovered;
  if (end != null && entry != null && peak != null && peak > entry + 5) {
    int? first, previous;
    final stop = math.min(end + 300, nextTradeStart ?? end + 300);
    for (final point in samples) {
      if (point.t < end || point.t >= stop) continue;
      if (!still(point.t)) break;
      if ((previous ?? end) + 15 < point.t) break;
      previous = point.t;
      if ((point.v - entry).abs() > 5) {
        first = null;
        continue;
      }
      first ??= point.t;
      if (point.t - first >= 10) {
        recovered = first - end;
        break;
      }
    }
  }
  return (entry: entry, peak: peak, recoverySeconds: recovered);
}

/// Integrate above-baseline BPM over observed intervals. Return coverage so
/// callers can distinguish a partial measure from a fully observed session.
({double load, int seconds}) pulseLoad(
  List<HrPt> samples,
  double baseline, {
  int maxGap = 15,
}) {
  var load = 0.0;
  var seconds = 0;
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1], b = samples[i];
    final dt = b.t - a.t;
    if (dt <= 0 || dt > maxGap) continue;
    final low = math.min(a.v, b.v) - baseline;
    final high = math.max(a.v, b.v) - baseline;
    if (high > 0) {
      final above = low >= 0
          ? (low + high) / 2
          : high * high / (2 * (high - low));
      load += above * dt / 60;
    }
    seconds += dt;
  }
  return (load: load, seconds: seconds);
}

typedef GroupComparison = ({
  int aCount,
  int bCount,
  double? aMedian,
  double? bMedian,
});

GroupComparison compareGroups(Iterable<num> a, Iterable<num> b) {
  final left = a.where((n) => n.isFinite).toList();
  final right = b.where((n) => n.isFinite).toList();
  return (
    aCount: left.length,
    bCount: right.length,
    aMedian: median(left),
    bMedian: median(right),
  );
}

/// Median and median absolute deviation of the previous nights. A floor in
/// the metric's own units keeps tiny changes from dominating a flat history.
({double center, double delta, bool unusual})? nightlyDifference(
  double? current,
  Iterable<double> previous,
  double minimumChange,
) {
  final history = previous.where((v) => v.isFinite).toList();
  if (current == null || !current.isFinite || history.length < 7) return null;
  final center = median(history)!;
  final mad = median(history.map((v) => (v - center).abs()))!;
  final delta = current - center;
  return (
    center: center,
    delta: delta,
    unusual: delta.abs() >= math.max(minimumChange, 2.5 * mad),
  );
}

/// Compare like-for-like full kilometre splits. Midpoint location and direction
/// must match, in addition to pace, to avoid comparing unrelated hills.
({int matches, double? difference, double? drift}) routePulseComparison(
  WorkoutRoute current,
  WorkoutRoute previous,
  double Function(RoutePoint, RoutePoint) distance,
) {
  final a = _locatedSplits(current, distance);
  final b = _locatedSplits(previous, distance);
  final changes = <double>[];
  final used = <int>{};
  for (final x in a) {
    var closest = -1;
    var best = 120.0;
    for (var i = 0; i < b.length; i++) {
      final y = b[i];
      if (used.contains(i) || !_samePace(x.split, y.split)) continue;
      if (distance(x.start, y.start) > 160 || distance(x.end, y.end) > 160)
        continue;
      final d = distance(x.mid, y.mid);
      if (d < best) {
        best = d;
        closest = i;
      }
    }
    if (closest < 0) continue;
    used.add(closest);
    changes.add(x.split.avgHr! - b[closest].split.avgHr!);
  }
  final drift = <double>[];
  final half = current.splitsKm.length ~/ 2;
  final early = a.where((r) => r.split.index <= half).toList();
  final remainingLate = a
      .where((r) => r.split.index > (current.splitsKm.length + 1) ~/ 2)
      .toList();
  for (final x in early) {
    final i = remainingLate.indexWhere(
      (late) => _samePace(x.split, late.split),
    );
    if (i >= 0)
      drift.add(remainingLate.removeAt(i).split.avgHr! - x.split.avgHr!);
  }
  return (
    matches: changes.length,
    difference: median(changes),
    drift: median(drift),
  );
}

bool _samePace(Split a, Split b) =>
    (a.paceSecPerUnit(1000) - b.paceSecPerUnit(1000)).abs() <= 20;

typedef _LocatedSplit = ({
  Split split,
  RoutePoint start,
  RoutePoint mid,
  RoutePoint end,
});

List<_LocatedSplit> _locatedSplits(
  WorkoutRoute route,
  double Function(RoutePoint, RoutePoint) distance,
) {
  final points = route.points;
  if (points.length < 2) return [];
  final result = <_LocatedSplit>[];
  var meters = 0.0;
  var index = 0;
  var start = points.first;
  RoutePoint? mid;
  var gap = false;

  RoutePoint interpolate(RoutePoint a, RoutePoint b, double fraction) =>
      RoutePoint(
        seq: b.seq,
        tsMs: (a.tsMs + (b.tsMs - a.tsMs) * fraction).round(),
        lat: a.lat + (b.lat - a.lat) * fraction,
        lng: a.lng + (b.lng - a.lng) * fraction,
      );

  for (var i = 1; i < points.length && index < route.splitsKm.length; i++) {
    final previous = points[i - 1], point = points[i];
    final dt = point.tsMs - previous.tsMs;
    final delta = distance(previous, point);
    if (dt <= 0 || isImplausibleSegment(delta, dt)) {
      gap = true;
      continue;
    }
    if (delta <= 0) continue;
    if (dt > 30000) gap = true;
    while (index < route.splitsKm.length) {
      final middle = (index + .5) * 1000;
      if (mid == null && meters + delta >= middle) {
        mid = interpolate(
          previous,
          point,
          ((middle - meters) / delta).clamp(0, 1),
        );
      }
      final boundary = (index + 1) * 1000;
      if (meters + delta + 1e-6 < boundary) break;
      final end = interpolate(
        previous,
        point,
        ((boundary - meters) / delta).clamp(0, 1),
      );
      final split = route.splitsKm[index++];
      final samples = route.hr
          .where((h) => h.tsMs >= start.tsMs && h.tsMs < end.tsMs)
          .length;
      if (!gap &&
          mid != null &&
          split.avgHr != null &&
          split.durationSec > 0 &&
          samples >= split.durationSec * .5) {
        result.add((split: split, start: start, mid: mid, end: end));
      }
      start = end;
      mid = null;
      gap = dt > 30000;
    }
    meters += delta;
  }
  return result;
}

/// Directional pulse response to the 4 s inhale / 6 s exhale cue. The first
/// second after each cue is excluded, and each cycle contributes at most once.
/// This is a descriptive within-session difference, not a coherence score.
({double delta, int cycles})? breathPhaseResponse(
  Map<int, double> pulseBySecond,
) {
  final swings = <double>[];
  for (var cycle = 0; cycle < 6; cycle++) {
    final start = cycle * 10;
    final inValues = [
      for (var i = 1; i <= 3; i++)
        if (pulseBySecond[start + i] case final double v) v,
    ];
    final outValues = [
      for (var i = 6; i <= 9; i++)
        if (pulseBySecond[start + i] case final double v) v,
    ];
    if (inValues.length >= 2 && outValues.length >= 2) {
      swings.add(median(inValues)! - median(outValues)!);
    }
  }
  if (swings.length < 4) return null;
  return (delta: median(swings)!, cycles: swings.length);
}
