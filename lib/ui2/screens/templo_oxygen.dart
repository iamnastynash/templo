import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

import '../../ble/pulse_oximeter.dart';
import '../../state/prefs.dart';
import '../../data/db.dart';
import '../ui2.dart';
import 'home_screen.dart' show go;
import 'metric_detail.dart';

class TemploOxygen extends StatefulWidget {
  const TemploOxygen({super.key});

  @override
  State<TemploOxygen> createState() => _TemploOxygenState();
}

typedef _OxygenReading = ({double value, DateTime date, String source});

class _TemploOxygenState extends State<TemploOxygen> {
  static const _key = 'templo.oxygen.v1';
  final _readings = <_OxygenReading>[];
  bool _working = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    try {
      for (final row in jsonDecode(Prefs.getString(_key, '[]')) as List) {
        final value = (row['v'] as num).toDouble();
        final date = DateTime.parse(row['d'] as String).toLocal();
        if (value.isFinite && value > 0 && value <= 100) {
          _readings.add((value: value, date: date, source: row['s'] as String));
        }
      }
    } catch (_) {}
  }

  void _save(double value, String source) {
    setState(() {
      _readings.insert(0, (value: value, date: DateTime.now(), source: source));
      if (_readings.length > 200) _readings.removeLast();
    });
    Prefs.setString(
      _key,
      jsonEncode([
        for (final r in _readings)
          {'v': r.value, 'd': r.date.toUtc().toIso8601String(), 's': r.source},
      ]),
    );
  }

  Future<void> _manual() async {
    var input = '';
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anotar lectura de oxímetro'),
        content: TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'SpO₂ (%)'),
          onChanged: (text) => input = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(input.replaceAll(',', '.'));
              if (v != null && v.isFinite && v > 0 && v <= 100)
                Navigator.pop(ctx, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (mounted && value != null) _save(value, 'Oxímetro · entrada manual');
  }

  Future<void> _bluetooth() async {
    if (_working) return;
    if (FlutterBluePlus.isScanningNow) {
      setState(() => _message = 'Hay otra búsqueda Bluetooth en curso.');
      return;
    }
    setState(() {
      _working = true;
      _message = 'Buscando oxímetros Bluetooth…';
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [pulseOximeterService],
        timeout: const Duration(seconds: 6),
      );
      await FlutterBluePlus.isScanning
          .where((active) => !active)
          .first
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final results = FlutterBluePlus.lastScanResults;
      if (results.isEmpty) {
        setState(
          () => _message =
              'No se encontró un oxímetro que anuncie el servicio PLX.',
        );
        return;
      }
      final selected = await showDialog<ScanResult>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Elige tu oxímetro'),
          children: [
            for (final result in results)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, result),
                child: Text(
                  result.device.advName.isEmpty
                      ? 'Oxímetro · ${result.device.remoteId}'
                      : result.device.advName,
                ),
              ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      setState(() => _message = 'Esperando una medición válida del oxímetro…');
      final reading = await readPulseOximeter(selected.device);
      if (!mounted) return;
      _save(
        reading,
        selected.device.advName.isEmpty
            ? 'Oxímetro Bluetooth PLX'
            : selected.device.advName,
      );
      setState(() => _message = null);
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'No llegó una lectura válida. Comprueba el Bluetooth y activa el oxímetro.',
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _inspectOptics() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final points = await LocalDb.withReadExecutor(
        (db) => db.query(
          'decoded_onehz',
          columns: const ['spo2_red_raw', 'spo2_ir_raw', 'rec_ts'],
          where: 'device_id = ? AND spo2_red_raw > 0 AND spo2_ir_raw > 0',
          whereArgs: const [LocalDb.kPrimaryDeviceId],
          orderBy: 'rec_ts DESC',
          limit: 1000,
        ),
      );
      final differences = <int>{};
      int? last;
      var count = 0;
      for (final point in points) {
        final ts = (point['rec_ts'] as num).toInt();
        if (last != null && last - ts > 60) break;
        last = ts;
        differences.add(
          (point['spo2_ir_raw'] as num).toInt() -
              (point['spo2_red_raw'] as num).toInt(),
        );
        count++;
      }
      final report = count < 30
          ? 'No hay un tramo sincronizado con suficientes muestras ópticas rojo/IR.'
          : '$count muestras recientes · ${differences.length} diferencias rojo/IR distintas. '
                'Este diagnóstico de señal no calcula saturación.';
      if (mounted) setState(() => _message = report);
    } catch (_) {
      if (mounted)
        setState(() => _message = 'No se pudieron leer las muestras ópticas.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final last = _readings.firstOrNull;
    return detailScaffold(context, 'Oxígeno', [
      const SizedBox(height: S.x4),
      Text('SpO₂', style: F.over.copyWith(color: p.ink3)),
      Text(
        last == null ? '—' : '${last.value.toStringAsFixed(1)}%',
        style: F.n48.copyWith(color: p.ink),
      ),
      if (last != null)
        Text(
          '${last.source} · ${DateFormat.yMMMd().add_jm().format(last.date)}',
        ),
      if (_readings.length > 1) ...[
        const SizedBox(height: S.x3),
        GlowLine(
          _readings.take(20).map((r) => r.value).toList().reversed.toList(),
          color: p.on(C.coral),
          height: 76,
        ),
      ],
      const SizedBox(height: S.x4),
      BigButton(
        'Leer oxímetro Bluetooth',
        color: C.coral,
        onTap: _working ? null : _bluetooth,
      ),
      TextButton(
        onPressed: _working ? null : _manual,
        child: const Text('Anotar lectura manual'),
      ),
      TextButton(
        onPressed: _working
            ? null
            : () => go(context, const MetricDetail('spo2')),
        child: const Text('Ver mediciones importadas de WHOOP'),
      ),
      TextButton(
        onPressed: _working ? null : _inspectOptics,
        child: const Text('Comprobar señal óptica sincronizada de WHOOP'),
      ),
      if (_message != null)
        Text(_message!, style: F.cap.copyWith(color: p.ink3)),
      const SizedBox(height: S.x3),
      Text(
        'La señal óptica disponible de la WHOOP carece de una medición validada de SpO₂ en Templo. Las lecturas aquí conservan su fuente.',
        style: F.cap.copyWith(color: p.ink3),
      ),
      for (final r in _readings.take(10))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${r.value.toStringAsFixed(1)}% · ${r.source}'),
          subtitle: Text(DateFormat.yMMMd().add_jm().format(r.date)),
        ),
    ]);
  }
}
