import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/chat_media.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import 'fm_more_sheet.dart';

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
class FmListControls {
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

  /// "Analiz ve diğer" levhasının bölümleri: Sırala · Süzgeç · Analiz ·
  /// Etiketler · ekrana özel [extras]. Ekran bunu HER çağrıda güncel
  /// alanlarla kurar (bkz. `FmMoreChip.sections`).
  List<FmMoreSection> sections(BuildContext context,
      {Map<String, int> tags = const {},
      List<FmMoreSection> extras = const []}) {
    final active = filter.activeCount;
    return [
      fmSortSection(context,
          sort: sort,
          descending: descending,
          onSort: onSort,
          options: sortOptions),
      FmMoreSection(context.t('more.filter'), [
        FmMoreTile(
          icon: AppIcons.filter,
          label: active > 0
              ? context.t('lc.filter_n', {'n': active})
              : context.t('lc.filter'),
          selected: active > 0,
          keepOpen: false,
          onTap: onOpenFilter,
        ),
        if (onTools != null)
          FmMoreTile(
            icon: AppIcons.insights,
            label: context.t('more.tools'),
            keepOpen: false,
            onTap: onTools!,
          ),
      ]),
      if (tags.isNotEmpty)
        fmTagsSection(context,
            counts: tags, filter: filter, onChanged: onFilterChanged),
      ...extras,
    ];
  }
}

/// Çip satırında GÖRÜNMEYEN etkin ölçütlerin kaldırılabilir küçük çipleri +
/// "Temizle" (bkz. [FmListControls.hiddenCriteria]). Ölçüt yokken çizilmez.
class FmActiveCriteria extends StatelessWidget {
  final FmFilter filter;
  final ValueChanged<FmFilter> onChanged;

  /// Yatay kenar payı (süzgeç satırının metin hizası).
  final EdgeInsetsGeometry padding;

  const FmActiveCriteria({
    super.key,
    required this.filter,
    required this.onChanged,
    this.padding = EdgeInsetsDirectional.zero,
  });

  @override
  Widget build(BuildContext context) {
    final hidden = FmListControls.hiddenCriteria(context, filter);
    if (hidden.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4).add(padding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, without) in hidden)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: InputChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(label),
                  onDeleted: () => onChanged(without),
                  deleteButtonTooltipMessage: context.t('common.clear'),
                ),
              ),
            TextButton(
              key: const ValueKey('lc-clear'),
              onPressed: () => onChanged(FmFilter.none),
              child: Text(context.t('lc.clear_all')),
            ),
          ],
        ),
      ),
    );
  }
}
