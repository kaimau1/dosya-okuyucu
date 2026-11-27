# DEVIR — faz-oto-B20-kalem
- Yapıldı: ortak kalem mantığı `lib/core/edit/ink_logic.dart`, tepsi `lib/widgets/ink/pen_tray.dart`;
  PDF kalem ekranı (`lib/screens/pdf_ink/*`) ve fotoğraf İşaretle (`image_edit_screen*`) tepsiye geçti.
- PDF `eraseMarksAt(partial:)` alan silgisi; fotoğraf silgisi gövde isabeti + alan kipi.
- Testler: `test/ink_logic_test.dart` (saf), `test/pdf_ink_screen_test.dart` (⇄ + ters uç).
- Şu an: CI bekleniyor. Kırmızıysa yalnız hatalı parçanın logu.
- Cihaz: docs/CIHAZ_TESTI.md B20. Birleştirmeden önce bu dosya silinir.
