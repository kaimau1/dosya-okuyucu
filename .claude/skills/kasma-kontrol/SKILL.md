---
name: kasma-kontrol
description: Liste/ızgaraya, görüntüleyici kabuğuna (PDF/Office/görsel/video) ya da ana ekrana GÖRÜNÜR yeni alan, kip veya sarmalayıcı eklerken push'tan önce uygula (kasma kontrol listesi, 8 madde).
---

# Kasma kontrol listesi

"not" projesindeki `kasma-kontrol` skill'inin (2026-11-09) dosya okuyucuya uyarlanmış hâli
(2026-11-14). Maddeler bu deponun kendi kuralları ve HAFIZA'daki gerçek kök nedenlerinden:
PERFORMANS KORUMA ANAYASASI (`docs/GELISTIRME_PLANI.md`), `docs/FERRARI_PLANI.md` §0.6 bekçileri,
HAFIZA 2026-11-13/14 tuzakları.

Görünür yeni alan, kip ya da sarmalayıcı eklerken, push'tan ÖNCE:
1. **Liste/ızgara hücresi:** `const` + `RepaintBoundary` + sabit `itemExtent`/`mainAxisExtent`;
   hücrede `saveLayer`/`Opacity`/`BackdropFilter`/geniş `ShaderMask` YASAK (simgeler tek
   `CustomPainter` deseni korunur). Görsel gösteren yüzey `cacheWidth = boyut×dpr`.
2. **Dar yeniden kurulum:** kökte `watch` yok (`test/root_rebuild_test.dart`); yerel UI durumu
   (aç/kapa, seçim, hover) için ekranın KÖK `setState`'i değil, alt widget'ın kendi durumu ya da
   `ValueNotifier` + dar `ValueListenableBuilder`. Her build'de yeni nesne (map, liste, kapanış)
   üretip önbellek/eşitlik anahtarına koyma.
3. **Ağaç şekli sabit:** eklenen sarmalayıcı (Stack, KeyedSubtree, TapRegion…) koşula göre
   gelip gitmesin (koşulda `SizedBox.shrink` tut) — şekil değişince alt ağaç ve görüntüleyici
   (pdfrx) sıfırdan kurulur.
4. **Görüntüleyici payı sabit:** okuma alanının üst/alt payını değiştiren her şey (durum çubuğu,
   klavye, `SafeArea`, çubuk gizleme) pdfrx'in sayfayı yeniden ortalamasına/başa atlamasına yol
   açar → `maintainBottomViewPadding: true`; durum çubuğu gizlenirken eski boy tutulur
   (`OfficeShell._statusHold`); `immersiveSticky` değil `manual + bottom` (HAFIZA 2026-11-13,
   2026-11-14 H3.6).
5. **Yerleşim sırasında `setState` yok:** pdfrx matrisi / kaydırma ölçüsü yerleşim sırasında
   değişebilir → dinleyiciden doğrudan `setState` değil, kare sonuna ertele (`_matrixSetState`,
   `fm_large_title.dart` deseni).
6. **Kaydırılan içerikle aynı Column/Row'daki bir şeyin BOYUNU animasyonla değiştirme**
   (yükseklik, `AnimatedSize`, `AnimatedContainer` boyu): içerik her karede yeniden dizilir. Boy
   TEK ADIMDA değişsin, hareket yalnız boyamada (`Transform`/`FractionalTranslation`/`Opacity`
   — liste hücresi dışında). ("not"ta kasmanın kök nedeni buydu.)
7. **Boşta 0 kare:** yeni `AnimationController`/`Timer.periodic` görünmezken durur
   (`TickerMode`, yaşam döngüsü); süre/eğri `Motion.of(context, …)` ("animasyonları kaldır"da 0 —
   `test/motion_tokens_test.dart`); widget'ta `Future.delayed` yok (iptal edilebilir `Timer`,
   `dispose`'ta iptal). Ağır iş (ayrıştırma, görüntü, PDF) ana iş parçacığında değil
   (`compute`/izolat — `test/perf_offload_test.dart`); açılışta yeni iş yok (`StartupQueue`).
8. **Doğrula:** ilgili cihazsız test yoksa yaz ("girdisi değişmeyen hücre/çubuk yeniden
   kurulmuyor" ya da `test/perf/*_perf_test.dart` senaryosu); CI'da `root_rebuild_test`,
   `design_tokens_test`, `motion_tokens_test`, `test/perf/*` kırmızıysa birleştirme yok. Şüphede
   ve ÖLÇÜM KAPISI kapsamındaysa `ab-olcum` ile cihazda ölç. Ölçmeden "düzeldi" deme.

Gerekçe ("not", kullanıcı 2026-11-10): "son güncellemelerden sonra kasma yeniden başladı…
zamanında kontrol et" — kök neden iki gün önce eklenen bir boy animasyonuydu (madde 6); testler
yeşildi, kimse ölçmemişti.
