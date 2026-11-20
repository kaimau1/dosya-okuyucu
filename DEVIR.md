# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1–6 main'de; dilim 7 (0317efd5, çizgi/kutu sezgisi) ve dilim 8 dalda.
Dilim 8 (2026-11-20):
- P18 form+imza tek ekran ÇEKİRDEĞİ (25bf5b28): pdf_form_screen imza alanını imzalar (kayıtlı imza/pano),
  kayıtta fill → `PdfTools.stampStrokes(rawSpace: true)` alan kutusuna. Test: test/pdf_form_screen_test.dart.
- P19 m.1 (ed191849): `PdfTools.addTextLayer(+InBackground)` + Pro araç `ocr_layer` (pro_actions `_ocrLayer/_ocrLines`).
  Test: test/pdf_tools_test.dart "addTextLayer".
Atlanan: P21 "bu kipte yazdır" — anlam belirsiz → sabah bakılacak. P16/P17 — editör yüzeyi sıcak yola yakın, bayrak + A/B.
Kalan (öneri sırası):
1. P18: serbest imza yerleştirmeyi (PdfSignScreen._pageArea) form ekranına sekme/kip olarak taşı; pdf_selection
   `_signPdf` → form ekranı; PdfSignScreen emekli (pro_actions:1032 de çağırıyor).
2. P19: döndürülmüş sayfada katman (stampTransform ile), renkli zeminde satır düzenleme (m.2), m.3.
3. P16/P17 (lib/screens/pdf_editor/layer*.dart) — bayrakla.
4. P22/P22b, PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1–8".
