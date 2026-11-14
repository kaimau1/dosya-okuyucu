# DEVIR — P07 (dal faz-oto-P07-artik)
- H1.4 son sayfa görüntüsü: `lib/services/pdf/pdf_last_view.dart` (SHA-1 ad + sayfa, ≤200 KB JPEG, 50 belge,
  kasa/parolalı yok, belge sonradan değiştiyse bayat). Kapanışta `viewer_screen.dart` `_captureLastView`
  (PopScope didPop) → pdfium çizer, `compute` kodlar. Köprü `pdf_open_bridge.dart` `page:` → önce son görüntü,
  yoksa (sayfa 1) kapak. Test `test/pdf_last_view_test.dart`.
- Sıradaki: H8.5 döndür (90°) + kareyi fotoğraf kaydet (video_trim_screen, video_edit, MediaTranscode.kt).
- Cihaz: telefon bağlı değil → CIHAZ_TESTI "Ferrari H1.4 / H8.5"; PDF kabuğuna dokunuldu → A/B gerekir.
