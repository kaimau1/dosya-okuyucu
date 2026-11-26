# DEVIR — faz-oto-B4-p21 (B4 madde 6: P21 güvenlik + çıktı)
Main'de zaten vardı (yazılmadı): Pro araçlar → İzinler (parola + yazdır/düzenle/kopyala, `_PermissionsSheet`),
Belge bilgileri (meta düzenle), PDF/A-2b (görüntü + görünmez metin), Agresif sıkıştırma (DPI/kalite/gri),
Araçlar menüsü → Sıkıştır / Parola koy-kaldır / Paylaş. Kullanıcı dosyası: `_apply` belleğe yazar (5 geri al), kaydet = üzerine/kopya seçimi.
Yapılanlar:
- m.1 meta temizle: `PdfDocPro.stripMeta` (Info boş + XMP yeniden kurulur + baştan yazım) + Belge bilgileri levhasında düğme + onay
- m.2 sıkıştır: nesne akışları (`PdfCrossReferenceType.crossReferenceStream`)
Sıradaki: m.3 ağır işlerde (agresif sıkıştırma, PDF/A) ilerleme + Durdur; m.4 araçlar menüsünde Yazdır.
Bilerek yapılmadı: yinelenen görsel/font birleştirme (düşük seviye yeniden yazım ister), ayrı e-posta kısayolu (Paylaş levhası e-postayı içerir),
PdfEditorScreen emekliliği (⋮ "Eski düzenleyici" hâlâ menüde — ayrı dilim).
Test: CI (`test/pdf_doc_pro_test.dart`, `test/pdf_tools_test.dart`).
