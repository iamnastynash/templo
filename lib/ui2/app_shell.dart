// Stable domain indices for saved selections and deep links.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import 'grammar.dart';
import 'theme.dart';

/// The four primary destinations, in bar order.
enum ShellDomain {
  today('Today', LucideIcons.house, C.domHome),
  sleep('Sleep', LucideIcons.moon, C.domSleep),
  activity('Activity', LucideIcons.dumbbell, C.domMove),
  health('Health', LucideIcons.heartPulse, C.domHealth),

  /// Pulso: Trabajo, Trading and Reseteo. LAST, so every tab index the
  /// guides, deep links and the saved tab already use keeps its meaning.
  focus('Enfoque', LucideIcons.crosshair, C.coral);

  const ShellDomain(this.label, this.icon, this.accent);

  final String label;
  final IconData icon;

  /// [label] in the user's language. Own keys rather than the screen titles,
  /// so two tabs can never end up with the same translated word.
  String title(BuildContext c) {
    final l = AppLocalizations.of(c);
    return switch (this) {
          ShellDomain.today => l?.tabToday,
          ShellDomain.sleep => l?.tabSleep,
          ShellDomain.activity => l?.tabActivity,
          ShellDomain.focus => null,
          ShellDomain.health => l?.tabHealth,
        } ??
        label;
  }

  /// The domain's pigment. Use `P.of(context).on(accent)` for text and
  /// `.fill(accent)` for a filled surface — the raw value is not AA-safe.
  final Color accent;
}

// There is no `Domain` InheritedWidget. There was one, promising that a screen
// "and anything it pushes" could pick up its accent without threading it — but
// nothing ever read it, and a pushed route could not have: `MaterialApp.home`
// is the gate, so `Navigator.of` pushes above the shell entirely. Screens take
// their accent as a parameter, which is honest about where it comes from.

class AppShell extends StatefulWidget {
  /// Builds the body of one domain. Called lazily — a tab is not built until
  /// it is first selected, then kept alive by the [IndexedStack].
  final Widget Function(BuildContext context, ShellDomain domain) builder;

  final ShellDomain initial;

  /// Notified on every tab change, including a re-tap of the current tab
  /// (which domains conventionally use to scroll to top) and a return via Back.
  final void Function(ShellDomain domain)? onSelect;

  /// Pinned between the domain and the tab bar, above every tab. This is not
  /// a general slot — it exists for state that is RUNNING and is not on
  /// screen, which today means a minimised workout. A domain's own content
  /// belongs inside the domain.
  final Widget? banner;

  /// External selection control. When provided, the shell follows changes to
  /// it and switches tabs WITHOUT being recreated, so a programmatic jump
  /// (a notification deep link) keeps every visited tab's state — scroll
  /// position included — alive in the [IndexedStack].
  final ValueNotifier<ShellDomain>? selection;

  final bool showGuideActivity;

  const AppShell({
    this.showGuideActivity = false,
    super.key,
    required this.builder,
    this.initial = ShellDomain.today,
    this.onSelect,
    this.banner,
    this.selection,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellDomain _current = widget.initial;
  late final Set<ShellDomain> _built = {widget.initial};
  // Tabs are kept alive, not pushed onto the Navigator. Keep their history
  // here so Android Back can return to the previous tab. A restored tab or
  // cold-launch deep link has Today as its way back into the app.
  late final List<ShellDomain> _history = [
    if (widget.initial != ShellDomain.today) ShellDomain.today,
  ];

  @override
  void initState() {
    super.initState();
    widget.selection?.addListener(_followSelection);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selection != oldWidget.selection) {
      oldWidget.selection?.removeListener(_followSelection);
      widget.selection?.addListener(_followSelection);
      // Reconcile with the new notifier's current value. didUpdateWidget
      // runs during the build phase, so the onSelect callback is deferred
      // to after the frame — it may setState on the parent.
      final s = widget.selection;
      if (s != null && s.value != _current) {
        final d = s.value;
        _select(d, notify: false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Discard the callback if the shell was unmounted, the notifier
          // was swapped, or the selection moved on since scheduling —
          // reporting the stale domain would write it back via onSelect.
          if (mounted && widget.selection == s && s.value == d) {
            widget.onSelect?.call(d);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.selection?.removeListener(_followSelection);
    super.dispose();
  }

  void _followSelection() {
    final s = widget.selection;
    if (s == null) return;
    if (s.value != _current) _select(s.value);
  }

  void _select(ShellDomain d, {bool notify = true}) {
    setState(() {
      // Each tab at most once, most recent last, so switching back and forth
      // between two tabs does not add a Back press per switch. Today stays in
      // as the way back into the app even while it is the tab on screen.
      if (d != _current) {
        _history.remove(_current);
        // Leaving Today puts it back at the bottom, never on top: it is the
        // last stop before Back leaves the app.
        if (_current == ShellDomain.today) {
          _history.insert(0, _current);
        } else {
          _history.add(_current);
        }
        if (d != ShellDomain.today) _history.remove(d);
      }
      _current = d;
      _built.add(d);
    });
    if (notify) widget.onSelect?.call(d);
  }

  void _back() {
    if (_history.isEmpty) return;
    setState(() {
      _current = _history.removeLast();
      _built.add(_current);
    });
    widget.onSelect?.call(_current);
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return PopScope<Object?>(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _current.index,
                  children: [
                    // An unvisited tab is an empty box, not a built screen — the
                    // old shell built all forty screens' worth of state on launch.
                    for (final d in ShellDomain.values)
                      if (_built.contains(d))
                        TickerMode(
                          enabled: d == _current,
                          child: widget.builder(c, d),
                        )
                      else
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              if (widget.banner != null) widget.banner!,
            ],
          ),
        ),
        bottomNavigationBar: _TabBar(
          current: _current,
          onTap: _select,
          showActivity: widget.showGuideActivity,
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final ShellDomain current;
  final ValueChanged<ShellDomain> onTap;

  final bool showActivity;

  const _TabBar({required this.current, required this.onTap, required this.showActivity});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: S.x2),
      child: Align(
        heightFactor: 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: p.dark ? C.dockDark : C.carbon,
            borderRadius: R.rPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in showActivity ? ShellDomain.values : const [
                ShellDomain.today,
                ShellDomain.sleep,
                ShellDomain.focus,
                ShellDomain.health,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _Tab(
                    key: ValueKey(d),
                    domain: d,
                    on: d == current,
                    onTap: () => onTap(d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final ShellDomain domain;
  final bool on;
  final VoidCallback onTap;

  const _Tab({super.key, required this.domain, required this.on, required this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final glyph = switch (domain) {
      ShellDomain.today =>
        '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.2"/>',
      ShellDomain.sleep =>
        '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
      ShellDomain.focus =>
        '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><path d="M12 2v3m0 14v3"/>',
      ShellDomain.health =>
        '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
      ShellDomain.activity =>
        '<path d="M3 12h4l3-6 4 12 3-6h4"/>',
    };
    return Semantics(
      selected: on,
      child: Tooltip(
        message: domain.title(c),
        excludeFromSemantics: true,
        child: Pressable(
          onTap: onTap,
          semanticLabel: domain.title(c),
          child: AnimatedContainer(
            duration: motion(c, Motion.base),
            width: 48,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.hi : Colors.transparent,
              borderRadius: R.rPill,
            ),
            child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
              'fill="none" stroke="black" stroke-width="1.8" '
              'stroke-linecap="round" stroke-linejoin="round">$glyph</svg>',
              width: 18,
              height: 18,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                on ? p.onHi : C.dockInactive,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
