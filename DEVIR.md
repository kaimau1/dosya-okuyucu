# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1–4 main'de (P21 meta + P17 XFDF, R6 kilit açma, P20 stüdyo çekirdeği + boş/dosyadan sayfa ekle).
Dilim 5 (dalda, 2026-11-20):
- 67a8e190 stüdyoda seçilenleri yeni PDF'e çıkar / seçilenlerden böl (PdfStudioResult.newFiles, PdfTools.studioSplit),
  "Sayfa ekle" menüsü (dosya / görsel A4 / tarama → _insertPdf), sürüklerken kenarda kendiliğinden kaydırma.
- Test: test/pdf_tools_test.dart "studioSplit …" (+1).
P20 bitti (kasma-kontrol: hücre ağacı değişmedi, yalnız sürükleme geri çağrıları; ölçüm C2'de).
Atlanan: P21 "bu kipte yazdır" — viewer/doc_actions.dart _print (kabuk; anlam belirsiz) → sabah bakılacak.
Kalan (öneri sırası):
1. P18 düz PDF'te alan algılama (çizgi/kutu sezgisi), form+imza tek yüzey (pro_actions _createForm + PdfRegionScreen field kipi zaten var — önce bak).
2. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — sıcak yola yakın; bayrakla.
3. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
4. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1–5".
