import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/bidi.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/name_spoof.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fm_colors_store.dart';
import '../../services/fm/smart_sort.dart';
import 'fm_entry_icon.dart';
import 'fm_inline_play.dart';
import '../motion.dart';

/// Dosya/klasör satırı ve ızgara hücresi — gözatıcı, kategori, arama ve
/// diğer dosya listesi ekranlarının ORTAK öğeleri.
///
/// *Niye ortak:* aynı tile üç ekranda ayrı ayrı yazılmıştı; ikon boyu ya da
/// seçim rozeti biri değişince diğerleri geride kalıyordu (2026-07-24
/// tutarsızlık bulgusunun aynısı). Yerleşim ([FmLayout]) tek yerden okunur.

/// [tag] varsa [child]'ı Hero'ya sarar (Ferrari H6.3). "Animasyonları
/// kaldır" açıkken uçuş yok — galeri düz açılır.
Widget fmHero(String? tag, Widget child) {
  if (tag == null) return child;
  return Builder(
    builder: (context) => HeroMode(
      enabled: !Motion.reduced(context),
      child: Hero(tag: tag, child: child),
    ),
  );
}

/// Dosya etiketlerini kompakt, renkli haplar olarak çizer.
///
/// [FmEntryRow] ve AI dosya listesi tarafından ortak kullanılır.
/// Renkli etiketlerde (`FmColorsStore.tagColor`) hafif tonlu zemin + renkli
/// nokta; renksiz etiketlerde sakin yüzey tonu + küçük etiket simgesi çizilir.
class FmTagPills extends StatelessWidget {
  final Iterable<String> tags;
  final int maxVisible;

  const FmTagPills({
    super.key,
    required this.tags,
    this.maxVisible = 4,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = tags.where((t) => t.trim().isNotEmpty).toList()..sort();
    if (sorted.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shown =
        sorted.length > maxVisible ? sorted.sublist(0, maxVisible) : sorted;
    final overflow = sorted.length - shown.length;
    final baseStyle = theme.textTheme.labelSmall?.copyWith(
      height: 1.15,
      fontWeight: FontWeight.w600,
    );

    Widget pill(String tag) {
      final accent = FmColorsStore.tagColor(tag);
      final bg = accent != null
          ? accent.withValues(alpha: isDark ? 0.22 : 0.12)
          : scheme.surfaceContainerHighest;
      final border = accent != null
          ? accent.withValues(alpha: isDark ? 0.45 : 0.30)
          : scheme.outlineVariant;
      final fg = accent != null
          ? (isDark
              ? Color.lerp(accent, AppColors.mixLight, 0.45)!
              : Color.lerp(accent, AppColors.mixDark, 0.28)!)
          : scheme.onSurfaceVariant;
      return Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 0.75),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accent != null)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(AppIcons.tag, size: 10.5, color: fg.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final tag in shown) pill(tag),
        if (overflow > 0)
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant, width: 0.75),
            ),
            child: Text(
              '+$overflow',
              maxLines: 1,
              style: baseStyle?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// Liste satırı — **üç katmanlı sade tasarım** (2026-11-23 yenilemesi,
/// 2026-11-25 sadeleştirmesi: kullanıcı "Belgeler/İndirilenler çok karışık"
/// dedi — ikinci ad + etiketler TEK satırda, kalın vurgu yalnız dosya adında,
/// İndirilenler'deki ayrı yaş sütunu tarih alanına taşındı).
///
/// KÖK NEDEN: eskiden ikinci ad (AI/Akıllı düzen), kaynak ("WhatsApp") ve
/// tarih tek bir `Text.rich` içinde birleştiriliyordu; ikinci ad uzayınca
/// tarih kesiliyor (`1...`, `18 K...` ya da tamamen kayıp), uzun dosya adları
/// tek satırda kırpılıyor ve kullanıcı etiketleri satırda hiç görünmüyordu.
///
/// Şimdi her bilgi kendi net katmanında durur:
/// 1. **Dosya adı** — 2 satıra kadar, satırdaki TEK kalın metin;
/// 2. **İkinci ad · #etiketler** (varsa) — tek satır, ikinci ad birincil
///    renkte, etiketler kendi renginde `#ad` (taşarsa "…");
/// 3. **Alt bilgi şeridi** — kaynak/konum solda esner, **tarih ve boyut**
///    sağda kesilmeden sabitlenir (büyük yazı ölçeğinde taşmadan alt satıra
///    iner).
class FmEntryRow extends StatelessWidget {
  final FsEntry entry;
  final bool selected;
  final bool selecting;
  final FmLayout layout;

  /// Alt bilgi şeridinin solundaki konum / kaynak / bağlam metni.
  final String subtitle;

  /// Alt bilgi şeridinde **kesinlikle kesilmeden** gösterilen tarih metni
  /// (ör. "20 Kas", "19 Kas 2025"). `null` = tarih ayrı geçilmedi.
  final String? dateText;

  /// Tarih metninin rengi (ör. İndirilenler'de yaşla koyulaşan "3 ay").
  /// `null` = alt bilgiyle aynı sakin ton.
  final Color? dateColor;

  /// Alt satırın SAĞINA hizalanan kısa bilgi (genelde boyut); null = yok.
  final String? subtitleEnd;
  final VoidCallback onTap;

  /// Uzun basış (yalnız [DragSelectArea] kullanmayan ekranlarda).
  final VoidCallback? onLongPress;

  /// Onay kutusuna dokunma (uzun basış [DragSelectArea]'da yakalanır).
  final VoidCallback? onCheck;
  final VoidCallback? onMore;

  /// Klasörlerde satır sonundaki "›" oku gösterilsin mi?
  final bool showChevron;

  /// ⋮'dan önce satır sonuna konan ekrana özel rozet (ör. indirilenlerde
  /// "3 ay" yaş etiketi).
  final Widget? badge;

  /// Küçük resim (bkz. [FmSelectableIcon.thumbnails]).
  final bool thumbnails;

  /// Ses dosyasında simge oynat/duraklat düğmesine döner ([FmInlinePlay]);
  /// dokunulunca bu liste çalınır. Null = satır içi oynatma yok.
  final List<String> Function()? audioQueue;

  /// Görsel satırında küçük resmin Hero etiketi (Ferrari H6.3): galeri
  /// satırdan büyüyerek açılır, kapanınca satıra küçülür. Seçim kipinde yok
  /// (simgenin yerinde onay kutusu var).
  final String? heroTag;

  /// Üst listeden hazır geçirilen AI/elle ikinci ad, etiketler, küçük resim
  /// ayarı ve DPR.
  final String? alias;
  final Iterable<String>? tags;

  /// Etiket hapları gösterilsin mi? Sanal arşiv girdilerinde `false`.
  final bool showTags;

  /// Satır altında metin hizasından başlayan ince ayırıcı çizgi çizilsin mi?
  final bool showDivider;
  final bool? thumbsOn;
  final double? dpr;

  const FmEntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.onLongPress,
    required this.subtitle,
    this.dateText,
    this.dateColor,
    this.subtitleEnd,
    this.layout = FmLayout.list,
    this.onCheck,
    this.onMore,
    this.showChevron = false,
    this.badge,
    this.thumbnails = true,
    this.audioQueue,
    this.heroTag,
    this.alias,
    this.tags,
    this.showTags = true,
    this.showDivider = false,
    this.thumbsOn,
    this.dpr,
  });

  static final Listenable _metaListenable = Listenable.merge([
    AiIndex.revision,
    SmartSort.revision,
    FileTags.changes,
    FmColorsStore.revision,
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconSize = layout.iconSizeFor(0) * context.fmIconScale;
    final vPad = layout == FmLayout.detail ? 12.0 : 10.0;
    final minRow = MediaQuery.sizeOf(context).width >= 840 ? 72.0 : 64.0;
    final more = _trailing(context, scheme);
    final visibleName = NameSpoof.visible(entry.name);
    final deceptiveExt = NameSpoof.deceptiveExtension(entry.name);
    final preAlias = alias;
    final preTags = showTags ? tags : const <String>[];
    final needsListen = preAlias == null || (showTags && preTags == null);

    Widget buildMetaBar() {
      final left = subtitle.trim();
      final date = (dateText ?? '').trim();
      final size = (subtitleEnd ?? '').trim();
      if (left.isEmpty && date.isEmpty && size.isEmpty) {
        return const SizedBox.shrink();
      }
      final baseStyle = theme.textTheme.bodySmall?.copyWith(
        height: 1.25,
        color: scheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      // Tarih artık kalın değil (sadeleştirme): satırda tek kalın metin ad.
      final dateStyle = dateColor == null
          ? baseStyle
          : baseStyle?.copyWith(
              color: dateColor, fontWeight: FontWeight.w600);
      final largeText = MediaQuery.textScalerOf(context).scale(12) > 17.5;

      Widget leftText() => Text(
            bidiParts(context, left),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
          );

      /// Tarih · boyut tek `Text.rich` içinde; [lead] (ör. " · ") başa
      /// eklenir. Satıra sığmazsa ancak o zaman "…" ile kısalır (taşma YOK).
      Widget trailingDateAndSize({String lead = ''}) => Text.rich(
            TextSpan(children: [
              if (lead.isNotEmpty) TextSpan(text: lead),
              if (date.isNotEmpty)
                TextSpan(text: bidiParts(context, date), style: dateStyle),
              if (date.isNotEmpty && size.isNotEmpty) const TextSpan(text: ' · '),
              if (size.isNotEmpty) TextSpan(text: bidiParts(context, size)),
            ]),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
          );

      // Çok büyük erişilebilirlik yazı ölçeğinde (≥ 1,5×) tarih ve boyut
      // taşmasın/kesilmesin diye konumun altına sarılır.
      if (largeText) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (left.isNotEmpty) leftText(),
            if (date.isNotEmpty || size.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: left.isNotEmpty ? 2 : 0),
                child: Wrap(
                  spacing: Gap.xs,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (date.isNotEmpty)
                      Text(bidiParts(context, date), style: dateStyle),
                    if (date.isNotEmpty && size.isNotEmpty)
                      Text('·', style: baseStyle),
                    if (size.isNotEmpty)
                      Text(bidiParts(context, size), style: baseStyle),
                  ],
                ),
              ),
          ],
        );
      }

      // Tek, sola hizalı akış (2026-11-25, kullanıcı: "boyut, tarih çok
      // dağınık"): "Belgeler · 18 Kas · 136 KB". Kaynak yalnız gerektiği
      // kadar yer alır (gevşek esneme) ve sığmazsa "…" ile kısalır; tarih ve
      // boyut hemen ardından gelir, KESİLMEZ. Eskiden tarih/boyut satırın en
      // sağına yaslanıyor, ortada büyük boşluk kalıyordu.
      if (left.isEmpty) return trailingDateAndSize();
      if (date.isEmpty && size.isEmpty) return leftText();
      // Tarih/boyut bloğu satır genişliğiyle SINIRLI (dar ekranda 5 px
      // taşma a11y testinde yakalandı); kaynak kalan yeri alır.
      return LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Flexible(child: leftText()),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth),
              child: trailingDateAndSize(lead: ' · '),
            ),
          ],
        ),
      );
    }

    Widget buildDetails(String currentAlias, Iterable<String> currentTags) {
      final hasAlias = currentAlias.isNotEmpty;
      final tagList = showTags
          ? (currentTags.where((t) => t.trim().isNotEmpty).toList()..sort())
          : const <String>[];
      final hasTags = tagList.isNotEmpty;
      final hasMeta = subtitle.trim().isNotEmpty ||
          (dateText ?? '').trim().isNotEmpty ||
          (subtitleEnd ?? '').trim().isNotEmpty;
      final detailStyle = theme.textTheme.bodySmall?.copyWith(
        height: 1.25,
        fontWeight: FontWeight.w500,
      );
      final isDark = theme.brightness == Brightness.dark;
      Color tagColor(String tag) {
        final accent = FmColorsStore.tagColor(tag);
        if (accent == null) return scheme.onSurfaceVariant;
        return isDark
            ? Color.lerp(accent, AppColors.mixLight, 0.45)!
            : Color.lerp(accent, AppColors.mixDark, 0.28)!;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // İkinci ad + etiketler TEK satırda (eskiden çizgili ad satırı +
          // ayrı hap satırı = satır başına 4 katman, "çok karışık").
          if (hasAlias || hasTags)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(children: [
                  if (hasAlias)
                    TextSpan(
                      text: bidiParts(context, currentAlias),
                      style: TextStyle(color: scheme.primary),
                    ),
                  for (var i = 0; i < tagList.length; i++) ...[
                    if (hasAlias || i > 0) const TextSpan(text: '  '),
                    TextSpan(
                      text: '#${tagList[i]}',
                      style: TextStyle(color: tagColor(tagList[i])),
                    ),
                  ],
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: detailStyle,
              ),
            ),
          if (hasMeta)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: buildMetaBar(),
            ),
        ],
      );
    }

    final semParts = [
      if (subtitle.trim().isNotEmpty) subtitle.trim(),
      if ((dateText ?? '').trim().isNotEmpty) dateText!.trim(),
      if ((subtitleEnd ?? '').trim().isNotEmpty) subtitleEnd!.trim(),
    ].join(' · ');

    return Semantics(
      selected: selected,
      button: true,
      // TalkBack: "PDF, Kira sözleşmesi, fatura, WhatsApp · 20 Kas · 117 KB".
      label: fmEntrySemanticsLabel(
        context,
        entry,
        semParts,
        alias: preAlias,
        tags: preTags,
        visibleName: visibleName,
        deceptiveExt: deceptiveExt,
        deceptiveChecked: true,
      ),
      customSemanticsActions: fmSelectAction(context, selected, onCheck),
      // Basılınca satır hafifçe içe çöker (H4.8) — uzun basışın seçim
      // başlatacağını parmak altında hissettirir; titreşim [DragSelectArea]'da.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressScale(
            scale: 0.985,
            child: Material(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
                side: selected
                    ? BorderSide(
                        color: scheme.primary.withValues(alpha: 0.32),
                        width: 1,
                      )
                    : BorderSide.none,
              ),
              clipBehavior: Clip.none,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(Radii.card),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minRow),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      Gap.md,
                      vPad,
                      more == null && badge == null ? Gap.md : Gap.xs,
                      vPad,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: _withPlay(
                            fmHero(
                              selecting ? null : heroTag,
                              FmSelectableIcon(
                                entry: entry,
                                size: iconSize,
                                selecting: selecting,
                                selected: selected,
                                onCheck: onCheck,
                                thumbnails: thumbnails,
                                thumbsOn: thumbsOn,
                                dpr: dpr,
                              ),
                            ),
                            iconSize,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ExcludeSemantics(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: iconSize),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FmEntryName(
                                    entry.name,
                                    visibleName: visibleName,
                                    deceptiveExt: deceptiveExt,
                                    deceptiveChecked: true,
                                    maxLines: 2,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      height: 1.24,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.15,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurface,
                                    ),
                                  ),
                                  if (!needsListen)
                                    buildDetails(preAlias, preTags ?? const [])
                                  else
                                    ListenableBuilder(
                                      listenable: _metaListenable,
                                      builder: (context, _) => buildDetails(
                                        preAlias ?? AiIndex.aliasOf(entry.path),
                                        showTags
                                            ? (preTags ??
                                                FileTags.forPath(entry.path))
                                            : const [],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: Gap.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: badge!,
                          ),
                        ],
                        ?more,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showDivider && !selected)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: Gap.md + iconSize + 14,
                end: Gap.md,
              ),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _withPlay(Widget icon, double size) {
    if (audioQueue == null ||
        selecting ||
        entry.isDir ||
        FmType.of(entry) != FmType.audio) {
      return icon;
    }
    // Ses satırlarında dosya uzantısı metninin üstüne binmek yerine sakin
    // tonlu yuvarlatılmış bir oynatma yuvası çiz.
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: SizedBox.square(
          dimension: size,
          child: FmInlinePlay(
            path: entry.path,
            size: size,
            queue: audioQueue,
          ),
        ),
      );
    });
  }

  Widget? _trailing(BuildContext context, ColorScheme scheme) {
    final more = onMore == null
        ? null
        : IconButton(
            // Soluk (H4.9): asıl yol uzun basış + seçim çubuğu; ⋮ yalnız kısayol.
            icon: Icon(AppIcons.more,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            // 48 dp dokunma alanı (erişilebilirlik, Faz 6 / 7. madde).
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onMore,
          );
    if (showChevron && entry.isDir && !selecting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?more,
          Icon(AppIcons.chevron,
              size: AppIcons.small, color: scheme.onSurfaceVariant),
        ],
      );
    }
    return more;
  }
}

/// Izgara hücresi: büyük çerçevesiz ikon/önizleme + iki satır ad.
///
/// İkon boyu **gerçek kısıtlardan** ölçülür (hücre yüksekliği eksi ad şeridi),
/// hesaplanmış bir en-boy oranından değil: yazı tipi ölçeği büyütülmüş bir
/// telefonda ad iki satıra çıkınca sabit oran `RenderFlex overflowed` verirdi
/// (Excel bölme sınırında yaşanan taşmanın aynısı — bkz. HAFIZA).
class FmEntryCard extends StatelessWidget {
  final FsEntry entry;
  final bool selected;
  final bool selecting;
  final FmLayout layout;
  final VoidCallback onTap;

  /// Bkz. [FmEntryRow.heroTag].
  final String? heroTag;
  final String? alias;
  final Iterable<String>? tags;
  final bool? thumbsOn;
  final double? dpr;

  /// Ad şeridinin yüksekliği (iki satır `bodySmall`).
  static const _labelHeight = 34.0;

  const FmEntryCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.layout = FmLayout.grid3,
    this.heroTag,
    this.alias,
    this.tags,
    this.thumbsOn,
    this.dpr,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleName = NameSpoof.visible(entry.name);
    final deceptiveExt = NameSpoof.deceptiveExtension(entry.name);
    final resolvedTags = tags ?? FileTags.forPath(entry.path);
    final firstTag = resolvedTags.isEmpty ? null : resolvedTags.first;
    final tagAccent =
        firstTag == null ? null : FmColorsStore.tagColor(firstTag);
    // Basınca hafifçe çöker; seçim kipinde değil (sürükleyerek seçerken
    // hücreler "nefes almasın").
    return Semantics(
      selected: selected,
      button: true,
      label: fmEntrySemanticsLabel(
        context,
        entry,
        null,
        alias: alias,
        tags: resolvedTags,
        visibleName: visibleName,
        deceptiveExt: deceptiveExt,
        deceptiveChecked: true,
      ),
      // Ad şeridi bir kez okunsun; dokunma eylemi burada yeniden verilir
      // (dışlanan InkWell'in eylemi düğümden düşer).
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        enabled: !selecting,
        scale: 0.96,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Hücrenin boyu ikon + ad şeridi kadar; tema ölçeği ikonu
                // BÜYÜTÜRSE üst sınır yine hücrenin kendisi olmalı, yoksa
                // "Modern" ailesinde ızgara satırı taşardı. Büyük yazı
                // ölçeğinde iki satırlık dosya adı 34 dp'ye sığmadığından
                // etiket kuşağı hücrenin %46'sına kadar esner.
                final labelH = MediaQuery.textScalerOf(context)
                    .scale(_labelHeight)
                    .clamp(_labelHeight, constraints.maxHeight * 0.46);
                final room = constraints.maxHeight - labelH;
                final iconSize = (room * context.fmIconScale).clamp(
                  16.0,
                  constraints.maxWidth < room ? constraints.maxWidth : room,
                );
                return Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        fmHero(
                            selecting ? null : heroTag,
                            FmEntryIcon(
                              entry: entry,
                              size: iconSize,
                              // Hücre büyüdükçe köşe yarıçapı da büyür (küçük
                              // kutuda 12 dp yuvarlaklık, 140 dp'lik kutuda
                              // ezik duruyordu).
                              radius: (iconSize * 0.12).clamp(6.0, 20.0),
                              thumbsOn: thumbsOn,
                              dpr: dpr,
                            )),
                        SizedBox(
                          height: labelH,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FmEntryName(
                              entry.name,
                              visibleName: visibleName,
                              deceptiveExt: deceptiveExt,
                              deceptiveChecked: true,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!selecting && firstTag != null)
                      PositionedDirectional(
                        top: 4,
                        start: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tagAccent ?? scheme.primary,
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            AppIcons.tag,
                            size: 10,
                            color: tagAccent ?? scheme.primary,
                          ),
                        ),
                      ),
                    if (selecting)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: Icon(
                          selected ? AppIcons.checkCircle : AppIcons.circle,
                          size: 20,
                          color: selected ? scheme.primary : scheme.outline,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Dosya satırının TalkBack metni: tür, ad, ikinci ad, etiketler ve alt satır.
/// Klasörde tür söylenmez — simge ve "›" zaten klasör olduğunu anlatıyor,
/// "Klasörler, Faturalar" kulağa yanlış geliyordu.
String fmEntrySemanticsLabel(
  BuildContext context,
  FsEntry entry,
  String? subtitle, {
  String? alias,
  Iterable<String>? tags,
  String? visibleName,
  String? deceptiveExt,
  bool deceptiveChecked = false,
}) {
  final type = FmType.of(entry);
  final resolvedAlias = alias ?? AiIndex.aliasOf(entry.path);
  final resolvedTags = tags ?? FileTags.forPath(entry.path);
  final shown = visibleName ?? NameSpoof.visible(entry.name);
  final ext = deceptiveChecked
      ? deceptiveExt
      : NameSpoof.deceptiveExtension(entry.name);
  final parts = [
    if (type != FmType.folder && type != FmType.other) context.t(type.labelKey),
    shown,
    if (ext != null) context.t('fm.name_spoof_warn', {'ext': ext}),
    if (resolvedAlias.isNotEmpty) resolvedAlias,
    for (final tag in resolvedTags) '#$tag',
    if (subtitle != null && subtitle.isNotEmpty) subtitle,
  ];
  return parts.join(', ');
}

/// Sürükleyerek/uzun basarak seçmenin erişilebilir karşılığı: TalkBack
/// menüsünde "Seç" / "Seçimden çıkar" eylemi.
Map<CustomSemanticsAction, VoidCallback>? fmSelectAction(
    BuildContext context, bool selected, VoidCallback? onCheck) {
  if (onCheck == null) return null;
  return {
    CustomSemanticsAction(
        label: context.t(selected ? 'a11y.deselect' : 'a11y.select')): onCheck,
  };
}

/// Dosya adı yazısı — uzantı aldatmasına karşı (G7.10).
///
/// Normal adda düz `Text` ile birebir aynıdır. Yön denetimi karakteri görünür
/// işarete çevrilir; `rapor.pdf.apk` gibi adda gerçek (tehlikeli) uzantı
/// kalın + hata rengiyle gösterilir; tek satırda ad kısalır, son uzantı her
/// zaman görünür.
class FmEntryName extends StatelessWidget {
  const FmEntryName(
    this.name, {
    super.key,
    this.maxLines = 1,
    this.style,
    this.textAlign,
    this.visibleName,
    this.deceptiveExt,
    this.deceptiveChecked = false,
  });

  final String name;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? visibleName;
  final String? deceptiveExt;
  final bool deceptiveChecked;

  @override
  Widget build(BuildContext context) {
    final ext =
        deceptiveChecked ? deceptiveExt : NameSpoof.deceptiveExtension(name);
    final shown = visibleName ?? NameSpoof.visible(name);
    if (ext == null) {
      return Text(shown,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style);
    }
    final cut = shown.toLowerCase().lastIndexOf('.$ext');
    final head = cut > 0 ? shown.substring(0, cut) : shown;
    final tail = cut > 0 ? shown.substring(cut) : '';
    final warn = Theme.of(context).colorScheme.error;
    final tailStyle = (style ?? const TextStyle())
        .copyWith(color: warn, fontWeight: FontWeight.w700);
    if (maxLines == 1) {
      // Tek satır: ad kısalır (…), gerçek uzantı hep görünür.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(head,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
          Text(tail, maxLines: 1, style: tailStyle),
        ],
      );
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: head),
        TextSpan(text: tail, style: tailStyle),
      ]),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}
