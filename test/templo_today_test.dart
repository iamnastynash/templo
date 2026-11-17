import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/ui2/screens/home_screen.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

void main() {
  for (final hasData in [false, true]) {
    testWidgets('Today keeps its dashboard with data=$hasData', (tester) async {
      var openedActivity = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeScreen(
              onOpenActivity: () => openedActivity = true,
              data: hasData
                  ? const HomeData(
                      dayId: '2026-11-17',
                      readiness: Metric(
                        value: 78,
                        confidence: .9,
                        tier: MetricTier.high,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('Energy'.toUpperCase()), findsOneWidget);
      expect(find.text('STRAIN'), findsOneWidget);
      expect(find.text('SLEEP'), findsOneWidget);
      expect(find.text('78'), hasData ? findsOneWidget : findsNothing);
      expect(find.text('Your first weeks'), findsNothing);
      await tester.tap(find.text('Activity'));
      expect(openedActivity, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
