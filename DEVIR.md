# DEVIR — faz-oto-B4-p20ust (B4 P20 kalan: üst/alt bilgi + numara)

- Yapılan: 5c71efd5'in geri aldığı arayüz (Pro "Gelişmiş numaralandırma": üst/alt bilgi, numara anahtarı, Kaldır;
  basit numara yolu emekli) geri getirildi; katman (OCG) yolu YERİNE işaretli blok:
  `lib/services/pdf/pdf_header_footer.dart` (markHeaderFooter / stripHeaderFooter / hasMarkedHeaderFooter),
  `PdfDocPro.addNumbering` `page.graphics` ile çizip işaretler.
- Kök neden: Syncfusion `PdfLayer.createGraphics` tek akışı sayfalar arasında paylaşıyor (pdf_layer.dart:95-130,
  `_graphics` katman başına) → katmanı silmek 2. sayfayı bozuyordu.
- Veri güvenliği testi: `test/pdf_doc_pro_test.dart` — 4 sayfa farklı içerik (metin içinde "EMC BDC (x)"),
  ekle → kaldır ve ekle → düzenle → kaldır sonrası sayfa başına metin + q/Q dışı içerik akışları birebir.
- Sıradaki: CI yeşil → yürütücü birleştirir (DEVIR silinir). Cihaz: docs/CIHAZ_TESTI.md B4-P20ust.
