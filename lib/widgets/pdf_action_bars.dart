/// **PDF sayfasının üstünde yüzen iki araç çubuğu:** metin seçilince çıkan
/// [PdfSelectionBar] ve yerinde düzenleme açıkken çıkan [PdfEditBar].
///
/// ## Niye yeniden yazıldı (2026-08-29)
/// Kullanıcı: *"düzenlerken vs açılan araç menüleri çok zarif yetersiz ve kötü
/// görünüyor, üzerlerine çalış."* Eski hâl:
/// - zemin `Colors.black.withValues(alpha: 0.78)` — her temada aynı, kağıt
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
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.30 : 0.06),
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

  const PdfBarAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.emphasized = false,
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
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: iconColor),
                    const SizedBox(height: 4),
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

/// Metin seçilince çıkan çubuk: başlık (seçilen metin + kapat), **renk
/// kutucukları + silgi**, altında Kopyala / Düzenle / Çevir.
class PdfSelectionBar extends StatelessWidget {
  /// Seçilen metnin kısaltılmış hâli (tırnak içinde gösterilir).
  final String preview;

  final List<int> colors;

  /// Son kullanılan renk — halkalı ve ✓ ile çizilir.
  final int selectedColor;

  /// Renk kutucuğuna dokunulunca. **Doğrudan vurgular:** eskiden önce renk
  /// seçilip sonra ayrı bir "Vurgula" düğmesine basmak gerekiyordu — iki adım,
  /// iki ayrı yer. Gerçek PDF okuyucularının yaptığı da tek dokunuş.
  final void Function(int argb) onHighlight;

  /// Silgi: seçime değen vurguları kaldırır (kullanıcı 2026-08-29:
  /// *"vurgu kaldır vb işlemler yok"*).
  final VoidCallback onRemoveHighlight;

  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onTranslate;

  /// Seçimi kapatır (×). Null verilirse düğme çizilmez.
  final VoidCallback? onClose;

  final String highlightTooltip;
  final String removeTooltip;
  final String copyLabel;
  final String editLabel;
  final String translateLabel;
  final String closeTooltip;

  const PdfSelectionBar({
    super.key,
    required this.preview,
    required this.colors,
    required this.selectedColor,
    required this.onHighlight,
    required this.onRemoveHighlight,
    required this.onCopy,
    required this.onEdit,
    required this.onTranslate,
    required this.highlightTooltip,
    required this.removeTooltip,
    required this.copyLabel,
    required this.editLabel,
    required this.translateLabel,
    this.onClose,
    this.closeTooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PdfFloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview.isNotEmpty || onClose != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.format_quote_rounded,
                        size: 16, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: closeTooltip.isEmpty ? null : closeTooltip,
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          // Renkler kendi hap zemininde. **Wrap, Row değil:** kutucuklar
          // ortalanır ve sığmazsa (yeni renk eklenirse, çok dar ekranda) alt
          // satıra iner — taşıp kırmızı şerit vermez.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6, left: 2),
                  child: Icon(Icons.border_color_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                for (final argb in colors)
                  _Swatch(
                    argb: argb,
                    selected: argb == selectedColor,
                    tooltip: highlightTooltip,
                    onTap: () => onHighlight(argb),
                  ),
                Container(
                  width: 1,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: scheme.outlineVariant,
                ),
                Tooltip(
                  message: removeTooltip,
                  child: InkResponse(
                    onTap: onRemoveHighlight,
                    radius: 22,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.format_color_reset_rounded,
                          size: 20, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PdfBarAction(
                  icon: Icons.content_copy_rounded,
                  label: copyLabel,
                  onPressed: onCopy),
              PdfBarAction(
                  icon: Icons.edit_rounded,
                  label: editLabel,
                  onPressed: onEdit,
                  emphasized: true),
              PdfBarAction(
                  icon: Icons.translate_rounded,
                  label: translateLabel,
                  onPressed: onTranslate),
            ],
          ),
        ],
      ),
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
            width: 36,
            height: 36,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 28 : 24,
                height: selected ? 28 : 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : Colors.black.withValues(alpha: 0.08),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: selected ? 8 : 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.black87)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yerinde düzenleme çubuğu: **Vazgeç / AI ile düzelt / Uygula.**
///
/// KÖK NEDEN — niye sayfanın üzerinde değil de ekranın altında
/// (2026-07-26 kullanıcı bulgusu: *"x, onay, ai işaretlerine tıklanmıyor"*):
/// `linkHandlerParams` verilince pdfrx TÜM görüntüyü kaplayan translucent bir
/// `GestureDetector` kurar ve bunu sayfa katmanlarının ÜSTÜNE koyar. Hit-test
/// yolunda bizden önce geldiği için tap tanıyıcısı arenaya önce girer; kimse
/// erken kazanmayınca `GestureArenaManager.sweep()` **ilk üyeyi** seçer →
/// sayfa katmanındaki hiçbir düğme ateşlenmez. (Metin kutusu çalışıyordu:
/// metin alanı tanıyıcısı arenayı erken kazanır.)
///
/// İlk çözüm "düzenleme açıkken köprüyü kapat" idi; ama bu, düzenleme her
/// açılıp kapandığında `PdfViewerParams`'ı değiştiriyordu. Çubuk ekranın
/// altına alınınca köprü hiç kapanmıyor: orası pdfrx'in TAMAMEN dışında,
/// üstteki Stack'te, dolayısıyla dokunuşu doğal olarak ilk o alıyor. Ek fayda:
/// çubuk sayfa kenarına taşıp kırpılmıyor ve klavyenin hemen üstünde duruyor.
class PdfEditBar extends StatelessWidget {
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onRewrite;
  final VoidCallback onApply;

  /// İmleci bir karakter sola/sağa taşır ve metnin tamamını seçer.
  ///
  /// **Niye düğme** (kullanıcı 2026-08-30: *"imleç zor hareket ediyor"*):
  /// yerinde düzenleme kutusu belgenin kendi puntosunda çiziliyor — gövde
  /// metninde 10-14 dp. O boyda bir yazının İÇİNDE parmakla tek karakter
  /// ilerlemek pratikte mümkün değil; sürükleme tutamacı da yazıdan büyük
  /// olduğu için altındaki harfi kapatıyor. Kutunun dokunma payı büyütüldü
  /// (bkz. `PdfInlineEditor`) ama "bir harf sola" isteğinin kesin karşılığı
  /// klavye okları; telefon klavyesinde ok tuşu yok, o yüzden burada.
  ///
  /// Null verilirse satır hiç çizilmez (çubuk eski hâline döner).
  final VoidCallback? onCaretLeft;
  final VoidCallback? onCaretRight;
  final VoidCallback? onSelectAll;

  final String cancelLabel;
  final String aiLabel;
  final String applyLabel;

  /// İmleç satırının ipuçları (sola / sağa / tümünü seç).
  final String caretLeftLabel;
  final String caretRightLabel;
  final String selectAllLabel;

  const PdfEditBar({
    super.key,
    required this.busy,
    required this.onCancel,
    required this.onRewrite,
    required this.onApply,
    required this.cancelLabel,
    required this.aiLabel,
    required this.applyLabel,
    this.onCaretLeft,
    this.onCaretRight,
    this.onSelectAll,
    this.caretLeftLabel = '',
    this.caretRightLabel = '',
    this.selectAllLabel = '',
    this.title = '',
  });

  /// Başlık satırındaki kısa açıklama ("Metni düzenle"). Boşsa çizilmez.
  final String title;

  /// İmleç denetimi: ◀ ▶ ve "tümünü seç" tek bir hap içinde. Simge
  /// düğmeleri **sabit ölçülü** ve sayıca üç — dar ekranda da taşmaz.
  Widget _caretPill(ColorScheme scheme) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: caretLeftLabel.isEmpty ? null : caretLeftLabel,
              onPressed: busy ? null : onCaretLeft,
              icon: const Icon(Icons.keyboard_arrow_left),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: caretRightLabel.isEmpty ? null : caretRightLabel,
              onPressed: busy ? null : onCaretRight,
              icon: const Icon(Icons.keyboard_arrow_right),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: selectAllLabel.isEmpty ? null : selectAllLabel,
              onPressed: busy ? null : onSelectAll,
              icon: const Icon(Icons.select_all),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caret = onCaretLeft != null || onCaretRight != null;
    return PdfFloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caret || title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if (title.isNotEmpty) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_note_rounded,
                          size: 18, color: scheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (caret) _caretPill(scheme),
                  if (!caret || title.isEmpty) const Spacer(),
                ],
              ),
            ),
          Row(
            children: [
              // İkisi eşit paylı tonlu karo, etiketler ellipsis: dar ekranda
              // taşmaz.
              PdfBarAction(
                icon: Icons.close_rounded,
                label: cancelLabel,
                onPressed: busy ? null : onCancel,
              ),
              PdfBarAction(
                icon: Icons.auto_fix_high_rounded,
                label: aiLabel,
                onPressed: busy ? null : onRewrite,
              ),
              // **Asıl eylem DOLU düğme**, karolardan geniş.
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 58,
                    child: busy
                        ? Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.primary),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: onApply,
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              applyLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
