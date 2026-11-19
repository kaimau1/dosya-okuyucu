# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Dilim 1 (P21 meta veri + P17 XFDF) main'de (952a4dbc).
Dilim 2 (dalda): P21 R6 kilit açma — commit "B4/P21: AES-256 R6 kilit açma" (7970f565).
- Kök: Syncfusion R6 belgede removePassword sayfasız çıktı (HAFIZA docs/hafiza/2026-11.md:746 tezgâh bulgusu).
- Çözüm: lib/services/pdf_tools.dart removePasswordInBackground → sayfa sayısı denetimi, eksikse removePasswordPdfium (pdfrx encodePdf(removeSecurity: true)).
- setPassword/setPermissions artık aesx256BitRevision6. Test: test/pdf_pro/pdf_unlock_r6_test.dart.
Atlanan: P21 "bu kipte yazdır" — lib/screens/viewer/doc_actions.dart _print (görüntüleyici kabuğu, bu işçinin dosya sınırı dışında; anlam belirsiz: gece/sepya kipiyle yazdırma mı?) → kapsam kararı sabah bakılacak.
Kalan (öneri sırası):
1. P20 sayfa stüdyosu: yeni dosya (pdf_tools/ altında) küçük resim ızgarası + çoklu seçim + döndür/sil/çoğalt + geri al; pdf_reorder_screen.dart (ListView, itemExtent 112, 72 DPI) örnek. Izgara → kasma-kontrol + C2 A/B.
2. P18 düz PDF'te alan algılama (çizgi/kutu sezgisi), form+imza tek yüzey.
3. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — sıcak yola yakın; bayrakla.
4. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
5. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz: docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1/2".
