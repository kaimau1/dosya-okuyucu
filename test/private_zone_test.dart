import 'package:dosya_okuyucu/core/private_zone.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:flutter_test/flutter_test.dart';

/// Güvenlik G10.3 + G2.8: kasa dosyası AI'ya ve açılış geçmişine girmez.
void main() {
  test('kasa klasör adı SecureVault ile aynı', () {
    expect(PrivateZone.vaultFolder, SecureVault.folderName);
  });

  test('kasa ve düz açma önbelleği gizli yol', () {
    expect(PrivateZone.isPrivatePath('/storage/emulated/0/.DosyaOkuyucuKasa/a.dvk'),
        isTrue);
    expect(
        PrivateZone.isPrivatePath(
            '/data/user/0/com.x/cache/vault_open/rapor.pdf'),
        isTrue);
    expect(PrivateZone.isPrivatePath('/storage/emulated/0/Download/rapor.pdf'),
        isFalse);
    expect(PrivateZone.isPrivatePath('/storage/emulated/0/vault_opener/a.pdf'),
        isFalse);
  });

  test('gizli bölge iç içe ve hata sonrası kapanır', () async {
    expect(PrivateZone.active, isFalse);
    await PrivateZone.run(() async {
      expect(PrivateZone.active, isTrue);
      await PrivateZone.run(() async => expect(PrivateZone.active, isTrue));
      expect(PrivateZone.active, isTrue);
    });
    expect(PrivateZone.active, isFalse);
    await expectLater(
        PrivateZone.run<void>(() async => throw StateError('x')), throwsStateError);
    expect(PrivateZone.active, isFalse);
  });

  test('AI kapsamı kasa klasörlerine gizliler açıkken bile girmez', () {
    const scope = AiScope(settings: AiScopeSettings(includeHidden: true));
    expect(scope.allowsDir('/storage/emulated/0/.DosyaOkuyucuKasa'), isFalse);
    expect(scope.allowsDir('/data/user/0/com.x/cache/vault_open'), isFalse);
    expect(scope.allowsDir('/storage/emulated/0/.gizli'), isTrue);
  });
}
