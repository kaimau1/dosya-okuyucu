# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1–5 main'de (P21 meta + P17 XFDF, R6 kilit açma, P20 sayfa stüdyosu tamamı).
Dilim 6 (dalda, 2026-11-20):
- P18 düz PDF'te alan algılama: `PdfFormPro.detectFields` (services/pdf_form_pro.dart; glif tabanlı
  `___`/`.....`/`☐`, etiket = alan adı), arayüz pro_actions `_detectFields` ("Form alanı ekle" levhası
  → "Doldurulacak yerleri bul" → PdfRegionScreen initial ile gözden geçir). Test: test/pdf_form_pro_test.dart "alan algılama …".
- Önce bakıldı: form oluşturma (`_createForm` + PdfRegionMode.field) ve otomatik doldurma profili zaten vardı.
Atlanan: P21 "bu kipte yazdır" — viewer/doc_actions.dart _print (kabuk; anlam belirsiz) → sabah bakılacak.
Kalan (öneri sırası):
1. P18 kalanı: form+imza tek yüzey (pdf_form_screen + pdf_sign_screen birleşimi, Faz 61 m.6 — editör yüzeyi,
   büyük iş); vektör çizgi/kutu sezgisi (pdf_objects yol nesneleri); akıllı karartma önerisi (Faz 65/3).
2. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — sıcak yola yakın; bayrakla.
3. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
4. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1–6".
