# pdfrx_engine 0.9.1 — yama (PDF Pro Faz 52)

**Ne:** `PdfDocument.computeOnIdleDocument(callback, message)` — geri çağırmayı pdfrx'in
**PDFium işçi izolatında**, pdfrx'in kendi belge değişikliklerinde kullandığı **boşta bekçisiyle**
(`_PdfiumIdleTask`: o belgenin etkin çizimi yokken) koşturur. Taban sınıfta varsayılan
`UnsupportedError`; yalnız yerel (`_PdfDocumentPdfium`) uygulama var.

**Niye:** PDF Pro düzenleme köprüsü (`lib/services/pdf/pro/pdf_edit_bridge.dart`) görüntüleyicinin
AÇIK belgesinde sayfa nesnelerini değiştiriyor (PK1/PK2). Hazır API'ler yetmiyor:
- `useNativeDocumentHandle` işçiyi askıya alıp işi **ana izolatta** koşturur (UI donar; ayrıca
  ilerlemeli çizimin yarıda olduğu sayfaya dokunma riski).
- `PdfrxEntryFunctions.compute` işçide koşar ama **bekçisiz** (aynı sayfa o an çiziliyor olabilir —
  PDFium iş parçacığı/yeniden giriş güvenli değil).
- Bekçili `_computeWithArena` özel (private).

**Değişen dosyalar:** `lib/src/pdf_document.dart` (+1 yöntem, varsayılan gövdeli),
`lib/src/native/pdfrx_pdfium.dart` (+1 override, mevcut `_computeWithArena`'yı çağırır).
`pubspec.yaml`'dan `resolution: workspace` satırı silindi (depo dışı kullanım).

**Ne zaman kalkar:** yukarı akış bekçili bir "işçide belge işi" API'si açınca klasör SİLİNİR
(usta 4b) ve köprü o API'ye geçer.
