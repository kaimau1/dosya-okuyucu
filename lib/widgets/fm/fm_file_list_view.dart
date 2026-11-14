import 'package:flutter/material.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/bidi.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fm_list_groups.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../motion.dart';
import 'drag_select.dart';
import 'fm_entry_icon.dart' show fmMediaHeroTag;
import 'fm_entry_tiles.dart';
import 'fm_fast_scroller.dart';
import 'fm_layout_sheet.dart';
import 'pinch_layout.dart';

/// **Ortak dosya listesi** (Faz 6 / U10, 2026-10-21).
///
/// KÖK NEDEN: gezgin, kategori, arama, indirilenler, yeni dosyalar, son
/// açılanlar, AI sonuçları ve seçici aynı satırı kullanıyordu ama liste /
/// ızgara / sürükleyerek seçim / boş durum / yükleniyor kodu her ekranda ayrı
/// yazılmıştı; biri değişince öbürleri geride kalıyordu (gezginin boş klasörü
/// hâlâ eski gri simgeydi, kategoride "sırala" görünmüyordu…). Şimdi hepsi tek
/// yerde:
/// * liste ([FmEntryRow]) / ızgara ([FmEntryCard]) — [layout]'tan;
/// * **gruplama** — [groupBy] tarihse "Bugün / Bu hafta / Bu ay / Daha
///   eski", türse tür başlıkları; ada göreyse hızlı kaydırıcıda harf;
/// * basılı tutup kaydırarak seçim ([DragSelectArea]) — indeks sıralı
///   listedeki yerdir, başlıklar indeks almaz;
/// * yükleniyor iskeleti, boş durum ([empty]), aşağı çekip yenileme.
///
/// Seçim durumu ÇAĞIRANDA tutulur ([selected]); bileşen durumsuzdur.
class FmFileListView extends StatelessWidget {
  final List<FsEntry> entries;
  final FmLayout layout;
  final Set<String> selected;
  final ScrollController? controller;
  final void Function(FsEntry) onOpen;
  final void Function(FsEntry) onToggle;
  final void Function(int start, int end, bool select)? onSelectRange;
  final void Function(FsEntry)? onMore;
  final String Function(FsEntry) subtitle;

  /// Alt satırın sağına hizalanan bilgi (bkz. [FmEntryRow.subtitleEnd]).
  final String? Function(FsEntry)? subtitleEnd;

  /// Satır sonu rozeti (bkz. [FmEntryRow.badge]); yalnız liste düzeninde.
  final Widget? Function(FsEntry)? badge;

  /// Gruplama ölçütü (genelde sıralama ölçütü). `null` = başlık yok.
  final FmSort? groupBy;

  /// Tarih gruplamasının zamanı (bkz. `groupEntries.timeOf`).
  final int Function(FsEntry e)? groupTimeOf;
  final Future<void> Function()? onRefresh;

  /// Liste boşken gösterilen yüz (genelde [FmEmptyState]).
  final Widget? empty;
  final bool loading;

  /// Altta bırakılan boşluk — bindirmeli seçim çubuğu ya da FAB son satırı
  /// örtmesin (çubuk yokken de aynı → liste zıplamaz).
  final double bottomPadding;
  final bool showChevron;

  /// İki parmakla sütun değiştirme (Faz 17 / G12); `null` ise kapalı.
  final ValueChanged<FmLayout>? onLayoutChange;

  const FmFileListView({
    super.key,
    required this.entries,
    required this.layout,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.subtitle,
    this.subtitleEnd,
    this.controller,
    this.onSelectRange,
    this.onMore,
    this.groupBy,
    this.groupTimeOf,
    this.onRefresh,
    this.empty,
    this.loading = false,
    this.bottomPadding = 96,
    this.showChevron = false,
    this.badge,
    this.onLayoutChange,
    this.focusPath,
    this.focusKey,
  });

  /// Vurgulanacak öğe ("İndirilenlerde göster", 2026-10-22) — satırı
  /// [focusKey] ile işaretlenir ki çağıran onu görünür alana kaydırabilsin.
  final String? focusPath;
  final GlobalKey? focusKey;

  Widget _focus(
      BuildContext context, FsEntry entry, Widget child, Set<String> fresh) {
    if (fresh.contains(entry.path)) {
      child = _FreshTint(key: ValueKey('fm-fresh:${entry.path}'), child: child);
    }
    if (focusPath == null || entry.path != focusPath) return child;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: focusKey,
      foregroundDecoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        border: Border.all(color: primary, width: 2),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: child,
    );
  }

  bool get _selecting => selected.isNotEmpty;

  void _tap(FsEntry e) => _selecting ? _toggle(e) : onOpen(e);

  /// Seçime ekle/çıkar — titreşimle (Ferrari H6.1).
  void _toggle(FsEntry e) {
    AppHaptics.selection();
    onToggle(e);
  }

  @override
  Widget build(BuildContext context) {
    if (loading && entries.isEmpty) return const FmListSkeleton();
    if (entries.isEmpty) {
      final face = empty ?? const SizedBox.shrink();
      if (onRefresh == null) return face;
      // Boş listede de aşağı çekip yenilenebilsin.
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: c.maxHeight, child: face),
          ),
        ),
      );
    }
    final items = groupBy == null
        ? [for (var i = 0; i < entries.length; i++) FmEntryItem(entries[i], i)]
        : groupEntries(entries, groupBy!,
            now: DateTime.now(), timeOf: groupTimeOf);

    Widget view = _FreshRows(
      entries: entries,
      builder: (fresh) => layout.isGrid
          ? _grid(context, items, fresh)
          : _list(context, items, fresh),
    );
    if (onSelectRange != null) {
      view = DragSelectArea(
        scrollController: controller,
        isSelected: (i) =>
            i >= 0 && i < entries.length && selected.contains(entries[i].path),
        onSelectRange: onSelectRange!,
        child: view,
      );
    }
    if (onRefresh != null) {
      view = RefreshIndicator(onRefresh: onRefresh!, child: view);
    }
    if (onLayoutChange != null) {
      view = PinchLayoutSwitcher(
          layout: layout, onChanged: onLayoutChange!, child: view);
    }
    // Ada göre sıralı uzun listede hızlı kaydırıcı baş harfi gösterir.
    if (controller != null && groupBy == FmSort.name && !layout.isGrid) {
      final rowExtent = layout.iconSizeFor(0) * context.fmIconScale +
          (layout == FmLayout.detail ? Gap.md : 12);
      view = Stack(
        children: [
          view,
          FmFastScroller(
            controller: controller!,
            padding: EdgeInsets.only(bottom: bottomPadding),
            labelFor: (offset) {
              final i =
                  (offset / rowExtent).floor().clamp(0, entries.length - 1);
              final name = entries[i].name;
              return name.isEmpty ? null : name.characters.first.toUpperCase();
            },
          ),
        ],
      );
    }
    return view;
  }

  EdgeInsets _pad(BuildContext context, double h) =>
      withNavInset(context, EdgeInsets.fromLTRB(h, Gap.xs, h, bottomPadding));

  Widget _list(
      BuildContext context, List<FmListItem> items, Set<String> fresh) {
    // **Sabit satır yüksekliği** (Faz 17 / G14): 5.000 öğede YUKARI
    // kaydırmada p99 50 ms ölçülmüştü — yukarıdan giren her satır ölçülüyor,
    // kaydırma ofseti tahminle düzeltiliyordu. Başlıksız listede bütün
    // satırlar aynı yükseklikte → ilk satır prototip olur, liste hiçbir
    // satırı ölçmeden konumlar. (Başlıklı listede yükseklik karışık; orada
    // eski yol.) Prototip GERÇEK satır: yazı ölçeği/tema ne olursa olsun
    // yükseklik birebir aynı, tahmin yok.
    final uniform = items.isNotEmpty && items.every((it) => it is FmEntryItem);
    if (uniform) {
      return ListView.builder(
        controller: controller,
        padding: _pad(context, Gap.xs),
        itemCount: items.length,
        prototypeItem: _row(items.first as FmEntryItem),
        itemBuilder: (context, i) =>
            _focus(context, (items[i] as FmEntryItem).entry,
                _row(items[i] as FmEntryItem), fresh),
      );
    }
    // **Yapışkan grup başlıkları** (Ferrari H4.5, 2026-11-14): "Bugün ·
    // Bu hafta · Daha eski" başlığı grubunun satırları kaydıkça üstte
    // durur, grup bitince bir sonrakine yer verir (`SliverMainAxisGroup` +
    // sabitlenmiş başlık). Grup İÇİNDE satırlar yine eş boylu → her grup
    // prototip satırla konumlanır (eski karışık `ListView`'dan da hızlı).
    final inset = _pad(context, Gap.xs);
    final headerExtent = FmGroupHeader.extentOf(context);
    final background = Theme.of(context).scaffoldBackgroundColor;
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: inset.top)),
        for (final (header, cells) in _groups(items))
          SliverMainAxisGroup(slivers: [
            if (header != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedGroupHeader(
                  label: context.t(header.labelKey),
                  count: header.count,
                  extent: headerExtent,
                  background: background,
                  padding: inset.copyWith(top: 0, bottom: 0),
                ),
              ),
            if (cells.isNotEmpty)
              SliverPadding(
                padding: inset.copyWith(top: 0, bottom: 0),
                sliver: SliverPrototypeExtentList.builder(
                  prototypeItem: _row(cells.first),
                  itemCount: cells.length,
                  itemBuilder: (context, i) =>
                      _focus(context, cells[i].entry, _row(cells[i]), fresh),
                ),
              ),
          ]),
        SliverPadding(padding: EdgeInsets.only(bottom: inset.bottom)),
      ],
    );
  }

  /// Başlık + altındaki satırlar (ilk başlıktan önceki satırlar başlıksız).
  static List<(FmHeaderItem?, List<FmEntryItem>)> _groups(
      List<FmListItem> items) {
    final groups = <(FmHeaderItem?, List<FmEntryItem>)>[];
    for (final it in items) {
      switch (it) {
        case FmHeaderItem():
          groups.add((it, []));
        case FmEntryItem():
          if (groups.isEmpty) groups.add((null, []));
          groups.last.$2.add(it);
      }
    }
    return groups;
  }

  Widget _row(FmEntryItem item) {
    final entry = item.entry;
    return DragSelectItem(
      index: item.index,
      child: FmEntryRow(
        entry: entry,
        layout: layout,
        selected: selected.contains(entry.path),
        selecting: _selecting,
        subtitle: subtitle(entry),
        subtitleEnd: subtitleEnd?.call(entry),
        showChevron: showChevron,
        badge: badge?.call(entry),
        onTap: () => _tap(entry),
        onCheck: () => _toggle(entry),
        onMore: onMore == null || _selecting ? null : () => onMore!(entry),
        audioQueue: _audioQueue,
        heroTag: _heroTag(entry),
      ),
    );
  }

  /// Görsel satırı galeriye büyüyerek açılır (Ferrari H6.3). Listede her yol
  /// bir kez geçer → etiket rotada tektir. Galeri `EntryOpener` →
  /// `imageGalleryRoute` ile açılır; hedef sayfa aynı etiketi taşır.
  String? _heroTag(FsEntry e) =>
      e.category == FmCategory.image ? fmMediaHeroTag(e.path) : null;

  /// Satır içi oynatmanın listesi: bu görünümdeki sesler, sırasıyla.
  List<String> _audioQueue() => [
        for (final e in entries)
          if (!e.isDir && FmType.of(e) == FmType.audio) e.path,
      ];

  Widget _grid(
      BuildContext context, List<FmListItem> items, Set<String> fresh) {
    // Izgarada başlıklar için gruplar ayrı `SliverGrid`lere bölünür;
    // başlık listede olduğu gibi yapışkan (H4.5).
    final groups = _groups(items);
    final headerExtent = FmGroupHeader.extentOf(context);
    final background = Theme.of(context).scaffoldBackgroundColor;
    return LayoutBuilder(builder: (context, constraints) {
      const pad = Gap.sm;
      final delegate = fmGridDelegate(layout, constraints.maxWidth - pad * 2);
      final inset = _pad(context, pad);
      return CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: inset.top)),
          for (final (header, cells) in groups) SliverMainAxisGroup(slivers: [
            if (header != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedGroupHeader(
                  label: context.t(header.labelKey),
                  count: header.count,
                  extent: headerExtent,
                  background: background,
                  padding: EdgeInsets.zero,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverGrid.builder(
                gridDelegate: delegate,
                itemCount: cells.length,
                itemBuilder: (context, i) {
                  final c = cells[i];
                  return _focus(
                      context,
                      c.entry,
                      DragSelectItem(
                        index: c.index,
                        child: FmEntryCard(
                          entry: c.entry,
                          layout: layout,
                          selected: selected.contains(c.entry.path),
                          selecting: _selecting,
                          onTap: () => _tap(c.entry),
                          heroTag: _heroTag(c.entry),
                        ),
                      ),
                      fresh);
                },
              ),
            ),
          ]),
          SliverPadding(padding: EdgeInsets.only(bottom: inset.bottom)),
        ],
      );
    });
  }
}

/// **Liste değişimi** (Ferrari H6.4, 2026-11-14): yapıştır/oluştur/taşı
/// sonrası listeye YENİ giren satır bir an vurgulanıp söner — kullanıcı
/// eklenenin nereye düştüğünü görür.
///
/// Yalnız boyamada (ön plan rengi): hücrede `Opacity`/katman ve boy
/// animasyonu yok (kasma kontrol 1 ve 6). Silinen satırın "kapanması"
/// YAPILMADI: satırlar sabit boylu (prototip, Faz 17 / G14) — kapanma boy
/// animasyonu ister, kaydırma ölçüsünü bozar.
///
/// Fark yalnız öğe sayısı ARTINCA ve iki liste de [fmFreshLimit]'i
/// aşmıyorsa hesaplanır: seçim/klasör boyutu gibi her `setState` O(1) kalır,
/// 5.000 öğelik klasörde hiç çalışmaz. [_freshMax]'tan çok yeni öğe (klasör
/// ya da süzgeç değişimi) vurgulanmaz.
const fmFreshLimit = 2000;
const _freshMax = 20;

@visibleForTesting
Set<String> fmFreshPaths(List<FsEntry> before, List<FsEntry> after) {
  if (before.isEmpty ||
      after.length <= before.length ||
      after.length > fmFreshLimit) {
    return const {};
  }
  final old = {for (final e in before) e.path};
  final fresh = <String>{};
  for (final e in after) {
    if (old.contains(e.path)) continue;
    if (fresh.length == _freshMax) return const {};
    fresh.add(e.path);
  }
  return fresh;
}

class _FreshRows extends StatefulWidget {
  final List<FsEntry> entries;
  final Widget Function(Set<String> fresh) builder;
  const _FreshRows({required this.entries, required this.builder});

  @override
  State<_FreshRows> createState() => _FreshRowsState();
}

class _FreshRowsState extends State<_FreshRows> {
  Set<String> _fresh = const {};

  @override
  void didUpdateWidget(_FreshRows old) {
    super.didUpdateWidget(old);
    if (!identical(old.entries, widget.entries)) {
      _fresh = fmFreshPaths(old.entries, widget.entries);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_fresh);
}

/// Yeni satırın sönen vurgusu; "animasyonları kaldır"da süre 0 → hiç
/// görünmez. Bittiğinde saydam kalır (ağaç şekli değişmez).
class _FreshTint extends StatelessWidget {
  final Widget child;
  const _FreshTint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: Motion.of(context, Motion.pulse),
      curve: Motion.exit,
      child: child,
      builder: (context, t, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.16 * t),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: child,
      ),
    );
  }
}

/// Grup başlığı: "Bu hafta · 12".
class FmGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  const FmGroupHeader({super.key, required this.label, required this.count});

  static TextStyle? _style(ThemeData theme) =>
      theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      );

  /// Başlığın tam boyu (yazı ölçeğiyle) — yapışkan başlık sabit boy ister.
  static double extentOf(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: _style(Theme.of(context))),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final h = painter.height;
    painter.dispose();
    return h + Gap.md + Gap.xs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 3.47: Android/iOS'ta `header` etkisiz, başlık `headingLevel` ile bildirilir.
    return Semantics(
      header: true,
      headingLevel: 2,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            Gap.md, Gap.md, Gap.md, Gap.xs),
        child: Text(
          '$label · $count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(theme),
        ),
      ),
    );
  }
}

/// Yapışkan grup başlığı (H4.5): satırların üstünde dururken altı görünmesin
/// diye zemin rengiyle örtülür.
class _PinnedGroupHeader extends SliverPersistentHeaderDelegate {
  final String label;
  final int count;
  final double extent;
  final Color background;
  final EdgeInsets padding;

  const _PinnedGroupHeader({
    required this.label,
    required this.count,
    required this.extent,
    required this.background,
    required this.padding,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: background,
        child: Padding(
          padding: padding,
          child: FmGroupHeader(label: label, count: count),
        ),
      );

  @override
  bool shouldRebuild(_PinnedGroupHeader old) =>
      old.label != label ||
      old.count != count ||
      old.extent != extent ||
      old.background != background ||
      old.padding != padding;
}

/// Liste üstündeki **araç şeridi** (Faz 6 / U2): solda "142 öğe · 3,2 GB",
/// sağda **Sırala: Ad ↑** (tek dokunuşla menü; yön oku görünür) ve
/// **Filtre** (etkin ölçüt sayısı rozetli).
///
/// KÖK NEDEN: sıralama 13 maddelik ⋮ menüsündeydi ve hangi sıralamanın açık
/// olduğu ekranda hiçbir yerde yazmıyordu.
class FmListToolbar extends StatelessWidget {
  final int count;
  final int? totalBytes;
  final FmSort sort;
  final bool descending;
  final void Function(FmSort sort, bool descending) onSort;
  final List<FmSort> sortOptions;

  /// Etkin filtre ölçütü sayısı (rozet).
  final int filterCount;

  /// Filtre düğmesi; `null` ise düğme çizilmez.
  final VoidCallback? onFilter;

  /// "Yalnız bu klasör" anahtarı (Faz 17 / G3) — `null` ise menüde yok.
  final bool? folderOnly;
  final ValueChanged<bool>? onFolderOnly;

  /// Satırın başına konan süzgeç hapları (ör. tür seçici). Verilirse özet
  /// metninin ("142 öğe") yerini alır — sayı zaten tür hapında yazar ve
  /// süzgeç ile sıralama TEK satırda durur (2026-10-28).
  final List<Widget> filters;

  const FmListToolbar({
    this.filters = const [],
    super.key,
    required this.count,
    required this.sort,
    required this.descending,
    required this.onSort,
    this.totalBytes,
    this.sortOptions = FmSort.values,
    this.filterCount = 0,
    this.onFilter,
    this.folderOnly,
    this.onFolderOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = totalBytes != null && totalBytes! > 0
        ? context.t('list.summary_size',
            {'n': count, 'size': FsPaths.humanSize(totalBytes!)})
        : context.t('list.summary', {'n': count});
    final sortName = context.t(sort.labelKey);
    final sortText = Text(
      sortName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
    );
    // Süzgeç hapları varsa sıralama onlarla AYNI kaydırmada durur: 360 dp +
    // 2,0× yazıda sabit bir sıralama düğmesi tür hapını ezip
    // dokunulamaz yapıyordu (2026-10-28 taşma testi).
    Widget sortMenu({required bool inScroll}) =>
        PopupMenuButton<(FmSort, bool)>(
          tooltip: context.t('list.sort_by', {'name': sortName}),
          onSelected: (v) => onSort(v.$1, v.$2),
          itemBuilder: (_) => [
            for (final s in sortOptions)
              CheckedPopupMenuItem(
                checked: s == sort,
                // Aynı ölçüte yeniden dokunmak yönü çevirir; yeni ölçüt
                // kendi doğal yönüyle başlar (tarih/boyut: yeni/büyük üstte).
                value: (
                  s,
                  s == sort
                      ? !descending
                      : (s == FmSort.date || s == FmSort.size),
                ),
                child: Text(context.t(s.labelKey)),
              ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem(
              checked: !descending,
              value: (sort, false),
              child: Text(context.t('list.sort_dir_asc')),
            ),
            CheckedPopupMenuItem(
              checked: descending,
              value: (sort, true),
              child: Text(context.t('list.sort_dir_desc')),
            ),
            if (folderOnly != null) ...[
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                key: const ValueKey('sort-folder-only'),
                checked: folderOnly!,
                // Değer döndürmez: anahtar kendi geri çağrısıyla çalışır.
                onTap: () => onFolderOnly?.call(!folderOnly!),
                child: Text(context.t('list.sort_folder_only')),
              ),
            ],
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.sort, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                  if (inScroll) sortText else Flexible(child: sortText),
                  Icon(
                    descending ? AppIcons.arrowDown : AppIcons.arrowUp,
                    size: 16,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.only(start: Gap.md, end: Gap.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (filters.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [...filters, sortMenu(inScroll: true)]),
              ),
            )
          else
            Expanded(
              child: Text(
                bidiParts(context, summary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          // Flexible: 360 dp + 2,0× yazıda "Tarihe göre ↓" sığmayınca kısalır
          // (Faz 13 taşma testi) — özet metni zaten Expanded.
          if (filters.isEmpty) Flexible(child: sortMenu(inScroll: false)),
          if (onFilter != null)
            IconButton(
              tooltip: filterCount > 0
                  ? context.t('list.filter_n', {'n': filterCount})
                  : context.t('list.filter'),
              onPressed: onFilter,
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: Icon(AppIcons.filter,
                    color: filterCount > 0 ? scheme.primary : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seçim üst çubuğunun **metinli** menüsü (Faz 6 / U8): görünür "Tümünü
/// seç / Seçimi kaldır" düğmesi + ⋮ içinde "Ters çevir", (tek öğe seçiliyken)
/// "Bunun üstündekileri / altındakileri seç".
///
/// KÖK NEDEN: bu eylemler üç çıplak simgeydi (`expand_less`, `expand_more`,
/// `swap_horiz`) — anlamlarını yalnız uzun basınca çıkan ipucu söylüyordu.
class FmSelectionActions extends StatelessWidget {
  final bool allSelected;
  final bool single;
  final VoidCallback onToggleAll;
  final VoidCallback? onInvert;
  final VoidCallback onAbove;
  final VoidCallback onBelow;

  /// Ekrana özel ek eylemler (⋮ menüsünün başında, metinli) — ör. Son
  /// açılanlar'da "Geçmişten kaldır". Simge düğmesi olarak çubuğa eklemek
  /// 360 dp + büyük yazıda başlığı taşırıyordu (Faz 13 taşma testi).
  final List<({IconData icon, String label, VoidCallback onTap})> extra;

  const FmSelectionActions({
    super.key,
    required this.allSelected,
    required this.single,
    required this.onToggleAll,
    required this.onAbove,
    required this.onBelow,
    this.onInvert,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(String v, IconData icon, String text) =>
        PopupMenuItem(
          value: v,
          child: Row(children: [
            Icon(icon, size: AppIcons.small),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(text)),
          ]),
        );
    final menu = [
      for (var i = 0; i < extra.length; i++)
        item('extra$i', extra[i].icon, extra[i].label),
      if (onInvert != null)
        item('invert', AppIcons.selectInvert, context.t('sel.invert')),
      if (single) ...[
        item('above', AppIcons.selectAbove, context.t('sel.above')),
        item('below', AppIcons.selectBelow, context.t('sel.below')),
      ],
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onToggleAll,
          child:
              Text(allSelected ? context.t('sel.none') : context.t('sel.all')),
        ),
        if (menu.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: context.t('sel.menu'),
            icon: const Icon(AppIcons.more),
            onSelected: (v) => switch (v) {
              _ when v.startsWith('extra') =>
                extra[int.parse(v.substring(5))].onTap(),
              'invert' => onInvert?.call(),
              'above' => onAbove(),
              _ => onBelow(),
            },
            itemBuilder: (_) => menu,
          ),
      ],
    );
  }
}
