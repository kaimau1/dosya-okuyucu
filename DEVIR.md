# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1–3 main'de (P21 meta + P17 XFDF, R6 kilit açma, P20 stüdyo çekirdeği).
Dilim 4 (dalda, 2026-11-20):
- 9fb27fae stüdyoda araya boş sayfa (PdfTools.studioBlank = -1; yerinde yolda vurgu kalır).
- ae2c73b1 stüdyoda dosyadan sayfa ekle: plan sanal indeks (önce bu belge, sonra extra), applyPageStudio(extra:) _compose; studioKeepsAnnotations(pageCount:).
- Testler: test/pdf_tools_test.dart "applyPageStudio" grubu (+2 test).
Önce bak bulgusu: Faz 63 m.2 kırpma/boyut, m.3 Bates/sayfa no/filigran, m.4 yer imi düzenleme Pro araçlarda zaten var (pro_views _OutlineEditor, crop, fit_a4, numbering, stamp).
Atlanan: P21 "bu kipte yazdır" — viewer/doc_actions.dart _print (kabuk; anlam belirsiz) → sabah bakılacak.
Kalan (öneri sırası):
1. P20 artığı: stüdyoda seçileni yeni PDF'e çıkar / böl (kaydetme akışı pro_actions'ta), görselden/taramadan sayfa ekle, sürüklerken kenar kaydırma.
2. P18 düz PDF'te alan algılama (çizgi/kutu sezgisi), form+imza tek yüzey (form_create zaten var — önce bak).
3. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — sıcak yola yakın; bayrakla.
4. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
5. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1–4".
