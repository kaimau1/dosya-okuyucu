import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_navigator.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../models/fs_entry.dart';
import '../screens/settings_screen.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/fs_scan.dart';
import '../services/fm/open_history.dart';
import '../services/side_menu.dart';
import 'app_dialog.dart';
import 'fm/fm_category_tile.dart';
import 'fm/fm_entry_icon.dart';

/// **Yan menü** görünümü — bkz. [SideMenu].
///
/// Bir ROTA olarak açılır (saydam, perde dokununca/geri tuşunda kapanır):
/// böylece hangi ekrandaysak onun üstünde durur, geri tuşu doğal çalışır ve
/// menüden açılan sayfa o ekranın üstüne gelir (ana ekrana dönmeden geçiş).
/// Genişlik ekranın en çok 3/5'i (kullanıcı kuralı), en çok 360 dp.
abstract final class SideMenuView {
  static const maxFraction = 0.6;

  static double widthFor(double screen) =>
      math.min(screen * maxFraction, 360);

  /// Açık menünün rotası (parmakla sürükleme onu sürer).
  static _SideMenuRoute? _route;

  /// Menüyü kök gezgin üstünde açar (zaten açıksa bir şey yapmaz).
  /// [interactive]: parmakla çekerek açılıyor — rota kapalı (0) durur,
  /// [dragBy] / [endDrag] parmağı izletir (2026-11-15, kullanıcı: "parmağımla
  /// beraber hareket etmeli").
  static Future<void> show({bool interactive = false}) async {
    final nav = navigatorKey.currentState;
    final menu = SideMenu.instance;
    if (nav == null || !menu.ready.value || menu.open.value) return;
    unawaited(menu.ensureLoaded());
    menu.open.value = true;
    final route = _SideMenuRoute(
      barrierLabel: nav.context.t('common.close'),
      barrierColor:
          Theme.of(nav.context).colorScheme.scrim.withValues(alpha: 0.32),
      interactive: interactive,
    );
    _route = route;
    try {
      await nav.push(route);
    } finally {
      if (identical(_route, route)) _route = null;
      menu.open.value = false;
    }
  }

  /// Sürüklemeyle açılış: menüyü [dx] (mantıksal piksel, açılma yönünde
  /// artı) kadar ilerletir.
  static void dragBy(double dx) => _route?.dragBy(dx);

  /// Sürükleme bitti: hıza/konuma göre açık kalır ya da kapanır.
  static void endDrag(double velocity) => _route?.endDrag(velocity);
}

class _SideMenuRoute extends PopupRoute<void> {
  @override
  final String barrierLabel;
  @override
  final Color barrierColor;

  _SideMenuRoute({
    required this.barrierLabel,
    required this.barrierColor,
    bool interactive = false,
  }) : _dragging = interactive;

  /// Parmak menüyü sürüyor: geçiş eğrisiz (parmağın altında kalsın).
  bool _dragging;

  /// Menü genişliği (son çizimden).
  double _width = 300;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => Motion.medium;

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    // Sürüklemeyle açılış: kendiliğinden kayma yok, parmak sürer.
    if (_dragging) controller?.stop();
    return future;
  }

  void dragBy(double dx) {
    final c = controller;
    if (c == null || !isActive) return;
    if (!_dragging) setState(() => _dragging = true);
    c.value = (c.value + dx / _width).clamp(0.0, 1.0);
  }

  void endDrag(double velocity) {
    final c = controller;
    if (c == null || !isActive) return;
    setState(() => _dragging = false);
    final open = velocity.abs() > 300 ? velocity > 0 : c.value > 0.5;
    if (open) {
      unawaited(c.forward());
    } else if (isCurrent) {
      navigator?.pop();
    } else {
      navigator?.removeRoute(this);
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final width = SideMenuView.widthFor(MediaQuery.sizeOf(context).width);
    _width = width;
    final fromRight = sideMenuFromRight(context);
    double dir(double dx) => fromRight ? -dx : dx;
    // Açıkken ekranın HERHANGİ bir yerinden geri kaydırmak menüyü parmakla
    // birlikte kapatır (2026-11-15); boşluğa dokunmak kapatır.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isCurrent) navigator?.maybePop();
      },
      onHorizontalDragUpdate: (d) => dragBy(dir(d.delta.dx)),
      onHorizontalDragEnd: (d) => endDrag(dir(d.primaryVelocity ?? 0)),
      onHorizontalDragCancel: () => endDrag(0),
      child: Align(
        alignment: SideMenu.instance.handleRight
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: SizedBox(
          width: width,
          // Panelin içine dokunmak perdeye gitmesin.
          child: GestureDetector(
            onTap: () {},
            child: const _SideMenuPanel(),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final fromRight = sideMenuFromRight(context);
    return SlideTransition(
      position: Tween(begin: Offset(fromRight ? 1 : -1, 0), end: Offset.zero)
          .animate(_dragging
              ? animation
              : CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic)),
      child: child,
    );
  }
}

/// Menü (ve tutamaç) fiziksel olarak sağ kenarda mı: sağdan sola dilde
/// varsayılan sağ; "Tutamaç sağda" ayarı bunu tersine çevirir.
bool sideMenuFromRight(BuildContext context) =>
    (Directionality.of(context) == TextDirection.rtl) !=
    SideMenu.instance.handleRight;

Color _tint(BuildContext context, Color c) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(c, AppColors.mixLight, 0.25)!
        : c;

class _SideMenuPanel extends StatelessWidget {
  const _SideMenuPanel();

  void _run(BuildContext context, void Function(BuildContext root) action) {
    Navigator.of(context).pop();
    final root = navigatorKey.currentContext;
    if (root != null) action(root);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = AppSkinData.of(context).metrics;
    final fromRight = sideMenuFromRight(context);
    final r = Radius.circular(metrics.radiusSheet);
    return Material(
        color: theme.scaffoldBackgroundColor,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: fromRight
              ? BorderRadius.horizontal(left: r)
              : BorderRadius.horizontal(right: r),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          right: fromRight,
          left: !fromRight,
          child: ListenableBuilder(
            listenable: SideMenu.instance,
            builder: (context, _) {
              final menu = SideMenu.instance;
              final tiles = menu.tiles();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        Gap.md, Gap.sm, Gap.xs, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t('side.title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('side-menu-edit'),
                          tooltip: context.t('side.edit'),
                          icon: const Icon(AppIcons.tune),
                          color: scheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => showSideMenuEditor(context),
                        ),
                        IconButton(
                          key: const ValueKey('side-menu-settings'),
                          tooltip: context.t('common.settings'),
                          icon: const Icon(AppIcons.settings),
                          color: scheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _run(
                              context,
                              (root) => Navigator.of(root).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SettingsScreen()))),
                        ),
                      ],
                    ),
                  ),
                  if (menu.showRecents)
                    _RecentMini(
                      onOpen: (e) => _run(
                          context, (root) => EntryOpener.open(root, e.path)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Divider(
                        height: Gap.md, color: scheme.outlineVariant),
                  ),
                  // Basılı tutup sürükleyerek sıra (2026-11-16, kullanıcı:
                  // "menüde basılı tutarak yer düzeni yapılabilsin").
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.sm, 0, Gap.sm, Gap.md),
                      buildDefaultDragHandles: false,
                      header: _MenuRow(
                        key: const ValueKey('side-menu-home'),
                        icon: AppIcons.home,
                        color: scheme.primary,
                        label: context.t('side.home'),
                        onTap: () => _run(
                            context,
                            (root) =>
                                Navigator.of(root).popUntil((r) => r.isFirst)),
                      ),
                      itemCount: tiles.length,
                      onReorderItem: (from, to) =>
                          unawaited(menu.moveVisible(from, to)),
                      itemBuilder: (context, i) {
                        final t = tiles[i];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey('side-menu-${t.id}'),
                          index: i,
                          child: _MenuRow(
                            icon: t.icon,
                            color: t.color,
                            label: t.label,
                            subtitle: t.subtitle,
                            badge: t.badged,
                            onTap: () =>
                                _run(context, (root) => t.gatedTap(root)()),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
  }
}

/// Tek satır: temanın simge diliyle renkli simge kutusu + ad + alt yazı.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final Widget Function(Widget icon)? badge;
  final VoidCallback onTap;

  const _MenuRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.subtitle = '',
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppSkinData.of(context).metrics;
    final c = _tint(context, color);
    final glyph = FmTintedIcon(icon: icon, color: c, size: 22);
    return InkWell(
      borderRadius: BorderRadius.circular(metrics.radiusControl),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm, vertical: Gap.xs + 2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(metrics.radiusControl),
              ),
              child: badge == null ? glyph : badge!(glyph),
            ),
            const SizedBox(width: Gap.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üstte küçük, yana kaydırılan "Son açılanlar" kartları.
class _RecentMini extends StatefulWidget {
  final void Function(FsEntry e) onOpen;
  const _RecentMini({required this.onOpen});

  @override
  State<_RecentMini> createState() => _RecentMiniState();
}

class _RecentMiniState extends State<_RecentMini> {
  static const _limit = 12;
  List<FsEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await OpenHistory.ensureLoaded();
      final paths = OpenHistory.pathsByRecency().take(_limit * 2).toList();
      final stats = await FsScan.statPaths(paths);
      if (!mounted) return;
      setState(() => _items = [
            for (final e in stats)
              if (!e.isDir) e,
          ].take(_limit).toList());
    } catch (_) {
      // Bilinçli: son açılanlar okunamazsa şerit çizilmez; menü yine açılır.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final metrics = AppSkinData.of(context).metrics;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    const thumb = 52.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.md, Gap.sm, Gap.md, Gap.xs),
          child: Text(
            context.t('dash.sec_recent'),
            style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary),
          ),
        ),
        SizedBox(
          height: thumb + Gap.xs + 18 * scale,
          child: ListView.separated(
            key: const ValueKey('side-menu-recents'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, i) {
              final e = _items[i];
              return Semantics(
                button: true,
                label: e.name,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(metrics.radiusControl),
                  onTap: () => widget.onOpen(e),
                  child: SizedBox(
                    width: thumb + Gap.xs,
                    child: Column(
                      children: [
                        FmEntryIcon(
                            entry: e,
                            size: thumb,
                            radius: metrics.radiusControl),
                        const SizedBox(height: Gap.xs / 2),
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Menüyü düzenle: son açılanlar / kenar tutamacı aç-kapa, kartların sırası
/// (sürükle) ve görünürlüğü (onay kutusu).
Future<void> showSideMenuEditor(BuildContext context) {
  final menu = SideMenu.instance;
  return showAppSheet<void>(
    context,
    title: context.t('side.edit'),
    scrollable: false,
    builder: (ctx) => ListenableBuilder(
      listenable: menu,
      builder: (ctx, _) {
        final tiles = menu.tiles(includeHidden: true);
        final theme = Theme.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const ValueKey('side-edit-recents'),
              title: Text(ctx.t('side.show_recents')),
              value: menu.showRecents,
              onChanged: menu.setShowRecents,
            ),
            SwitchListTile(
              key: const ValueKey('side-edit-handle'),
              title: Text(ctx.t('side.show_handle')),
              subtitle: Text(ctx.t('side.show_handle_sub')),
              value: menu.showHandle,
              onChanged: menu.setShowHandle,
            ),
            SwitchListTile(
              key: const ValueKey('side-edit-handle-right'),
              title: Text(ctx.t('side.handle_right')),
              subtitle: Text(ctx.t('side.handle_right_sub')),
              value: menu.handleRight,
              onChanged: menu.showHandle ? menu.setHandleRight : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
              child: Text(ctx.t('side.reorder_hint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: tiles.length,
                onReorderItem: (from, to) {
                  final ids = [for (final t in tiles) t.id];
                  ids.insert(to, ids.removeAt(from));
                  unawaited(menu.setOrder(ids));
                },
                itemBuilder: (ctx, i) {
                  final t = tiles[i];
                  final shown = !menu.isHidden(t.id);
                  return ListTile(
                    key: ValueKey('side-edit-${t.id}'),
                    leading: Checkbox(
                      value: shown,
                      onChanged: (v) =>
                          unawaited(menu.setHidden(t.id, v != true)),
                    ),
                    title: Text(t.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: shown
                            ? null
                            : TextStyle(
                                color: theme.colorScheme.onSurfaceVariant)),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(Gap.sm),
                        child: Icon(AppIcons.dragHandle),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => unawaited(menu.reset()),
                  icon: const Icon(AppIcons.restore),
                  label: Text(ctx.t('side.reset')),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// **Her ekranda** menüyü açan katman (MaterialApp `builder`'ında, gezginin
/// ÜSTÜNDE): sol kenarda ince tutamaç (dokun ya da sağa çek) ve kenardan
/// sağa sürükleme şeridi. Pano kurulmadan (kilit/ilk açılış) ve menü açıkken
/// çizilmez.
///
/// Not: Android hareketle gezintide sol kenardan kaydırma sistemin "geri"
/// hareketidir; bu yüzden tutamaca DOKUNMAK her durumda çalışan yoldur.
class SideMenuLayer extends StatefulWidget {
  final Widget child;
  const SideMenuLayer({super.key, required this.child});

  @override
  State<SideMenuLayer> createState() => _SideMenuLayerState();
}

/// Ekranın sol yarısından sağa çekince menü PARMAKLA birlikte açılır
/// (2026-11-15, kullanıcı: "soldan çekmek zor, neredeyse tüm soldan
/// çekilebilsin, parmağımla beraber hareket etmeli").
///
/// Kaydırma eşiği bilinçli olarak büyük ([_slop]): içerideki yatay
/// kaydırıcılar (şeritler, galeri sayfaları ~18 px) ve yakınlaştırılmış
/// PDF/görsel kaydırması (~36 px) yarışı ÖNCE kazanır; menü yalnız kimsenin
/// istemediği yatay sürüklemeyi alır. Sistem "geri" hareketinin kenar şeridi
/// uygulamaya hiç gelmez, ondan sonrası bizim.
class _SideMenuLayerState extends State<SideMenuLayer> {
  static const _slop = 40.0;

  /// Sol bölgenin ekran genişliğine oranı.
  static const _zone = 0.5;

  bool _opening = false;
  double _lead = 0;
  double? _down;

  bool _allowed(Offset position) {
    final menu = SideMenu.instance;
    if (!menu.ready.value || menu.open.value || !menu.showHandle) return false;
    final width = MediaQuery.sizeOf(context).width;
    final x = sideMenuFromRight(context) ? width - position.dx : position.dx;
    return x <= width * _zone;
  }

  void _begin(double lead) {
    _opening = false;
    _lead = lead;
  }

  void _update(double dx, bool rtl) {
    final d = rtl ? -dx : dx;
    if (!_opening) {
      if (d <= 0) return;
      _opening = true;
      unawaited(SideMenuView.show(interactive: true));
      SideMenuView.dragBy(_lead);
    }
    SideMenuView.dragBy(d);
  }

  void _end(double velocity, bool rtl) {
    if (!_opening) return;
    _opening = false;
    SideMenuView.endDrag(rtl ? -velocity : velocity);
  }

  @override
  Widget build(BuildContext context) {
    final menu = SideMenu.instance;
    // Tanıyıcı her çizimde yeniden kurulmaz; yön ayarı anında okunsun.
    bool rtlNow() => sideMenuFromRight(context);
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _EdgeOpenRecognizer:
            GestureRecognizerFactoryWithHandlers<_EdgeOpenRecognizer>(
          () => _EdgeOpenRecognizer(allowed: _allowed, debugOwner: this),
          (r) {
            r.gestureSettings = const DeviceGestureSettings(touchSlop: _slop);
            r.onDown = (d) {
              _down = d.globalPosition.dx;
            };
            r.onStart = (d) {
              final from = _down;
              final lead = from == null ? 0.0 : d.globalPosition.dx - from;
              _begin(rtlNow() ? -lead : lead);
            };
            r.onUpdate = (d) {
              _update(d.delta.dx, rtlNow());
            };
            r.onEnd = (d) {
              _end(d.primaryVelocity ?? 0, rtlNow());
            };
            r.onCancel = () {
              _end(0, rtlNow());
            };
          },
        ),
      },
      child: Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: Listenable.merge(
              [menu, menu.ready, menu.open, menu.handleHiders]),
          builder: (context, _) {
            if (!menu.ready.value || menu.open.value) {
              return const SizedBox.shrink();
            }
            final h = MediaQuery.sizeOf(context).height;
            // Video/foto görüntüleyicide çizgi gizli; kenardan çekme sürer.
            if (!menu.showHandle || menu.handleHiders.value > 0) {
              return const SizedBox.shrink();
            }
            final scheme = Theme.of(context).colorScheme;
            // "Tutamaç sağda" = yazı yönünün SONU (sağdan sola dilde sol).
            final atEnd = menu.handleRight;
            return PositionedDirectional(
              start: atEnd ? null : 0,
              end: atEnd ? 0 : null,
              top: h * 0.42,
              child: Semantics(
                button: true,
                label: context.t('side.open'),
                child: GestureDetector(
                  key: const ValueKey('side-menu-handle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(SideMenuView.show()),
                  // Sürükleme dıştaki bölge tanıyıcısında (tutamaç sol
                  // bölgede); burada yalnız dokunma.
                  child: SizedBox(
                    width: 14,
                    height: 64,
                    child: Align(
                      alignment: atEnd
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        width: 5,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.45),
                          borderRadius: (atEnd
                                  ? const BorderRadiusDirectional.horizontal(
                                      start: Radius.circular(4))
                                  : const BorderRadiusDirectional.horizontal(
                                      end: Radius.circular(4)))
                              .resolve(Directionality.of(context)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
    );
  }
}

class _EdgeOpenRecognizer extends HorizontalDragGestureRecognizer {
  final bool Function(Offset position) allowed;
  _EdgeOpenRecognizer({required this.allowed, super.debugOwner});

  @override
  bool isPointerAllowed(PointerEvent event) =>
      allowed(event.position) && super.isPointerAllowed(event);
}

/// Ana ekran gibi yerlerde menü düğmesi.
class SideMenuButton extends StatelessWidget {
  final Color? color;
  const SideMenuButton({super.key, this.color});

  @override
  Widget build(BuildContext context) => IconButton(
        key: const ValueKey('side-menu-button'),
        tooltip: context.t('side.open'),
        icon: const Icon(AppIcons.menu),
        iconSize: 22,
        color: color,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: () => unawaited(SideMenuView.show()),
      );
}
