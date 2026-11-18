import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../compute/pulso/focus.dart';
import '../../state/pulso_store.dart';
import '../ui2.dart';

Future<bool> editFocusSession(
  BuildContext context,
  FocusSession session,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _SessionEditor(session: session),
    ) ??
    false;

Future<bool> deleteFocusSession(
  BuildContext context,
  FocusSession session,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Eliminar sesión?'),
      content: const Text(
        'Se eliminarán esta sesión, sus operaciones y su registro de pulso de Enfoque. '
        'Las lecturas sincronizadas de la banda se conservan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Eliminar sesión'),
        ),
      ],
    ),
  );
  return confirmed == true && PulsoStore.instance.deleteSession(session);
}

class SessionSwipeActions extends StatefulWidget {
  const SessionSwipeActions({
    super.key,
    required this.session,
    required this.child,
  });
  final FocusSession session;
  final Widget child;

  @override
  State<SessionSwipeActions> createState() => _SessionSwipeActionsState();
}

class _SessionSwipeActionsState extends State<SessionSwipeActions> {
  static const _width = 156.0;
  double _offset = 0;
  bool _dragging = false;

  void _settle(bool open) => setState(() {
    _dragging = false;
    _offset = open ? -_width : 0;
  });

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final revealed = _offset == -_width && !_dragging;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(
                ignoring: !revealed,
                child: ExcludeSemantics(
                  excluding: !revealed,
                  child: SizedBox(
                    width: _width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _action(
                          'Editar',
                          LucideIcons.pencil,
                          p.hi,
                          p.onHi,
                          () async {
                            await editFocusSession(context, widget.session);
                            if (mounted) _settle(false);
                          },
                        ),
                        _action(
                          'Eliminar',
                          LucideIcons.trash2,
                          C.carbon,
                          C.dockInactive,
                          () async {
                            await deleteFocusSession(context, widget.session);
                            if (mounted) _settle(false);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : motion(context, Motion.fast),
            transform: Matrix4.translationValues(_offset, 0, 0),
            color: p.bg,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (details) => setState(() {
                _offset = (_offset + details.delta.dx).clamp(-_width, 0);
              }),
              onHorizontalDragCancel: () => _settle(_offset < -_width / 2),
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                _settle(
                  velocity < -250 || (velocity <= 250 && _offset < -_width / 2),
                );
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    String title,
    IconData icon,
    Color background,
    Color ink,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ink),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: F.cap.copyWith(color: ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SessionEditor extends StatefulWidget {
  const _SessionEditor({required this.session});
  final FocusSession session;
  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  static final _format = DateFormat('yyyy-MM-dd HH:mm:ss');
  late final _start = TextEditingController(text: _text(widget.session.start));
  late final _end = TextEditingController(text: _text(widget.session.end!));
  String? _error;

  String _text(int value) =>
      _format.format(DateTime.fromMillisecondsSinceEpoch(value * 1000));

  int? _parse(String input) {
    try {
      return _format.parseStrict(input.trim()).millisecondsSinceEpoch ~/ 1000;
    } on FormatException {
      return null;
    }
  }

  void _save() {
    final start = _parse(_start.text), end = _parse(_end.text);
    if (start == null ||
        end == null ||
        end <= start ||
        end > DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      setState(
        () =>
            _error = 'Elige un inicio y un fin posterior, sin fechas futuras.',
      );
      return;
    }
    if (!PulsoStore.instance.editSession(
      widget.session,
      start: start,
      end: end,
      now: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    )) {
      setState(
        () => _error = 'Las operaciones deben quedar dentro del nuevo horario.',
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
    title: const Text('Editar sesión'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Formato: AAAA-MM-DD HH:MM:SS'),
        TextField(
          controller: _start,
          decoration: const InputDecoration(labelText: 'Inicio'),
        ),
        TextField(
          controller: _end,
          decoration: const InputDecoration(labelText: 'Fin'),
        ),
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
