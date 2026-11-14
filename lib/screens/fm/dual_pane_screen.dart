import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/tablet.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/saf_write.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/saf_grant.dart';

/// **Çift bölme** (Faz 41 / madde 1 — A7.1, 2026-11-05).
///
/// İki klasör yan yana (dar ekranda üst üste); dokunulan bölme ETKİN olur,
/// seçili öğeler ötekine kopyalanır/taşınır (Total Commander / MiXplorer dili).
/// Klasör listesi `FsScan.list` (her bölme kendi klasörü, ayrı ayrı — iki
/// tam ağaç taraması yok); satırlar sabit yükseklikte (`itemExtent`, anayasa
/// §5), küçük resim `FmEntryIcon`'un kendi önbelleğinden.
class DualPaneScreen extends StatefulWidget {
  final String left;
  final String right;

  const DualPaneScreen({super.key, required this.left, required this.right});

  @override
  State<DualPaneScreen> createState() => _DualPaneScreenState();
}

/// Bir bölmenin durumu — saf, test edilebilir.
class PaneState {
  String path;
  final Set<String> selected = {};
  List<FsEntry> entries = const [];
  Object? error;

  PaneState(this.path);

  /// Bir üst klasör ([floor] köküne kadar); en üstteyse null.
  String? parent(String floor) {
    final up = p.dirname(path);
    if (up == path || !p.isWithin(floor, up) && up != floor) return null;
    return up;
  }
}

/// İki bölmenin ortak kararları (saf).
class DualPaneModel {
  final PaneState a;
  final PaneState b;
  int active = 0;

  DualPaneModel(String left, String right)
      : a = PaneState(left),
        b = PaneState(right);

  PaneState get current => active == 0 ? a : b;
  PaneState get other => active == 0 ? b : a;

  void swap() {
    final t = a.path;
    a.path = b.path;
    b.path = t;
    a.selected.clear();
    b.selected.clear();
  }

  /// Kopyala/taşı yapılabilir mi? Seçim var, hedef farklı klasör ve hedef
  /// seçilen bir klasörün İÇİ değil (klasörü kendi içine taşıma).
  bool canTransfer() {
    final src = current;
    if (src.selected.isEmpty) return false;
    final dest = other.path;
    if (p.equals(src.path, dest)) return false;
    for (final s in src.selected) {
      if (p.equals(s, dest) || p.isWithin(s, dest)) return false;
    }
    return true;
  }
}

class _DualPaneScreenState extends State<DualPaneScreen> {
  late final DualPaneModel _m = DualPaneModel(widget.left, widget.right);
  bool _busy = false;
  late final String _floor = FsScanRoots.floorOf(widget.left);
  final _paneKeys = [GlobalKey(), GlobalKey()];

  @override
  void initState() {
    super.initState();
    unawaited(_load(_m.a));
    unawaited(_load(_m.b));
  }

  Future<void> _load(PaneState pane) async {
    final hidden = context.read<AppState>().fmShowHidden;
    try {
      final list = await FsScan.list(pane.path, showHidden: hidden);
      pane
        ..entries = FsScan.sort(list, FmSort.name)
        ..error = null;
    } catch (e) {
      pane
        ..entries = const []
        ..error = e;
    }
    pane.selected.removeWhere((s) => !pane.entries.any((e) => e.path == s));
    if (mounted) setState(() {});
  }

  void _open(int index, FsEntry e) {
    final pane = index == 0 ? _m.a : _m.b;
    setState(() => _m.active = index);
    if (pane.selected.isNotEmpty) {
      _toggle(index, e);
      return;
    }
    if (e.isDir) {
      pane
        ..path = e.path
        ..selected.clear();
      unawaited(_load(pane));
    } else {
      unawaited(EntryOpener.open(context, e.path));
    }
  }

  void _toggle(int index, FsEntry e) {
    final pane = index == 0 ? _m.a : _m.b;
    setState(() {
      _m.active = index;
      if (!pane.selected.remove(e.path)) pane.selected.add(e.path);
    });
  }

  void _up(int index) {
    final pane = index == 0 ? _m.a : _m.b;
    final up = pane.parent(_floor);
    if (up == null) return;
    setState(() {
      _m.active = index;
      pane
        ..path = up
        ..selected.clear();
    });
    unawaited(_load(pane));
  }

  /// **Sürükle-bırak** (Ferrari H9.5, yalnız tablet): seçili satırın tutamacı
  /// karşı bölmeye bırakılınca seçim oraya KOPYALANIR (taşıma değil — en
  /// güvenli; taşımak için "Taşı" düğmesi). Başka uygulamaya bırakma yok
  /// (sistem sürükle-bırakı için eklenti gerekir).
  void _drop(int from) {
    setState(() => _m.active = from);
    unawaited(_transfer(move: false));
  }

  Future<void> _transfer({required bool move}) async {
    if (!_m.canTransfer() || _busy) return;
    final src = _m.current, dest = _m.other;
    final sources = src.selected.toList();
    final strings = AppStrings.of(context);
    setState(() => _busy = true);
    FmOpResult? r;
    try {
      r = move
          ? await FileOps.moveAll(sources, dest.path)
          : await FileOps.copyAll(sources, dest.path);
    } catch (_) {
      r = null;
    }
    src.selected.clear();
    FsEvents.changed([src.path, dest.path]);
    await Future.wait([_load(src), _load(dest)]);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null && r.errors.contains(SafWrite.noGrant)) {
      showSafGrantSnack(context, dest.path);
      return;
    }
    showSnack(
      context,
      r == null || r.errors.isNotEmpty
          ? strings.t('dp.failed')
          : strings.t(move ? 'dp.moved' : 'dp.copied', {'n': r.succeeded}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 600;
    final drag = isTabletWide(size);
    final panes = [_pane(0, drag: drag), _pane(1, drag: drag)];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('dp.title')),
        actions: [
          IconButton(
            key: const ValueKey('dp-swap'),
            tooltip: context.t('dp.swap'),
            icon: const Icon(AppIcons.compare),
            onPressed: () {
              setState(_m.swap);
              unawaited(_load(_m.a));
              unawaited(_load(_m.b));
            },
          ),
        ],
      ),
      body: wide
          ? Row(children: [
              Expanded(child: panes[0]),
              const VerticalDivider(width: 1),
              Expanded(child: panes[1]),
            ])
          : Column(children: [
              Expanded(child: panes[0]),
              const Divider(height: 1),
              Expanded(child: panes[1]),
            ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('dp-copy'),
                  onPressed: _m.canTransfer() && !_busy
                      ? () => _transfer(move: false)
                      : null,
                  icon: const Icon(AppIcons.copy),
                  label: Text(context.t('dp.copy_to'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('dp-move'),
                  onPressed: _m.canTransfer() && !_busy
                      ? () => _transfer(move: true)
                      : null,
                  icon: const Icon(AppIcons.move),
                  label: Text(context.t('dp.move_to'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pane(int index, {required bool drag}) {
    final pane = index == 0 ? _m.a : _m.b;
    final active = _m.active == index;
    final scheme = Theme.of(context).colorScheme;
    // GlobalKey: tablet döndürülünce bırakma hedefi gelip gider; bölme
    // (kaydırma konumu) yeniden kurulmasın (H9.2).
    final body = KeyedSubtree(
      key: _paneKeys[index],
      child: _paneBody(index, pane, active, scheme, drag: drag),
    );
    if (!drag) return body;
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _drop(d.data),
      builder: (context, cand, _) => cand.isEmpty
          ? body
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary, width: 2)),
              child: body,
            ),
    );
  }

  Widget _paneBody(int index, PaneState pane, bool active, ColorScheme scheme,
      {required bool drag}) {
    return Material(
      key: ValueKey('dp-pane-$index'),
      color: active ? scheme.surfaceContainerLow : scheme.surface,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _m.active = index),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                ),
              ),
              padding: const EdgeInsetsDirectional.only(start: 4, end: Gap.sm),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.t('dp.up'),
                    icon: const Icon(AppIcons.arrowUp),
                    onPressed:
                        pane.parent(_floor) == null ? null : () => _up(index),
                  ),
                  Expanded(
                    child: Text(
                      p.basename(pane.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.compact,
                    ),
                  ),
                  if (pane.selected.isNotEmpty)
                    Text(context.t('dp.selected', {'n': pane.selected.length}),
                        style: context.type.caption
                            .copyWith(color: scheme.primary)),
                ],
              ),
            ),
          ),
          Expanded(
            child: pane.error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Text(context.t('fm.unreadable'),
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView.builder(
                    itemExtent: 56,
                    itemCount: pane.entries.length,
                    itemBuilder: (context, i) {
                      final e = pane.entries[i];
                      final sel = pane.selected.contains(e.path);
                      return RepaintBoundary(
                        child: ListTile(
                          dense: true,
                          selected: sel,
                          leading: FmEntryIcon(entry: e, size: 36),
                          title: Text(e.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: !sel
                              ? null
                              : drag
                                  ? _dragHandle(index, pane, e)
                                  : const Icon(AppIcons.check),
                          onTap: () => _open(index, e),
                          onLongPress: () => _toggle(index, e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dragHandle(int index, PaneState pane, FsEntry e) => Draggable<int>(
        key: ValueKey('dp-drag-${e.path}'),
        data: index,
        onDragStarted: () => setState(() => _m.active = index),
        feedback: Material(
          elevation: 4,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            child: Text(context.t('dp.selected', {'n': pane.selected.length})),
          ),
        ),
        child: const Icon(AppIcons.dragHandle),
      );
}

/// Bölmenin çıkabileceği en üst klasör: dosyanın bulunduğu birimin kökü.
abstract final class FsScanRoots {
  static String floorOf(String path) {
    final parts = p.split(path);
    // /storage/emulated/0/... ya da /storage/XXXX-XXXX/...
    if (parts.length >= 4 && parts[1] == 'storage') {
      return parts[2] == 'emulated' && parts.length >= 4
          ? p.joinAll(parts.take(4))
          : p.joinAll(parts.take(3));
    }
    return parts.first;
  }
}
