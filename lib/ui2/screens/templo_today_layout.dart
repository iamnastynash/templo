import 'package:flutter/material.dart';

import '../../state/prefs.dart';
import '../ui2.dart';

enum TodayTile {
  pulse('Pulso en vivo', 'Live heart rate'),
  recovery('Recuperación', 'Recovery'),
  energy('Energía', 'Energy'),
  strain('Esfuerzo', 'Strain'),
  sleep('Sueño', 'Sleep');

  const TodayTile(this.spanish, this.english);
  final String spanish, english;
  String label(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'es' ? spanish : english;
}

typedef TodayTileSetting = ({TodayTile tile, bool visible});

class TodayLayout {
  static const _key = 'templo.today_layout.v1';
  static List<TodayTileSetting> get defaults => [
    for (final tile in TodayTile.values) (tile: tile, visible: true),
  ];

  static final value = ValueNotifier<List<TodayTileSetting>>(_load());

  static List<TodayTileSetting> _load() {
    final saved = Prefs.getString(_key, '').split(',');
    final result = <TodayTileSetting>[];
    final seen = <TodayTile>{};
    for (final item in saved) {
      final parts = item.split(':');
      if (parts.length != 2) continue;
      final tile = TodayTile.values
          .where((t) => t.name == parts.first)
          .firstOrNull;
      if (tile != null && seen.add(tile)) {
        result.add((tile: tile, visible: parts.last == '1'));
      }
    }
    return [...result, ...defaults.where((s) => !seen.contains(s.tile))];
  }

  static void save(List<TodayTileSetting> settings) {
    value.value = List.unmodifiable(settings);
    Prefs.setString(
      _key,
      settings.map((s) => '${s.tile.name}:${s.visible ? 1 : 0}').join(','),
    );
  }
}

class TemploTodayLayout extends StatelessWidget {
  const TemploTodayLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Personalizar Hoy' : 'Customize Today'),
        actions: [
          TextButton(
            onPressed: () => TodayLayout.save(TodayLayout.defaults),
            child: Text(es ? 'Restaurar' : 'Reset'),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: TodayLayout.value,
        builder: (context, settings, _) => ReorderableListView.builder(
          padding: const EdgeInsets.all(S.x4),
          header: Padding(
            padding: const EdgeInsets.only(bottom: S.x3),
            child: Text(
              es
                  ? 'Activa las tarjetas que quieras. Arrastra para ordenar.'
                  : 'Choose your cards and drag to reorder.',
            ),
          ),
          buildDefaultDragHandles: false,
          itemCount: settings.length,
          itemBuilder: (context, i) {
            final item = settings[i];
            return Row(
              key: ValueKey(item.tile),
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text(item.tile.label(context)),
                    value: item.visible,
                    onChanged: (visible) => TodayLayout.save([
                      for (final s in settings)
                        if (s.tile == item.tile)
                          (tile: item.tile, visible: visible)
                        else
                          s,
                    ]),
                  ),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.all(S.x3),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            );
          },
          onReorder: (from, to) {
            final next = [...settings];
            final item = next.removeAt(from);
            next.insert(to > from ? to - 1 : to, item);
            TodayLayout.save(next);
          },
        ),
      ),
    );
  }
}
