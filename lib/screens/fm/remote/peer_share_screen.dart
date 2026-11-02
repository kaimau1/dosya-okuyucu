/// Eski "Yakındaki cihaz" ekranı (Gönder/Al sekmeli) ve "QR ile paylaş"
/// ekranı 2026-10-29'da tek **Yakındakiler** ekranında birleşti
/// (`nearby_screen.dart`). Paylaş düğmelerinin içe aktardığı
/// [showShareChoice] (2026-11-02'den beri `share_choice.dart`) buradan da
/// görünür kalsın diye yeniden dışa aktarılır.
library;

export 'nearby_screen.dart' show NearbyScreen;
export 'share_choice.dart' show showShareChoice;
