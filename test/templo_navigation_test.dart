import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/live_guide_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'templo_navigation_test.db';
  });
  tearDownAll(LocalDb.close);

  for (final brightness in Brightness.values) {
    testWidgets('main tabs use the Templo layouts in ${brightness.name}', (
      tester,
    ) async {
      final app = await pumpLiveGuideApp(
        tester,
        brightness: brightness,
        locale: const Locale('es'),
      );

      expect(find.text('RECUPERACIÓN'), findsOneWidget);
      expect(find.text('Pulso en vivo'), findsOneWidget);
      expect(app.state.debugLiveOwners.visibleLiveHrView, isTrue);
      app.state.device
        ..connection = 'connected'
        ..liveHr = 72
        ..liveHrAt = DateTime.now().millisecondsSinceEpoch;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('72 lpm'), findsOneWidget);
      app.state.device.liveHrAt = DateTime.now()
          .subtract(AppState.liveHrMaxAge + const Duration(seconds: 1))
          .millisecondsSinceEpoch;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('72 lpm'), findsNothing);
      await tester.tap(find.byTooltip('Sueño'));
      await settleLiveGuide(tester);
      expect(app.state.debugLiveOwners.visibleLiveHrView, isFalse);
      expect(find.text('7:00'), findsOneWidget);
      expect(find.text('Detalle, plan y alarma'), findsOneWidget);

      await tester.tap(find.byTooltip('Enfoque'));
      await settleLiveGuide(tester);
      expect(find.text('Empezar'), findsNWidgets(2));
      expect(find.text('60 s'), findsOneWidget);

      await tester.tap(find.byTooltip('Salud'));
      await settleLiveGuide(tester);
      expect(find.text('Salud cardiovascular'), findsOneWidget);
      expect(find.text('Edad del cuerpo'), findsOneWidget);
      expect(find.text('Tendencia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
