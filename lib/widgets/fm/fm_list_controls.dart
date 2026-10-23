import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import 'fm_quick_filters.dart';

/// **Liste denetim şeridi** — kategori / hızlı klasör ekranlarının yeni üst
/// alanı (2026-10-23, kullanıcı ekran görüntüsüyle: *"işaretli üst alanlar UI
/// olarak tamamen yenilenmeli; filtreleme daha kolay, göze hoş, anlaşılır
/// olmalı"*).
///
/// Eski araç şeridi solda soluk "161 öğe", ortada mavi bir metin düğmesi
/// ("Tarihe göre ↓") ve sağda çıplak bir süzgeç simgesinden oluşuyordu: üçü
/// üç ayrı görsel dil konuşuyor, süzgecin ne yaptığı ve açık olup olmadığı
/// anlaşılmıyordu. Şimdi:
/// - sayı başlığın altına çıktı (bkz. `CategoryScreen` üst çubuğu);
/// - **üç aynı biçimli hap**: Sırala · Süzgeç · Analiz — tür çipleriyle aynı
///   tonlu dil; süzgeç açıksa hap dolu renkte ve ölçüt sayısını yazar;
/// - çip satırında GÖRÜNMEYEN etkin ölçütler (tarih, boyut, uzantı, etiket,
///   sohbet türü) hapların altında **kaldırılabilir** küçük çipler olarak
///   yazar; "Temizle" hepsini kaldırır. Böylece "neden yalnız 12 dosya?"
///   sorusunun cevabı ekranda.
class FmListControls extends StatelessWidget {
  final FmSort sort;
  final bool descending;
  final void Function(FmSort sort, bool descending) onSort;
  final List<FmSort> sortOptions;

  final FmFilter filter;
  final ValueChanged<FmFilter> onFilterChanged;
  final VoidCallback onOpenFilter;

  /// "Analiz ve düzenle" levhası; null ise hap çizilmez.
  final VoidCallback? onTools;

  const FmListControls({
    super.key,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilter,
    this.onTools,
    this.sortOptions = FmSort.values,
  });

  /// Çip satırında görünmeyen etkin ölçütler → (etiket, kaldıran süzgeç).
  static List<(String, FmFilter)> hiddenCriteria(
      BuildContext context, FmFilter f) {
    final out = <(String, FmFilter)>[];
    if (f.dateRange != FmDateRange.any) {
      out.add((context.t(f.dateRange.labelKey),
          f.withDateRange(FmDateRange.any)));
    }
    if (f.sizeRange != FmSizeRange.any) {
      out.add((context.t(f.sizeRange.labelKey),
          f.withSizeRange(FmSizeRange.any)));
    }
    for (final ext in f.extensions) {
      out.add(('.$ext', f.toggleExtension(ext)));
    }
    for (final tag in f.tags) {
      out.add(('#$tag', f.toggleTag(tag)));
    }
    for (final kind in f.chatKinds) {
      out.add((context.t(kind.labelKey), f.toggleChatKind(kind)));
    }
    if (f.direction != ChatDirection.any) {
      out.add((context.t(f.direction.labelKey),
          f.withDirection(ChatDirection.any)));
    }
    if (f.hideDuplicates) {
      out.add((context.t('lc.no_dupes'), f.withHideDuplicates(false)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = filter.activeCount;
    final hidden = hiddenCriteria(context, filter);
    final sortName = context.t(sort.labelKey);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 2, Gap.sm, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  PopupMenuButton<(FmSort, bool)>(
                    key: const ValueKey('lc-sort'),
                    tooltip: context.t('list.sort_by', {'name': sortName}),
                    onSelected: (v) => onSort(v.$1, v.$2),
                    itemBuilder: (_) => [
                      for (final s in sortOptions)
                        CheckedPopupMenuItem(
                          checked: s == sort,
                          // Aynı ölçüte yeniden dokunmak yönü çevirir; yeni
                          // ölçüt kendi doğal yönüyle başlar.
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
                    child: FmPill(
                      icon: descending ? AppIcons.arrowDown : AppIcons.arrowUp,
                      label: sortName,
                      dropdown: true,
                    ),
                  ),
                  _Tap(
                    key: const ValueKey('lc-filter'),
                    onTap: onOpenFilter,
                    tooltip: active > 0
                        ? context.t('list.filter_n', {'n': active})
                        : context.t('list.filter'),
                    child: FmPill(
                      icon: AppIcons.filter,
                      label: active > 0
                          ? context.t('lc.filter_n', {'n': active})
                          : context.t('lc.filter'),
                      highlighted: active > 0,
                    ),
                  ),
                  if (onTools != null)
                    _Tap(
                      key: const ValueKey('lc-tools'),
                      onTap: onTools!,
                      tooltip: context.t('ct.title'),
                      child: FmPill(
                        icon: AppIcons.insights,
                        label: context.t('lc.tools'),
                      ),
                    ),
                ],
              ),
            ),
            if (hidden.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, without) in hidden)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: InputChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: Text(label),
                            onDeleted: () => onFilterChanged(without),
                            deleteButtonTooltipMessage:
                                context.t('common.clear'),
                          ),
                        ),
                      TextButton(
                        key: const ValueKey('lc-clear'),
                        onPressed: () => onFilterChanged(FmFilter.none),
                        child: Text(context.t('lc.clear_all')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final Widget child;
  const _Tap(
      {super.key,
      required this.onTap,
      required this.tooltip,
      required this.child});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: child,
          ),
        ),
      );
}
