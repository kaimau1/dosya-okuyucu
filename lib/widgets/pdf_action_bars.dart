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
        duration: const Duration(milliseconds: 180),
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
                            ? Icons.border_color_rounded
                            : Icons.format_quote_rounded,
                        size: 16,
                        color: marking ? Colors.black87 : scheme.primary),
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
                      icon: Icon(Icons.more_horiz_rounded,
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
                      icon: const Icon(Icons.close_rounded, size: 20),
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
                      icon: Icons.content_copy_rounded,
                      label: copyLabel,
                      onPressed: onCopy),
                  PdfBarAction(
                    icon: Icons.border_color_rounded,
                    label: highlightLabel,
                    onPressed: onHighlight,
                    accent: Color(selectedColor),
                  ),
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
          icon: const Icon(Icons.undo_rounded),
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
                duration: const Duration(milliseconds: 160),
                width: selected ? 30 : 24,
                height: selected ? 30 : 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : Colors.black.withValues(alpha: 0.08),
                    width: selected ? 2.5 : 1,
                  ),
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
