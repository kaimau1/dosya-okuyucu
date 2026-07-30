import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';

/// Süzgeç sayfasının sonucu: süzgeç + sıralama birlikte döner.
class FmFilterResult {
  final FmFilter filter;
  final FmSort sort;
  final bool descending;
  const FmFilterResult(this.filter, this.sort, this.descending);
}

/// **Süzgeç ve sıralama** sayfası — Fotoğraflar, kategori listeleri, arama ve
/// bellek analizinde AYNI sayfa kullanılır.
///
/// Kullanıcı isteği (2026-07-29): "daha çok filtreleme seçeneği lazım video
/// foto için · aramada sıralama seçenekleri lazım · arama her yerde olmalı ve
/// filtrelenebilmeli".
///
/// Tasarım kararları:
/// - Sayfa **yerel kopya** üzerinde çalışır, "Uygula"ya basılınca döner:
///   her çip dokunuşunda 20 bin dosyayı yeniden süzmek listeyi kilitlerdi.
/// - Tür (uzantı) çipleri **listede gerçekten bulunan** uzantılardan üretilir;
///   boş bir "mkv" çipi göstermek kullanıcıyı yanıltırdı.
/// - Sayılar çiplerin üstünde: kaç dosyayı süzdüğü seçmeden önce görülür.
Future<FmFilterResult?> showFmFilterSheet(
  BuildContext context, {
  required FmFilter filter,
  required FmSort sort,
  required bool descending,
  Map<String, int> extensions = const {},
  Map<MediaBucket, int> buckets = const {},
  Map<ChatMediaKind, int> chatKinds = const {},
  Map<String, int> tags = const {},
  bool showSort = true,
  bool showDuplicateSwitch = false,
  List<FmSort> sortOptions = FmSort.values,
}) =>
    showModalBottomSheet<FmFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        filter: filter,
        sort: sort,
        descending: descending,
        extensions: extensions,
        buckets: buckets,
        chatKinds: chatKinds,
        tags: tags,
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
      // 1980: dosya sistemlerinde görülen en eski makul tarih; ileri sınır
      // bugün + 1 gün, saat farkı yüzünden "bugün" seçilemez olmasın.
      firstDate: DateTime(1980),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
      helpText: context.t('flt.pick_range'),
      saveText: 'Tamam',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.sm, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.t('flt.title'),
                        style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _filter = FmFilter.none
                        .withHideDuplicates(_filter.hideDuplicates)),
                    child: const Text('Temizle'),
                  ),
                ],
              ),
            ),
            const Divider(height: Gap.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  if (widget.showSort) ...[
                    _label(context.t('flt.sort')),
                    Wrap(
                      spacing: Gap.sm,
                      children: [
                        for (final s in widget.sortOptions)
                          ChoiceChip(
                            label: Text(context.t(s.labelKey)),
                            selected: _sort == s,
                            onSelected: (_) => setState(() => _sort = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.arrow_downward),
                          label: Text(context.t('flt.desc')),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.arrow_upward),
                          label: Text(context.t('flt.asc')),
                        ),
                      ],
                      selected: {_desc},
                      onSelectionChanged: (v) =>
                          setState(() => _desc = v.first),
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                  _label(context.t('flt.date')),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    children: [
                      for (final r in FmDateRange.values)
                        ChoiceChip(
                          label: Text(r == FmDateRange.custom
                              ? _customLabel
                              : context.t(r.labelKey)),
                          selected: _filter.dateRange == r,
                          onSelected: (_) {
                            if (r == FmDateRange.custom) {
                              _pickCustomRange();
                            } else {
                              setState(
                                  () => _filter = _filter.withDateRange(r));
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  _label(context.t('flt.size')),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    children: [
                      for (final s in FmSizeRange.values)
                        ChoiceChip(
                          label: Text(context.t(s.labelKey)),
                          selected: _filter.sizeRange == s,
                          onSelected: (_) =>
                              setState(() => _filter = _filter.withSizeRange(s)),
                        ),
                    ],
                  ),
                  if (widget.buckets.length > 1) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('flt.source')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        // Boş küme = tümü; "Tümü" çipi seçimi temizler.
                        ChoiceChip(
                          label: Text(context.t('flt.all')),
                          selected: _filter.buckets.isEmpty,
                          onSelected: (_) => setState(
                              () => _filter = _filter.withBuckets(const {})),
                        ),
                        for (final e in _sortedBuckets)
                          FilterChip(
                            label: Text(context.t('ph.chip_count', {
                              'label': context.t(e.key.labelKey),
                              'n': e.value,
                            })),
                            selected: _filter.buckets.contains(e.key),
                            onSelected: (_) => setState(
                                () => _filter = _filter.toggleBucket(e.key)),
                          ),
                      ],
                    ),
                  ],
                  // ── Mesajlaşma kırılımı ────────────────────────────────
                  // Yalnız listede WhatsApp/Telegram gibi bir kaynak varsa
                  // gösterilir: kamera fotoğraflarında "Sesli not" çipi
                  // anlamsız gürültü olurdu.
                  if (_showChatSection) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('flt.chat_kind')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        ChoiceChip(
                          label: Text(context.t('flt.all')),
                          selected: _filter.chatKinds.isEmpty,
                          onSelected: (_) => setState(() =>
                              _filter = _filter.withChatKinds(const {})),
                        ),
                        for (final e in _sortedChatKinds)
                          FilterChip(
                            label: Text(context.t('ph.chip_count', {
                              'label': context.t(e.key.labelKey),
                              'n': e.value,
                            })),
                            selected: _filter.chatKinds.contains(e.key),
                            onSelected: (_) => setState(() =>
                                _filter = _filter.toggleChatKind(e.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    _label(context.t('flt.direction')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final d in ChatDirection.values)
                          ChoiceChip(
                            label: Text(context.t(d.labelKey)),
                            selected: _filter.direction == d,
                            onSelected: (_) => setState(
                                () => _filter = _filter.withDirection(d)),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      context.t('flt.direction_note'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  // ── Etiketler (kişi/grup) ──────────────────────────────
                  if (widget.tags.isNotEmpty) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('flt.tag')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        ChoiceChip(
                          label: Text(context.t('flt.all')),
                          selected: _filter.tags.isEmpty,
                          onSelected: (_) => setState(
                              () => _filter = _filter.withTags(const {})),
                        ),
                        for (final e in _sortedTags)
                          FilterChip(
                            label: Text('${e.key} (${e.value})'),
                            selected: _filter.tags.contains(e.key),
                            onSelected: (_) => setState(
                                () => _filter = _filter.toggleTag(e.key)),
                          ),
                      ],
                    ),
                  ],
                  if (widget.extensions.isNotEmpty) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('flt.file_type')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final e in _topExtensions)
                          FilterChip(
                            label: Text('.${e.key} (${e.value})'),
                            selected: _filter.extensions.contains(e.key),
                            onSelected: (_) => setState(() =>
                                _filter = _filter.toggleExtension(e.key)),
                          ),
                      ],
                    ),
                  ],
                  if (widget.showDuplicateSwitch) ...[
                    const SizedBox(height: Gap.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _filter.hideDuplicates,
                      onChanged: (v) => setState(
                          () => _filter = _filter.withHideDuplicates(v)),
                      title: Text(context.t('flt.hide_dupes')),
                      subtitle: Text(context.t('flt.hide_dupes_sub')),
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                          context, FmFilterResult(_filter, _sort, _desc)),
                      child: Text(context.t('common.apply')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
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
        child: const Icon(Icons.tune),
      ),
    );
  }
}
