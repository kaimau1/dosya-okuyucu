import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/ocr_service.dart';

/// Görselin ÜSTÜNE yerleşen, görünmez ama seçilebilir OCR metin katmanı
/// (Google Lens gibi: basılı tut → sürükle → kopyala).
///
/// Görselle aynı `Stack` içinde `Positioned.fill` olarak durmalı; katmanın
/// boyutu = ekranda çizilen görselin boyutu. Kutular ML Kit'ten resim piksel
/// koordinatında gelir; ölçek, resmin asıl boyutundan hesaplanır (EXIF ile
/// dönmüş fotoğrafta genişlik/yükseklik yer değiştirir → ekrandaki en-boy
/// oranına uyan yön seçilir).
class OcrTextOverlay extends StatefulWidget {
  final String path;
  final List<OcrLine> lines;

  /// Satırların arkasına hafif bir vurgu çizilsin mi (metnin nerede olduğu
  /// görünsün diye; seçim yine çalışır).
  final bool showBoxes;

  /// Seçim değiştikçe seçili düz metin (boş = seçim yok). Alt panel bunu
  /// gösterir ("19 karakter seçildi" + metin + Kopyala).
  final ValueChanged<String>? onSelection;

  const OcrTextOverlay({
    super.key,
    required this.path,
    required this.lines,
    this.showBoxes = true,
    this.onSelection,
  });

  @override
  State<OcrTextOverlay> createState() => _OcrTextOverlayState();
}

class _OcrTextOverlayState extends State<OcrTextOverlay> {
  Size? _source;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  @override
  void didUpdateWidget(OcrTextOverlay old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _source = null;
      _readSize();
    }
  }

  /// Resmin asıl boyutu: yalnız başlık okunur, piksel çözülmez.
  Future<void> _readSize() async {
    Size? size;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? desc;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(widget.path);
      desc = await ui.ImageDescriptor.encoded(buffer);
      size = Size(desc.width.toDouble(), desc.height.toDouble());
    } catch (_) {
      size = null;
    } finally {
      desc?.dispose();
      buffer?.dispose();
    }
    if (!mounted || size == null) return;
    setState(() => _source = size);
  }

  @override
  Widget build(BuildContext context) {
    final src = _source;
    if (src == null || widget.lines.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      if (!box.hasBoundedWidth || box.maxWidth <= 0 || box.maxHeight <= 0) {
        return const SizedBox.shrink();
      }
      final shown = box.maxWidth / box.maxHeight;
      final upright = src.width / src.height;
      final turned = src.height / src.width;
      final w = (shown - upright).abs() <= (shown - turned).abs()
          ? src.width
          : src.height;
      final s = box.maxWidth / w;
      final hl = scheme.primary.withValues(alpha: 0.14);
      final tiny = Theme.of(context).textTheme.bodySmall!
          .apply(fontSizeFactor: 0.001, heightFactor: 0.01);
      // Kutular resmin fiziksel piksel koordinatında: sağdan sola dilde de
      // aynalanmamalı → katman hep soldan sağa dizilir.
      return SelectionArea(
        onSelectionChanged: (c) =>
            widget.onSelection?.call((c?.plainText ?? '').trim()),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
          children: [
            for (final line in widget.lines)
              PositionedDirectional(
                start: line.box.left * s,
                top: line.box.top * s,
                width: (line.box.width * s).clamp(1.0, double.infinity),
                height: (line.box.height * s).clamp(1.0, double.infinity),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.showBoxes ? hl : null,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: line.text),
                        // Kopyalanan metinde satırlar ayrı kalsın; yüksekliği
                        // yok denecek kadar küçük, kutuyu bozmaz.
                        TextSpan(text: '\n', style: tiny),
                      ]),
                      maxLines: 2,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.transparent,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          ),
        ),
      );
    });
  }
}
