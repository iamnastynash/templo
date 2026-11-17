// Pulso · the day's load split (esfuerzo bueno vs estrés) and Energía.
//
// Inputs are what the day bundle already stores: per-minute heart rate
// (`hr_curve`), per-5-minute movement fraction (`activity_curve`, 0…1), the
// night's sleep windows, resting HR and a max HR.
//
//   esfuerzo  HR ≥ resting + 20 while MOVING (movement fraction ≥ 0.2)
//   estrés    HR ≥ resting + 15 while STILL
// A minute whose movement is unknown is not classified at all — never guessed.
//
// ENERGÍA is an ESTIMATE, stated as one in the UI. It starts at the morning's
// recovery score when you wake (no recovery → no energy, never a made-up
// start), then each awake minute drains a little, more under effort or
// stress, and recharges a little when you are calm and still or napping.
//
// Pure: no I/O, no clock.

typedef Pt = ({int t, double v});
typedef SleepWin = ({int onset, int wake});

const kEffortAbove = 20.0;
const kStressAbove = 15.0;
const kCalmAbove = 8.0;
const kMovingFrac = .2;

class LoadRun {
  final int start, end; // epoch seconds, end exclusive
  final bool stress;
  const LoadRun(this.start, this.end, this.stress);
  int get minutes => (end - start) ~/ 60;
}

class DayLoad {
  final double effort, stress;
  final int effortMin, stressMin;

  /// Runs of ≥10 minutes of one kind, oldest first.
  final List<LoadRun> runs;
  const DayLoad(this.effort, this.stress, this.effortMin, this.stressMin, this.runs);

  /// Share of the load that was good effort, 0…1, or null with no load.
  double? get goodShare {
    final t = effort + stress;
    return t <= 0 ? null : effort / t;
  }
}

bool _asleep(int t, List<SleepWin> sleep) =>
    sleep.any((s) => t >= s.onset && t < s.wake);

Map<int, double> _activityByBucket(List<Pt> activity) =>
    {for (final a in activity) a.t ~/ 300: a.v};

/// 1 = this minute was effort, -1 = stress, 0 = neither, null = unknown.
int? _kind(double hr, double? moveFrac, double rhr) {
  if (moveFrac == null) return null;
  final moving = moveFrac >= kMovingFrac;
  if (moving && hr >= rhr + kEffortAbove) return 1;
  if (!moving && hr >= rhr + kStressAbove) return -1;
  return 0;
}

double _rel(double hr, double rhr, double maxHr) {
  final r = (hr - rhr) / (maxHr - rhr);
  return r < 0 ? 0 : (r > 1 ? 1 : r);
}

DayLoad dayLoad({
  required List<Pt> hr,
  required List<Pt> activity,
  required double rhr,
  required double maxHr,
  List<SleepWin> sleep = const [],
}) {
  final act = _activityByBucket(activity);
  var effort = 0.0, stress = 0.0;
  var eMin = 0, sMin = 0;
  final kinds = <({int t, int k})>[];
  for (final p in hr) {
    if (_asleep(p.t, sleep)) continue;
    final k = _kind(p.v, act[p.t ~/ 300], rhr);
    if (k == null || k == 0) continue;
    final r = _rel(p.v, rhr, maxHr);
    if (k == 1) {
      effort += r;
      eMin++;
    } else {
      stress += r;
      sMin++;
    }
    kinds.add((t: p.t, k: k));
  }
  // Group into runs, bridging gaps of up to 3 minutes.
  final runs = <LoadRun>[];
  int? rs, re, rk;
  void close() {
    final s = rs, e = re;
    if (s != null && e != null && e - s >= 10 * 60) runs.add(LoadRun(s, e, rk == -1));
  }
  for (final m in kinds) {
    if (rs != null && m.k == rk && m.t - re! <= 3 * 60) {
      re = m.t + 60;
    } else {
      close();
      rs = m.t;
      re = m.t + 60;
      rk = m.k;
    }
  }
  close();
  return DayLoad(effort, stress, eMin, sMin, runs);
}

/// The energy curve from this morning's wake to [now], one point per 5 min.
/// Empty when there is no wake today or no [wakeEnergy] (recovery) to start
/// from.
List<Pt> energyCurve({
  required List<Pt> hr,
  required List<Pt> activity,
  required double rhr,
  required double maxHr,
  required List<SleepWin> sleep,
  required double? wakeEnergy,
  required int now,
}) {
  if (wakeEnergy == null) return const [];
  final wakes = [for (final s in sleep) if (s.wake <= now) s.wake]..sort();
  if (wakes.isEmpty) return const [];
  final wake = wakes.last;
  final act = _activityByBucket(activity);
  final hrAt = {for (final p in hr) p.t ~/ 60: p.v};
  var v = wakeEnergy.clamp(0, 100).toDouble();
  final out = <Pt>[(t: wake, v: v)];
  for (var t = wake; t < now; t += 60) {
    if (_asleep(t, sleep)) {
      v += .12; // a nap recharges
    } else {
      var drain = .035; // being awake costs a little, band on or off
      final h = hrAt[t ~/ 60];
      final move = act[t ~/ 300];
      if (h != null && move != null) {
        final r = _rel(h, rhr, maxHr);
        final moving = move >= kMovingFrac;
        if (moving && h >= rhr + kEffortAbove) {
          drain += .35 * r;
        } else if (!moving && h >= rhr + kStressAbove) {
          drain += .25 * r + .03;
        } else if (!moving && h <= rhr + kCalmAbove) {
          drain -= .06; // calm and still: a slow recharge
        }
      }
      v -= drain;
    }
    v = v.clamp(0, 100).toDouble();
    if ((t - wake) % 300 == 240) out.add((t: t + 60, v: v));
  }
  if (out.last.t != now) out.add((t: now, v: v));
  return out;
}

/// The curve's value at [t] (the last point at or before it), or null.
double? energyAt(List<Pt> curve, int t) {
  double? v;
  for (final p in curve) {
    if (p.t > t) break;
    v = p.v;
  }
  return v;
}
