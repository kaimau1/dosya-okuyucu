import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/motion.dart';
import '../../core/skin.dart';
import '../../core/theme.dart';
import '../motion.dart';
import 'drag_trash_target.dart';
import 'fm_category_tile.dart';
import 'reorder_hover_gate.dart';

/// **Ana ekran kutuları — sürükle-sırala, çöpe at, dört düzen** (2026-11-15).
///
/// Kullanıcı: *"buradaki kartların üzerine basılı tutarak yerini değiştirme,
/// silme, taşıma işlemleri yapılabilmeli; silmek için altta çöp simgesi
/// çıksın, notlar uygulamasındaki gibi"* + Fable tasarımları
/// (`docs/design/ana_ekran/` A Sakin · B Bento · C Koyu başlık).
///
/// - Basılı tut → kutu elde; parmak başka kutunun üstünde DURUNCA sıra canlı
///   önizlenir ([ReorderHoverGate]: durma + soğuma + kilit — iki hücre
///   arasında zıplama yok, "not" P56 kök nedeni). Parmak kalkınca görünen
///   sıra [onReorder]'a gider.
/// - Sürüklerken [dragging] true → ekranın altında [DragTrashTarget] belirir;
///   oraya bırakılan kutu ana ekrandan kalkar (çağıran karar verir).
/// - Düzen [style]'a göre: klasik (bugünkü çerçevesiz simgeler), Sakin
///   (çerçeveli simge kutusu), Bento (büyük/orta/küçük kartlar), Koyu başlık
///   (iki sütunlu liste kartı).
///
/// AKICILIK (kasma listesi): önizleme sırası YALNIZ bu widget'ın durumu —
/// pano yeniden kurulmaz; hücreler `RepaintBoundary` ve sabit oranlı.
class HomeTileBoard extends StatefulWidget {
  final List<FmTileData> tiles;
  final HomeStyle style;

  /// Parmak kalkınca görünen sıra (kimlikler).
  final ValueChanged<List<String>> onReorder;

  /// Sürükleme sürüyor mu? Çöp hedefi bunu dinler.
  final ValueNotifier<bool> dragging;

  const HomeTileBoard({
    super.key,
    required this.tiles,
    required this.style,
    required this.onReorder,
    required this.dragging,
  });

  @override
  State<HomeTileBoard> createState() => _HomeTileBoardState();
}

class _HomeTileBoardState extends State<HomeTileBoard> {
  late List<String> _order = _ids(widget.tiles);
  final _gate = ReorderHoverGate();
  String? _dragged;
  Timer? _retry;

  static List<String> _ids(List<FmTileData> tiles) =>
      [for (final t in tiles) t.id];

  @override
  void didUpdateWidget(HomeTileBoard old) {
    super.didUpdateWidget(old);
    // Sürükleme sürerken dışarıdan gelen yeniden kurulum önizlemeyi bozmasın.
    if (_dragged == null) _order = _ids(widget.tiles);
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _start(String id) {
    _gate.reset();
    _dragged = id;
    AppHaptics.selection();
    widget.dragging.value = true;
  }

  void _hover(String target) {
    final dragged = _dragged;
    if (dragged == null || dragged == target) return;
    if (!_gate.offer(target)) {
      // Durma süresi dolunca parmak kımıldamasa da yer değişsin.
      final wait = _gate.remaining();
      _retry?.cancel();
      if (wait != null) {
        _retry = Timer(wait, () {
          if (mounted && _gate.candidate == target) _hover(target);
        });
      }
      return;
    }
    final from = _order.indexOf(dragged);
    final to = _order.indexOf(target);
    if (from < 0 || to < 0) return;
    setState(() {
      _order = [..._order]..removeAt(from);
      _order.insert(to, dragged);
    });
    AppHaptics.step();
  }

  void _end() {
    _retry?.cancel();
    final changed = !_listEq(_order, _ids(widget.tiles));
    _dragged = null;
    widget.dragging.value = false;
    if (changed) widget.onReorder(List.of(_order));
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<FmTileData> get _ordered {
    final byId = {for (final t in widget.tiles) t.id: t};
    return [
      for (final id in _order)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Sürüklenebilir + bırakma hedefi hücre.
  Widget _cell(FmTileData t, double width, double height, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    final radius = context.fmCardRadius;
    final motion = !Motion.reduced(context);
    return DragTarget<String>(
      key: ValueKey('home-tile-${t.id}'),
      onWillAcceptWithDetails: (d) => d.data != t.id,
      onMove: (_) => _hover(t.id),
      onLeave: (_) => _gate.leave(t.id),
      onAcceptWithDetails: (_) {},
      builder: (context, candidate, _) => LongPressDraggable<String>(
        data: t.id,
        // Titreşim uygulama ayarından ([AppHaptics], `_start`) — bekçi testi.
        hapticFeedbackOnStart: false,
        onDragStarted: () => _start(t.id),
        // `onDragEnd` hücre yeniden kurulunca gelmez ("not" F60.S12 kökü);
        // bu ikisi birbirini dışlar ve her bırakmada tam bir kez gelir.
        onDragCompleted: _end,
        onDraggableCanceled: (_, _) => _end(),
        feedback: TrashPullFeedback(
          child: Transform.rotate(
            angle: motion ? -0.8 * math.pi / 180 : 0,
            child: Transform.scale(
              scale: motion ? 1.04 : 1,
              child: Material(
                color: scheme.surfaceContainerLow,
                elevation: 8,
                shadowColor: scheme.shadow,
                borderRadius: BorderRadius.circular(radius),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(width: width, height: height, child: child),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: child),
        child: RepaintBoundary(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => switch (widget.style) {
          HomeStyle.classic => _grid(c.maxWidth, 0.94, FmCategoryTile.new),
          HomeStyle.calm => _grid(c.maxWidth, 0.80, _CalmTile.new),
          HomeStyle.bento => _bento(c.maxWidth),
          HomeStyle.band => _band(c.maxWidth),
        },
      );

  Widget _grid(double width, double aspect,
      Widget Function({Key? key, required FmTileData data}) tile) {
    final tiles = _ordered;
    final columns = FmCategoryGrid.columnsFor(width);
    const gap = Gap.xs;
    final w = (width - gap * (columns - 1)) / columns;
    final h = w / aspect;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final t in tiles)
          SizedBox(
            width: w,
            height: h,
            child: _cell(t, w, h, tile(data: t)),
          ),
      ],
    );
  }

  /// B · Bento: ilk iki kutu büyük renkli, sonraki iki orta, gerisi küçük.
  Widget _bento(double width) {
    final tiles = _ordered;
    const gap = Gap.sm;
    final half = (width - gap) / 2;
    final columns = FmCategoryGrid.columnsFor(width);
    final small = (width - gap * (columns - 1)) / columns;
    final scaler = MediaQuery.textScalerOf(context);
    // 2026-11-15 (kullanıcı: büyük kutular "çok büyük alınlı", %20 alçalsın):
    // 140 → 112 dp (yazı ölçeğiyle büyüyen pay korunur).
    final bigH = 72 + scaler.scale(40);
    final midH = 52 + scaler.scale(24);
    final smallH = 70 + scaler.scale(30);
    Widget sized(FmTileData t, double w, double h, Widget child) =>
        SizedBox(width: w, height: h, child: _cell(t, w, h, child));
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var i = 0; i < tiles.length; i++)
          if (i < 2)
            sized(tiles[i], half, bigH, _BentoBig(data: tiles[i]))
          else if (i < 4)
            sized(tiles[i], half, midH, _BentoMid(data: tiles[i]))
          else
            sized(tiles[i], small, smallH, _BentoSmall(data: tiles[i])),
      ],
    );
  }

  /// C · Koyu başlık: tek kartta iki sütunlu liste, satırlar arası ince çizgi.
  Widget _band(double width) {
    final tiles = _ordered;
    final scheme = Theme.of(context).colorScheme;
    final radius = context.fmCardRadius;
    final h = 52 + MediaQuery.textScalerOf(context).scale(20);
    final w = (width - 2) / 2;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: scheme.outlineVariant));
      }
      rows.add(Row(
        children: [
          for (final t in tiles.skip(i).take(2))
            SizedBox(width: w, height: h, child: _cell(t, w, h, _BandRow(data: t))),
        ],
      ));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(children: rows),
      ),
    );
  }
}

/// Koyu temada kimlik rengi bir tık açılır (kategori kutusuyla aynı kural).
Color _tint(BuildContext context, Color c) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(c, AppColors.mixLight, 0.25)!
        : c;

/// Simge kutusu: rengin %14'ü zemin, glif kimlik renginde.
class _IconBox extends StatelessWidget {
  final FmTileData data;
  final double size;
  final double glyph;
  final bool framed;
  const _IconBox({
    required this.data,
    required this.size,
    required this.glyph,
    this.framed = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _tint(context, data.color);
    return data.badged(SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: framed
              ? scheme.surfaceContainerLow
              : c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.3),
          border: framed ? Border.all(color: scheme.outlineVariant) : null,
        ),
        child: Icon(data.icon, size: glyph, color: c),
      ),
    ));
  }
}

class _Label extends StatelessWidget {
  final FmTileData data;
  final TextAlign align;
  final bool large;
  const _Label(this.data, {this.align = TextAlign.center, this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = align == TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          start ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: (large ? theme.textTheme.titleSmall : theme.textTheme.labelLarge)
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
        if (data.subtitle.isNotEmpty)
          Text(
            data.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: theme.textTheme.bodySmall?.copyWith(
                letterSpacing: 0, color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Dokunma + basınca çökme — tüm düzenlerin ortak kabuğu.
class _Tap extends StatelessWidget {
  final FmTileData data;
  final Widget child;
  const _Tap({required this.data, required this.child});

  @override
  Widget build(BuildContext context) => PressScale(
        child: InkWell(
          onTap: data.gatedTap(context),
          borderRadius: BorderRadius.circular(context.fmCardRadius),
          child: child,
        ),
      );
}

/// A · Sakin: beyaz çerçeveli simge kutusu, altında ad + bilgi.
class _CalmTile extends StatelessWidget {
  final FmTileData data;
  const _CalmTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) => _Tap(
        data: data,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconBox(data: data, size: 52, glyph: 26, framed: true),
              const SizedBox(height: Gap.xs + 2),
              _Label(data),
            ],
          ),
        ),
      );
}

/// B · Bento büyük kutu: kimlik renginde açık zemin, büyük rakam.
class _BentoBig extends StatelessWidget {
  final FmTileData data;
  const _BentoBig({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _tint(context, data.color);
    final parts = data.subtitle.split(' · ');
    return Material(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(context.fmCardRadius),
      clipBehavior: Clip.antiAlias,
      child: _Tap(
        data: data,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.md, vertical: Gap.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              data.badged(Icon(data.icon, size: 28, color: c)),
              const Spacer(),
              Text(data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: parts.first,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (parts.length > 1)
                    TextSpan(
                        text: '  ${parts.skip(1).join(' · ')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// B · Bento orta kutu: beyaz kart, solda simge kutusu.
class _BentoMid extends StatelessWidget {
  final FmTileData data;
  const _BentoMid({required this.data});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.fmCardRadius),
        clipBehavior: Clip.antiAlias,
        child: _Tap(
          data: data,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Row(
              children: [
                _IconBox(data: data, size: 40, glyph: 22),
                const SizedBox(width: Gap.sm + 4),
                Expanded(child: _Label(data, align: TextAlign.start, large: true)),
              ],
            ),
          ),
        ),
      );
}

/// B · Bento küçük kutu: beyaz kart, ortada simge + ad.
class _BentoSmall extends StatelessWidget {
  final FmTileData data;
  const _BentoSmall({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = _tint(context, data.color);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(context.fmCardRadius),
      clipBehavior: Clip.antiAlias,
      child: _Tap(
        data: data,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: Gap.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              data.badged(Icon(data.icon, size: 24, color: c)),
              const SizedBox(height: Gap.xs + 2),
              _Label(data),
            ],
          ),
        ),
      ),
    );
  }
}

/// C · Koyu başlık liste satırı: renkli simge kutusu + ad + bilgi.
class _BandRow extends StatelessWidget {
  final FmTileData data;
  const _BandRow({required this.data});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: _Tap(
          data: data,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Row(
              children: [
                _IconBox(data: data, size: 40, glyph: 22),
                const SizedBox(width: Gap.sm + 4),
                Expanded(child: _Label(data, align: TextAlign.start, large: true)),
              ],
            ),
          ),
        ),
      );
}

/// C · Koyu başlık düzeninde **sabit** iki sütunlu liste (araçlar: sırası
/// kullanıma göre, sürüklenmez).
class HomeBandList extends StatelessWidget {
  final List<FmTileData> tiles;
  const HomeBandList({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = context.fmCardRadius;
    final h = 52 + MediaQuery.textScalerOf(context).scale(20);
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: scheme.outlineVariant));
      }
      final pair = tiles.skip(i).take(2).toList();
      rows.add(SizedBox(
        height: h,
        child: Row(children: [
          for (final t in pair) Expanded(child: _BandRow(data: t)),
          if (pair.length == 1) const Spacer(),
        ]),
      ));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(children: rows),
      ),
    );
  }
}
