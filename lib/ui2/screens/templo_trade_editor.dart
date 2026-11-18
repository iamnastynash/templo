import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../compute/pulso/focus.dart';
import '../../state/pulso_store.dart';
import '../ui2.dart';

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Future<bool> editFocusTrade(
  BuildContext context,
  FocusSession session,
  Trade trade,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _TradeEditor(session: session, trade: trade),
    ) ??
    false;

Future<bool> deleteFocusTrade(
  BuildContext context,
  FocusSession session,
  Trade trade,
) async {
  final open = trade.end == null;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(open ? '¿Descartar trade?' : '¿Eliminar trade?'),
      content: const Text(
        'Se quitará esta operación y se conservará el resto de la sesión.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(open ? 'Descartar' : 'Eliminar'),
        ),
      ],
    ),
  );
  return confirmed == true && PulsoStore.instance.deleteTrade(session, trade);
}

class TradeActions extends StatelessWidget {
  const TradeActions({
    super.key,
    required this.session,
    required this.trade,
    required this.onChanged,
  });
  final FocusSession session;
  final Trade trade;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return PopupMenuButton<bool>(
      tooltip: 'Opciones de la operación',
      position: PopupMenuPosition.under,
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: R.rLg,
        side: BorderSide(color: p.line),
      ),
      child: Semantics(
        button: true,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: p.hi, borderRadius: R.rPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: S.x2,
                  vertical: S.x1,
                ),
                child: Icon(LucideIcons.ellipsis, size: 20, color: p.onHi),
              ),
            ),
          ),
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: true, child: Text('Editar trade')),
        PopupMenuItem(
          value: false,
          child: Text(trade.end == null ? 'Descartar trade' : 'Eliminar trade'),
        ),
      ],
      onSelected: (edit) async {
        if (!context.mounted) return;
        final changed = await (edit
            ? editFocusTrade(context, session, trade)
            : deleteFocusTrade(context, session, trade));
        if (changed && context.mounted) onChanged();
      },
    );
  }
}

class _TradeEditor extends StatefulWidget {
  const _TradeEditor({required this.session, required this.trade});
  final FocusSession session;
  final Trade trade;
  @override
  State<_TradeEditor> createState() => _TradeEditorState();
}

class _TradeEditorState extends State<_TradeEditor> {
  late final _start = TextEditingController(text: _offset(widget.trade.start));
  late final _end = TextEditingController(text: _offset(widget.trade.end));
  late String? _outcome = widget.trade.result;
  String? _error;

  String _offset(int? time) {
    if (time == null) return '';
    final offset = Duration(seconds: time - widget.session.start);
    String digits(int value) => value.toString().padLeft(2, '0');
    return '${digits(offset.inHours)}:${digits(offset.inMinutes % 60)}:${digits(offset.inSeconds % 60)}';
  }

  int? _parse(String text) {
    final match = RegExp(
      r'^(\d{1,5}):([0-5]\d):([0-5]\d)$',
    ).firstMatch(text.trim());
    if (match == null) return null;
    return widget.session.start +
        int.parse(match[1]!) * 3600 +
        int.parse(match[2]!) * 60 +
        int.parse(match[3]!);
  }

  void _save() {
    final start = _parse(_start.text);
    final end = _parse(_end.text);
    final open = widget.trade.end == null;
    if (start == null || (!open && end == null)) {
      setState(
        () => _error = 'Usa horas, minutos y segundos en formato HH:MM:SS.',
      );
      return;
    }
    if (!PulsoStore.instance.editTrade(
      widget.session,
      widget.trade,
      start: start,
      end: open ? null : end,
      result: _outcome,
      now: _now(),
    )) {
      setState(
        () => _error =
            'Las horas deben estar dentro de la sesión y no pueden solaparse con otro trade.',
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar trade'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Los tiempos cuentan desde el inicio de la sesión.'),
        TextField(
          controller: _start,
          decoration: const InputDecoration(
            labelText: 'Entrada',
            hintText: 'HH:MM:SS',
          ),
        ),
        if (widget.trade.end != null) ...[
          TextField(
            controller: _end,
            decoration: const InputDecoration(
              labelText: 'Salida',
              hintText: 'HH:MM:SS',
            ),
          ),
          const SizedBox(height: 12),
          const Text('Resultado'),
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label) in const [
                (null, 'Sin marcar'),
                ('win', 'Ganado'),
                ('loss', 'Perdido'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _outcome == value,
                  onSelected: (_) => setState(() => _outcome = value),
                ),
            ],
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar cambios')),
    ],
  );
}
