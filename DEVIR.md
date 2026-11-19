# DEVIR — U2 tek akıllı şerit (dal faz-oto-U2-tek-serit)

- Yapıldı: `lib/widgets/fm/recent_strip.dart` iki sekme (Geçmiş | Yeniler) → tek şerit;
  sıra `mergeStripItems` (24 sa içinde gelen açılmamış yeniler öne, ≤ limit-3; gerisi zamana göre;
  yol tekil; açıldıktan sonra değişmemiş yeni = son açılan). "Yeni" etiketi / ince saat işareti.
  Başlık "Son dosyalar" + "Yeniler" / "Geçmiş" düğmeleri. Dizgeler `8_enum_aih.dart`.
- Test: `test/recent_strip_test.dart` (mergeStripItems 4 test).
- Göç: `home_recent_tab` artık okunmuyor, silinmedi (geri alınabilir).
- Hız: ilk karede disk işi yok (FreshCache.last bellekten; warm + scan post-frame, izolat).
- Sıradaki: CI yeşil → HAFIZA + PLAN satırı + CIHAZ_TESTI. Cihaz A/B yapılmadı (kurulum onayı).
