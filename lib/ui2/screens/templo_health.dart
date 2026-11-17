import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../profile/profile.dart';
import '../ui2.dart';
import 'health_screen.dart';
import 'home_screen.dart' show go, pad;
import 'pulso_day.dart';
import 'pulso_health.dart';

class TemploHealth extends StatelessWidget {
  const TemploHealth({super.key});

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    return ListView(
      padding: pad,
      children: [
        ScreenTitle(
          AppLocalizations.of(context)?.healthTitle ?? 'Health',
          trailing: const ProfileAvatar(accent: C.coral),
        ),
        const SizedBox(height: S.x3),
        for (final (title, subtitle, icon, destination) in [
          (
            es ? 'Salud cardiovascular' : 'Cardiovascular health',
            es
                ? 'Pulso en reposo, HRV y recuperación'
                : 'Resting heart rate, HRV and recovery',
            LucideIcons.heartPulse,
            const CardioScreen(),
          ),
          (
            es ? 'Edad del cuerpo' : 'Body age',
            es
                ? 'Una estimación según tus hábitos'
                : 'An estimate based on your habits',
            kBodyAgeIcon,
            const BodyAgeScreen(),
          ),
          (
            es ? 'Tendencia' : 'Trend',
            es
                ? 'Pulso, HRV y sueño · 8 semanas'
                : 'Heart rate, HRV and sleep · 8 weeks',
            LucideIcons.trendingUp,
            const TrendScreen(),
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: S.x2),
            child: Surface(
              onTap: () => go(context, destination),
              semanticLabel: title,
              child: Row(
                children: [
                  Icon(icon, color: p.on(C.coral), size: 21),
                  const SizedBox(width: S.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: F.head.copyWith(color: p.ink)),
                        Text(subtitle, style: F.cap.copyWith(color: p.ink3)),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, color: p.ink3, size: 18),
                ],
              ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => go(
              context,
              Scaffold(appBar: AppBar(), body: const HealthScreen()),
            ),
            child: Text(es ? 'Todas las métricas' : 'All metrics'),
          ),
        ),
      ],
    );
  }
}
