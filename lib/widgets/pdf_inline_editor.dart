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
/// Kutu neden opak: altında sayfanın ÇİZİLMİŞ hâli duruyor; saydam bıraksak
/// eski yazı yenisinin altından okunur, kullanıcı neyi yazdığını göremezdi.
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

  /// Tek satırın yüksekliği — punto tahmini buradan gelir.
  double get _lineHeight {
    if (widget.rects.isEmpty) return 14;
    final first = widget.rects.first
        .toRect(page: widget.page, scaledPageSize: widget.pageSize);
    return first.height <= 0 ? 14 : first.height;
  }

  Future<void> _runAi() async {
    final result = await widget.onAi(_controller.text);
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _controller.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    if (box == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // pdfium'un karakter kutusu yaklaşık yazı bloğu yüksekliğidir; Flutter'da
    // aynı görsel boyu yakalamak için biraz küçültülür.
    final fontSize = (_lineHeight * 0.82).clamp(7.0, 96.0);
    final multiline = widget.original.contains('\n');
    final width =
        (box.width + 10).clamp(60.0, (widget.pageSize.width - box.left + 4));

    // Araç çubuğu kutunun üstünde; sayfanın tepesindeyse altına alınır.
    final toolbarAbove = box.top > 46;

    // Positioned.fill: katman sayfanın tamamını kaplar, içindeki konumlar
    // doğrudan sayfa koordinatı olur (PdfSelectLayer ile aynı düzen).
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: box.left - 5,
            top: box.top - 3,
            width: width,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                // Kağıt beyazı: altındaki eski yazı görünmesin. Gece modunda
                // sayfayla birlikte terslendiği için uyum bozulmaz.
                color: Colors.white,
                border: Border.all(color: scheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(3),
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
                onSubmitted: multiline
                    ? null
                    : (value) {
                        if (value.trim().isNotEmpty) widget.onApply(value);
                      },
                cursorColor: scheme.primary,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.15,
                  color: Colors.black,
                ),
                decoration: const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
          Positioned(
            left: box.left - 5,
            top: toolbarAbove ? box.top - 45 : box.bottom + 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(20),
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
                        padding: EdgeInsets.symmetric(horizontal: 10),
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
                        onPressed: () {
                          final text = _controller.text;
                          if (text.trim().isNotEmpty) widget.onApply(text);
                        },
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
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
      );
}
