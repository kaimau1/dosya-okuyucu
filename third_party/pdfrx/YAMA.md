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

## 3. değişiklik (2026-11-13) — fırlatma aşamalı ölçümde kesilmesin

`interactive_viewer.dart`: `InteractiveViewerState.shiftPanInertia(delta)` — süren kaydırma
ataletinin tween uçlarını kaydırır (eğri/süre aynı). `pdf_viewer.dart`: düzen "sayfa boyları
değişti" dalında yeniden demirleme sırasında (`_reanchoringLayout`) `_goTo` süresiz çağrıda
animasyonu DURDURMAZ, ataleti aynı miktar kaydırır. Ayrıca `loadPagesProgressively` geri
çağırması kullanıcı sürükler/fırlatırken (`_isUserScrolling`, en çok 4 sn) bekler.

**Kök neden (kullanıcı: "1 GB resimli PDF akmıyor, parmağı bırakınca bir anda duruyor"):**
aşamalı ölçüm ~250 ms'de bir sayfa boylarını yayımlıyor → düzen değişiyor → `Legacy`
boy temsilcisi `goToPosition` → `_goTo` → `_stopInteractiveViewerAnimation()` → fırlatma kesiliyor.
Ölçüm aynı tek PDFium işçisini tuttuğu için kaydırırken gelen sayfaların çizimi de sırada bekliyordu.

**Yükseltmede:** yukarı akış yeniden demirlemede ataleti koruyorsa iki ek de silinir.

## 3. değişiklik (2026-11-22) — dokununca fırlatma durur

`interactive_viewer.dart` `_onPointerDown`: `widget.scrollPhysics != null` koşulu kalktı; süren
kaydırma ataleti her parmak değişinde `stopAllAnimations` ile durur. **Neden:** görüntüleyici `scrollPhysics` vermiyor (sürtünme `kPdfPanFriction`), bu yüzden kayan sayfaya basmak akışı durdurmuyordu (kullanıcı bulgusu). **Yükseltmede:** aynı koşulu yeni sürümde de kaldır.

## 4. değişiklik (R8/R9, 2026-11-28) — `pdfrxOnPageImagePainted` ve kaydırma sıcak yolu

1. `pdf_viewer.dart` üst düzey kanca (`pdfrxOnPageImagePainted`): sayfa görüntüsü (önizleme / net parça) tuvale çizilince çağrılır. **Neden:** `onDocumentLoadFinished` arka sayfaların ölçümünü da beklediği için ilk görünür sayfa anını göstermiyordu; açılış damgaları ve açılış köprüsü buradan kalkar.
2. `_relayoutPages`: `_layoutDirty` yoksa `widget.params.layoutPages` verilmiş olsa bile her kaydırma karesinde tüm sayfa düzenini yeniden kurup karşılaştırmaz (`didUpdateWidget` params değişince `_layoutDirty = true` yapar). `_updateLayout` yalnızca sayfa/görünüm/zoom değişince `_recalculateMetrics`, `_calcZoomStopTable` ve `_adjustBoundaryMargins` çalıştırır; `_paintPagesCustom` döngü dışında tek `Paint` nesnesi paylaşır. **Neden:** fırlatma/kaydırma sırasında her karede 320+ sayfalık düzen ve sınır yeniden hesaplanıyordu.
