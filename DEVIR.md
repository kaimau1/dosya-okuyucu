# DEVIR — B2 Akıllı düzen 2.0 kullanım (dal faz-oto-B2-duzen-kullanim)

## Dilim 1 (yerel, 2026-11-19) — bitti, CI yeşil (koşu 44480874761, a18abae6)
- Tuzak: `SmartTaxonomy.sensitive` zaten vardı (kullanılmıyordu) — ikinci tanım analyze'ı kırdı, kaldırıldı.
- m.1 Ayıkla 2 en net kare (f806672e): `image_hash.dart` laplacianVariance + sharpnessTier,
  `MediaFingerprint.sharpness` (128x128, oturum önbelleği, yalnız gruptakiler),
  `SimilarFinder.orderBest`; Ayıkla AppBar "Benzer kareler" (scope `smart_photos`).
  Test: `test/similar_best_frame_test.dart`.
- m.5 hassas kilit (8d9f053c): `SmartTaxonomy.sensitive`; `smart_sort_screen._openList`
  listede hassas kayıt varsa PIN (PIN var + uygulama kilidi kapalı, oturumda bir kez).
- m.3 düzeltme → tezgâh örneği (f43a78b5): `smart_fix_sheet._benchSample`.

## Kalan (dilim 2+)
- Ayıkla 2: AI `score` (net/gözler açık/kadraj), WhatsApp iletilen kopyalar, ekran görüntüsü yaşı.
- Kontrol listeleri (kaydedilebilir; ✓/✗ + güven; PDF rapor).
- Taşıma kuralları (varsayılan KAPALI, ilk sefer onay, geri alınabilir).
- Decisions kalanları: tarayıcı sayfa kalitesi, akıllı temizlik doğrulama, sohbet yönlendirici,
  PDF imza alanı toplu denetim, galeri kategori süzgeci.

## Doğrulama
CI `verify` (yerel test yok). Cihaz: `docs/CIHAZ_TESTI.md` B2 maddesi.
