# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1 (P21 meta veri + P17 XFDF) ve dilim 2 (P21 R6 kilit açma) main'de (ccf161cd).
Dilim 3 (dalda): P20 sayfa stüdyosu çekirdeği — commit da313e6e (+ CI düzeltmesi: hapticFeedbackOnStart).
- lib/screens/pdf_tools/page_studio.dart (ızgara, seç/döndür/sil/çoğalt, LongPressDraggable taşı, 50 adım geri al); PdfReorderScreen silindi.
- lib/services/pdf_tools.dart applyPageStudio(+InBackground) / studioKeepsAnnotations; test test/pdf_tools_test.dart "applyPageStudio" grubu.
- Kasma: hücre RepaintBoundary + delege sabit boy, Opacity yok; seçim kök setState (araç ekranı) — C2'de ölçülecek.
Atlanan: P21 "bu kipte yazdır" — viewer/doc_actions.dart _print (kabuk; anlam belirsiz) → sabah bakılacak.
Kalan (öneri sırası):
1. P20 devamı: araya boş/dosyadan/görselden sayfa ekle, böl, başka PDF'le birleştir (stüdyo içinde); kırpma/sayfa boyutu; üst bilgi/Bates; yer imi düzenleme (pro_views outline zaten var); sürüklerken kenar kaydırma.
2. P18 düz PDF'te alan algılama (çizgi/kutu sezgisi), form+imza tek yüzey.
3. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — sıcak yola yakın; bayrakla.
4. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
5. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1/2/3".
