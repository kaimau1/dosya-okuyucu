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
/// **Punto nasıl bulunuyor (2026-07-26 II. tur).** Önce karakter kutusunun
/// yüksekliği sabit bir katsayıyla çarpılıyordu; kullanıcı *"yazı fontu boyutu
/// vs hepsi korunmalı, sanki o yazıya aitmiş gibi olmalı"* dedi çünkü katsayı
/// belgeden belgeye tutmuyordu (dar/geniş fontlarda gözle görülür kayıyordu).
/// Şimdi punto **ölçülerek** bulunuyor: özgün metin, seçimin ekrandaki
/// genişliğini verecek puntoda çiziliyor. Kutunun kendi çerçevesi de kalktı —
/// yalnız ince bir alt çizgi kaldı, gerisi sayfanın kendi görüntüsü gibi duruyor.
class PdfInlineEditor extends StatefulWidget {
  const PdfInlineEditor({
    super.key,
    required this.page,
    required this.pageSize,
    required this.rects,
    required this.original,
    required this.onApply,
    required this.onCancel,
    required this.onAi,
    this.busy = false,
  });

  final PdfPage page;

  /// Sayfanın ekrandaki (ölçekli) boyutu.
  final Size pageSize;

  /// Düzenlenen metnin PDF-koordinat dikdörtgenleri (satır başına bir).
  final List<PdfRect> rects;

  final String original;

  /// Yeni metinle uygula.
  final void Function(String newText) onApply;

  final VoidCallback onCancel;

  /// AI ile yeniden yazdır; dönen metin kutuya yazılır.
  final Future<String?> Function(String current) onAi;

  /// Kaydetme sürerken düğmeler kilitlenir.
  final bool busy;

  @override
  State<PdfInlineEditor> createState() => _PdfInlineEditorState();
}

class _PdfInlineEditorState extends State<PdfInlineEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.original);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Kutu açılır açılmaz metnin tamamı seçili gelsin: kullanıcı doğrudan
    // yazmaya başlayabilir (Word'de bir kelimeye çift tıklamak gibi).
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: widget.original.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Seçili satırların ekran dikdörtgeni (hepsini kapsayan).
  Rect? get _box {
    Rect? out;
    for (final r in widget.rects) {
      final rect = r.toRect(page: widget.page, scaledPageSize: widget.pageSize);
      out = out == null ? rect : out.expandToInclude(rect);
    }
    return out;
  }

  /// Tek satırın yüksekliği — punto tahmininin başlangıcı buradan gelir.
  double get _lineHeight {
    if (widget.rects.isEmpty) return 14;
    final first = widget.rects.first
        .toRect(page: widget.page, scaledPageSize: widget.pageSize);
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
    final text = widget.original;
    if (text.trim().isEmpty || box.width <= 1 || text.contains('\n')) {
      return base;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
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

  Future<void> _runAi() async {
    final result = await widget.onAi(_controller.text);
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _controller.text = result);
    }
  }

  void _apply() {
    final text = _controller.text;
    if (text.trim().isNotEmpty) widget.onApply(text);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    if (box == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fontSize = _fontSizeFor(box);
    final multiline = widget.original.contains('\n');
    // Birkaç harf sağa yer bırakılır (yeni metin biraz uzun olabilir) ama
    // fazlası komşu yazıyı beyaza boyardı; gerisi kutunun içinde kayar.
    final width = (box.width + 14).clamp(48.0, widget.pageSize.width - box.left);

    // Araç çubuğu kutunun üstünde; sayfanın tepesindeyse altına alınır.
    final toolbarAbove = box.top > 52;

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
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                enabled: !widget.busy,
                maxLines: multiline ? null : 1,
                keyboardType:
                    multiline ? TextInputType.multiline : TextInputType.text,
                textInputAction:
                    multiline ? TextInputAction.newline : TextInputAction.done,
                onSubmitted: multiline ? null : (_) => _apply(),
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
          Positioned(
            left: box.left,
            top: toolbarAbove ? box.top - 50 : box.bottom + 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _button(
                      icon: Icons.close,
                      tooltip: 'Vazgeç',
                      onPressed: widget.busy ? null : widget.onCancel,
                    ),
                    _button(
                      icon: Icons.auto_fix_high,
                      tooltip: 'AI ile düzelt',
                      onPressed: widget.busy ? null : _runAi,
                    ),
                    if (widget.busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    else
                      _button(
                        icon: Icons.check,
                        tooltip: 'Uygula',
                        onPressed: _apply,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 22, color: Colors.white),
        onPressed: onPressed,
      );
}
