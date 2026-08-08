import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/pptx_render.dart';
import 'slide_canvas.dart';

/// Slaytı **ekranda göründüğü gibi** PNG'e basar (PDF'e aktarma için).
///
/// **Neden ekran dışı gerçek çizim, neden başsız (headless) çizim değil:**
/// `SlideCanvas` görselleri `Image.memory` ile çiziyor ve çözümleme
/// asenkrondur. Başsız bir `BuildOwner`/`PipelineOwner` kurup tek karede
/// boyamak, görseli olan slaytları **boş** basardı — üstelik sessizce, çünkü
/// `Image.memory` yüklenene kadar hiçbir şey çizmez ve hata da atmaz.
/// Bu yüzden slayt gerçek ağaca (Overlay) ekleniyor, görseller önceden
/// önbelleğe alınıyor ve gerçek kareler beklendikten sonra yakalanıyor.
///
/// Slayt ekranın DIŞINA ötelenerek konuyor: `Offstage` işe yaramaz, çünkü
/// offstage bir alt ağaç hiç boyanmaz ve `toImage` boş döner. Öteleme ise
/// yerleşimi ve boyamayı olduğu gibi bırakır; `RepaintBoundary.toImage` kendi
/// katmanını çizdiği için üst katmandaki kırpma/öteleme çıktıya yansımaz.
class SlideSnapshot {
  /// [slide]'ı [pixelRatio] katı çözünürlükte PNG olarak döndürür.
  ///
  /// [pixelRatio] 2 = slayt puntosunun iki katı piksel. Yükseltmek yazıyı
  /// keskinleştirir ama dosyayı büyütür; 40 slaytlık bir destede 3'ün üstü
  /// telefonda belleği zorlar.
  ///
  /// Ekran (overlay) kapanırsa null döner — çağıran bunu "vazgeçildi" sayar.
  static Future<Uint8List?> toPng(
    BuildContext context,
    SlideVM slide, {
    double pixelRatio = 2,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    // Görseller ÖNCE önbelleğe: çizim anında hazır olmazlarsa slayt görselsiz
    // basılır ve bu sessiz bir bozulmadır (kimse hata görmez, sadece PDF eksik).
    await _precacheImages(context, slide);
    if (!context.mounted) return null;

    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Ekranın dışında ama ölçülüp boyanıyor.
        left: -30000,
        top: -30000,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: slide.widthPt,
            height: slide.heightPt,
            // `step: null` = her şey görünür. Sunum modundaki animasyon adımı
            // PDF'e taşınmamalı: kâğıtta "henüz belirmemiş" madde yoktur.
            child: SlideCanvas(slide: slide),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // İlk kare yerleşimi kurar; ikinci kare görsellerin çizimini garantiler.
      await _nextFrame();
      await _nextFrame();

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        // `ui.Image` yerel bellek tutar ve GC'yi beklemez; 40 slaytlık bir
        // destede bırakılırsa bellek kullanımı slayt sayısıyla büyür.
        image.dispose();
      }
    } finally {
      entry.remove();
    }
  }

  static Future<void> _precacheImages(
      BuildContext context, SlideVM slide) async {
    final bytes = <Uint8List>[
      if (slide.backgroundImage != null) slide.backgroundImage!,
      for (final s in slide.shapes)
        if (s.image != null) s.image!,
    ];
    for (final b in bytes) {
      if (!context.mounted) return;
      // Bozuk/desteklenmeyen görsel yüzünden tüm aktarma düşmemeli: tuval
      // zaten `errorBuilder` ile o şekli boş bırakıyor.
      try {
        await precacheImage(MemoryImage(b), context);
      } catch (_) {
        // yok say — o şekil boş çizilir
      }
    }
  }

  static Future<void> _nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    // Overlay eklendiği karede zaten yeniden çizim planlanıyor; yine de
    // kareyi biz de isteyelim ki uygulama boştayken (hiç animasyon yokken)
    // geri çağrı asılı kalmasın.
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }
}
