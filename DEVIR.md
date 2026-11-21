# DEVIR — faz-oto-B4-metin (B4 dilim 1, P16 metin) — 2026-11-21

Limit freni (%93) ile durdu. Kod 4 madde yazıldı, CI HİÇ koşmadı/beklenmedi.

Yapılanlar (her biri ayrı commit):
1. Font seçici (Faz 56 m.7): PdfStyleSpan.font `doc:`/`pkg:`, yazıcı grup anahtarı, PdfFallbackFonts.choices/keyBits/packageFor, showPdfFontSheet, rozet dokunuşu.
2. Metne bağlantı (Faz 58 m.7): PdfAnnotChange.link/update(uri), PdfEditBridge.links, PdfLinkTarget, kayıtta PdfLinkDests (`#page=N` → /Dest), "Bağlantı" çipi.
3. Taşma uyarısı (Faz 57 m.3): live.collision, liveOverflow(shrink/push/widen), _pushBelow bitişte ayrı adım.
4. Bütçe dokun→imleç (Faz 57 m.10) + test/pdf_pro/pdf_pro_text_tools_test.dart (hepsini test eder).

Yerelde analyze/test YOK — derleme hatası olabilir. Şüpheli yerler:
- pdf_mutate.dart `_links`: FPDFLink_GetAction/FPDFAction_GetDest/GetURIPath imzaları (pdfium_dart 0.4.1).
- pdf_typeset.dart: siblings[(fam, …)] fam artık String? (Map[] Object? alır, sorun beklenmez).
- Testte bağlantı/itme beklentileri (külliyat geometrisi) tahmin; kırmızıysa beklentiyi değil kökü incele.

Sıradaki adım: `gh run list -b faz-oto-B4-metin -L 1` → sonucu oku, kırmızıysa `--log-failed | tail -n 60`.
Sonra: kasma-kontrol (biçim çubuğuna uyarı satırı + rozet InkWell), PLAN §1.4 dilim 1 sil + B4 satırı,
HAFIZA kaydı (KÖK: PDFium /Dest yazamıyor → `#page=N` + kayıtta /Dest), CIHAZ_TESTI maddeleri.
Yapılmadı: cihaz fontları (/system/fonts) seçicide yok; başka sayfanın belge fontu yok (yalnız aynı sayfa).
