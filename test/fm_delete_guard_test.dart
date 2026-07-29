import 'package:dosya_okuyucu/screens/fm/entry_actions.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var (2026-07-29 sadakat denetimi, 2. tur — CRITICAL):**
/// Fotoğraflar ekranındaki "Temizle" kendi penceresinde *"çöp kutusuna
/// taşınacak, her gruptan en eski dosya korunur"* yazıp `deleteEntries`i
/// `confirm: false` ile çağırıyordu. `confirm` bayrağı ise TÜM onay bloğunu
/// atlıyordu — `!useTrash` dalı dahil. Yani Ayarlar > "Çöp kutusunu kullan"
/// kapalıyken 31 fotoğraf **kalıcı** siliniyor, çöp kutusu boş kalıyor ve
/// kullanıcı geri yükleyecek bir şey bulamıyordu.
///
/// Kural: **kalıcı silme onayı hiçbir koşulda atlanamaz.**
void main() {
  group('needsDeleteConfirm', () {
    test('KALICI silmede onay HER ZAMAN sorulur', () {
      // Dört kombinasyonun hepsinde: çöp kutusu kapalı → sor.
      for (final confirmSetting in [true, false]) {
        for (final askAllowed in [true, false]) {
          expect(
            needsDeleteConfirm(
              useTrash: false,
              confirmSetting: confirmSetting,
              askAllowed: askAllowed,
            ),
            isTrue,
            reason: 'kalıcı silme geri alınamaz; '
                'confirmSetting=$confirmSetting askAllowed=$askAllowed',
          );
        }
      }
    });

    test('çöp kutusu açıkken çağıranın kendi onayı yeter', () {
      expect(
        needsDeleteConfirm(
            useTrash: true, confirmSetting: true, askAllowed: false),
        isFalse,
        reason: 'ikinci pencere akışı boğar; dosya çöpten geri alınabilir',
      );
    });

    test('çöp kutusu açık + "silmeden önce sor" açık → sorulur', () {
      expect(
        needsDeleteConfirm(
            useTrash: true, confirmSetting: true, askAllowed: true),
        isTrue,
      );
    });

    test('çöp kutusu açık + kullanıcı sormayı kapatmış → sorulmaz', () {
      expect(
        needsDeleteConfirm(
            useTrash: true, confirmSetting: false, askAllowed: true),
        isFalse,
      );
    });
  });

  /// Düğme metni de ayarı okumak zorunda: çöp kutusu kapalıyken "çöpe taşı"
  /// yazan bir düğme, kullanıcıya geri alabileceğini söyleyip dosyayı kalıcı
  /// silmek demekti.
  group('deleteActionText', () {
    test('çöp kutusu açıkken "çöpe taşı"', () {
      expect(deleteActionText(useTrash: true, what: '12 dosyayı'),
          '12 dosyayı çöpe taşı');
    });

    test('çöp kutusu kapalıyken "kalıcı sil"', () {
      expect(deleteActionText(useTrash: false, what: '12 dosyayı'),
          '12 dosyayı kalıcı sil');
    });

    test('metin "çöp" sözünü ASLA kalıcı silmede kullanmaz', () {
      expect(deleteActionText(useTrash: false, what: '3 kopyayı'),
          isNot(contains('çöp')));
    });
  });
}
