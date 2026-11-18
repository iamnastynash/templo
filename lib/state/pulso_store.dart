// Pulso · local storage for Enfoque sessions and Reseteo results.
//
// SharedPreferences JSON (via Prefs): small, on-device only, no schema change
// to the health database. Sessions keep aggregates only (see focus.dart).
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../compute/pulso/focus.dart';
import 'prefs.dart';

class PulsoStore extends ChangeNotifier {
  PulsoStore._();
  static final PulsoStore instance = PulsoStore._();

  static const _kSessions = 'pulso.focus.v1';
  static const _kResets = 'pulso.resets.v1';

  /// Keep the store bounded: the newest sessions only.
  static const _maxSessions = 400;

  List<FocusSession>? _sessions;
  List<ResetResult>? _resets;

  List<FocusSession> get sessions => _sessions ??= _readSessions();
  List<ResetResult> get resets => _resets ??= _readResets();

  FocusSession? get active {
    for (final s in sessions.reversed) {
      if (s.open) return s;
    }
    return null;
  }

  List<FocusSession> _readSessions() {
    try {
      final raw = Prefs.getString(_kSessions, '');
      if (raw.isEmpty) return [];
      return [for (final m in jsonDecode(raw) as List) FocusSession.fromJson(m as Map)];
    } catch (_) {
      return [];
    }
  }

  List<ResetResult> _readResets() {
    try {
      final raw = Prefs.getString(_kResets, '');
      if (raw.isEmpty) return [];
      return [for (final m in jsonDecode(raw) as List) ResetResult.fromJson(m as Map)];
    } catch (_) {
      return [];
    }
  }

  void _save() {
    final s = sessions;
    if (s.length > _maxSessions) s.removeRange(0, s.length - _maxSessions);
    try {
      Prefs.setString(_kSessions, jsonEncode([for (final x in s) x.toJson()]));
      Prefs.setString(_kResets, jsonEncode([for (final x in resets) x.toJson()]));
    } catch (_) {}
    notifyListeners();
  }

  FocusSession start(FocusKind kind, int now) {
    final open = active;
    if (open != null) open.end = now;
    final s = FocusSession('${kind.name}-$now', kind, now);
    sessions.add(s);
    _save();
    return s;
  }

  void end(FocusSession s, int now) {
    s.openTrade?.end = now;
    s.end = now;
    _save();
  }

  bool editSession(FocusSession session, {required int start, required int end, required int now}) {
    if (!sessions.contains(session) || session.open || start >= end || end > now ||
        session.trades.any((trade) => trade.start < start || (trade.end ?? end + 1) > end)) {
      return false;
    }
    session.start = start;
    session.end = end;
    _save();
    return true;
  }

  bool deleteSession(FocusSession session) {
    if (session.open || !sessions.remove(session)) return false;
    _save();
    return true;
  }

  void openTrade(FocusSession s, int now, double? entryAbove, {double? bpm}) {
    if (s.openTrade != null) return;
    s.trades.add(Trade(now, entryAbove: entryAbove, entryBpm: bpm));
    _save();
  }

  void closeTrade(FocusSession s, int now) {
    s.openTrade?.end = now;
    _save();
  }

  void markResult(Trade t, String result) {
    t.result = t.result == result ? null : result;
    _save();
  }

  bool editTrade(FocusSession session, Trade trade, {
    required int start, required int? end, required String? result,
    required int now,
  }) {
    final index = session.trades.indexOf(trade);
    if (index < 0 || (trade.end == null) != (end == null) ||
        (result != null && result != 'win' && result != 'loss')) {
      return false;
    }
    final earliest = index == 0 ? session.start : session.trades[index - 1].end;
    final latest = index + 1 == session.trades.length
        ? session.end ?? now : session.trades[index + 1].start;
    if (earliest == null || start < earliest || start > latest ||
        (end != null && (end < start || end > latest))) {
      return false;
    }

    session.trades[index] = Trade(
      start, end: end, result: result,
      entryAbove: start == trade.start ? trade.entryAbove : null,
      entryBpm: start == trade.start ? trade.entryBpm : null,
    );
    _save();
    return true;
  }

  bool deleteTrade(FocusSession session, Trade trade) {
    if (!session.trades.remove(trade)) return false;
    _save();
    return true;
  }

  void addSample(FocusSession s, int t, double v) {
    s.samples.add((t: t, v: v));
    _save();
  }

  void addReset(ResetResult r) {
    resets.add(r);
    if (resets.length > 200) resets.removeAt(0);
    _save();
  }

  @visibleForTesting
  void resetForTest() {
    _sessions = [];
    _resets = [];
  }
}
