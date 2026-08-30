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
/// ## Niye ayrı dosya
/// İkisi de `ViewerScreen`in içindeki özel metotlardı, yani dar ekranda taşıp
/// taşmadıkları ölçülemiyordu. Buraya alınınca `pdf_action_bars_test.dart`
/// 320/360/412 dp genişliklerde çizip taşma olmadığını doğruluyor.
library;

import 'package:flutter/material.dart';

/// Ortak kap: tema yüzeyi, yumuşak gölge, ince kenarlık.
class PdfFloatingCard extends StatelessWidget {
  final Widget child;

  const PdfFloatingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: child,
      ),
    );
  }
}

/// Çubuktaki eylem: simge üstte, etiket altında.
///
/// **Eşit paylı** ([Expanded]) ve etiket tek satır + ellipsis: uzun çeviriler
/// (Arapça "ترجمة", İngilizce "Translate") dar ekranda taşırmıyor.
class PdfBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const PdfBarAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = onPressed == null
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.onSurface;
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Metin seçilince çıkan çubuk: **renk kutucukları + silgi**, altında
/// Kopyala / Düzenle / Çevir.
class PdfSelectionBar extends StatelessWidget {
  /// Seçilen metnin kısaltılmış hâli (tırnak içinde gösterilir).
  final String preview;

  final List<int> colors;

  /// Son kullanılan renk — halkalı çizilir.
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

  final String highlightTooltip;
  final String removeTooltip;
  final String copyLabel;
  final String editLabel;
  final String translateLabel;

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
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PdfFloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                preview,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          // **Wrap, Row değil:** kutucuklar ortalanır ve sığmazsa (yeni renk
          // eklenirse, çok dar ekranda) alt satıra iner — taşıp kırmızı
          // şerit vermez. Yatay kaydırma denendi ama kaydırılabilir alan
          // daima tam genişliği kaplıyor, yani içerik sola yapışıyordu.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.border_color,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                for (final argb in colors)
                  _Swatch(
                    argb: argb,
                    selected: argb == selectedColor,
                    tooltip: highlightTooltip,
                    onTap: () => onHighlight(argb),
                  ),
                const SizedBox(width: 6),
                Tooltip(
                  message: removeTooltip,
                  child: InkResponse(
                    onTap: onRemoveHighlight,
                    radius: 22,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(Icons.format_color_reset,
                          size: 18, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
          Row(
            children: [
              PdfBarAction(
                  icon: Icons.copy_rounded, label: copyLabel, onPressed: onCopy),
              PdfBarAction(
                  icon: Icons.edit_outlined, label: editLabel, onPressed: onEdit),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Color(argb),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
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
  });

  /// İmleç satırı: ◀ ▶ ve "tümünü seç". Simge düğmeleri **sabit ölçülü**
  /// (48 dp'lik dokunma hedefi) ve sayıca üç — dar ekranda da taşmaz.
  Widget _caretRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caret = onCaretLeft != null || onCaretRight != null;
    return PdfFloatingCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caret) _caretRow(),
          Row(
            children: [
          // İkisi eşit paylı, etiketler ellipsis: dar ekranda taşmaz.
          PdfBarAction(
            icon: Icons.close,
            label: cancelLabel,
            onPressed: busy ? null : onCancel,
          ),
          PdfBarAction(
            icon: Icons.auto_fix_high,
            label: aiLabel,
            onPressed: busy ? null : onRewrite,
          ),
          // **Asıl eylem DOLU düğme:** üçü de düz metin düğmesiyken hangisinin
          // asıl eylem olduğu belli değildi.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: busy
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.primary),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        applyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
