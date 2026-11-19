# DEVIR — B13 Deneyim hissi (dal faz-oto-B13-his)

## Yapılanlar
- m.3 dokunuş haritası (713177dd): AppHaptics.longPress/drop/warning; yeniden sıralama, sürükleme, sürükleyerek seçim, kelime seçimi, bırakma hedefleri; kopyalanabilir hata bildirimi = uyarı. Bekçi app_haptics_test.
- m.5 geri al: trashWithUndo ortak uç; Önemli kategori silme çöp açıksa çöpe + Geri al (eskiden ayardan bağımsız kalıcı); kategori yeniden adlandırma Geri al. Bekçi test/undo_paths_guard_test.dart.
- m.2 öngörülü geri: H6.6'da yapılmış (page_transitions _PredictiveBackPreview; levhalar rota → geri hareketi kapatır). Yeni iş yok.
- m.9 erişilebilirlik: Faz 16 test/a11y_guidelines_test.dart 10 ana ekranda (tap target, etiket, kontrast, 2× taşma) zaten. Pano (DashboardScreen) Ahem yazı tipiyle 360 dp'de taşıdığı için dışarıda (tablet_h9_test notu).

## Sıradaki
- m.6 otomatik kayıt kapsamı (viewer/pending_save.dart), m.8 klavye viewInsets testi, m.4 aşamalı açılış (Excel/Slayt), m.7 hareket eşitliği, m.1 Office/PDF açılış geçişi (H1.4 cihaz ölçümüne bağlı).

## Doğrulama
CI verify (yerel test yok).
