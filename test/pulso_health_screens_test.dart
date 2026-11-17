import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/compute/pulso/cardio_score.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

final _today = DateTime(2026, 11, 17);

List<Reading> _days(List<double> v) => [
      for (var i = 0; i < v.length; i++)
        (
          t: DateTime(_today.year, _today.month, _today.day - (v.length - 1 - i), 4)
                  .millisecondsSinceEpoch ~/
              1000,
          v: v[i],
        ),
    ];

List<double> _ramp(double a, double b, int n, {double wobble = 0}) => [
      for (var i = 0; i < n; i++)
        a + (b - a) * i / (n - 1) + (i.isEven ? wobble : -wobble),
    ];

Future<void> _pump(WidgetTester t, Widget w, {Brightness b = Brightness.light}) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: buildTheme(b),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: w,
  ));
  await t.pumpAndSettle();
}

void main() {
  final full = {
    'rhr': _days(_ramp(58, 52, 84, wobble: .6)),
    'rmssd': _days(_ramp(52, 62, 84, wobble: 2)),
    'dip_pct': _days(_ramp(11, 14, 84, wobble: 1)),
    'hrr_bpm': _days([12, 10, 11, 12]),
  };

  testWidgets('Salud cardiovascular: score, trend word and five rows',
      (t) async {
    await _pump(t, CardioScreen(series: full, today: _today));
    final r = cardioScore(full, _today);
    expect(find.text('${r.score}'), findsOneWidget);
    expect(
        find.text(switch (r.direction) {
          1 => 'Mejorando',
          -1 => 'Bajando',
          _ => 'Estable',
        }),
        findsOneWidget);
    for (final n in ['Pulso en reposo', 'HRV nocturna', 'Consistencia del pulso',
        'Caída nocturna', 'Recuperación tras esfuerzo']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.byType(GlowLine), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Salud cardiovascular: a few nights → learning, no number',
      (t) async {
    await _pump(
        t,
        CardioScreen(series: {
          'rhr': _days([55, 54, 56, 55]),
          'rmssd': _days([58, 60, 57, 61]),
        }, today: _today));
    expect(find.textContaining('Aprendiendo'), findsOneWidget);
    expect(find.textContaining('4 de 7 noches'), findsOneWidget);
    expect(find.text('Sin entrenamientos en los últimos 14 días.'), findsOneWidget);
  });

  testWidgets('Tendencia: verdict per metric, sleep included', (t) async {
    await _pump(
        t,
        TrendScreen(series: {
          'resting_hr': _days(_ramp(56, 52, 56, wobble: .4)),
          'hrv': _days(_ramp(54, 62, 56, wobble: 1.5)),
          'sleep': _days(_ramp(430, 440, 56, wobble: 20)),
        }, today: _today));
    expect(find.text('Mejorando'), findsOneWidget);
    expect(find.textContaining('pulso en reposo'), findsOneWidget);
    expect(find.byType(GlowLine), findsNWidgets(3));
  });

  testWidgets('Tendencia: no data says so', (t) async {
    await _pump(t, TrendScreen(series: const {}, today: _today));
    expect(find.text('Faltan datos'), findsOneWidget);
    expect(find.byType(GlowLine), findsNothing);
  });
}

