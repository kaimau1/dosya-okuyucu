# pdfrx 2.12.0 yaması (Faz 48, 2026-11-08)

**1. değişiklik** — `lib/src/widgets/pdf_viewer.dart`:

```diff
   bool get _shouldBuildTextSemantics =>
-      widget.params.forceEnableTextSemantics || SemanticsBinding.instance.semanticsEnabled;
+      widget.params.forceEnableTextSemantics;
```

**Neden (ölçüm, `docs/perf/2026-11-48-pdfrx.md`):** erişilebilirlik hizmeti açıkken
(Xiaomi'de parola yöneticisi, otomatik tıklayıcı vb. bile açar) pdfrx görünen her sayfanın
her satırına `Focus` + `Semantics` düğümünü **her karede** kurar. `forceEnableTextSemantics:
true` ile taklit edildi: UI kare p99 3,3 → 5,8–6,3 ms (120 Hz bütçesi 8,3 ms), PDF-B PSS
412 → 496 MB. 2.4.8'deki kasmanın (HAFIZA 2026-11-03) 2.12'de kalan tek nedeni (N1).
`ExcludeSemantics` yetmez: bayrak `SemanticsBinding`'den okunuyor.

**Bedel:** ekran okuyucu PDF sayfa metnini satır satır okumaz; sayfa metni Okuma
görünümü (`ReaderScreen`) ve sesli okuma (TTS) ile erişilebilir kalır.

**Yükseltmede:** yeni sürümün `_shouldBuildTextSemantics`'ine bak; kapatma parametresi
geldiyse kopyayı sil, parametreyi `body.dart`/`pdf_editor/views.dart`'ta ver.

## 2. değişiklik (2026-11-13) — `repaintPageImages(pageNumber)`

`PdfViewerController.repaintPageImages` + `_PdfViewerState.repaintPageImages`: sayfanın önbellek
görüntülerini (önizleme + gerçek boy parça) **geometriye bakmadan** kirli işaretler.

**Neden (kök neden, cihaz bulgusu):** `_onDocumentEvent` → `makeCacheImageForPageDirty(n, page:)`
sayfanın boyu/dönüşü aynıysa görüntüyü "hâlâ geçerli" sayar (isteğe bağlı ölçüm için konmuş
kısayol). PDF Pro düzenlemesi sayfanın İÇERİĞİNİ değiştirir, geometrisini değil → `reloadPages`
olayı geliyor ama görüntü hiç yeniden çizilmiyordu: yazılan/silinen metin ekranda görünmüyordu.
Uygulama düzenleme kipindeyken belge olayını dinleyip bu yöntemi çağırır
(`lib/screens/viewer/pdf_pro_edit.dart`).

**Yükseltmede:** yukarı akış içerik değişimini geometriden ayırıyorsa (ya da sayfa başına
"yeniden çiz" API'si geldiyse) bu yöntem silinir.
