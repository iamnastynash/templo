import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/pulso/cardio_score.dart';

final _today = DateTime(2026, 11, 17);

/// One reading per local day, [values] oldest first, ending today.
List<Reading> _days(List<double> values, {int endDaysBack = 0}) => [
      for (var i = 0; i < values.length; i++)
        (
          t: DateTime(_today.year, _today.month,
                      _today.day - endDaysBack - (values.length - 1 - i), 4)
                  .millisecondsSinceEpoch ~/
              1000,
          v: values[i],
        ),
    ];

void main() {
  test('a full fortnight scores every component and averages them', () {
    final r = cardioScore({
      'rhr': _days(List.filled(14, 55)),
      'rmssd': _days(List.filled(14, 60)),
      'dip_pct': _days(List.filled(14, 14)),
      'hrr_bpm': _days([20, 20]),
    }, _today);
    // rhr 55 → 100, sd 0 → 100, rmssd 60 → 100, dip 14 → 100, hrr 20 → 100.
    expect(r.score, 100);
    expect(r.parts.every((p) => p.score == 100), isTrue);
    expect(r.nights, 14);
  });

  test('anchors map to 0 at the bad end', () {
    expect(cardioQuality('rhr', 70), 0);
    expect(cardioQuality('rmssd', 35), 0);
    expect(cardioQuality('rhr_consistency', 6), 0);
    expect(cardioQuality('dip_pct', 2), 0);
    expect(cardioQuality('hrr_bpm', 5), 0);
  });

  test('fewer than 7 nights: no score, but the parts still show', () {
    final r = cardioScore({
      'rhr': _days(List.filled(5, 54)),
      'rmssd': _days(List.filled(5, 58)),
      'dip_pct': _days(List.filled(5, 12)),
    }, _today);
    expect(r.score, isNull);
    expect(r.nights, 5);
    expect(r.parts.firstWhere((p) => p.key == 'rhr').value, 54);
  });

  test('a missing component is absent, not zero, and does not count', () {
    final r = cardioScore({
      'rhr': _days(List.filled(10, 55)),
      'rmssd': _days(List.filled(10, 60)),
      'dip_pct': _days(List.filled(10, 14)),
      // no hrr_bpm: no workouts
    }, _today);
    final hrr = r.parts.firstWhere((p) => p.key == 'hrr_bpm');
    expect(hrr.value, isNull);
    expect(hrr.score, isNull);
    expect(r.score, 100); // the four present ones, not dragged down by a 0
  });

  test('only two components: no score', () {
    final r = cardioScore({
      'rhr': _days(List.filled(10, 55)),
      // rmssd, dip and hrr all missing; rhr + consistency = 2 parts
    }, _today);
    expect(r.score, isNull);
  });

  test('readings outside the 14-day window are ignored', () {
    final r = cardioScore({
      'rhr': [..._days(List.filled(7, 90), endDaysBack: 20), ..._days(List.filled(7, 55))],
      'rmssd': _days(List.filled(7, 60)),
      'dip_pct': _days(List.filled(7, 14)),
    }, _today);
    expect(r.parts.first.value, 55);
  });

  test('direction compares with the previous fortnight', () {
    final r = cardioScore({
      'rhr': [..._days(List.filled(14, 64), endDaysBack: 14), ..._days(List.filled(14, 55))],
      'rmssd': [..._days(List.filled(14, 45), endDaysBack: 14), ..._days(List.filled(14, 60))],
      'dip_pct': [..._days(List.filled(14, 8), endDaysBack: 14), ..._days(List.filled(14, 14))],
    }, _today);
    expect(r.previous, isNotNull);
    expect(r.direction, 1);
  });

  test('weakest is the lowest scored component', () {
    final r = cardioScore({
      'rhr': _days(List.filled(14, 55)),
      'rmssd': _days(List.filled(14, 60)),
      'dip_pct': _days(List.filled(14, 14)),
      'hrr_bpm': _days([11]),
    }, _today);
    expect(r.weakest?.key, 'hrr_bpm');
  });
}
