# DEVIR — B4 PDF Pro (dal faz-oto-B4-pdfpro)
Yapılan (dilim 1): P21 meta veri + P17 XFDF dışa/içe — commit "B4/P21+P17" (pdf_doc_pro.dart, pdf_tools/pro_actions+pro_views, 22_pdf_pro.dart, test/pdf_doc_pro_test.dart).
Önce bak bulgusu: parola koy/kaldır, izinler AES-256, PDF/A, sert sıkıştırma, sayfa sırala/boş/kırp, form oluştur, otomatik doldurma profili ZATEN VAR (pdf_tools/pro_actions.dart _openProTools).
Kalan (öneri sırası, önce az riskli):
1. P21 "bu kipte yazdır" (Printing.layoutPdf zaten içe alınmış, pdf_tools_screen.dart:16) + R6 kilit açma hatası var mı (kanıt: R6 belgeyle test).
2. P20 sayfa stüdyosu: pdf_reorder_screen.dart üstüne küçük resim ızgarası + geri alınabilir komutlar (_apply zaten geri alma tutar).
3. P18 düz PDF'te alan algılama (çizgi/kutu sezgisi), form+imza tek yüzey.
4. P16/P17 düzenleyici işleri (lib/screens/pdf_editor/layer*.dart) — görüntüleyici sıcak yoluna yakın; bayrakla.
5. P19 OCR görünmez katman (services/pdf/ocr_page_text.dart, pdf_ocr_text.dart incele).
6. P22/P22b — P22b görüntüleyici kabuğu (sıcak yol) → ayrı bayrak + A/B; PdfEditorScreen emekliliği (P21) en son.
Doğrulama: yalnız CI (gh run list -b faz-oto-B4-pdfpro -L 1). Cihaz maddeleri docs/CIHAZ_TESTI.md "B4 PDF Pro dilim 1".
