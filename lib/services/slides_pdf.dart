import 'dart:ui' show Rect;

import 'ocr_service.dart' show OcrLine;
import 'pptx_render.dart';

/// Slaytı PDF'e basarken **görünmez metin katmanını** üreten saf katman.
///
/// **Neden görüntü + görünmez metin, neden vektör yeniden çizim değil:**
/// slayt sadakati (ön tanımlı şekiller, `custGeom` serbest çizimler, `lnRef`
/// kalınlığı, gradient dolgular, kırpılmış görseller) `slide_canvas` içinde
/// uzun uğraşla oturtuldu. Aynı çizimi `pdf` paketinin widget'larıyla ikinci
/// kez yazmak, o sadakati sıfırdan riske atmak olurdu — üstelik iki çizici
/// birbirinden bağımsız bozulur ve fark ancak kullanıcının ekranında görülür.
/// Bu yüzden PDF'e **ekranda çizilenin ta kendisi** basılıyor; metin ise
/// üstüne `3 Tr` (çizme ama belgede tut) ile yazılıyor. Sonuç hem birebir
/// aynı görünüyor hem aranabilir/kopyalanabilir kalıyor.
///
/// Bu dosya bilerek **saf Dart**: Flutter widget'ı tanımaz, yalnız
/// [SlideVM] → [OcrLine] dönüşümünü yapar, böylece testle sabitlenebilir.
/// Ekran görüntüsünü almak (widget → PNG) çağıranın işi.
class SlidesPdf {
  /// [slide] üzerindeki metinleri, **görüntü pikseli** koordinatlarında
  /// görünmez metin satırlarına çevirir.
  ///
  /// [pixelRatio] slaytın kaç katı çözünürlükte basıldığı. `ConversionService
  /// .imagesToPdf` gelen kutuları görüntü boyutundan hesapladığı ölçekle
  /// çarpıyor; bu yüzden kutular **punto değil piksel** olmalı. Ölçeği burada
  /// uygulamak, çağıranın iki yerde aynı çarpanı hatırlamasından iyidir.
  ///
  /// Kutu şeklin tamamı değil, **paragraf başına** bir dilim: bir metin
  /// kutusunda üç madde varsa üçü tek kutuya sıkıştırılırsa kopyalanan metin
  /// tek satıra iner ve arama "ikinci madde"yi şeklin en üstünde gösterir.
  static List<OcrLine> textLines(SlideVM slide, {double pixelRatio = 1}) {
    final lines = <OcrLine>[];
    for (final shape in slide.shapes) {
      if (!shape.hasText) continue;

      // Metni olan paragrafları say: boş paragraflar (satır arası boşluk için
      // konmuş `<a:p/>`) yer kaplamamalı, yoksa dolu maddeler kutunun üst
      // yarısına sıkışır ve seçim kutuları metinden kayar.
      final filled = [
        for (final p in shape.paragraphs)
          if (p.plainText.trim().isNotEmpty) p,
      ];
      if (filled.isEmpty) continue;

      final sliceHeight = shape.h / filled.length;
      for (var i = 0; i < filled.length; i++) {
        final text = filled[i].plainText.trim();
        lines.add(OcrLine(
          text,
          Rect.fromLTWH(
            shape.x * pixelRatio,
            (shape.y + sliceHeight * i) * pixelRatio,
            shape.w * pixelRatio,
            sliceHeight * pixelRatio,
          ),
        ));
      }
    }
    return lines;
  }

  /// Slaytın düz metni — "PDF'e aktar" dışında paylaşım/arama için de işe yarar.
  /// Şekil sırası korunur (okuma sırası bu değildir ama PowerPoint'in kendi
  /// "Anahat" görünümü de şekil sırasını kullanır).
  static String plainText(SlideVM slide) {
    final buf = <String>[];
    for (final shape in slide.shapes) {
      for (final p in shape.paragraphs) {
        final t = p.plainText.trim();
        if (t.isNotEmpty) buf.add(t);
      }
    }
    return buf.join('\n');
  }
}
