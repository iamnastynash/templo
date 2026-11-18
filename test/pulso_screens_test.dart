import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:openstrap_edge/compute/pulso/body_age.dart';
import 'package:openstrap_edge/compute/pulso/day_load.dart';
import 'package:openstrap_edge/compute/pulso/focus.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/state/pulso_store.dart';
import 'package:openstrap_edge/state/app_state.dart';
import 'package:openstrap_edge/theme/theme_controller.dart';
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
  await t.pumpWidget(ChangeNotifierProvider(
    create: (_) => ThemeController.seed(AppThemeChoice.dark, Brightness.dark),
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: w),
    ),
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
    await t.tap(find.text('Entré en un trade'));
    await t.pump();
    final finish = find.text('Terminar');
    expect(t.getSize(finish).width, greaterThan(44));
    await t.tap(finish);
    await t.pumpAndSettle();
    expect(s.end, isNotNull);
    expect(s.trades.last.end, s.end);
    expect(find.byType(FocusSummaryScreen), findsOneWidget);
  });

  testWidgets('Trading can edit and discard an accidental open trade', (t) async {
    final s = PulsoStore.instance.start(FocusKind.trading, _wake);
    await _pump(t, FocusLiveScreen(s));
    await t.tap(find.text('Entré en un trade'));
    await t.pump();
    await t.tap(find.byTooltip('Opciones de la operación'));
    await t.pumpAndSettle();
    await t.tap(find.text('Editar trade'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '00:00:01');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect(s.openTrade?.start, _wake + 1);

    await t.tap(find.text('Descartar trade'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(s.openTrade, isNotNull);
    await t.tap(find.text('Descartar trade'));
    await t.pumpAndSettle();
    await t.tap(find.text('Descartar'));
    await t.pumpAndSettle();
    expect(s.trades, isEmpty);
    expect(s.open, isTrue);
    expect(find.text('Entré en un trade'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a closed trade has visible edit and delete actions during Trading', (t) async {
    final store = PulsoStore.instance;
    final session = store.start(FocusKind.trading, _wake);
    store.openTrade(session, _wake + 10, null);
    store.closeTrade(session, _wake + 30);
    await _pump(t, FocusLiveScreen(session));
    expect(find.text('Operaciones de esta sesión'), findsOneWidget);
    expect(find.text('Trade #1'), findsOneWidget);
    await t.tap(find.byTooltip('Opciones de la operación'));
    await t.pumpAndSettle();
    expect(find.text('Editar trade'), findsOneWidget);
    await t.tap(find.text('Eliminar trade'));
    await t.pumpAndSettle();
    await t.tap(find.text('Eliminar'));
    await t.pumpAndSettle();
    expect(session.trades, isEmpty);
    expect(session.open, isTrue);
    expect(find.text('Entré en un trade'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  test('editing a closed trade rejects overlap and preserves the other trades', () {
    final store = PulsoStore.instance;
    final session = store.start(FocusKind.trading, 100);
    store.openTrade(session, 110, 5, bpm: 75);
    store.closeTrade(session, 120);
    store.openTrade(session, 130, 6, bpm: 76);
    store.end(session, 150);
    final first = session.trades.first;
    expect(store.editTrade(session, first, start: 110, end: 140, result: 'loss', now: 160), isFalse);
    expect(store.editTrade(session, first, start: 115, end: 125, result: 'loss', now: 160), isTrue);
    expect(session.trades.first.result, 'loss');
    expect(session.trades.first.entryBpm, isNull);
    expect(session.trades.last.start, 130);
  });

  testWidgets('a saved session can be edited in its summary and deleted by swiping', (t) async {
    final store = PulsoStore.instance;
    for (var i = 0; i < 3; i++) {
      final past = store.start(FocusKind.trading, _wake + i * 120);
      store.end(past, past.start + 60);
    }
    final latest = store.start(FocusKind.trading, _wake + 360);
    store.end(latest, latest.start + 60);
    await _pump(t, const FocusTab());
    expect(find.text('Respiración guiada'), findsOneWidget);
    expect(find.text('60 s'), findsOneWidget);

    final row = find.byKey(ObjectKey(latest));
    await t.drag(find.byType(ListView), const Offset(0, -380));
    await t.pumpAndSettle();
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.text('Eliminar sesión'), findsOneWidget);
    await t.tap(find.text('Editar sesión'));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    final originalEnd = latest.end!;
    final end = t.widget<TextField>(fields.last).controller!.text;
    await t.enterText(fields.last, '${end.substring(0, end.length - 2)}15');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect(latest.end, originalEnd + 15);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    await t.ensureVisible(row);
    await t.pumpAndSettle();
    await t.drag(row, const Offset(-230, 0));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: row, matching: find.text('Eliminar')));
    await t.pumpAndSettle();
    expect(find.text('¿Eliminar sesión?'), findsOneWidget);
    await t.tap(find.text('Eliminar sesión'));
    await t.pumpAndSettle();
    expect(store.sessions, hasLength(3));
    expect(store.sessions, isNot(contains(latest)));
  });

  testWidgets('Trading uses lime for a live reading and clears stale data', (t) async {
    final app = AppState.forTesting();
    addTearDown(app.dispose);
    final s = PulsoStore.instance.start(FocusKind.trading, _wake);
    await _pump(t, ChangeNotifierProvider<AppState>.value(
      value: app, child: FocusLiveScreen(s),
    ));
    app.device
      ..connection = 'connected'
      ..liveHr = 78
      ..liveHrAt = DateTime.now().millisecondsSinceEpoch;
    await t.pump(const Duration(seconds: 1));
    final value = find.text('78');
    expect(t.widget<Text>(value).style?.color, C.lime);
    expect(find.text('Pulso en vivo'), findsOneWidget);

    app.device.liveHrAt = DateTime.now()
        .subtract(AppState.liveHrMaxAge + const Duration(seconds: 1))
        .millisecondsSinceEpoch;
    await t.pump(const Duration(seconds: 1));
    expect(value, findsNothing);
    expect(find.text('Sin pulso en vivo'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
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

  testWidgets('the one-minute routine leads into Trading after completion', (t) async {
    await _pump(t, const ResetScreen());
    expect(find.text('Empezar Trading'), findsNothing);
    await t.tap(find.text('Empezar respiración'));
    await t.pump(const Duration(seconds: 60));
    await t.pumpAndSettle();
    expect(PulsoStore.instance.resets, hasLength(1));
    await t.scrollUntilVisible(find.text('Empezar Trading'), 140);
    await t.tap(find.text('Empezar Trading'));
    await t.pumpAndSettle();
    expect(find.byType(FocusLiveScreen), findsOneWidget);
    expect(PulsoStore.instance.active?.kind, FocusKind.trading);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Reseteo shows its button and runs without a band', (t) async {
    await _pump(t, const ResetScreen());
    expect(find.text('Empezar respiración'), findsOneWidget);
    await t.tap(find.text('Empezar respiración'));
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Parar'), findsOneWidget);
    await t.tap(find.text('Parar'));
    await t.pump();
    await t.pumpWidget(const SizedBox());
  });
}
