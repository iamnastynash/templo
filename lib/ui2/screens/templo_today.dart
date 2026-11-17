import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../profile/profile.dart';
import '../ui2.dart';
import 'home_screen.dart' show HomeData, hm;
import 'pulso_day.dart';
import 'templo_live_pulse.dart';

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
  });

  final String date;
  final HomeData? data;
  final Object? revision;
  final Widget? status;
  final VoidCallback onRecovery, onStrain, onSleep, onHistory, onActivity;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final l = AppLocalizations.of(context);
    final recovery = data?.readiness.value;
    final strain = data?.strain.value;
    final sleep = data?.sleepMin.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(date, style: F.cap.copyWith(color: p.ink3)),
            ),
            const ProfileAvatar(accent: C.domHome),
          ],
        ),
        const SizedBox(height: S.x3),
        const TemploLivePulse(),
        const SizedBox(height: S.x4),
        Semantics(
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
                    style: F.hero.copyWith(
                      color: p.ink,
                      fontSize: 96,
                      height: 1,
                    ),
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
        const SizedBox(height: S.x4),
        PulsoTodayCard(
          key: ValueKey(revision),
          summary: true,
          afterEnergy: Padding(
            padding: const EdgeInsets.only(top: S.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _stat(
                    context,
                    es ? 'ESFUERZO' : 'STRAIN',
                    strain == null ? '—' : '${strain.toStringAsFixed(1)} / 21',
                    onStrain,
                  ),
                ),
                const SizedBox(width: S.x2),
                Expanded(
                  child: _stat(
                    context,
                    (l?.tabSleep ?? 'Sleep').toUpperCase(),
                    sleep == null ? '—' : hm(sleep.toDouble()),
                    onSleep,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (status != null) ...[const SizedBox(height: S.x4), status!],
        const SizedBox(height: S.x2),
        Wrap(
          spacing: S.x3,
          children: [
            TextButton(
              onPressed: onHistory,
              child: Text(es ? 'Historial y detalles' : 'History and details'),
            ),
            TextButton(
              onPressed: onActivity,
              child: Text(l?.tabActivity ?? 'Activity'),
            ),
          ],
        ),
      ],
    );
  }

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
