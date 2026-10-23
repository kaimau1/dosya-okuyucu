/// **PDF sayfasının üstünde yüzen araç çubuğu:** metin seçilince çıkan
/// [PdfSelectionBar]. (Yerinde düzenleme çubuğu `PdfEditBar` Faz 8'de eski
/// kelime-bazlı düzenleme yoluyla birlikte kalktı — düzenleme artık
/// `PdfEditorScreen`de.)
///
/// ## Niye yeniden yazıldı (2026-08-29)
/// Kullanıcı: *"düzenlerken vs açılan araç menüleri çok zarif yetersiz ve kötü
/// görünüyor, üzerlerine çalış."* Eski hâl:
/// - zemin `AppColors.shade.withValues(alpha: 0.78)` — her temada aynı, kağıt
///   temanın üstünde yabancı duran bir blok;
/// - dört `TextButton.icon` tek bir `Wrap` içinde: dar ekranda alt satıra
///   taşıyor, renk noktaları düğmelerin arasında kayboluyordu;
/// - "Vazgeç / AI / Uygula" üçü de aynı ağırlıkta düz metin düğmesiydi,
///   hangisinin asıl eylem olduğu belli değildi.
///
/// Yenisi tema yüzeyini kullanıyor (kağıtta açık, gecede koyu), eylemleri
/// **eşit paylı** yerleştiriyor (taşma matematiksel olarak imkânsız) ve asıl
/// eylemi dolu düğmeyle ayırıyor.
///
/// ## İkinci tur (2026-09-24)
/// Kullanıcı: *"işaretli alan güzel görünmüyor, basit bir uygulama gibi
/// görülüyor."* Düz gri kart, çıplak simge+yazı eylemler ve kalem simgesinin
/// yanında sıralanmış noktalar "taslak" gibi duruyordu. Şimdi:
/// - kart temanın en açık yüzeyi + katmanlı yumuşak gölge, 24 dp köşe;
/// - başlık satırı: tırnak rozeti + seçilen metin + **kapat (×)** — seçimden
///   çıkmanın tek yolu eskiden sayfada boş bir yere dokunmaktı;
/// - renkler kendi hap zemininde, seçili renkte ✓, silgi ayraçla ayrık;
/// - eylemler tonlu karo; asıl eylem (Düzenle) vurgu renginde.
///
/// ## Niye ayrı dosya
/// İkisi de `ViewerScreen`in içindeki özel metotlardı, yani dar ekranda taşıp
/// taşmadıkları ölçülemiyordu. Buraya alınınca `pdf_action_bars_test.dart`
/// 320/360/412 dp genişliklerde çizip taşma olmadığını doğruluyor.
library;

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/motion.dart';
import '../core/app_colors.dart';

/// Ortak kap: tema yüzeyi, katmanlı yumuşak gölge, ince kenarlık.
class PdfFloatingCard extends StatelessWidget {
  final Widget child;

  const PdfFloatingCard({super.key, required this.child});

  static const double radius = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return ConstrainedBox(
      // Tablette/yatayda boydan boya uzayan bir şerit değil, kart kalsın.
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? scheme.surfaceContainerHigh : scheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shade.withValues(alpha: dark ? 0.45 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.shade.withValues(alpha: dark ? 0.30 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Çubuktaki eylem: tonlu karo, simge üstte, etiket altında.
///
/// **Eşit paylı** ([Expanded]) ve etiket tek satır + ellipsis: uzun çeviriler
/// (Arapça "ترجمة", İngilizce "Translate") dar ekranda taşırmıyor.
/// [emphasized] asıl eylemi vurgu renginde çizer.
class PdfBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  /// Simgenin altına küçük renk çizgisi (Vurgula: şu anki vurgu rengi).
  final Color? accent;

  const PdfBarAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.emphasized = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final bg = emphasized
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final fg = emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    final iconColor = emphasized ? scheme.onPrimaryContainer : scheme.primary;
    final fade = enabled ? 1.0 : 0.38;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Opacity(
              opacity: fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, size: 21, color: iconColor),
                        if (accent != null)
                          Positioned(
                            left: 1,
                            right: 1,
                            bottom: -3,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Daha fazla" menüsündeki bir satır (seçim çubuğunun ⋯ düğmesi).
class PdfBarMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PdfBarMenuItem(
      {required this.icon, required this.label, required this.onTap});
}

/// Metin seçilince çıkan çubuk.
///
/// ## Üçüncü tur (2026-09-27) — renkler artık ilk bakışta YOK
/// Kullanıcı: *"vurgu menüsü çok kullanılan bir şey değil, hemen karşımıza
/// çıkıp yer kaplıyor"* ve *"yanlışlıkla basarsan hemen vurgulama yapılıp
/// düzenleme ekranı kapanıyor"*. Eski çubuk üç kattı (başlık + renk hapı +
/// eylemler) ve renk kutucuğuna değen parmak ANINDA vurgulayıp çubuğu
/// kapatıyordu; geri almanın yolu yoktu.
///
/// Şimdi iki kat: başlık (metin · ⋯ · ×) ve dört eylem (Kopyala · Vurgula ·
/// Düzenle · Çevir). **Vurgula** son kullanılan renkle vurgular ama çubuk
/// KAPANMAZ: [marking] kipine geçer — renkler ancak o zaman görünür (rengi
/// değiştir), yanında **Geri al** ve **Bitti**. Yanlış dokunuş tek
/// dokunuşla geri alınır; vurgu da belgeyi yeniden yüklemeden, anında
/// çizilir (bkz. görüntüleyicinin bekleyen vurguları).
class PdfSelectionBar extends StatelessWidget {
  /// Seçilen metnin kısaltılmış hâli (tırnak içinde gösterilir).
  final String preview;

  final List<int> colors;

  /// Son kullanılan renk — Vurgula düğmesindeki nokta ve seçili kutucuk.
  final int selectedColor;

  /// Vurgula (normal kip): son renkle vurgular, çubuk vurgu kipine geçer.
  final VoidCallback onHighlight;

  /// Vurgu kipinde renk kutucuğu: az önceki vurgunun rengini değiştirir.
  final void Function(int argb) onPickColor;

  /// Vurgu kipi: az önceki vurguyu geri al.
  final VoidCallback onUndoHighlight;

  /// Vurgu kipi: bitti (seçimi kapatır, vurgu kalır).
  final VoidCallback onDone;

  /// Çubuk vurgu kipinde mi (az önce vurgulandı)?
  final bool marking;

  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onTranslate;

  /// ⋯ menüsü (vurguyu kaldır, AI'ya sor, paylaş…). Boşsa düğme çizilmez.
  final List<PdfBarMenuItem> moreItems;

  /// Seçimi kapatır (×). Null verilirse düğme çizilmez.
  final VoidCallback? onClose;

  final String highlightLabel;
  final String copyLabel;
  final String editLabel;
  final String translateLabel;
  final String closeTooltip;
  final String moreTooltip;
  final String markedLabel;
  final String undoLabel;
  final String doneLabel;
  final String colorTooltip;

  const PdfSelectionBar({
    super.key,
    required this.preview,
    required this.colors,
    required this.selectedColor,
    required this.onHighlight,
    required this.onPickColor,
    required this.onUndoHighlight,
    required this.onDone,
    required this.onCopy,
    required this.onEdit,
    required this.onTranslate,
    required this.highlightLabel,
    required this.copyLabel,
    required this.editLabel,
    required this.translateLabel,
    this.marking = false,
    this.moreItems = const [],
    this.onClose,
    this.closeTooltip = '',
    this.moreTooltip = '',
    this.markedLabel = '',
    this.undoLabel = '',
    this.doneLabel = '',
    this.colorTooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PdfFloatingCard(
      child: AnimatedSize(
        duration: Motion.of(context, Motion.short),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: marking
                          ? Color(selectedColor)
                          : scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        marking
                            ? AppIcons.borderColor
                            : AppIcons.formatQuote,
                        size: 16,
                        color: marking ? AppColors.inkStrong : scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      marking && markedLabel.isNotEmpty
                          ? '$markedLabel · $preview'
                          : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (moreItems.isNotEmpty && !marking)
                    PopupMenuButton<int>(
                      tooltip: moreTooltip.isEmpty ? null : moreTooltip,
                      icon: Icon(AppIcons.moreHoriz,
                          size: 20, color: scheme.onSurfaceVariant),
                      style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      position: PopupMenuPosition.over,
                      onSelected: (i) => moreItems[i].onTap(),
                      itemBuilder: (_) => [
                        for (var i = 0; i < moreItems.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                Icon(moreItems[i].icon,
                                    size: 20, color: scheme.primary),
                                const SizedBox(width: 12),
                                Flexible(child: Text(moreItems[i].label)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  if (onClose != null)
                    IconButton(
                      tooltip: closeTooltip.isEmpty ? null : closeTooltip,
                      onPressed: onClose,
                      icon: const Icon(AppIcons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (marking)
              _MarkingRow(
                colors: colors,
                selected: selectedColor,
                onPick: onPickColor,
                onUndo: onUndoHighlight,
                onDone: onDone,
                undoLabel: undoLabel,
                doneLabel: doneLabel,
                colorTooltip: colorTooltip,
              )
            else
              Row(
                children: [
                  PdfBarAction(
                      icon: AppIcons.clipCopy,
                      label: copyLabel,
                      onPressed: onCopy),
                  PdfBarAction(
                    icon: AppIcons.borderColor,
                    label: highlightLabel,
                    onPressed: onHighlight,
                    accent: Color(selectedColor),
                  ),
                  PdfBarAction(
                      icon: AppIcons.edit,
                      label: editLabel,
                      onPressed: onEdit,
                      emphasized: true),
                  PdfBarAction(
                      icon: AppIcons.translate,
                      label: translateLabel,
                      onPressed: onTranslate),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Vurgu kipinin satırı: renkler (az önceki vurgunun rengini değiştirir) +
/// Geri al + Bitti. `Wrap` değil `Row` + `Flexible`: kutucuklar sığmazsa
/// yatay kayar, düğmeler hep görünür kalır.
class _MarkingRow extends StatelessWidget {
  final List<int> colors;
  final int selected;
  final void Function(int) onPick;
  final VoidCallback onUndo;
  final VoidCallback onDone;
  final String undoLabel;
  final String doneLabel;
  final String colorTooltip;

  const _MarkingRow({
    required this.colors,
    required this.selected,
    required this.onPick,
    required this.onUndo,
    required this.onDone,
    required this.undoLabel,
    required this.doneLabel,
    required this.colorTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final argb in colors)
                    _Swatch(
                      argb: argb,
                      selected: argb == selected,
                      tooltip: colorTooltip,
                      onTap: () => onPick(argb),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: undoLabel,
          onPressed: onUndo,
          icon: const Icon(AppIcons.undo),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(doneLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final int argb;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _Swatch({
    required this.argb,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(argb);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 38,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.short),
                width: selected ? 30 : 24,
                height: selected ? 30 : 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : AppColors.shade.withValues(alpha: 0.08),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: selected
                    ? const Icon(AppIcons.check,
                        size: 16, color: AppColors.inkStrong)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
