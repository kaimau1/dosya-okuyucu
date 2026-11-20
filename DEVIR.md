# DEVIR — faz-oto-B3-hiz (B3 Hız, yalnız P29 kodu)
- Yapıldı: P29 hata şeridi (tek commit). Büyük başlık iş değil (H4.2 kaldırıldı).
- Kök: ci/Extras.kt exitReasons low_memory/signaled arka plan kapatmasını "hata" sayıyordu; şerit açılış yarışı.
- Değişen: lib/services/crash_log.dart (isBackgroundKill, notifies, unseen), lib/screens/fm/dashboard/tools.dart (InboxEvent crash), dashboard_screen.dart, main.dart, ci/Extras.kt; lib/widgets/crash_notice.dart silindi; test/crash_log_test.dart.
- Sıradaki: CI yeşil → yürütücü birleştirir. P06 plan evresi + cihaz; P12b yalnız cihaz ölçümü.
- Doğrulama: CI verify (test/crash_log_test.dart).
