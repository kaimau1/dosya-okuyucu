import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/hidden_vault.dart';
import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:dosya_okuyucu/widgets/fm/pin_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **Tek Kasa göçü** (2026-10-21, Faz 2): şifresiz gizli dosyalar şifreli
/// kasaya taşınır. Kullanıcı verisine dokunan tek göç — kopyala → doğrula →
/// sil sırası, yarıda kesilme ve geri çıkarma burada kilitli.
void main() {
  late Directory root;
  final vault = SecureVault.instance;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('vault_merge');
    FmEnv.primaryRoot = root.path;
    HiddenVault.debugRoot = root.path;
    SecureVault.debugRoot = p.join(root.path, '.kasa');
    await vault.create('2468');
  });

  tearDown(() {
    HiddenVault.debugRoot = null;
    SecureVault.debugRoot = null;
    vault.debugReset();
    root.deleteSync(recursive: true);
  });

  File write(String rel, String content) =>
      File(p.join(root.path, rel))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  test('gizli dosya şifreli kasaya taşınır, geri çıkınca aynı yerinde',
      () async {
    final f = write('Belgeler/kimlik.pdf', 'TC-gizli-icerik');
    await HiddenVault.hide([f.path]);
    expect(f.existsSync(), isFalse);

    final r = await vault.importHidden();
    expect(r.succeeded, 1);
    expect(r.errors, isEmpty);
    expect(await HiddenVault.list(), isEmpty, reason: 'gizli dizin boşaldı');
    expect(vault.items.single.name, 'kimlik.pdf');
    expect(vault.items.single.originalDir, p.join(root.path, 'Belgeler'));
    // Kasa klasöründe düz içerik yok.
    for (final e in Directory(vault.dir).listSync()) {
      if (e is File && e.path.endsWith('.dvk')) {
        expect(e.readAsStringSync(encoding: latin1),
            isNot(contains('TC-gizli')));
      }
    }

    final back = await vault.restore(vault.items.single);
    expect(back, f.path);
    expect(File(back).readAsStringSync(), 'TC-gizli-icerik');
  });

  test('gizlenmiş klasör: alt klasörleriyle taşınır ve ağacına döner',
      () async {
    write('Proje/a.txt', 'A');
    write('Proje/alt/b.txt', 'B');
    await HiddenVault.hide([p.join(root.path, 'Proje')]);

    final r = await vault.importHidden();
    expect(r.succeeded, 2);
    expect(await HiddenVault.list(), isEmpty);
    final dirs = {for (final i in vault.items) i.name: i.originalDir};
    expect(dirs['a.txt'], p.join(root.path, 'Proje'));
    expect(dirs['b.txt'], p.join(root.path, 'Proje', 'alt'));

    for (final item in List.of(vault.items)) {
      await vault.restore(item);
    }
    expect(File(p.join(root.path, 'Proje', 'alt', 'b.txt')).readAsStringSync(),
        'B');
  });

  test('yarıda kesilen göç tekrarlanınca kopya üretmez, kalan devam eder',
      () async {
    final a = write('x/a.txt', 'birinci');
    final b = write('x/b.txt', 'ikinci');
    await HiddenVault.hide([a.path, b.path]);

    // İlk dosyadan sonra iptal.
    var calls = 0;
    final first = await vault.importHidden(isCancelled: () => calls++ >= 1);
    expect(first.cancelled, isTrue);
    expect(vault.items, hasLength(1));
    expect(await HiddenVault.list(), hasLength(1), reason: 'kalan gizli');

    final second = await vault.importHidden();
    expect(second.succeeded, 1);
    expect(vault.items, hasLength(2));
    expect(await HiddenVault.list(), isEmpty);
  });

  test('aslı silinmeden çökülmüş göç: içerik aynıysa ikinci şifreleme yok, '
      'aynı ad farklı içerikse YENİ kayıt (aslı şifrelenmeden silinmez)',
      () async {
    final a = write('y/not.txt', 'aaaa');
    await vault.add([a.path]);
    expect(vault.items, hasLength(1));

    // Aynı içerik aynı yerde yeniden belirdi (sil adımından önce çökme).
    final again = write('y/not.txt', 'aaaa');
    final r1 = await vault.add([again.path]);
    expect(r1.succeeded, 1);
    expect(vault.items, hasLength(1), reason: 'kopya kayıt yok');
    expect(again.existsSync(), isFalse);

    // Aynı ad + aynı boy ama FARKLI içerik → ayrı kayıt olarak şifrelenir.
    final other = write('y/not.txt', 'bbbb');
    await vault.add([other.path]);
    expect(vault.items, hasLength(2));
    final restored = <String>[];
    for (final item in List.of(vault.items)) {
      restored.add(File(await vault.restore(item)).readAsStringSync());
    }
    expect(restored, unorderedEquals(['aaaa', 'bbbb']));
  });

  test('tek PIN: kilit PIN\'i değişince kasa yeni PIN\'le açılır', () async {
    await vault.lock();
    expect(await syncVaultPin('2468', '1357'), isTrue);
    expect(vault.unlocked, isFalse, reason: 'kilitliyse yine kilitli kalır');
    expect(await vault.unlockWithPin('2468'), isFalse);
    expect(await vault.unlockWithPin('1357'), isTrue);
    // Eski sürümde AYRI PIN'le kurulmuş kasa: eski kilit PIN'i açmıyor →
    // kasanın PIN'i olduğu gibi kalır.
    await vault.lock();
    expect(await syncVaultPin('0000', '9999'), isFalse);
    expect(await vault.unlockWithPin('1357'), isTrue);
    // PBKDF2 (120 bin tur) yedi kez koşuyor — varsayılan 30 sn yetmiyor.
  }, timeout: const Timeout(Duration(minutes: 3)));
}
