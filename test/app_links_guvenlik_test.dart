import 'package:dosya_okuyucu/screens/app_links.dart';
import 'package:dosya_okuyucu/services/fm/hidden_vault.dart';
import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:flutter_test/flutter_test.dart';

/// G1.2 (B4): dışarıdan gelebilecek bağlantı/yol beyaz listesi.
void main() {
  group('isSafeLinkPath', () {
    test('ortak depolama yolları açılır', () {
      expect(isSafeLinkPath('/storage/emulated/0/Download/a.pdf'), isTrue);
      expect(isSafeLinkPath('/storage/1A2B-3C4D/DCIM/x.jpg'), isTrue);
    });
    test('../ geçen yol reddedilir', () {
      expect(isSafeLinkPath('/storage/emulated/0/../../../data/data/x/a'), isFalse);
      expect(isSafeLinkPath('/storage/emulated/0/Download/../a.pdf'), isFalse);
    });
    test('uygulamanın özel dizini reddedilir', () {
      expect(isSafeLinkPath('/data/data/com.dosyaokuyucu.dosya_okuyucu/files/x'), isFalse);
      expect(isSafeLinkPath('/data/user/0/com.dosyaokuyucu.dosya_okuyucu/shared_prefs/a.xml'), isFalse);
      expect(isSafeLinkPath('/storage/emulated/0/Android/data/x/files/a'), isFalse);
    });
    test('kasa klasörleri reddedilir', () {
      expect(isSafeLinkPath('/storage/emulated/0/${SecureVault.folderName}/index.dvk'), isFalse);
      expect(isSafeLinkPath('/storage/emulated/0/${HiddenVault.folderName}/a.jpg'), isFalse);
    });
    test('göreli ve boş yol reddedilir', () {
      expect(isSafeLinkPath(''), isFalse);
      expect(isSafeLinkPath('Download/a.pdf'), isFalse);
    });
  });

  group('isAllowedAppLink', () {
    test('bilinen şemalar kabul', () {
      expect(isAllowedAppLink('app:scan'), isTrue);
      expect(isAllowedAppLink('app:library'), isTrue);
      expect(isAllowedAppLink('file:/storage/emulated/0/Download/a.pdf'), isTrue);
      expect(isAllowedAppLink('davet:abc'), isTrue);
    });
    test('bilinmeyen şema / kötü yol reddedilir', () {
      expect(isAllowedAppLink('http://evil'), isFalse);
      expect(isAllowedAppLink('app:bilinmeyen'), isFalse);
      expect(isAllowedAppLink('file:/data/data/x/y'), isFalse);
      expect(isAllowedAppLink('file:../x'), isFalse);
    });
  });
}
