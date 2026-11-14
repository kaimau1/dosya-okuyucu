# DEVIR — P10 Ferrari H9 tablet (dal faz-oto-P10-tablet)

- Tablet ölçütü: `lib/core/tablet.dart` isTabletWide (≥ 840 dp VE kısa kenar ≥ 600) — telefon yatayda false.
- Test: `test/tablet_h9_test.dart` (1280×800 ↔ 800×1280, dpr 1). Yerel test yok — CI.
- [x] H9.2 gezgin: liste sütunu GlobalKey (kök neden: browser_screen.dart build'de `if (wide) Row(... Expanded(listColumn)) else listColumn` anahtarsız yer değiştiriyor → ScrollPosition yeniden kuruluyor, PageStorageKey yok → 0).
- [ ] H9.1 ana ekran gezinme sütunu (home_screen, IndexedStack sekmeleri yeniden kullanılır)
- [ ] H9.3 kalem (pdf_ink input.dart: avuç dokunuşu `_pointers>1` ile darbeyi iptal ediyor)
- [ ] H9.4 LargeTextView satır sınırı (öteki metin görünümleri zaten 820/720)
- [ ] H9.5 çift bölme sürükle-bırak; başka uygulamaya bırakma yok (paket gerekir)
- Sıradaki: H9.1.
