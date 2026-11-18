import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../ui2.dart';
import 'home_screen.dart' show HomeData, hm, go;
import 'pulso_day.dart';
import 'templo_live_pulse.dart';
import 'templo_today_layout.dart';
import 'templo_insights.dart';

class TemploToday extends StatelessWidget {
  const TemploToday({
    super.key,
    required this.date,
    required this.data,
    required this.revision,
    required this.status,
    required this.onRecovery,
    required this.onStrain,
    required this.onSleep,
    required this.onHistory,
    required this.onActivity,
    this.bandAction,
  });

  final String date;
  final HomeData? data;
  final Object? revision;
  final Widget? status;
  final ({String label, IconData icon, VoidCallback onTap})? bandAction;
  final VoidCallback onRecovery, onStrain, onSleep, onHistory, onActivity;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final l = AppLocalizations.of(context);
    final recovery = data?.readiness.value;
    final strain = data?.strain.value;
    final sleep = data?.sleepMin.value;
    final cards = <TodayTile, Widget>{
      TodayTile.pulse: const TemploLivePulse(),
      TodayTile.recovery: Semantics(
        button: true,
        child: Pressable(
          onTap: onRecovery,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  es ? 'RECUPERACIÓN' : 'RECOVERY',
                  style: F.over.copyWith(color: p.ink3),
                ),
                Text(
                  recovery?.toStringAsFixed(0) ?? '—',
                  style: F.hero.copyWith(color: p.ink, fontSize: 96, height: 1),
                ),
                if (recovery == null)
                  Text(
                    es
                        ? 'A la espera de tu primera recuperación'
                        : 'Waiting for your recovery score',
                    style: F.body.copyWith(color: p.ink3),
                  ),
              ],
            ),
          ),
        ),
      ),
      TodayTile.energy: PulsoTodayCard(key: ValueKey(revision), summary: true),
      TodayTile.strain: _stat(
        context,
        TodayTile.strain.label(context).toUpperCase(),
        strain == null ? '—' : '${strain.toStringAsFixed(1)} / 21',
        onStrain,
      ),
      TodayTile.sleep: _stat(
        context,
        TodayTile.sleep.label(context).toUpperCase(),
        sleep == null ? '—' : hm(sleep.toDouble()),
        onSleep,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(date, style: F.cap.copyWith(color: p.ink3)),
            ),
            PopupMenuButton<VoidCallback>(
              tooltip: es ? 'Opciones de Hoy' : 'Today options',
              position: PopupMenuPosition.under,
              color: p.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: R.rLg,
                side: BorderSide(color: p.line),
              ),
              icon: Icon(LucideIcons.ellipsis, size: 18, color: p.ink3),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                if (bandAction case final band?)
                  _todayAction(band.icon, band.label, band.onTap),
                _todayAction(
                  LucideIcons.calendarDays,
                  es ? 'Historial y detalles' : 'History and details',
                  onHistory,
                ),
                _todayAction(
                  LucideIcons.dumbbell,
                  l?.tabActivity ?? 'Activity',
                  onActivity,
                ),
                _todayAction(
                  LucideIcons.notebookPen,
                  es ? 'Diario rápido' : 'Quick journal',
                  () => go(context, const TemploQuickJournal()),
                ),
              ],
            ),
          ],
        ),
        if (status != null) status!,
        const SizedBox(height: S.x3),
        ValueListenableBuilder(
          valueListenable: TodayLayout.value,
          builder: (context, settings, _) {
            final shown = [
              for (final s in settings)
                if (s.visible) s.tile,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: S.x3),
                  if (shown[i] == TodayTile.strain &&
                      i + 1 < shown.length &&
                      shown[i + 1] == TodayTile.sleep)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[shown[i]]!),
                        const SizedBox(width: S.x2),
                        Expanded(child: cards[shown[++i]]!),
                      ],
                    )
                  else
                    cards[shown[i]]!,
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  PopupMenuItem<VoidCallback> _todayAction(
    IconData icon,
    String label,
    VoidCallback action,
  ) => PopupMenuItem(
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: S.x3),
        Flexible(child: Text(label)),
      ],
    ),
  );

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    final p = P.of(context);
    return Surface(
      onTap: onTap,
      semanticLabel: '$label, $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: F.over.copyWith(color: p.ink3)),
          Text(value, style: F.head.copyWith(color: p.ink)),
        ],
      ),
    );
  }
}
