# DEVIR — faz-oto-B4-p21 (B4 madde 6: P21 güvenlik + çıktı)
Main'de zaten vardı (yazılmadı): Pro araçlar → İzinler (parola + yazdır/düzenle/kopyala, `_PermissionsSheet`),
Belge bilgileri (meta düzenle), PDF/A-2b (görüntü + görünmez metin), Agresif sıkıştırma (DPI/kalite/gri),
Araçlar menüsü → Sıkıştır / Parola koy-kaldır / Paylaş. Kullanıcı dosyası: `_apply` belleğe yazar (5 geri al), kaydet = üzerine/kopya seçimi.
Yapılanlar (dal):
- m.1 meta temizle: `PdfDocPro.stripMeta` + Belge bilgileri levhasında düğme + onay (+ NUL bayt düzeltmesi)
- m.2 sıkıştır: nesne akışları (`PdfCrossReferenceType.crossReferenceStream`)
- m.3–4 agresif sıkıştırma/PDF-A ilerleme + Durdur (`renderJpegs(isCancelled:)`, `JobCancelled`), Araçlar ⋮ Yazdır
- PLAN §1 B4 satırı + §1.4 m.6, CIHAZ_TESTI "B4-P21", HAFIZA kaydı
Kalan: yinelenen font/görsel birleştirme, PdfEditorScreen emekliliği (PLAN §1.4 m.6).
Test: CI (`test/pdf_doc_pro_test.dart`, `test/pdf_tools_test.dart`). Cihaz: CIHAZ_TESTI B4-P21.
