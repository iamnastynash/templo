import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../compute/pulso/insights.dart';
import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../../gps/route_models.dart';
import '../../gps/route_math.dart' show haversineMeters;
import '../../l10n/display_text.dart' show kTemploQuickTags;
import '../ui2.dart';
import 'home_screen.dart' show go, repoOf;
import 'journal_compose.dart';
import 'metric_detail.dart';

DateTime _epoch(int timestamp) =>
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
String _fmt(double value) =>
    '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(1)}';

Future<Map<String, double>> _dailySeries(
  LocalRepository repo,
  String key,
) async {
  final data = await repo.getChart(key);
  return {
    for (final p in (data['points'] as List?) ?? const [])
      if (p is Map && p['t'] is num && p['v'] is num)
        dayLabelOf(_epoch((p['t'] as num).toInt())): (p['v'] as num).toDouble(),
  };
}

class TemploQuickJournal extends StatefulWidget {
  const TemploQuickJournal({super.key});
  @override
  State<TemploQuickJournal> createState() => _TemploQuickJournalState();
}

class _TemploQuickJournalState extends State<TemploQuickJournal> {
  Future<({List<Map<String, dynamic>> journal, Map<String, double> sleep})>?
  _data;
  bool _writing = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<({List<Map<String, dynamic>> journal, Map<String, double> sleep})>
  _load() async {
    final repo = repoOf(context);
    if (repo == null)
      return (journal: <Map<String, dynamic>>[], sleep: <String, double>{});
    return (
      journal: await repo.getJournal(range: '90d'),
      sleep: await _dailySeries(repo, 'sleep'),
    );
  }

  Future<void> _toggle(String tag) async {
    final repo = repoOf(context);
    if (repo == null || _writing) return;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      final date = todayLabel();
      // Read the latest entry so a quick label preserves the note and any
      // other labels already written by the full journal.
      final journal = await repo.getJournal();
      final today = journal.where((row) => row['date'] == date).firstOrNull;
      final tags = ((today?['tags'] as List?) ?? const [])
          .whereType<String>()
          .toSet();
      if (!tags.add(tag)) tags.remove(tag);
      await repo.postJournal(
        date,
        tags.toList(),
        today?['note'] as String? ?? '',
      );
      if (mounted)
        setState(() {
          _data = _load();
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar la etiqueta.');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _openEntry([String? date]) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => JournalCompose(date: date)));
    if (mounted)
      setState(() {
        _data = _load();
      });
  }

  Future<void> _pickEntry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (mounted && date != null) await _openEntry(dayLabelOf(date));
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return detailScaffold(context, 'Diario rápido', [
      const SizedBox(height: S.x3),
      if (_error != null) Text(_error!),
      FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Text('No se pudo leer tu diario.');
          final data = snapshot.data;
          if (data == null) return const LinearProgressIndicator();
          final today = todayLabel();
          final journal = data.journal;
          final current = journal.where((r) => r['date'] == today).firstOrNull;
          final selected = ((current?['tags'] as List?) ?? const []).toSet();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('HOY', style: F.over.copyWith(color: p.ink3)),
              Wrap(
                spacing: S.x2,
                children: [
                  for (final tag in kTemploQuickTags.entries)
                    FilterChip(
                      label: Text(tag.value.$1),
                      selected: selected.contains(tag.key),
                      onSelected: _writing ? null : (_) => _toggle(tag.key),
                    ),
                ],
              ),
              const SizedBox(height: S.x4),
              TextButton(
                onPressed: _writing ? null : () => _openEntry(today),
                child: const Text('Editar entrada de hoy'),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Entradas anteriores'),
                children: [
                  for (final row in journal)
                    if (row['date'] case final String date when date != today)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(date),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _writing ? null : () => _openEntry(date),
                      ),
                  TextButton(
                    onPressed: _writing ? null : _pickEntry,
                    child: const Text('Buscar por fecha'),
                  ),
                ],
              ),
              const SizedBox(height: S.x3),
              Text(
                'CÓMO DORMISTE DESPUÉS',
                style: F.over.copyWith(color: p.ink3),
              ),
              const SizedBox(height: S.x2),
              const Text(
                'Se comparan noches posteriores a días con una entrada en el diario. Un día sin registrar queda fuera.',
              ),
              const SizedBox(height: S.x3),
              for (final tag in kTemploQuickTags.entries)
                _journalComparison(tag.key, tag.value.$1, journal, data.sleep),
            ],
          );
        },
      ),
    ]);
  }

  Widget _journalComparison(
    String key,
    String label,
    List<Map<String, dynamic>> journal,
    Map<String, double> sleep,
  ) {
    final tagged = <double>[], untagged = <double>[];
    for (final row in journal) {
      final day = DateTime.tryParse(row['date'] as String? ?? '');
      if (day == null) continue;
      final next = dayLabelOf(DateTime(day.year, day.month, day.day + 1));
      final minutes = sleep[next];
      if (minutes == null) continue;
      final tags = (row['tags'] as List?) ?? const [];
      (tags.contains(key) ? tagged : untagged).add(minutes);
    }
    final group = compareGroups(tagged, untagged);
    final enough = group.aCount >= 3 && group.bCount >= 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x2),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: F.head),
            Text(
              enough
                  ? '${group.aMedian!.round()} min con marca · ${group.bMedian!.round()} min sin marca'
                  : 'Aún no hay tres noches en cada grupo',
            ),
            Text('${group.aCount} con marca · ${group.bCount} sin marca'),
          ],
        ),
      ),
    );
  }
}

class TemploNight extends StatefulWidget {
  const TemploNight({super.key});
  @override
  State<TemploNight> createState() => _TemploNightState();
}

typedef _NightResult = ({
  String date,
  List<({String label, String unit, double delta, bool unusual})> metrics,
});

class _TemploNightState extends State<TemploNight> {
  Future<_NightResult?>? _summary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _summary ??= _load();
  }

  Future<_NightResult?> _load() async {
    final repo = repoOf(context);
    if (repo == null) return null;
    final windows = await repo.sleepWindows(days: 35);
    final nights = {
      for (final row in windows)
        if (row['date'] is String && row['onset_ts'] is num)
          row['date'] as String: (row['onset_ts'] as num).toInt(),
    };
    final dates = nights.keys.toList()..sort();
    if (dates.isEmpty) return null;
    final date = dates.last;
    final previous = dates.reversed.skip(1).take(28).toSet();
    double bedtime(int epoch) {
      final time = _epoch(epoch);
      // Anchor the clock at noon so midnight stays continuous.
      return ((time.hour + 12) % 24) * 60.0 + time.minute;
    }

    final series =
        <
          ({
            String label,
            String unit,
            double floor,
            Map<String, double> values,
          })
        >[
          (
            label: 'Pulso en reposo',
            unit: 'lpm',
            floor: 3,
            values: await _dailySeries(repo, 'resting_hr'),
          ),
          (
            label: 'Variabilidad cardíaca',
            unit: 'ms',
            floor: 5,
            values: await _dailySeries(repo, 'hrv'),
          ),
          (
            label: 'Respiración nocturna',
            unit: 'resp/min',
            floor: 1,
            values: await _dailySeries(repo, 'resp_rate'),
          ),
          (
            label: 'Hora de acostarte',
            unit: 'min',
            floor: 30,
            values: nights.map((d, t) => MapEntry(d, bedtime(t))),
          ),
        ];
    final results =
        <({String label, String unit, double delta, bool unusual})>[];
    for (final s in series) {
      final comparison = nightlyDifference(
        s.values[date],
        previous.map((day) => s.values[day]).whereType<double>(),
        s.floor,
      );
      if (comparison != null) {
        results.add((
          label: s.label,
          unit: s.unit,
          delta: comparison.delta,
          unusual: comparison.unusual,
        ));
      }
    }
    return (date: date, metrics: results);
  }

  @override
  Widget build(
    BuildContext context,
  ) => detailScaffold(context, 'Tu noche habitual', [
    const SizedBox(height: S.x3),
    FutureBuilder<_NightResult?>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Text('No se pudieron leer tus noches.');
        if (snapshot.connectionState != ConnectionState.done)
          return const LinearProgressIndicator();
        final data = snapshot.data;
        if (data == null || data.metrics.isEmpty) {
          return const Text(
            'Aparece al registrar una noche y al menos siete noches anteriores con señal suficiente.',
          );
        }
        final p = P.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat.yMMMd().format(DateTime.parse(data.date)),
              style: F.head,
            ),
            const SizedBox(height: S.x2),
            const Text(
              'Comparación con la mediana de tus últimas noches. El color coral señala una diferencia mayor de lo habitual.',
            ),
            const SizedBox(height: S.x3),
            for (final metric in data.metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: S.x2),
                child: Surface(
                  child: Row(
                    children: [
                      Expanded(child: Text(metric.label)),
                      Text(
                        '${_fmt(metric.delta)} ${metric.unit}',
                        style: F.head.copyWith(
                          color: metric.unusual ? p.on(C.coral) : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
    TextButton(
      onPressed: () => go(context, const TemploQuickJournal()),
      child: const Text('Ver etiquetas del diario'),
    ),
  ]);
}

class TemploRoutePulse extends StatefulWidget {
  const TemploRoutePulse({super.key});
  @override
  State<TemploRoutePulse> createState() => _TemploRoutePulseState();
}

typedef _RoutePick = ({String id, String label, WorkoutRoute route});

class _TemploRoutePulseState extends State<TemploRoutePulse> {
  Future<List<_RoutePick>>? _routes;
  String? _a, _b;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routes ??= _load();
  }

  Future<List<_RoutePick>> _load() async {
    final repo = repoOf(context);
    if (repo == null) return [];
    final payload = await repo.getWorkouts(range: 'quarter');
    final workouts = (payload['workouts'] as List? ?? const [])
        .whereType<Map>();
    final result = <_RoutePick>[];
    for (final row in workouts.where((w) => w['type'] == 'running').take(30)) {
      final id = row['id'];
      if (id is! String) continue;
      final route = await repo.getWorkoutRoute(id);
      if (route == null || !route.hasPath || route.hr.isEmpty) continue;
      final stamp = (row['start_ts'] as num?)?.toInt();
      final label = stamp == null
          ? id
          : DateFormat.yMMMd().add_jm().format(_epoch(stamp));
      result.add((id: id, label: label, route: route));
    }
    return result;
  }

  @override
  Widget build(
    BuildContext context,
  ) => detailScaffold(context, 'Pulso al mismo ritmo', [
    const SizedBox(height: S.x3),
    const Text(
      'Elige dos carreras con GPS. Templo compara kilómetros del mismo recorrido y sentido con ritmos separados por hasta 20 s/km.',
    ),
    const SizedBox(height: S.x3),
    FutureBuilder<List<_RoutePick>>(
      future: _routes,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Text('No se pudieron leer las rutas.');
        final routes = snapshot.data;
        if (routes == null) return const LinearProgressIndicator();
        if (routes.length < 2)
          return const Text(
            'Se necesitan dos carreras guardadas con GPS y pulso.',
          );
        final a = _a ?? routes.first.id;
        final b = _b ?? routes.firstWhere((route) => route.id != a).id;
        final current = routes.firstWhere((route) => route.id == a).route;
        final previous = routes.firstWhere((route) => route.id == b).route;
        final report = routePulseComparison(
          current,
          previous,
          (x, y) => haversineMeters(x.lat, x.lng, y.lat, y.lng),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _picker(
              'Carrera actual',
              a,
              routes,
              b,
              (value) => setState(() => _a = value),
            ),
            const SizedBox(height: S.x2),
            _picker(
              'Carrera de referencia',
              b,
              routes,
              a,
              (value) => setState(() => _b = value),
            ),
            const SizedBox(height: S.x4),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.difference == null
                        ? 'Sin tramos comparables'
                        : '${_fmt(report.difference!)} lpm · ${report.matches} km comparables',
                    style: F.head,
                  ),
                  Text(
                    report.drift == null
                        ? 'Sin datos suficientes para comparar las dos mitades.'
                        : 'Segunda mitad frente a primera, a ritmo similar: ${_fmt(report.drift!)} lpm',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  ]);

  Widget _picker(
    String label,
    String value,
    List<_RoutePick> routes,
    String excluded,
    ValueChanged<String?> onChanged,
  ) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        items: [
          for (final route in routes)
            if (route.id != excluded)
              DropdownMenuItem(value: route.id, child: Text(route.label)),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}
