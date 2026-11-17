import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/compute/pulso/body_age.dart';
import 'package:openstrap_edge/compute/pulso/day_load.dart';
import 'package:openstrap_edge/compute/pulso/focus.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/state/pulso_store.dart';
import 'package:openstrap_edge/ui2/screens/screens.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

final _wake = DateTime(2026, 11, 17, 7).millisecondsSinceEpoch ~/ 1000;

PulsoDay _day() {
  // 07:00 wake; 09:00–11:30 still with HR 85 (stress); 18:00–18:50 moving at 140.
  final hr = <Pt>[
    for (var m = 0; m < 12 * 60; m++)
      (
        t: _wake + m * 60,
        v: (m >= 120 && m < 270)
            ? 85.0
            : (m >= 660 && m < 710)
                ? 140.0
                : 64.0,
      ),
  ];
  final act = <Pt>[
    for (var m = 0; m < 12 * 60; m += 5)
      (t: (_wake + m * 60) ~/ 300 * 300, v: (m >= 660 && m < 710) ? .7 : .05),
  ];
  return PulsoDay(
    readiness: 82,
    rhr: 55,
    age: 34,
    hr: hr,
    activity: act,
    sleep: [(onset: _wake - 8 * 3600, wake: _wake)],
    workouts: [(start: _wake + 660 * 60, end: _wake + 710 * 60, name: 'Carrera')],
    now: _wake + 12 * 3600,
    sleepMin: 450,
    sleepNeedMin: 470,
  );
}

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.dark),
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: w),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => PulsoStore.instance.resetForTest());

  testWidgets('Energía starts at recovery and shows the events', (t) async {
    await _pump(t, EnergyScreen(data: _day()));
    expect(find.textContaining('Al despertar · tu recuperación'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.textContaining('Carrera'), findsOneWidget);
    expect(find.byType(GlowLine), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Carga de hoy splits effort and stress', (t) async {
    await _pump(t, LoadScreen(data: _day()));
    expect(find.textContaining('esfuerzo bueno'), findsWidgets);
    expect(find.textContaining('Estrés · 2h 30m'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Hoy card: energy, effort share and a consejo', (t) async {
    await _pump(t, SingleChildScrollView(child: PulsoTodayCard(data: _day())));
    expect(find.text('ENERGÍA'), findsOneWidget);
    expect(find.text('ESFUERZO BUENO'), findsOneWidget);
    expect(find.textContaining('estrés', findRichText: true), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Edad del cuerpo with and without enough data', (t) async {
    await _pump(
        t,
        BodyAgeScreen(
            data: bodyAge(age: 34, rhr: 52, rmssd: 62, vo2max: 48, sleepHours: 7.3,
                sleepMidpointSdHours: 1.1, exerciseMinPerWeek: 120, stress: 30)));
    expect(find.textContaining('Tienes 34'), findsOneWidget);
    expect(find.textContaining('Regularidad del sueño'), findsOneWidget);
    await _pump(t, BodyAgeScreen(key: UniqueKey(), data: bodyAge(age: null, rhr: 52)));
    expect(find.text('Sin estimación'), findsOneWidget);
  });

  testWidgets('Enfoque: start trading, open and close a trade, mark it',
      (t) async {
    await _pump(t, const FocusTab());
    expect(find.text('Trading'), findsWidgets);
    final s = PulsoStore.instance.start(FocusKind.trading, _wake);
    await _pump(t, FocusLiveScreen(s));
    await t.tap(find.text('Entré en un trade'));
    await t.pump();
    expect(find.text('Salí del trade'), findsOneWidget);
    await t.tap(find.text('Salí del trade'));
    await t.pump();
    await t.tap(find.text('Ganada'));
    await t.pump();
    expect(s.trades.single.result, 'win');
    expect(s.trades.single.end, isNotNull);
    await t.pumpWidget(const SizedBox()); // dispose the 1 s timer
  });

  testWidgets('Summary without band data says so, never a number', (t) async {
    final s = FocusSession('x', FocusKind.trading, _wake, end: _wake + 3600);
    await _pump(t, FocusSummaryScreen(s, day: _day()));
    // The day's HR covers the window, so there is a figure, and the lock card.
    expect(find.textContaining('de $kInsightTrades'), findsOneWidget);
    final empty = FocusSession('y', FocusKind.trabajo, _wake - 30 * 3600, end: _wake - 29 * 3600);
    await _pump(t, FocusSummaryScreen(empty, key: UniqueKey(), day: _day()));
    expect(find.text('Sin pulso'), findsOneWidget);
  });

  testWidgets('Reseteo shows its button and runs without a band', (t) async {
    await _pump(t, const ResetScreen());
    expect(find.text('Empezar reseteo'), findsOneWidget);
    await t.tap(find.text('Empezar reseteo'));
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Parar'), findsOneWidget);
    await t.tap(find.text('Parar'));
    await t.pump();
    await t.pumpWidget(const SizedBox());
  });
}
