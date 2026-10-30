import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/services/platform/duo_navigation.dart';

/// Keeps existing header controls mounted so their reactive state and callbacks
/// remain authoritative while UIKit presents their native representations.
class DuoPageChrome extends StatefulWidget {
  const DuoPageChrome({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.hidden = false,
    this.immersive = false,
    this.dark,
    this.child = const SizedBox.shrink(),
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool hidden;
  final bool immersive;
  final bool? dark;
  final Widget child;

  @override
  State<DuoPageChrome> createState() => _DuoPageChromeState();
}

class _DuoPageChromeState extends State<DuoPageChrome> {
  static int _nextId = 0;
  final int _id = ++_nextId;
  final _title = GlobalKey();
  final _leading = GlobalKey();
  final _actions = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routes = <ModalRoute<dynamic>>[];
    var route = ModalRoute.of(context);
    while (route != null && !routes.contains(route)) {
      routes.add(route);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    var depth = 0;
    context.visitAncestorElements((_) {
      depth++;
      return true;
    });
    DuoNavigation.register(
      this,
      DuoHeaderRegistration(
        id: _id,
        depth: depth,
        routes: routes,
        inspect: _inspect,
      ),
    );
  }

  @override
  void dispose() {
    DuoNavigation.unregister(this);
    super.dispose();
  }

  DuoChrome _inspect() {
    final reader = _HeaderReader();
    final leading = reader.controls(_leading.currentContext).firstOrNull;
    final titleActions = reader.controls(_title.currentContext);
    final actions = [
      ...titleActions,
      ...reader.controls(_actions.currentContext),
    ];
    final title = _textIn(_title.currentContext);
    return DuoChrome(
      title: title,
      dark: widget.dark ?? Theme.of(context).brightness == Brightness.dark,
      hidden:
          widget.hidden ||
          widget.immersive ||
          (leading == null && actions.isEmpty),
      immersive: widget.immersive,
      leading: leading,
      actions: actions,
      callbacks: reader.callbacks,
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      // The controls are built, but neither painted nor focusable. In
      // particular, native menus call KazumiMenuItem callbacks directly;
      // they never try to open a MenuAnchor located off screen.
      Offstage(
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: OverflowBox(
              minWidth: 1000,
              maxWidth: 1000,
              minHeight: 100,
              maxHeight: 100,
              child: Row(
                children: [
                  KeyedSubtree(
                    key: _leading,
                    child: widget.leading ?? const SizedBox(),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: _title,
                      child: widget.title ?? const SizedBox(),
                    ),
                  ),
                  KeyedSubtree(
                    key: _actions,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

String _textIn(BuildContext? context) {
  final texts = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      if (text.isNotEmpty) texts.add(text);
      return;
    }
    element.visitChildren(visit);
  }

  if (context is Element) visit(context);
  return texts.join(' ');
}

IconData? _iconIn(Element element) {
  IconData? icon;
  void find(Element node) {
    if (icon != null) return;
    final widget = node.widget;
    if (widget is Icon) {
      icon = widget.icon;
      return;
    }
    node.visitChildren(find);
  }

  find(element);
  return icon;
}

class _HeaderReader {
  int _next = 0;
  final callbacks = <String, VoidCallback>{};

  List<Map<String, Object?>> controls(BuildContext? context) {
    final result = <Map<String, Object?>>[];
    void visit(Element element, [String? tooltip]) {
      final widget = element.widget;
      if (widget is Tooltip) tooltip = widget.message;
      if (widget is KazumiMenuButton) {
        var label = tooltip ?? '';
        void findLabel(Element node) {
          if (node.widget case IconButton(:final tooltip?)) label = tooltip;
          node.visitChildren(findLabel);
        }

        element.visitChildren(findLabel);
        result.add(
          _control(
            label.isEmpty ? _textIn(element) : label,
            _iconIn(element),
            null,
            enabled: widget.enabled,
            menu: _menu(widget.menuChildren, element),
          ),
        );
        return;
      }
      if (widget is IconButton) {
        result.add(
          _control(
            widget.tooltip ?? tooltip ?? _iconLabel(_iconIn(element)),
            _iconIn(element),
            widget.onPressed,
          ),
        );
        return;
      }
      if (widget is ButtonStyleButton) {
        result.add(
          _control(
            tooltip ?? _textIn(element),
            _iconIn(element),
            widget.onPressed,
          ),
        );
        return;
      }
      if (widget is InkWell && widget.onTap != null) {
        result.add(
          _control(tooltip ?? _textIn(element), _iconIn(element), widget.onTap),
        );
        return;
      }
      element.visitChildren((child) => visit(child, tooltip));
    }

    if (context is Element) visit(context);
    return result;
  }

  Map<String, Object?> _control(
    String label,
    IconData? icon,
    VoidCallback? callback, {
    bool? enabled,
    List<Map<String, Object?>>? menu,
    bool selected = false,
    bool destructive = false,
  }) {
    final id = '${_next++}';
    if (callback != null) callbacks[id] = callback;
    return {
      'id': id,
      'label': label.isEmpty ? '操作' : label,
      'symbol': duoSymbolFor(icon),
      'enabled': enabled ?? callback != null,
      'selected': selected,
      'destructive': destructive,
      'menu': ?menu,
    };
  }

  List<Map<String, Object?>> _menu(
    List<Widget> widgets,
    BuildContext context,
  ) => [
    for (final widget in widgets)
      if (widget is KazumiMenuItem)
        _control(
          widget.label,
          widget.leadingIcon is Icon ? (widget.leadingIcon as Icon).icon : null,
          widget.onPressed,
          selected: widget.selected == true,
          destructive: widget.destructive,
        )
      else if (widget is MenuItemButton)
        _control(
          _menuLabel(widget.child, context),
          widget.leadingIcon is Icon ? (widget.leadingIcon as Icon).icon : null,
          widget.onPressed,
        )
      else if (widget is SubmenuButton)
        _control(
          _menuLabel(widget.child, context),
          null,
          null,
          enabled: true,
          menu: _menu(widget.menuChildren, context),
        ),
  ];
}

String _menuLabel(Widget? widget, BuildContext context) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is ValueListenableBuilder) {
    return _menuLabel(
      widget.builder(context, widget.valueListenable.value, widget.child),
      context,
    );
  }
  if (widget is SingleChildRenderObjectWidget) {
    return _menuLabel(widget.child, context);
  }
  if (widget is Row) {
    return widget.children
        .map((child) => _menuLabel(child, context))
        .where((text) => text.isNotEmpty)
        .join(' ');
  }
  return '';
}

String _iconLabel(IconData? icon) => switch (duoSymbolFor(icon)) {
  'chevron.backward' => '返回',
  'xmark' => '关闭',
  _ => '操作',
};

/// Symbols are a presentation detail; labels and callbacks come from the real
/// Flutter controls, including dynamically built menus and disabled actions.
String? duoSymbolFor(IconData? icon) =>
    icon == null ? null : _duoSymbols[icon] ?? 'ellipsis.circle';

final _duoSymbolGroups = <String, Set<IconData>>{
  'chevron.backward': {
    Icons.arrow_back,
    Icons.arrow_back_rounded,
    Icons.arrow_back_ios_new_rounded,
    Icons.arrow_back_ios_new,
    Icons.arrow_back_ios,
    Icons.chevron_left,
  },
  'xmark': {Icons.close, Icons.close_rounded, Icons.cancel_outlined},
  'magnifyingglass': {
    Icons.search,
    Icons.search_rounded,
    Icons.search_outlined,
  },
  'clock.arrow.circlepath': {
    Icons.history,
    Icons.history_rounded,
    Icons.history_outlined,
  },
  'gearshape': {
    Icons.settings,
    Icons.settings_outlined,
    Icons.settings_rounded,
  },
  'slider.horizontal.3': {
    Icons.tune,
    Icons.tune_rounded,
    Icons.filter_list,
    Icons.filter_list_rounded,
  },
  'arrow.clockwise': {
    Icons.refresh,
    Icons.refresh_outlined,
    Icons.refresh_rounded,
    Icons.restart_alt_rounded,
  },
  'arrow.triangle.2.circlepath': {Icons.sync, Icons.sync_rounded},
  'heart': {Icons.favorite_border, Icons.favorite_border_rounded},
  'heart.fill': {Icons.favorite, Icons.favorite_rounded},
  'star': {Icons.star_rounded, Icons.star_border_rounded},
  'checkmark': {Icons.done, Icons.check, Icons.check_rounded},
  'trash': {
    Icons.delete,
    Icons.delete_outline,
    Icons.delete_sweep_outlined,
    Icons.delete_outline_rounded,
  },
  'square.and.pencil': {Icons.edit, Icons.edit_outlined, Icons.edit_rounded},
  'plus': {Icons.add, Icons.add_rounded},
  'square.and.arrow.down': {
    Icons.save,
    Icons.save_outlined,
    Icons.save_rounded,
    Icons.download,
    Icons.download_rounded,
  },
  'square.and.arrow.up': {
    Icons.share,
    Icons.share_rounded,
    Icons.upload_rounded,
  },
  'doc.on.doc': {Icons.copy, Icons.copy_rounded},
  'flask': {Icons.science_outlined, Icons.science_rounded},
  'photo': {Icons.image_search_rounded, Icons.image_outlined},
  'arrow.up.right.square': {Icons.open_in_new, Icons.open_in_new_rounded},
  'heart.slash': {Icons.heart_broken},
  'clock.badge.questionmark': {Icons.pending_actions},
  'questionmark.circle': {Icons.help_outline_rounded, Icons.help_outline},
  'ellipsis': {Icons.more_horiz_rounded, Icons.more_horiz, Icons.more_vert},
  'sidebar.right': {Icons.menu_open_rounded, Icons.menu_open},
  'ladybug': {Icons.bug_report, Icons.bug_report_outlined},
  'play': {Icons.play_arrow, Icons.play_arrow_rounded},
  'pause': {Icons.pause, Icons.pause_rounded},
  'backward.end': {Icons.skip_previous, Icons.skip_previous_rounded},
  'forward.end': {Icons.skip_next, Icons.skip_next_rounded},
  'arrow.up.left.and.arrow.down.right': {
    Icons.fullscreen_exit,
    Icons.fullscreen_exit_rounded,
  },
  'arrow.down.right.and.arrow.up.left': {
    Icons.fullscreen,
    Icons.fullscreen_rounded,
  },
};

final _duoSymbols = <IconData, String>{
  for (final entry in _duoSymbolGroups.entries)
    for (final icon in entry.value) icon: entry.key,
};
