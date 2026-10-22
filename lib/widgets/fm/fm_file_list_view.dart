import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/bidi.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fm_list_groups.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../motion.dart';
import 'drag_select.dart';
import 'fm_entry_tiles.dart';
import 'fm_fast_scroller.dart';
import 'fm_layout_sheet.dart';

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

  const FmFileListView({
    super.key,
    required this.entries,
    required this.layout,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    required this.subtitle,
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
  });

  bool get _selecting => selected.isNotEmpty;

  void _tap(FsEntry e) => _selecting ? onToggle(e) : onOpen(e);

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

    Widget view = layout.isGrid ? _grid(context, items) : _list(context, items);
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

  Widget _list(BuildContext context, List<FmListItem> items) =>
      ListView.builder(
        controller: controller,
        padding: _pad(context, Gap.xs),
        itemCount: items.length,
        itemBuilder: (context, i) => switch (items[i]) {
          FmHeaderItem(:final labelKey, :final count) =>
            FmGroupHeader(label: context.t(labelKey), count: count),
          FmEntryItem(:final entry, :final index) => DragSelectItem(
              index: index,
              child: FmEntryRow(
                entry: entry,
                layout: layout,
                selected: selected.contains(entry.path),
                selecting: _selecting,
                subtitle: subtitle(entry),
                showChevron: showChevron,
                badge: badge?.call(entry),
                onTap: () => _tap(entry),
                onCheck: () => onToggle(entry),
                onMore:
                    onMore == null || _selecting ? null : () => onMore!(entry),
              ),
            ),
        },
      );

  Widget _grid(BuildContext context, List<FmListItem> items) {
    // Izgarada başlıklar için gruplar ayrı `SliverGrid`lere bölünür.
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
    return LayoutBuilder(builder: (context, constraints) {
      const pad = Gap.sm;
      final delegate = fmGridDelegate(layout, constraints.maxWidth - pad * 2);
      final inset = _pad(context, pad);
      return CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: inset.top)),
          for (final (header, cells) in groups) ...[
            if (header != null)
              SliverToBoxAdapter(
                child: FmGroupHeader(
                    label: context.t(header.labelKey), count: header.count),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverGrid.builder(
                gridDelegate: delegate,
                itemCount: cells.length,
                itemBuilder: (context, i) {
                  final c = cells[i];
                  return DragSelectItem(
                    index: c.index,
                    child: FmEntryCard(
                      entry: c.entry,
                      layout: layout,
                      selected: selected.contains(c.entry.path),
                      selecting: _selecting,
                      onTap: () => _tap(c.entry),
                    ),
                  );
                },
              ),
            ),
          ],
          SliverPadding(padding: EdgeInsets.only(bottom: inset.bottom)),
        ],
      );
    });
  }
}

/// Grup başlığı: "Bu hafta · 12".
class FmGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  const FmGroupHeader({super.key, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            Gap.md, Gap.md, Gap.md, Gap.xs),
        child: Text(
          '$label · $count',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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

  const FmListToolbar({
    super.key,
    required this.count,
    required this.sort,
    required this.descending,
    required this.onSort,
    this.totalBytes,
    this.sortOptions = FmSort.values,
    this.filterCount = 0,
    this.onFilter,
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
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.only(start: Gap.md, end: Gap.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
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
          Flexible(
            child: PopupMenuButton<(FmSort, bool)>(
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
                      Flexible(
                        child: Text(
                          sortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                      Icon(
                        descending ? AppIcons.arrowDown : AppIcons.arrowUp,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
