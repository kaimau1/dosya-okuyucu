import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/fm_colors_store.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../app_dialog.dart';
import 'fm_filter_widgets.dart';
import 'pin_dialog.dart';
import 'smart_cat_style.dart';

/// Süzgeç sayfasının sonucu: süzgeç + sıralama birlikte döner.
class FmFilterResult {
  final FmFilter filter;
  final FmSort sort;
  final bool descending;
  const FmFilterResult(this.filter, this.sort, this.descending);
}

/// **Süzgeç ve sıralama** sayfası — Fotoğraflar, kategori listeleri, arama,
/// indirilenler ve bellek analizinde AYNI sayfa kullanılır.
///
/// 2026-11-23 yeniden tasarım: dağınık Material çipleri yerine her ölçüt
/// grubu kendi kartında ([FmFilterSectionCard]), dengeli 2×2 sıralama +
/// modern yön anahtarı ([FmSortDirectionToggle]), renkli etiket/kategori
/// hapları ([FmFilterOptionChip]), sabit başlık ve sabit alt işlem çubuğu.
Future<FmFilterResult?> showFmFilterSheet(
  BuildContext context, {
  required FmFilter filter,
  required FmSort sort,
  required bool descending,
  Map<String, int> extensions = const {},
  Map<MediaBucket, int> buckets = const {},
  Map<ChatMediaKind, int> chatKinds = const {},
  Map<String, int> tags = const {},
  Map<String, int> smartCats = const {},
  bool showSort = true,
  bool showDuplicateSwitch = false,
  List<FmSort> sortOptions = FmSort.values,
}) =>
    showAppSheet<FmFilterResult>(
      context,
      scrollable: false,
      builder: (_) => _FilterSheet(
        filter: filter,
        sort: sort,
        descending: descending,
        extensions: extensions,
        buckets: buckets,
        chatKinds: chatKinds,
        tags: tags,
        smartCats: smartCats,
        showSort: showSort,
        showDuplicateSwitch: showDuplicateSwitch,
        sortOptions: sortOptions,
      ),
    );

class _FilterSheet extends StatefulWidget {
  final FmFilter filter;
  final FmSort sort;
  final bool descending;
  final Map<String, int> extensions;
  final Map<MediaBucket, int> buckets;
  final Map<ChatMediaKind, int> chatKinds;
  final Map<String, int> tags;
  final Map<String, int> smartCats;
  final bool showSort;
  final bool showDuplicateSwitch;
  final List<FmSort> sortOptions;

  const _FilterSheet({
    required this.filter,
    required this.sort,
    required this.descending,
    required this.extensions,
    required this.buckets,
    required this.chatKinds,
    required this.tags,
    required this.smartCats,
    required this.showSort,
    required this.showDuplicateSwitch,
    required this.sortOptions,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FmFilter _filter = widget.filter;
  late FmSort _sort = widget.sort;
  late bool _desc = widget.descending;
  late bool _smartExpanded =
      widget.filter.smartCats.isNotEmpty || widget.smartCats.length <= 6;

  /// En çok dosyası olan 12 uzantı — 60 çipli bir liste seçilemez hâle gelir.
  List<MapEntry<String, int>> get _topExtensions {
    final list = widget.extensions.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    // Seçili olan bir uzantı ilk 12'ye girmese bile görünmeli, yoksa
    // kullanıcı kendi seçtiği süzgeci kaldıramaz.
    final top = list.take(12).toList();
    for (final ext in _filter.extensions) {
      if (top.any((e) => e.key == ext)) continue;
      top.add(MapEntry(ext, widget.extensions[ext] ?? 0));
    }
    return top;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _filter.customFromMs == null || _filter.customToMs == null
        ? null
        : DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(_filter.customFromMs!),
            end: DateTime.fromMillisecondsSinceEpoch(_filter.customToMs!),
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
      helpText: context.t('flt.pick_range'),
      saveText: context.t('common.ok'),
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = _filter.withDateRange(
          FmDateRange.custom,
          fromMs: picked.start.millisecondsSinceEpoch,
          toMs: picked.end.millisecondsSinceEpoch,
        ));
  }

  String get _customLabel {
    final from = _filter.customFromMs;
    final to = _filter.customToMs;
    if (from == null || to == null) {
      return context.t(FmDateRange.custom.labelKey);
    }
    String d(int ms) {
      final x = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${x.day}.${x.month}.${x.year}';
    }

    return '${d(from)} – ${d(to)}';
  }

  static IconData _sortIcon(FmSort s) => switch (s) {
        FmSort.name => AppIcons.sort,
        FmSort.date => AppIcons.calendarMonth,
        FmSort.size => AppIcons.storage,
        FmSort.type => AppIcons.tune,
      };

  static IconData _bucketIcon(MediaBucket b) => switch (b) {
        MediaBucket.camera => AppIcons.photoCamera,
        MediaBucket.screenshot => AppIcons.screenshot,
        MediaBucket.download => AppIcons.download,
        _ => AppIcons.folder,
      };

  static Color _bucketColor(MediaBucket b, ColorScheme scheme) => switch (b) {
        MediaBucket.whatsapp => AppHues.green,
        MediaBucket.telegram => AppHues.blue,
        MediaBucket.instagram => AppHues.tangerine,
        MediaBucket.download => AppHues.teal,
        MediaBucket.camera => AppHues.navy,
        _ => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pal = AppSkinData.of(context).palette;
    final activeCount = _filter.activeCount;
    final sections = <Widget>[];

    void addSection(Widget w) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: Gap.sm + 2));
      sections.add(w);
    }

    if (widget.showSort) {
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.sort,
          title: context.t('flt.sort'),
          badgeText: '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
          badgeActive: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (ctx, box) {
                final scale = MediaQuery.textScalerOf(ctx).scale(1);
                final effective =
                    scale > 1.0 ? box.maxWidth / scale : box.maxWidth;
                final cols = effective < 220 ? 1 : 2;
                final w = (box.maxWidth - Gap.sm * (cols - 1)) / cols;
                return Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final s in widget.sortOptions)
                      SizedBox(
                        width: w,
                        child: FmFilterOptionChip(
                          icon: _sortIcon(s),
                          label: context.t(s.labelKey),
                          selected: _sort == s,
                          filledSelected: true,
                          expand: true,
                          onTap: () => setState(() => _sort = s),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: Gap.sm + 2),
              FmSortDirectionToggle(
                descending: _desc,
                descLabel: context.t('flt.desc'),
                ascLabel: context.t('flt.asc'),
                onChanged: (v) => setState(() => _desc = v),
              ),
            ],
          ),
        ),
      );
    }

    addSection(
      FmFilterSectionCard(
        icon: AppIcons.calendarMonth,
        title: context.t('flt.date'),
        badgeText: _filter.dateRange == FmDateRange.any
            ? null
            : (_filter.dateRange == FmDateRange.custom
                ? _customLabel
                : context.t(_filter.dateRange.labelKey)),
        badgeActive: _filter.dateRange != FmDateRange.any,
        child: Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final r in FmDateRange.values)
              FmFilterOptionChip(
                icon: r == FmDateRange.custom ? AppIcons.calendarMonth : null,
                label: r == FmDateRange.custom
                    ? _customLabel
                    : context.t(r.labelKey),
                selected: _filter.dateRange == r,
                filledSelected: true,
                onTap: () {
                  if (r == FmDateRange.custom) {
                    _pickCustomRange();
                  } else {
                    setState(() => _filter = _filter.withDateRange(r));
                  }
                },
              ),
          ],
        ),
      ),
    );

    addSection(
      FmFilterSectionCard(
        icon: AppIcons.storage,
        title: context.t('flt.size'),
        badgeText: _filter.sizeRange == FmSizeRange.any
            ? null
            : context.t(_filter.sizeRange.labelKey),
        badgeActive: _filter.sizeRange != FmSizeRange.any,
        child: Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in FmSizeRange.values)
              FmFilterOptionChip(
                label: context.t(s.labelKey),
                selected: _filter.sizeRange == s,
                filledSelected: true,
                onTap: () =>
                    setState(() => _filter = _filter.withSizeRange(s)),
              ),
          ],
        ),
      ),
    );

    if (widget.smartCats.isNotEmpty || _filter.smartCats.isNotEmpty) {
      final cats = _sortedSmartCats;
      final selectedCount = _filter.smartCats.length;
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.ai,
          title: context.t('sm.filter_title'),
          badgeText: selectedCount > 0
              ? '$selectedCount / ${cats.length}'
              : '${cats.length}',
          badgeActive: selectedCount > 0,
          expanded: _smartExpanded,
          onToggle: () => setState(() => _smartExpanded = !_smartExpanded),
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              FmFilterOptionChip(
                label: context.t('flt.all'),
                selected: _filter.smartCats.isEmpty,
                filledSelected: true,
                onTap: () => setState(
                    () => _filter = _filter.withSmartCats(const {})),
              ),
              for (final e in cats)
                FmFilterOptionChip(
                  icon: SmartCatStyle.icon(e.key),
                  accentColor: SmartCatStyle.color(e.key),
                  label: SmartCatStyle.label(context, e.key),
                  count: e.value,
                  selected: _filter.smartCats.contains(e.key),
                  onTap: () async {
                    final adding = !_filter.smartCats.contains(e.key);
                    if (adding &&
                        SmartTaxonomy.sensitive.contains(e.key) &&
                        !await unlockSensitiveCats(context)) {
                      return;
                    }
                    if (!mounted) return;
                    setState(() => _filter = _filter.toggleSmartCat(e.key));
                  },
                ),
            ],
          ),
        ),
      );
    }

    if (widget.buckets.length > 1) {
      final buckets = _sortedBuckets;
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.folder,
          title: context.t('flt.source'),
          badgeText: _filter.buckets.isEmpty
              ? null
              : '${_filter.buckets.length}',
          badgeActive: _filter.buckets.isNotEmpty,
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              FmFilterOptionChip(
                label: context.t('flt.all'),
                selected: _filter.buckets.isEmpty,
                filledSelected: true,
                onTap: () =>
                    setState(() => _filter = _filter.withBuckets(const {})),
              ),
              for (final e in buckets)
                FmFilterOptionChip(
                  icon: _bucketIcon(e.key),
                  accentColor: _bucketColor(e.key, scheme),
                  label: context.t(e.key.labelKey),
                  count: e.value,
                  selected: _filter.buckets.contains(e.key),
                  onTap: () =>
                      setState(() => _filter = _filter.toggleBucket(e.key)),
                ),
            ],
          ),
        ),
      );
    }

    if (_showChatSection) {
      final chatActive = _filter.chatKinds.length +
          (_filter.direction != ChatDirection.any ? 1 : 0);
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.chat,
          title: context.t('flt.chat_kind'),
          badgeText: chatActive > 0 ? '$chatActive' : null,
          badgeActive: chatActive > 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  FmFilterOptionChip(
                    label: context.t('flt.all'),
                    selected: _filter.chatKinds.isEmpty,
                    filledSelected: true,
                    onTap: () => setState(
                        () => _filter = _filter.withChatKinds(const {})),
                  ),
                  for (final e in _sortedChatKinds)
                    FmFilterOptionChip(
                      label: context.t(e.key.labelKey),
                      count: e.value,
                      selected: _filter.chatKinds.contains(e.key),
                      onTap: () => setState(
                          () => _filter = _filter.toggleChatKind(e.key)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  context.t('flt.direction'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final d in ChatDirection.values)
                    FmFilterOptionChip(
                      label: context.t(d.labelKey),
                      selected: _filter.direction == d,
                      filledSelected: true,
                      onTap: () => setState(
                          () => _filter = _filter.withDirection(d)),
                    ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('flt.direction_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.tags.isNotEmpty) {
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.tag,
          title: context.t('flt.tag'),
          badgeText:
              _filter.tags.isEmpty ? null : '${_filter.tags.length}',
          badgeActive: _filter.tags.isNotEmpty,
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              FmFilterOptionChip(
                label: context.t('flt.all'),
                selected: _filter.tags.isEmpty,
                filledSelected: true,
                onTap: () =>
                    setState(() => _filter = _filter.withTags(const {})),
              ),
              for (final e in _sortedTags)
                () {
                  final tagColor = FmColorsStore.tagColor(e.key);
                  return FmFilterOptionChip(
                    dotColor: tagColor,
                    icon: tagColor == null ? AppIcons.tag : null,
                    accentColor: tagColor ?? scheme.primary,
                    label: e.key,
                    count: e.value,
                    selected: _filter.tags.contains(e.key),
                    onTap: () =>
                        setState(() => _filter = _filter.toggleTag(e.key)),
                  );
                }(),
            ],
          ),
        ),
      );
    }

    if (widget.extensions.isNotEmpty) {
      addSection(
        FmFilterSectionCard(
          icon: AppIcons.tune,
          title: context.t('flt.file_type'),
          badgeText: _filter.extensions.isEmpty
              ? null
              : '${_filter.extensions.length}',
          badgeActive: _filter.extensions.isNotEmpty,
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final e in _topExtensions)
                FmFilterOptionChip(
                  label: '.${e.key}',
                  count: e.value,
                  selected: _filter.extensions.contains(e.key),
                  onTap: () => setState(
                      () => _filter = _filter.toggleExtension(e.key)),
                ),
            ],
          ),
        ),
      );
    }

    if (widget.showDuplicateSwitch) {
      addSection(
        Material(
          color: pal.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card + 2),
            side: BorderSide(color: pal.rule),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card + 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            value: _filter.hideDuplicates,
            onChanged: (v) =>
                setState(() => _filter = _filter.withHideDuplicates(v)),
            title: Text(
              context.t('flt.hide_dupes'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(context.t('flt.hide_dupes_sub')),
          ),
        ),
      );
    }

    return FmFilterSheetScaffold(
      title: context.t('flt.title'),
      activeCount: activeCount,
      trailing: TextButton.icon(
        onPressed: activeCount == 0
            ? null
            : () => setState(() => _filter = FmFilter.none
                .withHideDuplicates(_filter.hideDuplicates)),
        icon: const Icon(AppIcons.clearAll, size: 18),
        label: Text(context.t('common.clear')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: sections,
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('common.cancel')),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(
                context,
                FmFilterResult(_filter, _sort, _desc),
              ),
              icon: const Icon(AppIcons.check, size: 20),
              label: Text(
                activeCount > 0
                    ? '${context.t('common.apply')} ($activeCount)'
                    : context.t('common.apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<MediaBucket, int>> get _sortedBuckets {
    final list = widget.buckets.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Mesajlaşma kırılımı yalnız listede gerçekten mesajlaşma dosyası varsa
  /// (ya da kullanıcı zaten böyle bir süzgeç seçtiyse) gösterilir.
  bool get _showChatSection {
    if (_filter.chatKinds.isNotEmpty ||
        _filter.direction != ChatDirection.any) {
      return true;
    }
    for (final source in const [
      MediaBucket.whatsapp,
      MediaBucket.telegram,
      MediaBucket.instagram,
    ]) {
      if ((widget.buckets[source] ?? 0) > 0) return true;
    }
    return false;
  }

  List<MapEntry<ChatMediaKind, int>> get _sortedChatKinds {
    final list = widget.chatKinds.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<MapEntry<String, int>> get _sortedTags {
    final list = widget.tags.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return list;
  }

  List<MapEntry<String, int>> get _sortedSmartCats {
    final map = <String, int>{...widget.smartCats};
    for (final c in _filter.smartCats) {
      map.putIfAbsent(c, () => 0);
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// Süzgeç düğmesi: etkin ölçüt sayısını rozetle gösterir — kullanıcı listenin
/// neden kısa olduğunu ekrana bakınca anlasın (görünmez süzgeç = "dosyam
/// kayboldu" hatası).
class FmFilterButton extends StatelessWidget {
  final FmFilter filter;
  final VoidCallback onPressed;
  const FmFilterButton({
    super.key,
    required this.filter,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final count = filter.activeCount;
    return IconButton(
      tooltip: count == 0
          ? context.t('flt.title')
          : context.t('flt.active_count', {'n': count}),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(AppIcons.tune),
      ),
    );
  }
}
