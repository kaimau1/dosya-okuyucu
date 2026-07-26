import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// **Sayfa üzerinde yerinde metin düzenleme kutusu.**
///
/// Kullanıcı isteği (2026-07-26): *"sayfa üzerinde yeni bir alan açılmadan
/// klavyeden değişiklik yapabilmeliyim, sanki orijinali oymuş gibi olmalı."*
/// Eskiden "Düzenle" ayrı bir EKRAN açıyordu: belge gözden kayboluyor, metin
/// bağlamından kopuyor ve düzeltmenin sayfada nasıl duracağı görülmüyordu.
///
/// Artık kutu, seçili metnin TAM ÜSTÜNDE açılıyor: aynı yerde, aynı satır
/// yüksekliğinde, klavye hemen geliyor. Kaydedilince belgenin kendi metni
/// değiştiği için sonuç "sanki hep öyleymiş gibi" duruyor
/// (bkz. `PdfContentEditor`).
///
/// **Punto nasıl bulunuyor.** Önce karakter kutusunun yüksekliği sabit bir
/// katsayıyla çarpılıyordu; kullanıcı *"yazı fontu boyutu vs hepsi korunmalı,
/// sanki o yazıya aitmiş gibi olmalı"* dedi çünkü katsayı belgeden belgeye
/// tutmuyordu. Şimdi punto **ölçülerek** bulunuyor: özgün metin, seçimin
/// ekrandaki genişliğini verecek puntoda çiziliyor.
///
/// **Düğmeler burada DEĞİL** (2026-07-26, 8. tur): vazgeç / AI / uygula
/// çubuğu ekranın altında, `ViewerScreen` içinde duruyor. Sebebi
/// `ViewerScreen._editBar`'da yazılı — kısaca pdfrx'in köprü katmanı sayfa
/// katmanlarının üstünde bir tap tanıyıcısı kuruyor ve buradaki düğmelere
/// basılamıyordu. Metin kutusunun kendisi çalışıyor (metin alanı tanıyıcısı
/// arenayı erken kazanır), o yüzden yalnız o kaldı.
class PdfInlineEditor extends StatelessWidget {
  const PdfInlineEditor({
    super.key,
    required this.page,
    required this.pageSize,
    required this.rects,
    required this.original,
    required this.controller,
    required this.onSubmit,
    this.busy = false,
  });

  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu.
  final Size pageSize;

  /// Düzenlenen metnin PDF-koordinat dikdörtgenleri (satır başına bir).
  final List<PdfRect> rects;

  final String original;

  /// Metin denetleyicisi **dışarıda** (ViewerScreen) tutuluyor: alttaki
  /// düğme çubuğu da aynı metni okuyor.
  final TextEditingController controller;

  /// Klavyenin "bitti" tuşu — tek satırlık metinde doğrudan uygular.
  final VoidCallback onSubmit;

  /// Kaydetme sürerken kutu kilitlenir.
  final bool busy;

  /// Seçili satırların ekran dikdörtgeni (hepsini kapsayan).
  Rect? get _box {
    Rect? out;
    for (final r in rects) {
      final rect = r.toRect(page: page, scaledPageSize: pageSize);
      out = out == null ? rect : out.expandToInclude(rect);
    }
    return out;
  }

  /// Tek satırın yüksekliği — punto tahmininin başlangıcı buradan gelir.
  double get _lineHeight {
    if (rects.isEmpty) return 14;
    final first = rects.first.toRect(page: page, scaledPageSize: pageSize);
    return first.height <= 0 ? 14 : first.height;
  }

  /// Özgün metni seçimin ekrandaki GENİŞLİĞİNE oturtan punto.
  ///
  /// pdfium'un karakter kutusu yaklaşık yazı bloğu yüksekliğidir; ondan
  /// hesaplanan punto başlangıç tahminidir. Sonra özgün metin o puntoda
  /// ölçülür ve genişlik oranıyla düzeltilir — belgenin fontu dar da olsa
  /// geniş de olsa yazı aynı yeri kaplar, yani "o yazıya aitmiş gibi" durur.
  ///
  /// Oran [0.7, 1.4] arasında kısılıyor: seçim tek harf ya da çok boşluklu
  /// olduğunda ölçüm yanıltıcı olabilir, saçma bir puntoya savrulmayalım.
  double _fontSizeFor(Rect box) {
    final base = (_lineHeight * 0.86).clamp(6.0, 120.0);
    if (original.trim().isEmpty || box.width <= 1 || original.contains('\n')) {
      return base;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: original,
        style: TextStyle(fontSize: base, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final measured = painter.width;
    painter.dispose();
    if (measured <= 1) return base;
    final ratio = (box.width / measured).clamp(0.7, 1.4);
    return (base * ratio).clamp(6.0, 120.0);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    if (box == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fontSize = _fontSizeFor(box);
    final multiline = original.contains('\n');
    // Birkaç harf sağa yer bırakılır (yeni metin biraz uzun olabilir) ama
    // fazlası komşu yazıyı beyaza boyardı; gerisi kutunun içinde kayar.
    final width = (box.width + 14).clamp(48.0, pageSize.width - box.left);

    // Positioned.fill: katman sayfanın tamamını kaplar, içindeki konumlar
    // doğrudan sayfa koordinatı olur (PdfSelectLayer ile aynı düzen).
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: box.left,
            top: box.top,
            width: width,
            child: Container(
              // Kağıt beyazı ve TAM eski yazının üstünde: altındaki eski yazı
              // okunmasın, ama çevresinde kutu/çerçeve görünmesin. Gece modunda
              // sayfayla birlikte terslendiği için uyum bozulmaz.
              constraints: BoxConstraints(minHeight: box.height),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  // Tek görsel işaret: ince alt çizgi. Çerçeve yerine bu,
                  // çünkü çerçeve "ayrı bir kutu" hissi veriyordu.
                  bottom: BorderSide(color: scheme.primary, width: 1.2),
                ),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                enabled: !busy,
                maxLines: multiline ? null : 1,
                keyboardType:
                    multiline ? TextInputType.multiline : TextInputType.text,
                textInputAction:
                    multiline ? TextInputAction.newline : TextInputAction.done,
                onSubmitted: multiline ? null : (_) => onSubmit(),
                cursorColor: scheme.primary,
                cursorWidth: 1.4,
                style: TextStyle(
                  fontSize: fontSize,
                  // height 1.0: satır kutusu puntoyla aynı kalsın, yazı
                  // özgün satırın üstünde/altında kaymasın.
                  height: 1.0,
                  color: Colors.black,
                ),
                strutStyle: StrutStyle(
                  fontSize: fontSize,
                  height: 1.0,
                  forceStrutHeight: true,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
