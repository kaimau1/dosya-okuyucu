# DEVIR — faz-oto-B4-nesne (PLAN §1.4 dilim 2, P17 nesne; PDF_PRO Faz 59 m.4–6)
Yapılanlar:
- m.4 hizalama kılavuzu + tutunma (sayfa kenarı/ortası, 1 inç kenar boşluğu, öteki nesne/blok) — commit 1.
  Kod: lib/services/pdf/pro/pdf_object_geometry.dart (saf), pdf_block_layer(_painter).dart `_DragPreview`/`_DragPainter`.
  Kasma: sürüklemede setState yok, önizleme kendi RepaintBoundary'sinde; bekçi test/pdf_pro/pdf_pro_object_drag_test.dart.
Sıradaki: m.5 çoklu seçim (kement + uzun bas) + grup taşıma + hizala/dağıt (controller selectedItems, `drawing` getter'ına
kement → body.dart'a dokunmadan); m.6 OCG katmanları (Pro araçlar, syncfusion PdfLayer.visible);
kamera = DocumentScanner.scanPages(maxPages:1).
Test: CI (dala push). Yerel test yok.
