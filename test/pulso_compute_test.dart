import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/pulso/body_age.dart';
import 'package:openstrap_edge/compute/pulso/day_load.dart';
import 'package:openstrap_edge/compute/pulso/focus.dart';

const _t0 = 1763366400; // a minute boundary

List<Pt> _minutes(int from, int n, double hr) =>
    [for (var i = 0; i < n; i++) (t: from + i * 60, v: hr)];
List<Pt> _move(int from, int n, double frac) =>
    [for (var i = 0; i < n; i += 5) (t: (from + i * 60) ~/ 300 * 300, v: frac)];

void main() {
  group('dayLoad', () {
    test('high HR while moving is effort, while still is stress', () {
      final hr = [..._minutes(_t0, 30, 130), ..._minutes(_t0 + 3600, 30, 80)];
      final act = [..._move(_t0, 30, .6), ..._move(_t0 + 3600, 30, .05)];
      final l = dayLoad(hr: hr, activity: act, rhr: 55, maxHr: 185);
      expect(l.effortMin, 30);
      expect(l.stressMin, 30);
      expect(l.runs.map((r) => r.stress), [false, true]);
      expect(l.goodShare, greaterThan(.5)); // 130 bpm effort outweighs 80 bpm stress
    });

    test('unknown movement is not classified', () {
      final l = dayLoad(hr: _minutes(_t0, 30, 120), activity: const [], rhr: 55, maxHr: 185);
      expect(l.effortMin + l.stressMin, 0);
      expect(l.goodShare, isNull);
    });

    test('sleep minutes are skipped', () {
      final l = dayLoad(
          hr: _minutes(_t0, 30, 90),
          activity: _move(_t0, 30, 0),
          rhr: 55,
          maxHr: 185,
          sleep: [(onset: _t0 - 60, wake: _t0 + 3600)]);
      expect(l.stressMin, 0);
    });
  });

  group('energyCurve', () {
    test('starts at recovery on waking and drains under stress', () {
      final wake = _t0;
      final curve = energyCurve(
        hr: _minutes(wake, 120, 85),
        activity: _move(wake, 120, 0),
        rhr: 55,
        maxHr: 185,
        sleep: [(onset: wake - 8 * 3600, wake: wake)],
        wakeEnergy: 80,
        now: wake + 120 * 60,
      );
      expect(curve.first.v, 80);
      expect(curve.last.v, lessThan(80));
    });

    test('calm and still recharges, never above 100', () {
      final curve = energyCurve(
        hr: _minutes(_t0, 300, 58),
        activity: _move(_t0, 300, 0),
        rhr: 55,
        maxHr: 185,
        sleep: [(onset: _t0 - 8 * 3600, wake: _t0)],
        wakeEnergy: 99,
        now: _t0 + 300 * 60,
      );
      expect(curve.every((p) => p.v <= 100), isTrue);
    });

    test('no recovery, no energy', () {
      expect(
          energyCurve(
              hr: const [], activity: const [], rhr: 55, maxHr: 185,
              sleep: [(onset: _t0 - 3600, wake: _t0)], wakeEnergy: null, now: _t0 + 60),
          isEmpty);
    });
  });

  group('bodyAge', () {
    test('good habits take years off, capped', () {
      final b = bodyAge(age: 34, rhr: 50, rmssd: 70, vo2max: 52,
          sleepHours: 7.5, sleepMidpointSdHours: .4, exerciseMinPerWeek: 200, stress: 25);
      expect(b.bodyAge, lessThan(34));
      expect(b.pace, lessThan(1));
    });
    test('irregular sleep adds years', () {
      final b = bodyAge(age: 34, rhr: 60, rmssd: 45, sleepMidpointSdHours: 1.5);
      expect(b.factors.firstWhere((f) => f.key == 'regularity').years, closeTo(1.2, 1e-9));
    });
    test('fewer than three factors or no age: no estimate', () {
      expect(bodyAge(age: 34, rhr: 55, rmssd: 60).bodyAge, isNull);
      expect(bodyAge(age: null, rhr: 55, rmssd: 60, vo2max: 45).bodyAge, isNull);
    });
  });

  group('focus', () {
    test('traffic light thresholds', () {
      expect(lightFor(74, 56), Light.calma);
      expect(lightFor(79, 62), Light.calma);
      expect(lightFor(80, 62), Light.alerta);
      expect(lightFor(81, 70), Light.calma);
      expect(lightFor(82, 70), Light.alerta);
      expect(lightFor(94, 70), Light.alerta);
      expect(lightFor(95, 70), Light.acelerado);
      expect(lightFor(100, 89), Light.calma);
    });

    test('session round-trips through JSON', () {
      final s = FocusSession('x', FocusKind.trading, _t0, trades: [
        Trade(_t0 + 60, end: _t0 + 300, result: 'win', entryAbove: 4),
      ], samples: [(t: _t0, v: 80)]);
      final back = FocusSession.fromJson(s.toJson());
      expect(back.trades.single.result, 'win');
      expect(back.samples.single.v, 80);
      expect(back.kind, FocusKind.trading);
    });

    test('insight only after 20 scored trades', () {
      FocusSession withTrades(int n, String r, double above) => FocusSession(
          r, FocusKind.trading, _t0,
          trades: [for (var i = 0; i < n; i++) Trade(_t0 + i, end: _t0 + i + 1, result: r, entryAbove: above)]);
      expect(tradingInsight([withTrades(10, 'win', 2), withTrades(9, 'loss', 10)]), isNull);
      final s = tradingInsight([withTrades(10, 'win', 2), withTrades(10, 'loss', 10)]);
      expect(s, contains('perdidos empezaron con 8 lpm'));
    });

    test('waking base falls back to resting + 10', () {
      expect(
          wakingBase(hr: const [], moveBy5min: const {}, asleep: (_) => false, rhr: 55),
          65);
    });
  });
}
