import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/ble/pulse_oximeter.dart';
import 'package:openstrap_edge/compute/pulso/focus.dart';
import 'package:openstrap_edge/compute/pulso/insights.dart';
import 'package:openstrap_edge/gps/route_models.dart';

void main() {
  test('integrates excess pulse without bridging gaps', () {
    final result = pulseLoad([
      (t: 0, v: 72.0),
      (t: 10, v: 82.0),
      (t: 200, v: 82.0),
      (t: 210, v: 82.0),
    ], 72);
    expect(result.seconds, 20);
    expect(result.load, closeTo(2.5, .0001));
  });

  test('returns to the pre-entry level only with continuous quiet signal', () {
    final trade = Trade(60, end: 100);
    final trace = <HrPt>[
      for (var t = 0; t < 60; t++) (t: t, v: 70),
      (t: 80, v: 100),
      for (var t = 100; t < 130; t++) (t: t, v: t < 112 ? 86 : 72),
    ];
    final review = reviewTrade(trade, trace, still: (_) => true);
    expect(review.entry, 70);
    expect(review.peak, 100);
    expect(review.recoverySeconds, 12);
    expect(
      reviewTrade(trade, trace, still: (t) => t != 111).recoverySeconds,
      isNull,
    );
    expect(
      reviewTrade(
        trade,
        trace,
        still: (_) => true,
        nextTradeStart: 120,
      ).recoverySeconds,
      isNull,
    );
    expect(
      reviewTrade(
        trade,
        trace.where((p) => p.t < 100 || p.t > 115).toList(),
        still: (_) => true,
      ).recoverySeconds,
      isNull,
    );
  });

  test(
    'only integrates the above-baseline fraction of a crossing interval',
    () {
      final result = pulseLoad([(t: 0, v: 62.0), (t: 10, v: 82.0)], 72);
      expect(result.load, closeTo(25 / 60, .0001));
    },
  );

  test(
    'route comparison matches the same direction and pace with enough pulse',
    () {
      WorkoutRoute route(
        int bpm, {
        bool reverse = false,
        bool sparse = false,
      }) => WorkoutRoute(
        sessionId: '$bpm',
        points: [
          for (var i = 0; i <= 40; i++)
            RoutePoint(
              seq: i,
              tsMs: 10000 * i,
              lat: 0,
              lng: (reverse ? 40 - i : i) * .05,
            ),
        ],
        hr: [
          for (var i = 0; i < (sparse ? 10 : 400); i++)
            HrSample(tsMs: i * 1000, hr: bpm + i ~/ 200 * 5),
        ],
        distanceMeters: 2000,
        movingSec: 400,
        splitsKm: [
          Split(
            index: 1,
            meters: 1000,
            durationSec: 200,
            avgHr: bpm.toDouble(),
          ),
          Split(index: 2, meters: 1000, durationSec: 200, avgHr: bpm + 5.0),
        ],
        splitsMi: [],
      );
      double distance(RoutePoint a, RoutePoint b) =>
          (a.lng - b.lng).abs() * 1000;
      final result = routePulseComparison(route(142), route(148), distance);
      expect(result, (matches: 2, difference: -6.0, drift: 5.0));
      expect(
        routePulseComparison(
          route(142),
          route(148, reverse: true),
          distance,
        ).matches,
        0,
      );
      expect(
        routePulseComparison(
          route(142),
          route(148, sparse: true),
          distance,
        ).matches,
        0,
      );
    },
  );

  test('nightly comparison needs history and an informative change', () {
    expect(nightlyDifference(64, [59, 60], 3), isNull);
    expect(
      nightlyDifference(61, [58, 59, 60, 60, 61, 62, 70], 3)?.unusual,
      isFalse,
    );
    expect(
      nightlyDifference(64, [58, 59, 60, 60, 61, 62, 70], 3)?.unusual,
      isTrue,
    );
  });

  test('breathing phase response needs enough paired cycles', () {
    expect(breathPhaseResponse({1: 82, 2: 80, 7: 74, 8: 76}), isNull);
    final phases = <int, double>{
      for (var cycle = 0; cycle < 4; cycle++)
        for (final second in [1, 2, 7, 8])
          cycle * 10 + second: second < 5 ? 82 : 76,
    };
    expect(breathPhaseResponse(phases), (delta: 6.0, cycles: 4));
  });

  test(
    'PLX parses normal and scaled values and rejects invalid flags and sentinels',
    () {
      expect(decodePulseOximetry([0, 98, 0, 72, 0], continuous: false), 98);
      expect(
        decodePulseOximetry([0, 0xD7, 0xF3, 72, 0], continuous: true),
        closeTo(98.3, .01),
      );
      expect(
        decodePulseOximetry([0, 0xff, 0x07, 72, 0], continuous: false),
        isNull,
      );
      expect(
        decodePulseOximetry([2, 98, 0, 72, 0, 0, 0x80], continuous: false),
        isNull,
      );
      expect(decodePulseOximetry([4, 98, 0, 72, 0], continuous: true), isNull);
    },
  );
}
