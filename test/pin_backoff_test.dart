import 'package:dosya_okuyucu/services/fm/pin_backoff.dart';
import 'package:dosya_okuyucu/services/fm/secure_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **G3.2 (2026-11-11) yanlış PIN beklemesi** — kalıcı, ortak, saat geri
/// alınınca kısalmaz. Saat enjekte edilir.
void main() {
  late DateTime now;
  late SharedPreferences prefs;
  PinBackoff make() => PinBackoff(prefs, clock: () => now);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 11, 12);
  });

  test('bekleme tablosu: 5 serbest, 30 sn, iki katı, en çok 1 sa', () {
    expect(PinBackoff.waitFor(0), Duration.zero);
    expect(PinBackoff.waitFor(4), Duration.zero);
    expect(PinBackoff.waitFor(5), const Duration(seconds: 30));
    expect(PinBackoff.waitFor(6), const Duration(seconds: 60));
    expect(PinBackoff.waitFor(7), const Duration(seconds: 120));
    expect(PinBackoff.waitFor(11), const Duration(seconds: 1920));
    expect(PinBackoff.waitFor(12), const Duration(hours: 1));
    expect(PinBackoff.waitFor(100), const Duration(hours: 1));
  });

  test('ilk dört yanlış serbest, beşinciden sonra 30 sn bekletir', () async {
    final b = make();
    for (var i = 0; i < 4; i++) {
      await b.recordFailure();
      expect(b.blocked, isFalse);
    }
    await b.recordFailure();
    expect(b.remaining(), const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 29));
    expect(b.blocked, isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(b.blocked, isFalse);
    // Altıncı yanlış: 60 sn.
    await b.recordFailure();
    expect(b.remaining(), const Duration(seconds: 60));
  });

  test('sayaç kalıcı: yeni örnek (uygulama yeniden açıldı) beklemeyi sürdürür',
      () async {
    final b = make();
    for (var i = 0; i < 5; i++) {
      await b.recordFailure();
    }
    now = now.add(const Duration(seconds: 10));
    final again = make();
    expect(again.failures, 5);
    expect(again.remaining(), const Duration(seconds: 20));
  });

  test('doğru PIN sayacı sıfırlar', () async {
    final b = make();
    for (var i = 0; i < 6; i++) {
      await b.recordFailure();
    }
    await b.recordSuccess();
    expect(b.failures, 0);
    expect(b.blocked, isFalse);
  });

  test('saat geri alınırsa bekleme baştan başlar (kısalmaz)', () async {
    final b = make();
    for (var i = 0; i < 5; i++) {
      await b.recordFailure();
    }
    now = now.subtract(const Duration(days: 1));
    expect(b.remaining(), const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 15));
    expect(b.remaining(), const Duration(seconds: 15));
  });

  group('G3.5 kasa otomatik kilit', () {
    final at = DateTime(2026, 11, 11, 12);
    test('0 = hemen', () {
      expect(VaultAutoLock.expired(at, at, 0), isTrue);
    });
    test('süre dolmadan açık, dolunca kilitli', () {
      expect(VaultAutoLock.expired(at, at.add(const Duration(seconds: 29)), 30),
          isFalse);
      expect(VaultAutoLock.expired(at, at.add(const Duration(seconds: 30)), 30),
          isTrue);
    });
    test('saat geri alınırsa kilitler', () {
      expect(
          VaultAutoLock.expired(
              at, at.subtract(const Duration(minutes: 1)), 300),
          isTrue);
    });
    test('ayar kalıcı, varsayılan 0', () async {
      expect(await VaultAutoLock.seconds(), 0);
      await VaultAutoLock.setSeconds(60);
      expect(await VaultAutoLock.seconds(), 60);
    });
  });
}
