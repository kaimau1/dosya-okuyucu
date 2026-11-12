import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/app_icons.dart';
import '../../core/bidi.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/name_spoof.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_index.dart';
import 'fm_entry_icon.dart';
import 'fm_inline_play.dart';
import '../motion.dart';

/// Dosya/klasör satırı ve ızgara hücresi — gözatıcı, kategori ve arama
/// ekranlarının ORTAK öğeleri.
///
/// *Niye ortak:* aynı tile üç ekranda ayrı ayrı yazılmıştı; ikon boyu ya da
/// seçim rozeti biri değişince diğerleri geride kalıyordu (2026-07-24
/// tutarsızlık bulgusunun aynısı). Yerleşim ([FmLayout]) tek yerden okunur.

/// Liste satırı — **kendi `Row`umuz** (Faz 6 / U4, 2026-10-21).
///
/// KÖK NEDEN: `ListTile` `leading` yuvasını 56 dp ile
/// sınırlıyordu; 68 dp'lik önizleme (kullanıcı 2026-08-17: *"simgeleri
/// olabildiğince büyüt"*) bu tavana çarpıp sıkışıyor, alt satır da tek
/// aralıklı yazıyla "teknik" görünüyordu. Şimdi:
/// * önizleme boyu yerleşimden gelir ([FmLayout.iconSizeFor] × tema ölçeği),
///   satır boyu ondan türer — tavan yok;
/// * ad tek satır, alt satır **orantılı** yazıyla "boyut · tarih";
/// * sağda 48 dp dokunma alanlı ⋮ (erişilebilirlik);
/// * seçimde önizleme durur, üstüne onay rozeti biner ([FmSelectableIcon]).
class FmEntryRow extends StatelessWidget {
  final FsEntry entry;
  final bool selected;
  final bool selecting;
  final FmLayout layout;
  final String subtitle;
  final VoidCallback onTap;

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

  const FmEntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.subtitle,
    this.layout = FmLayout.list,
    this.onCheck,
    this.onMore,
    this.showChevron = false,
    this.badge,
    this.thumbnails = true,
    this.audioQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Tema ailesi simge ölçeğini de belirler (2026-08-25): "İş programı"nda
    // %22 küçük, "Modern"de %12 büyük — kullanıcı temayı seçerken boyutu da
    // seçmiş oluyor.
    final iconSize = layout.iconSizeFor(0) * context.fmIconScale;
    final vPad = layout == FmLayout.detail ? Gap.sm : 6.0;
    final more = _trailing(context, scheme);
    return Semantics(
      selected: selected,
      button: true,
      // TalkBack: "PDF, Kira sözleşmesi, 117 KB · dün" (Faz 16 / madde 4).
      // Ad ve alt satır metinleri aşağıda ayrıca okunmasın diye dışlanır.
      label: fmEntrySemanticsLabel(context, entry, subtitle),
      customSemanticsActions: fmSelectAction(context, selected, onCheck),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(Gap.md, vPad,
                  more == null && badge == null ? Gap.md : Gap.xs, vPad),
              child: Row(
                children: [
                  _withPlay(FmSelectableIcon(
                    entry: entry,
                    size: iconSize,
                    selecting: selecting,
                    selected: selected,
                    onCheck: onCheck,
                    thumbnails: thumbnails,
                  ), iconSize),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FmEntryName(
                            entry.name,
                            maxLines: 1,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: selected ? scheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // İkinci ad (AI, 2026-11-08) alt satırın başında;
                          // tek satır kalır → satır yüksekliği sabit (G14).
                          ValueListenableBuilder<int>(
                            valueListenable: AiIndex.revision,
                            builder: (context, _, _) {
                              final alias = AiIndex.aliasOf(entry.path);
                              return Text.rich(
                                TextSpan(children: [
                                  if (alias.isNotEmpty)
                                    TextSpan(
                                      text: '$alias · ',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  TextSpan(text: bidiParts(context, subtitle)),
                                ]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: Gap.sm),
                    badge!,
                  ],
                  ?more,
                ],
              ),
            ),
          ),
        ),
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
    return Stack(children: [
      icon,
      FmInlinePlay(path: entry.path, size: size, queue: audioQueue),
    ]);
  }

  Widget? _trailing(BuildContext context, ColorScheme scheme) {
    final more = onMore == null
        ? null
        : IconButton(
            icon: const Icon(AppIcons.more),
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

  /// Ad şeridinin yüksekliği (iki satır `bodySmall`).
  static const _labelHeight = 34.0;

  const FmEntryCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.selecting,
    required this.onTap,
    this.layout = FmLayout.grid3,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Basınca hafifçe çöker; seçim kipinde değil (sürükleyerek seçerken
    // hücreler "nefes almasın").
    return Semantics(
      selected: selected,
      button: true,
      label: fmEntrySemanticsLabel(context, entry, null),
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
                // "Modern" ailesinde ızgara satırı taşardı.
                final room = constraints.maxHeight - _labelHeight;
                final iconSize = (room * context.fmIconScale).clamp(
                  16.0,
                  constraints.maxWidth < room ? constraints.maxWidth : room,
                );
                return Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FmEntryIcon(
                          entry: entry,
                          size: iconSize,
                          // Hücre büyüdükçe köşe yarıçapı da büyür (küçük kutuda
                          // 12 dp yuvarlaklık, 140 dp'lik kutuda ezik duruyordu).
                          radius: (iconSize * 0.12).clamp(6.0, 20.0),
                        ),
                        SizedBox(
                          height: _labelHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FmEntryName(
                              entry.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ],
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

/// Dosya satırının TalkBack metni: tür, ad ve (varsa) alt satır.
/// Klasörde tür söylenmez — simge ve "›" zaten klasör olduğunu anlatıyor,
/// "Klasörler, Faturalar" kulağa yanlış geliyordu.
String fmEntrySemanticsLabel(
    BuildContext context, FsEntry entry, String? subtitle) {
  final type = FmType.of(entry);
  final alias = AiIndex.aliasOf(entry.path);
  final parts = [
    if (type != FmType.folder && type != FmType.other) context.t(type.labelKey),
    NameSpoof.visible(entry.name),
    if (NameSpoof.deceptiveExtension(entry.name) case final ext?)
      context.t('fm.name_spoof_warn', {'ext': ext}),
    if (alias.isNotEmpty) alias,
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
  const FmEntryName(this.name,
      {super.key, this.maxLines = 1, this.style, this.textAlign});

  final String name;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final ext = NameSpoof.deceptiveExtension(name);
    final shown = NameSpoof.visible(name);
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
