import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../ui2.dart';
import 'home_screen.dart' show go;
import 'metric_detail.dart';

class TemploLivePulse extends StatefulWidget {
  const TemploLivePulse({super.key});

  @override
  State<TemploLivePulse> createState() => _TemploLivePulseState();
}

typedef _Reading = ({int? bpm, bool paired, bool connected});

class _TemploLivePulseState extends State<TemploLivePulse> {
  AppState? _owner;
  Timer? _refresh;
  _Reading _reading = (bpm: null, paired: false, connected: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled && (ModalRoute.isCurrentOf(context) ?? true);
    final app = visible ? context.read<AppState?>() : null;
    if (identical(app, _owner)) return;
    _stop();
    _owner = app;
    if (app == null) return;

    app.retainLiveHrView();
    _reading = _read(app);
    // Recheck freshness even when an interrupted stream sends no new event.
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      final reading = _read(app);
      if (reading != _reading) setState(() => _reading = reading);
    });
  }

  _Reading _read(AppState app) =>
      (bpm: app.liveHr, paired: app.isPaired, connected: app.isConnected);

  void _stop() {
    _refresh?.cancel();
    _refresh = null;
    _owner?.releaseLiveHrView();
    _owner = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final l = AppLocalizations.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final label = es ? 'Pulso en vivo' : 'Live heart rate';
    final reading = _reading;
    final bpm = reading.bpm;
    final status = bpm != null
        ? null
        : !reading.paired
        ? l?.liveHrNotPairedWhy ?? 'No band is paired.'
        : !reading.connected
        ? l?.liveHrNotConnectedWhy ?? 'Your band is not connected.'
        : es
        ? 'Esperando señal de la banda'
        : 'Waiting for a signal from the band';
    final value = bpm == null ? '—' : '$bpm ${es ? 'lpm' : 'bpm'}';

    return Surface(
      onTap: _owner == null
          ? null
          : () => go(context, const MetricDetail('resting_hr')),
      semanticLabel: '$label, ${status ?? value}',
      child: Row(
        children: [
          Icon(LucideIcons.heartPulse, size: 20, color: p.on(C.coral)),
          const SizedBox(width: S.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: F.head.copyWith(color: p.ink)),
                if (status != null)
                  Text(status, style: F.cap.copyWith(color: p.ink3)),
              ],
            ),
          ),
          const SizedBox(width: S.x2),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: F.n24.copyWith(color: p.ink),
            ),
          ),
          const SizedBox(width: S.x1),
          Icon(LucideIcons.chevronRight, size: 16, color: p.ink3),
        ],
      ),
    );
  }
}
