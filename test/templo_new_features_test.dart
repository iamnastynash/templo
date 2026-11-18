import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/day_label.dart';
import 'package:openstrap_edge/data/journal_fields.dart';
import 'package:openstrap_edge/ui2/screens/templo_insights.dart';
import 'package:openstrap_edge/ui2/screens/templo_oxygen.dart';
import 'package:openstrap_edge/ui2/screens/templo_today_layout.dart';

import 'support/live_guide_harness.dart';

class _JournalRepo extends GuideFakeRepo {
  List<String> tags = ['custom'];
  String note = 'Existing note';
  bool deleted = false;

  @override
  Future<List<Map<String, dynamic>>> getJournal({String range = '30d'}) async =>
      [
        if (!deleted)
          {
            'date': todayLabel(),
            'tags': [...tags],
            'note': note,
          },
      ];

  @override
  Future<List<JournalFieldSpec>> getJournalFields() async => [];

  @override
  Future<Map<String, JournalMetricValue>> getJournalMetrics(
    String date,
  ) async => {};

  @override
  Future<void> deleteJournal(String date) async {
    expect(date, todayLabel());
    deleted = true;
    tags.clear();
    note = '';
  }

  @override
  Future<void> postJournal(String date, List<String> tags, String note) async {
    expect(date, todayLabel());
    this.tags = tags;
    this.note = note;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'templo_new_features_test.db';
  });
  tearDownAll(LocalDb.close);

  testWidgets('a quick diary toggle preserves other labels and the note', (
    t,
  ) async {
    final repo = _JournalRepo();
    await pumpLiveGuideApp(t, home: const TemploQuickJournal(), repo: repo);
    await t.tap(find.widgetWithText(FilterChip, 'Café tarde'));
    await settleLiveGuide(t);
    expect(repo.tags, ['custom', 'late_caffeine']);
    expect(repo.note, 'Existing note');
    await t.tap(find.widgetWithText(FilterChip, 'Café tarde'));
    await settleLiveGuide(t);
    expect(repo.tags, ['custom']);
  });

  test(
    'deleting a journal entry removes its tags, note and metrics for that day',
    () async {
      const day = '2026-11-15', other = '2026-11-16';
      await LocalDb.putJournal(day, '["late_caffeine"]', 'note');
      await LocalDb.putJournal(other, '[]', 'keep');
      await LocalDb.putJournalMetrics(day, {
        'mood': const JournalMetricValue(3),
      });
      await LocalDb.deleteJournal(day);
      final rows = await LocalDb.journalRows(sinceDaysEpoch: day);
      expect(rows.map((row) => row['date']), [other]);
      expect(await LocalDb.journalMetricsForDay(day), isEmpty);
    },
  );

  testWidgets(
    'the diary editor confirms deletion and returns to a clean entry',
    (t) async {
      final repo = _JournalRepo();
      await pumpLiveGuideApp(
        t,
        locale: const Locale('es'),
        home: const TemploQuickJournal(),
        repo: repo,
      );
      await t.tap(find.text('Editar entrada de hoy'));
      await settleLiveGuide(t);
      await t.tap(find.text('Borrar entrada'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(repo.deleted, isFalse);
      await t.tap(find.text('Borrar entrada'));
      await t.pumpAndSettle();
      await t.tap(find.text('Borrar'));
      await settleLiveGuide(t);
      expect(repo.deleted, isTrue);
      expect(find.text('Editar entrada de hoy'), findsOneWidget);
    },
  );

  testWidgets('manual oxygen records the value and its source', (t) async {
    await pumpLiveGuideApp(t, home: const TemploOxygen());
    await t.tap(find.text('Anotar lectura manual'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '97,5');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('97.5%'), findsOneWidget);
    expect(find.text('97.5% · Oxímetro · entrada manual'), findsOneWidget);
  });

  testWidgets('hiding a Today card updates the running dashboard', (t) async {
    final app = await pumpLiveGuideApp(t, locale: const Locale('es'));
    expect(find.text('Pulso en vivo'), findsOneWidget);
    app.navigator.push(
      MaterialPageRoute<void>(builder: (_) => const TemploTodayLayout()),
    );
    await settleLiveGuide(t);
    await t.tap(find.widgetWithText(SwitchListTile, 'Pulso en vivo'));
    await t.pump();
    app.navigator.pop();
    await settleLiveGuide(t);
    expect(find.text('Pulso en vivo'), findsNothing);
    expect(find.text('RECUPERACIÓN'), findsOneWidget);
    TodayLayout.save(TodayLayout.defaults);
    await t.pump();
  });
}
