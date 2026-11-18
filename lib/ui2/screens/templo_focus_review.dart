import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../compute/pulso/focus.dart';
import '../../compute/pulso/insights.dart';
import '../../data/day_label.dart';
import '../../data/db.dart';
import '../../state/pulso_store.dart';
import '../skeleton/guide_plot.dart';
import '../ui2.dart';
import 'home_screen.dart' show repoOf;
import 'metric_detail.dart';
import 'templo_trade_editor.dart';

typedef _Marker = ({int time, String name, Color color});
typedef _SessionData = ({
  List<HrPt> pulse,
  List<TradeReview> trades,
  List<ResetResult> resets,
  double? baseline,
  double? load,
  int coverage,
  double? sleepMin,
});

Future<_SessionData> _analyze(
  FocusSession session, {
  required bool database,
  double? sleepMin,
}) async {
  final stop = session.end ?? session.start;
  final raw = <HrPt>[];
  final motion = <int, bool>{};
  if (database) {
    try {
      final rows = await LocalDb.onehzHrAccelBetween(
        session.start - 60,
        math.min(stop + 300, session.start + 12 * 3600 + 300),
        deviceId: LocalDb.kPrimaryDeviceId,
      );
      for (final row in rows) {
        final t = (row['rec_ts'] as num).toInt();
        final value = (row['hr'] as num).toDouble();
        if (!value.isFinite || value <= 0) continue;
        final x = row['ax'] as num, y = row['ay'] as num, z = row['az'] as num;
        final movement = (math.sqrt(x * x + y * y + z * z) - 1).abs();
        raw.add((t: t, v: value));
        motion[t] = movement <= .08;
      }
    } catch (_) {
      // The live recording still works when the band has yet to sync.
    }
  }
  final local = [for (final p in session.samples) if (p.t >= session.start && p.t <= stop) p]..sort((a, b) => a.t.compareTo(b.t));
  final synced = [
    for (final point in raw)
      if (point.t >= session.start && point.t <= stop) point,
  ];
  final useSynced =
      synced.length >= 30 &&
      pulseLoad(synced, 0, maxGap: 3).seconds >= (stop - session.start) * .65;
  final pulse = useSynced ? synced : local;
  final lead = [
    for (final point in raw)
      if (point.t < session.start && motion[point.t] == true) point.v,
  ];
  final initial = [
    for (final point in pulse)
      if (point.t < session.start + 60 &&
          (session.trades.firstOrNull?.start ?? stop) > point.t)
        point.v,
  ];
  final reset = PulsoStore.instance.resets;
  final pre = reset
      .where((r) => r.t + 60 <= session.start && r.t >= session.start - 300)
      .lastOrNull;
  final baseline = lead.length >= 20
      ? median(lead)
      : pre?.after ?? (initial.length >= 3 ? median(initial) : null);
  final integrated = pulseLoad(
    pulse,
    baseline ?? 0,
    maxGap: useSynced ? 3 : 35,
  );
  return (
    pulse: pulse,
    trades: [
      for (var i = 0; i < session.trades.length; i++)
        (() {
          final trade = session.trades[i];
          final review = reviewTrade(
            trade,
            raw,
            still: (t) => motion[t] == true,
            nextTradeStart: i + 1 < session.trades.length
                ? session.trades[i + 1].start
                : null,
          );
          final peak = trade.end == null
              ? null
              : windowStats(pulse, trade.start, trade.end! + 1).peak;
          return (
            entry: review.entry ?? trade.entryBpm,
            peak: review.peak ?? peak,
            recoverySeconds: review.recoverySeconds,
          );
        })(),
    ],
    resets: [
      ?pre,
      for (final r in reset)
        if (r.t >= session.start && r.t <= stop) r,
    ],
    baseline: baseline,
    load: baseline == null || integrated.seconds < 30 ? null : integrated.load,
    coverage: integrated.seconds,
    sleepMin: sleepMin,
  );
}

String _time(int seconds) =>
    DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
String _duration(int? seconds) => seconds == null
    ? '—'
    : seconds < 60
    ? '${seconds}s'
    : '${seconds ~/ 60}m ${seconds % 60}s';
String _bpm(double? value) => value == null ? '—' : '${value.round()} lpm';

class TemploSessionReview extends StatefulWidget {
  const TemploSessionReview(this.session, {super.key});
  final FocusSession session;
  @override
  State<TemploSessionReview> createState() => _TemploSessionReviewState();
}

class _TemploSessionReviewState extends State<TemploSessionReview> {
  Future<_SessionData>? _report;
  int? _selection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report ??= _analyze(widget.session, database: repoOf(context) != null);
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final s = widget.session;
    return detailScaffold(context, 'Revisión de sesión', [
      const SizedBox(height: S.x3),
      FutureBuilder<_SessionData>(
        future: _report,
        builder: (c, snapshot) {
          final d = snapshot.data;
          if (snapshot.hasError) {
            return const Text('No se pudo recalcular la sesión.');
          }
          if (d == null || snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          final marks = <_Marker>[
            for (final (i, trade) in s.trades.indexed) ...[
              (time: trade.start, name: '${i + 1}E', color: p.hi),
              if (trade.end != null)
                (time: trade.end!, name: '${i + 1}S', color: p.on(C.coral)),
            ],
            for (final reset in d.resets)
              if (reset.t >= s.start && reset.t <= (s.end ?? s.start))
                (time: reset.t, name: 'R', color: p.ink),
          ];
          final index = _selection;
          final selected = index != null && index < d.trades.length
              ? d.trades[index]
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_time(s.start)} – ${_time(s.end ?? s.start)}',
                style: F.t2.copyWith(color: p.ink),
              ),
              const SizedBox(height: S.x3),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARGA DE PULSO',
                      style: F.over.copyWith(color: p.ink3),
                    ),
                    Text(
                      d.load == null ? '—' : '${d.load!.round()} lpm·min',
                      style: F.n24.copyWith(color: p.ink),
                    ),
                    if (d.baseline != null)
                      Text(
                        'Referencia ${_bpm(d.baseline)} · ${_duration(d.coverage)} con señal',
                        style: F.cap.copyWith(color: p.ink3),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: S.x4),
              if (d.pulse.length > 1) ...[
                SizedBox(
                  height: 130,
                  child: CustomPaint(
                    painter: _PulseTimeline(
                      d.pulse,
                      marks,
                      s.start,
                      s.end ?? s.start,
                      p.on(C.coral),
                    ),
                  ),
                ),
                Text(
                  'E entrada · S salida · R reseteo',
                  style: F.cap.copyWith(color: p.ink3),
                ),
              ] else
                const Text(
                  'Todavía no hay una curva de pulso para esta sesión.',
                ),
              const SizedBox(height: S.x3),
              for (final reset in d.resets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.air),
                  title: Text(
                    '${reset.t < s.start ? 'Rutina previa' : 'Reseteo'} · ${_time(reset.t)}',
                  ),
                  subtitle: Text(
                    '${_bpm(reset.before)} → ${_bpm(reset.after)}',
                  ),
                ),
              if (s.trades.isNotEmpty) ...[
                const SizedBox(height: S.x3),
                Wrap(
                  spacing: S.x2,
                  children: [
                    for (final (i, trade) in s.trades.indexed)
                      ChoiceChip(
                        label: Text(
                          'Trade ${i + 1} · ${trade.result == 'win'
                              ? 'ganado'
                              : trade.result == 'loss'
                              ? 'perdido'
                              : 'sin marcar'}',
                        ),
                        selected: _selection == i,
                        onSelected: (_) => setState(() => _selection = i),
                      ),
                  ],
                ),
              ],
              if (selected != null) ...[
                const SizedBox(height: S.x2),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Trade ${_selection! + 1}',
                              style: F.head,
                            ),
                          ),
                          TradeActions(
                            session: s,
                            trade: s.trades[_selection!],
                            onChanged: () => setState(() {
                              _selection = null;
                              _report = _analyze(
                                s,
                                database: repoOf(context) != null,
                              );
                            }),
                          ),
                        ],
                      ),
                      Text('Entrada: ${_bpm(selected.entry)}'),
                      Text('Pico: ${_bpm(selected.peak)}'),
                      Text(
                        'Vuelta a tu nivel: ${_duration(selected.recoverySeconds)}',
                      ),
                      if (selected.recoverySeconds == null)
                        Text(
                          'Se necesita señal continua y poco movimiento antes y después de salir.',
                          style: F.cap.copyWith(color: p.ink3),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ]);
  }
}

class _PulseTimeline extends CustomPainter implements GuidePlot {
  const _PulseTimeline(
    this.points,
    this.marks,
    this.start,
    this.end,
    this.color,
  );
  final List<HrPt> points;
  final List<_Marker> marks;
  final int start, end;
  final Color color;

  @override
  Color get guideLineColor => color;

  @override
  void paint(Canvas canvas, Size size) {
    final min = points.map((p) => p.v).reduce(math.min);
    final max = points.map((p) => p.v).reduce(math.max);
    double x(int t) =>
        ((t - start) / math.max(1, end - start)).clamp(0, 1) * size.width;
    final path = Path();
    int? previous;
    for (final point in points) {
      final y =
          20 +
          (1 - (point.v - min) / math.max(1, max - min)) * (size.height - 25);
      if (previous == null || point.t - previous > 35) {
        path.moveTo(x(point.t), y);
      } else {
        path.lineTo(x(point.t), y);
      }
      previous = point.t;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final marker in marks) {
      final dx = x(marker.time);
      canvas.drawLine(
        Offset(dx, 17),
        Offset(dx, size.height),
        Paint()..color = marker.color.withValues(alpha: .55),
      );
      final label = TextPainter(
        text: TextSpan(
          text: marker.name,
          style: F.over.copyWith(color: marker.color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          (dx - label.width / 2).clamp(
            0,
            math.max(0, size.width - label.width),
          ),
          0,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulseTimeline oldDelegate) =>
      points != oldDelegate.points ||
      marks != oldDelegate.marks ||
      color != oldDelegate.color ||
      start != oldDelegate.start ||
      end != oldDelegate.end;
}

class TemploSessionComparisons extends StatefulWidget {
  const TemploSessionComparisons({super.key});

  @override
  State<TemploSessionComparisons> createState() =>
      _TemploSessionComparisonsState();
}

class _TemploSessionComparisonsState extends State<TemploSessionComparisons> {
  Future<List<({FocusSession session, _SessionData data})>>? _report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report ??= _load();
  }

  Future<List<({FocusSession session, _SessionData data})>> _load() async {
    final repo = repoOf(context);
    final week =
        DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch ~/
        1000;
    final sessions = PulsoStore.instance.sessions.reversed
        .where((s) => !s.open && s.start >= week)
        .take(30)
        .toList();
    final sleep = <String, double?>{};
    final out = <({FocusSession session, _SessionData data})>[];
    for (final session in sessions) {
      final day = dayLabelOf(
        DateTime.fromMillisecondsSinceEpoch(session.start * 1000),
      );
      if (repo != null && !sleep.containsKey(day)) {
        try {
          sleep[day] = ((await repo.getDaySleepV2(day))['duration_min'] as num?)
              ?.toDouble();
        } catch (_) {
          sleep[day] = null;
        }
      }
      out.add((
        session: session,
        data: await _analyze(
          session,
          database: repo != null,
          sleepMin: sleep[day],
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(
    BuildContext context,
  ) => detailScaffold(context, 'Comparar sesiones', [
    const SizedBox(height: S.x3),
    const Text(
      'Últimos 7 días · medianas y número de datos. Las coincidencias no explican el resultado de una operación.',
    ),
    const SizedBox(height: S.x3),
    FutureBuilder(
      future: _report,
      builder: (context, snapshot) {
        final rows = snapshot.data;
        if (rows == null) return const LinearProgressIndicator();
        final won = <TradeReview>[], lost = <TradeReview>[];
        final byDate = <String, ({int balance, List<double> pulses})>{};
        for (final row in rows) {
          final date = dayLabelOf(
            DateTime.fromMillisecondsSinceEpoch(row.session.start * 1000),
          );
          for (final (i, trade) in row.session.trades.indexed) {
            final outcome = trade.result;
            if (outcome != 'win' && outcome != 'loss') continue;
            final review = row.data.trades[i];
            (outcome == 'win' ? won : lost).add(review);
            final day = byDate[date] ?? (balance: 0, pulses: <double>[]);
            if (review.entry != null) day.pulses.add(review.entry!);
            byDate[date] = (
              balance: day.balance + (outcome == 'win' ? 1 : -1),
              pulses: day.pulses,
            );
          }
        }
        Iterable<double> loadWhere(
          bool Function(FocusSession, _SessionData) filter,
        ) => rows
            .where((r) => filter(r.session, r.data))
            .map((r) => r.data.load)
            .whereType<double>();
        final typicalSleep = median(
          rows.map((r) => r.data.sleepMin).whereType<double>(),
        );
        final resets = rows.expand((r) => r.data.resets).toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _compare(
              'Pulso de entrada (lpm)',
              'Ganados',
              'Perdidos',
              compareGroups(
                won.map((t) => t.entry).whereType<double>(),
                lost.map((t) => t.entry).whereType<double>(),
              ),
            ),
            _compare(
              'Vuelta al nivel previo (s)',
              'Ganados',
              'Perdidos',
              compareGroups(
                won.map((t) => t.recoverySeconds).whereType<int>(),
                lost.map((t) => t.recoverySeconds).whereType<int>(),
              ),
            ),
            _compare(
              'Pulso de entrada por día (lpm)',
              'Más trades ganados',
              'Más trades perdidos',
              compareGroups(
                byDate.values
                    .where((d) => d.balance > 0)
                    .map((d) => median(d.pulses))
                    .whereType<double>(),
                byDate.values
                    .where((d) => d.balance < 0)
                    .map((d) => median(d.pulses))
                    .whereType<double>(),
              ),
            ),
            _compare(
              'Carga de pulso (lpm·min)',
              'Trabajo',
              'Trading',
              compareGroups(
                loadWhere((s, _) => s.kind == FocusKind.trabajo),
                loadWhere((s, _) => s.kind == FocusKind.trading),
              ),
            ),
            if (typicalSleep != null)
              _compare(
                'Carga según horas de sueño',
                'Menos de tu mediana',
                'En tu mediana o más',
                compareGroups(
                  loadWhere(
                    (_, d) => d.sleepMin != null && d.sleepMin! < typicalSleep,
                  ),
                  loadWhere(
                    (_, d) => d.sleepMin != null && d.sleepMin! >= typicalSleep,
                  ),
                ),
              ),
            _compare(
              'Pulso alrededor del reseteo (lpm)',
              'Antes',
              'Después',
              compareGroups(
                resets.where((r) => r.drop != null).map((r) => r.before!),
                resets.where((r) => r.drop != null).map((r) => r.after!),
              ),
            ),
          ],
        );
      },
    ),
  ]);

  Widget _compare(String title, String a, String b, GroupComparison group) =>
      Padding(
        padding: const EdgeInsets.only(bottom: S.x2),
        child: Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: F.head),
              Text('$a · ${group.aMedian?.round() ?? '—'} · n=${group.aCount}'),
              Text('$b · ${group.bMedian?.round() ?? '—'} · n=${group.bCount}'),
            ],
          ),
        ),
      );
}
