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

/// Ana ekran kutularının yükseklik çarpanı (2026-11-15, kullanıcı: "bütün
/// butonların yüksekliğini %5 azalt, Araçlar ekrana sığsın").
const _kHomeHeight = 0.95;

/// Koyu başlık (band) satırları ayrıca %6 alçak (2026-11-15, kullanıcı:
/// "koyu başlık temasında yükseklikleri %6 azalt, Araçlar sığsın").
const _kBandHeight = 0.94;

/// Bento kutuları ayrıca %7 alçak (2026-11-15 üçüncü tur, kullanıcı:
/// "Araçlar hâlâ azıcık sığmıyor").
const _kBentoHeight = 0.93;

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
    AppHaptics.longPress();
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
          HomeStyle.calm =>
            _grid(c.maxWidth, 0.80, _CalmTile.new, iconExtent: 52),
          HomeStyle.bento => _bento(c.maxWidth),
          HomeStyle.band => _band(c.maxWidth),
        },
      );

  Widget _grid(
    double width,
    double aspect,
    Widget Function({Key? key, required FmTileData data, bool reserveSubtitle})
        tile, {
    double? iconExtent,
  }) {
    final tiles = _ordered;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = FmCategoryGrid.balancedColumns(
      width,
      tiles.length,
      textScale: scale,
    );
    const gap = Gap.xs;
    final w = (width - gap * (columns - 1)) / columns;
    // Klasik/Sakin ızgara yüksekliği metin ölçeğini de hesaba katar (sabit
    // en-boy oranı dar ekranda veya büyük yazıda `RenderFlex overflowed`
    // üretiyordu).
    final h = FmCategoryGrid.cellHeight(
      context,
      w,
      aspect: aspect,
      iconExtent: iconExtent,
    );
    final withSub = tiles.any((t) => t.subtitle.isNotEmpty);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final t in tiles)
          SizedBox(
            width: w,
            height: h,
            child: _cell(t, w, h, tile(data: t, reserveSubtitle: withSub)),
          ),
      ],
    );
  }

  /// B · Bento: ilk iki kutu büyük renkli, sonraki [_bentoMid] orta (uzun),
  /// gerisi küçük.
  ///
  /// 2026-11-18 (kullanıcı: "İndirilenler ve Belgeler de foto video gibi 2
  /// uzun kart olsun"): orta kart sayısı 2 → 4.
  static const _bentoMid = 4;

  Widget _bento(double width) {
    final tiles = _ordered;
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    const gap = Gap.sm;
    final half = (width - gap) / 2;
    // Çok büyük yazı ölçeğinde (veya çok dar ekranda) orta yatay kartlar iki
    // sütuna sıkışınca simge kutusundan sonra metne yer kalmıyor; tek sütuna
    // açılarak tam genişlik alır.
    final midW = width / math.max(1.0, scale) < 235 ? width : half;
    final smallCount = math.max(0, tiles.length - 2 - _bentoMid);
    final columns = FmCategoryGrid.balancedColumns(
      width,
      smallCount,
      textScale: scale,
    );
    final small = (width - gap * (columns - 1)) / columns;
    // 2026-11-15 (kullanıcı: büyük kutular "çok büyük alınlı", %20 alçalsın):
    // 140 → 112 dp (yazı ölçeğiyle büyüyen pay korunur).
    // 2026-11-15 (ikinci tur): tüm kutular %5 daha alçak ([_kHomeHeight]),
    // Araçlar bölümü ilk ekrana sığsın.
    // 2026-11-17: büyütülmüş yazı ölçeğinde (1,15×–2×) başlık + büyük rakamın
    // gerçek satır yüksekliği taban formülü aşabiliyordu; alt sınır eklendi.
    final bigH = math.max(
      (72 + scaler.scale(40)) * _kHomeHeight * _kBentoHeight,
      48 + scaler.scale(52),
    );
    final midH = math.max(
      (52 + scaler.scale(24)) * _kHomeHeight * _kBentoHeight,
      20 + scaler.scale(34),
    );
    final smallH = math.max(
      (70 + scaler.scale(30)) * _kHomeHeight * _kBentoHeight,
      44 + scaler.scale(30),
    );
    final smallWithSub =
        tiles.skip(2 + _bentoMid).any((t) => t.subtitle.isNotEmpty);
    Widget sized(FmTileData t, double w, double h, Widget child) =>
        SizedBox(width: w, height: h, child: _cell(t, w, h, child));
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var i = 0; i < tiles.length; i++)
          if (i < 2)
            sized(tiles[i], half, bigH, _BentoBig(data: tiles[i]))
          else if (i < 2 + _bentoMid)
            sized(tiles[i], midW, midH, _BentoMid(data: tiles[i]))
          else
            sized(
              tiles[i],
              small,
              smallH,
              _BentoSmall(data: tiles[i], reserveSubtitle: smallWithSub),
            ),
      ],
    );
  }

  /// C · Koyu başlık: tek kartta iki sütunlu liste, satırlar arası ince çizgi.
  Widget _band(double width) {
    final tiles = _ordered;
    final scheme = Theme.of(context).colorScheme;
    final radius = context.fmCardRadius;
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    final h = math.max(
      (52 + scaler.scale(20)) * _kHomeHeight * _kBandHeight,
      20 + scaler.scale(34),
    );
    final cols = width / math.max(1.0, scale) < 235 ? 1 : 2;
    final innerW = width - 2;
    final w = innerW / cols;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += cols) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: scheme.outlineVariant));
      }
      rows.add(Row(
        children: [
          for (final t in tiles.skip(i).take(cols))
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
  final bool reserveSubtitle;
  const _Label(
    this.data, {
    this.align = TextAlign.center,
    this.large = false,
    this.reserveSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final start = align == TextAlign.start;
    final boxAlign =
        start ? AlignmentDirectional.centerStart : Alignment.center;
    // Dört sütunlu küçük kutularda (`large == false`) `labelLarge` (14 sp) +
    // `bodySmall` (12 sp) ~70 dp hücrede hemen "..." ile kesiliyordu; klasik
    // ızgaradaki gibi `labelMedium` (12 sp) + `micro` (10 sp) kullanılır ve
    // hafif taşmalarda `FittedBox` metni kesmeden sığdırır.
    final titleStyle =
        (large ? theme.textTheme.labelLarge : theme.textTheme.labelMedium)
            ?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      height: 1.15,
    );
    final subStyle = (large
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelSmall?.merge(context.type.micro))
        ?.copyWith(
      letterSpacing: 0,
      height: 1.15,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titleH = scaler.scale(large ? 14 : 12) * 1.25;
    final subH = scaler.scale(large ? 11 : 10) * 1.25;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          start ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: titleH,
          child: Align(
            alignment: boxAlign,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: boxAlign,
              child: Text(
                data.label,
                maxLines: 1,
                textAlign: align,
                style: titleStyle,
              ),
            ),
          ),
        ),
        if (data.subtitle.isNotEmpty || reserveSubtitle)
          SizedBox(
            height: subH,
            child: data.subtitle.isEmpty
                ? null
                : Align(
                    alignment: boxAlign,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: boxAlign,
                      child: Text(
                        data.subtitle,
                        maxLines: 1,
                        textAlign: align,
                        style: subStyle,
                      ),
                    ),
                  ),
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
  final bool reserveSubtitle;
  const _CalmTile({
    super.key,
    required this.data,
    this.reserveSubtitle = false,
  });

  @override
  Widget build(BuildContext context) => _Tap(
        data: data,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconBox(data: data, size: 52, glyph: 26, framed: true),
              const SizedBox(height: Gap.xs),
              _Label(data, reserveSubtitle: reserveSubtitle),
            ],
          ),
        ),
      );
}

/// B · Bento büyük kutu: kimlik renginde açık zemin, büyük rakam.
class _BentoBig extends StatelessWidget {
  final FmTileData data;
  const _BentoBig({required this.data});

  static final _leadNumber = RegExp(
    r'^([+-]?\d[\d.,]*(?:\s*(?:KB|MB|GB|TB|B))?)\s*(.*)$',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _tint(context, data.color);
    final parts = data.subtitle.split(' · ');
    final first = parts.first.trim();
    // "120 GB · 3.093 dosya" veya "382 dosya düzenli" gibi sayısal özetlerde
    // yalnız baştaki sayı/boyut ("120 GB", "382") büyük rakamdır; kalan metin
    // ("dosya düzenli") temiz gövde stiliyle ayrılır.
    final m = _leadNumber.firstMatch(first);
    final leadNum = m?.group(1)?.trim() ?? '';
    final leadRest = m?.group(2)?.trim() ?? '';
    final tailParts = parts.skip(1).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final restText = [
      if (leadRest.isNotEmpty) leadRest,
      ...tailParts,
    ].join(' · ');
    return Material(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(context.fmCardRadius),
      clipBehavior: Clip.antiAlias,
      child: _Tap(
        data: data,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              // 2026-11-15: kutu alçaldı, içerik sığsın (12 → 9, simge 26).
              horizontal: Gap.md, vertical: Gap.sm + 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              data.badged(Icon(data.icon, size: 26, color: c)),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  data.label,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (data.subtitle.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: leadNum.isNotEmpty
                      ? Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: leadNum,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (restText.isNotEmpty)
                              TextSpan(
                                text: leadRest.isNotEmpty
                                    ? ' $restText'
                                    : '  $restText',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ]),
                          maxLines: 1,
                        )
                      : Text(
                          data.subtitle,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2),
            child: Row(
              children: [
                _IconBox(data: data, size: 36, glyph: 20),
                const SizedBox(width: Gap.sm),
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
  final bool reserveSubtitle;
  const _BentoSmall({
    required this.data,
    this.reserveSubtitle = false,
  });

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
              const SizedBox(height: Gap.xs),
              _Label(data, reserveSubtitle: reserveSubtitle),
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
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2),
            child: Row(
              children: [
                _IconBox(data: data, size: 36, glyph: 20),
                const SizedBox(width: Gap.sm),
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
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    final h = math.max(
      (52 + scaler.scale(20)) * _kHomeHeight * _kBandHeight,
      20 + scaler.scale(34),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth / math.max(1.0, scale) < 235 ? 1 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          if (i > 0) {
            rows.add(
                Divider(height: 1, thickness: 1, color: scheme.outlineVariant));
          }
          final pair = tiles.skip(i).take(cols).toList();
          rows.add(SizedBox(
            height: h,
            child: Row(children: [
              for (final t in pair) Expanded(child: _BandRow(data: t)),
              if (cols == 2 && pair.length == 1) const Spacer(),
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
      },
    );
  }
}
