// Pulso · Edad del cuerpo — an ESTIMATE, labelled as one.
//
// Your real age plus a bounded number of years per habit, each from data the
// app already has, over the last 4 weeks. The directions follow published
// associations with healthspan (higher VO2max, lower resting HR, higher HRV,
// 7–8 h of regular sleep, ~150 min/week of exercise, lower stress); the sizes
// are ours, kept small and capped so no single factor can dominate. No body
// composition: the band has no sensor for it.
//
// Missing input → that factor is absent (not zero). No age, or fewer than
// three factors → no estimate. Pure: no I/O, no clock.

class AgeFactor {
  final String key;

  /// Years added (+) or removed (−).
  final double years;

  /// The input as shown ("52 lpm", "7 h 20").
  final String shown;
  const AgeFactor(this.key, this.years, this.shown);
}

class BodyAge {
  final int? age;
  final double? bodyAge;
  final List<AgeFactor> factors;
  const BodyAge(this.age, this.bodyAge, this.factors);

  /// Body age per year of real age: under 1 is ageing slower.
  double? get pace {
    final a = age, b = bodyAge;
    return a == null || b == null || a == 0 ? null : b / a;
  }
}

double _cap(double x, double lo, double hi) => x < lo ? lo : (x > hi ? hi : x);

String _hm(double h) {
  final m = (h * 60).round();
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

BodyAge bodyAge({
  required int? age,
  double? rhr,
  double? rmssd,
  double? vo2max,
  double? sleepHours,
  double? sleepMidpointSdHours,
  double? exerciseMinPerWeek,
  double? stress,
}) {
  final f = <AgeFactor>[];
  if (vo2max != null) {
    f.add(AgeFactor('vo2max', _cap((40 - vo2max) * .25, -3, 3),
        '${vo2max.round()} ml/kg/min'));
  }
  if (rhr != null) {
    f.add(AgeFactor('rhr', _cap((rhr - 60) * .12, -2.5, 2.5), '${rhr.round()} lpm'));
  }
  if (rmssd != null) {
    f.add(AgeFactor('rmssd', _cap((45 - rmssd) * .05, -2, 2), '${rmssd.round()} ms'));
  }
  if (sleepHours != null) {
    f.add(AgeFactor('sleep', _cap(((sleepHours - 7.5).abs() - .25) * .8, 0, 2),
        _hm(sleepHours)));
  }
  if (sleepMidpointSdHours != null) {
    f.add(AgeFactor('regularity', _cap((sleepMidpointSdHours - .5) * 1.2, -.5, 2),
        '±${(sleepMidpointSdHours * 60).round()} min'));
  }
  if (exerciseMinPerWeek != null) {
    f.add(AgeFactor('exercise', _cap((150 - exerciseMinPerWeek) / 150, -1, 1),
        '${exerciseMinPerWeek.round()} min/sem'));
  }
  if (stress != null) {
    f.add(AgeFactor('stress', _cap((stress - 35) / 30, -.5, 1), '${stress.round()}/100'));
  }
  if (age == null || f.length < 3) return BodyAge(age, null, f);
  final years = f.fold<double>(0, (a, x) => a + x.years);
  return BodyAge(age, age + years, f);
}
