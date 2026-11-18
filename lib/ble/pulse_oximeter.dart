import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final pulseOximeterService = Guid('1822');
final _spot = Guid('2a5e');
final _continuous = Guid('2a5f');

/// Bluetooth SIG PLXS 1.0.1, sections 3.1–3.2 and 5.1.
double? decodePulseOximetry(List<int> data, {required bool continuous}) {
  if (data.length < 5) return null;
  final flags = data[0];
  if ((flags & 0xe0) != 0) return null;
  int word(int offset) => data[offset] | (data[offset + 1] << 8);
  var offset = 5;
  if (continuous) {
    if ((flags & 1) != 0) offset += 4;
    if ((flags & 2) != 0) offset += 4;
  } else if ((flags & 1) != 0) {
    offset += 7; // Timestamp. A new Bluetooth reading uses receipt time.
  }
  final hasStatus = (flags & (continuous ? 4 : 2)) != 0;
  final hasSensor = (flags & (continuous ? 8 : 4)) != 0;
  final hasAmplitude = (flags & (continuous ? 16 : 8)) != 0;
  if (data.length <
      offset +
          (hasStatus ? 2 : 0) +
          (hasSensor ? 3 : 0) +
          (hasAmplitude ? 2 : 0))
    return null;
  if (hasStatus) {
    if ((word(offset) & 0xfe60) != 0) return null;
    offset += 2;
  }
  if (hasSensor && (word(offset) != 0 || data[offset + 2] != 0)) return null;

  final raw = word(1);
  if (const [0x07fe, 0x07ff, 0x0800, 0x0801, 0x0802].contains(raw)) return null;
  var mantissa = raw & 0xfff, exponent = raw >> 12;
  if (mantissa >= 0x800) mantissa -= 0x1000;
  if (exponent >= 8) exponent -= 16;
  final value = mantissa * math.pow(10, exponent);
  return value > 0 && value <= 100 ? value.toDouble() : null;
}

Future<double> readPulseOximeter(BluetoothDevice device) async {
  final wasConnected = device.isConnected;
  StreamSubscription<List<int>>? subscription;
  BluetoothCharacteristic? enabled;
  try {
    if (!wasConnected)
      await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices(timeout: 12);
    final chars = [
      for (final service in services)
        if (service.uuid == pulseOximeterService)
          for (final c in service.characteristics)
            if ((c.uuid == _spot || c.uuid == _continuous) &&
                (c.properties.notify || c.properties.indicate))
              c,
    ];
    if (chars.isEmpty) throw StateError('El equipo no publica lecturas PLX.');
    final ch = chars.firstWhere(
      (c) => c.uuid == _spot,
      orElse: () => chars.first,
    );
    final value = Completer<double>();
    subscription = ch.onValueReceived.listen((data) {
      final reading = decodePulseOximetry(
        data,
        continuous: ch.uuid == _continuous,
      );
      if (reading != null && !value.isCompleted) value.complete(reading);
    });
    if (!ch.isNotifying) {
      await ch.setNotifyValue(true, timeout: 10);
      enabled = ch;
    }
    return await value.future.timeout(const Duration(seconds: 25));
  } finally {
    await subscription?.cancel();
    if (enabled != null && device.isConnected) {
      try {
        await enabled.setNotifyValue(false, timeout: 3);
      } catch (_) {}
    }
    if (!wasConnected && device.isConnected) {
      try {
        await device.disconnect(timeout: 4);
      } catch (_) {}
    }
  }
}
