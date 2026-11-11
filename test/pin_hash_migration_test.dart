import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/services/fm/folder_lock.dart';
import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// **G3.1 + G3.3 (2026-11-11) göçleri**: eski kayıt → yeni kayıt.
/// - Kilit PIN özeti `v1:` (sabit tuzlu FNV) → `v2:` (tuzlu PBKDF2).
/// - Kasa başlığı az turlu → doğru PIN'le hedef turla yeniden sarılır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FolderLock.targetIterations = 1000;
    SecureVault.targetIterations = 1000;
  });

  group('kilit PIN özeti', () {
    test('v2: doğru PIN tutar, yanlış tutmaz, tuz her seferinde farklı',
        () async {
      final a = await FolderLock.hashPinSecure('1234');
      final b = await FolderLock.hashPinSecure('1234');
      expect(a, startsWith('v2:1000:'));
      expect(a, isNot(b), reason: 'rastgele tuz');
      expect(await FolderLock.verifyAsync('1234', a), isTrue);
      expect(await FolderLock.verifyAsync('1235', a), isFalse);
      expect(await FolderLock.verifyAsync('1234', ''), isFalse);
      expect(await FolderLock.verifyAsync('1234', 'v2:bozuk'), isFalse);
      expect(FolderLock.needsUpgrade(a), isFalse);
    });

    test('eski v1 özet doğrulanır ve yükseltme ister', () async {
      final v1 = FolderLock.hashPin('1234');
      expect(await FolderLock.verifyAsync('1234', v1), isTrue);
      expect(await FolderLock.verifyAsync('9999', v1), isFalse);
      expect(FolderLock.needsUpgrade(v1), isTrue);
    });

    test('az turlu v2 yükseltme ister', () async {
      final h = await FolderLock.hashPinSecure('1234');
      FolderLock.targetIterations = 2000;
      expect(FolderLock.needsUpgrade(h), isTrue);
    });

    test('AppState: v1 kayıt doğru PIN\'le v2\'ye çevrilir, yanlışta dokunulmaz',
        () async {
      final v1 = FolderLock.hashPin('2468');
      SharedPreferences.setMockInitialValues(
          {'fm_lock_pin': v1, 'app_lock_on': true});
      final state = AppState();
      await state.init();
      expect(await state.verifyLockPin('1111'), isFalse);
      expect(state.fmLockPinHash, v1, reason: 'yanlış PIN göç tetiklemez');
      expect(await state.verifyLockPin('2468'), isTrue);
      expect(state.fmLockPinHash, startsWith('v2:'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fm_lock_pin'), state.fmLockPinHash);
      // Yeni biçimle yine açılır.
      expect(await state.verifyLockPin('2468'), isTrue);
      expect(await state.verifyLockPin('1111'), isFalse);
    });

    test('yeni kurulan PIN doğrudan v2', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.init();
      await state.setFmLockPin('1357');
      expect(state.fmLockPinHash, startsWith('v2:'));
      expect(await state.verifyLockPin('1357'), isTrue);
    });
  });

  group('kasa başlığı turu', () {
    late Directory tmp;
    final vault = SecureVault.instance;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('vault_iter');
      SecureVault.debugRoot = p.join(tmp.path, '.kasa');
    });
    tearDown(() {
      SecureVault.debugRoot = null;
      vault.debugReset();
      tmp.deleteSync(recursive: true);
    });

    test('eski (az turlu) başlık açılır → yeniden sarılır → yeni turla açılır',
        () async {
      await vault.create('2468');
      await vault.lock();
      expect(await vault.debugMetaIterations(), 1000);

      SecureVault.targetIterations = 3000;
      expect(await vault.unlockWithPin('0000'), isFalse);
      expect(await vault.debugMetaIterations(), 1000,
          reason: 'yanlış PIN başlığa dokunmaz');
      expect(await vault.unlockWithPin('2468'), isTrue);
      expect(await vault.debugMetaIterations(), 3000);

      await vault.lock();
      expect(await vault.unlockWithPin('2468'), isTrue);
      expect(await vault.debugMetaIterations(), 3000);
      expect(File(p.join(SecureVault.debugRoot!, 'vault.json.tmp')).existsSync(),
          isFalse);
    });
  });
}
