# DEVIR — faz-oto-K15-iap (K15 tek uygulama + tek seferlik satın alım)
- f17249c5 satın alım: `lib/services/pro_purchase.dart` (ürün `pro_unlock`), `Edition.tier/proActive` + `ProUnlock.owned` (lib/core/edition.dart), Pro sayfası Satın al/Geri yükle (lib/widgets/pro_gate.dart), Ayarlar Pro satırı, main: loadCached + StartupQueue `pro-dogrula`; in_app_purchase 3.3.1 + _android 0.5.5; BILLING üç izin tabanında; test/pro_purchase_test.dart.
- 8d81e64c Lite diyeti geri: ci/prepare_android.sh §11b kaldırıldı; build-apk.yml Lite bütçe 91 MB, libmpv + LiteRT Lite'ta zorunlu; PlayerEngine.available / ImageEnhance.upscaleAvailable = proActive.
- docs: PLAN §3 m.6/m.7, B7b satırı, HAFIZA, CIHAZ_TESTI K15, yayin_rehberi, izin_beyanlari.
- Sıradaki: CI yeşil → yürütücü birleştirir (bu dosyayı siler). İlk Lite [apk] sonrası bütçeyi ölçülen + %3'e indir.
- Doğrulanamayan: gerçek Play satın alımı (👤 Play Console `pro_unlock`), cihaz akışı (CIHAZ_TESTI K15).
