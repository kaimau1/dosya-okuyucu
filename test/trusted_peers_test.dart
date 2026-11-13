import 'package:dosya_okuyucu/services/fm/remote/trusted_peers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenilen cihazlar (2026-11-03): kimlik varsa kimlikle, yoksa adla eşleşir.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TrustedPeers.instance.debugReset();
  });

  test('kimlikle güvenilen: aynı adlı başka kurulum güvenilmez', () async {
    final t = TrustedPeers.instance;
    await t.add('Fatih telefon', 'id-1');
    expect(t.isTrusted('Fatih telefon', 'id-1'), isTrue);
    expect(t.isTrusted('Fatih telefon', 'id-2'), isFalse);
    expect(t.isTrusted('Fatih telefon'), isTrue,
        reason: 'kimlik göndermeyen (bilgisayar) adla eşleşir');
  });

  test('adla güvenilen bilgisayar; kalıcı; kaldırılınca sorulur', () async {
    final t = TrustedPeers.instance;
    await t.add('MASAUSTU');
    expect(t.isTrusted('MASAUSTU'), isTrue);
    expect(t.isTrusted('Başka'), isFalse);

    t.debugReset();
    await t.ensureLoaded();
    expect(t.isTrusted('MASAUSTU'), isTrue, reason: 'diske yazıldı');

    await t.remove(t.items.single);
    expect(t.isTrusted('MASAUSTU'), isFalse);
  });

  test('G5: anahtarlı kayıt yalnız aynı parmak iziyle eşleşir', () async {
    final t = TrustedPeers.instance;
    await t.add('Telefon', 'id-1');
    expect(t.isTrusted('Telefon', 'id-1', 'fp-a'), isFalse,
        reason: 'eski kayıt şifreli teklifte bir kez sorulur');
    expect(t.hasLegacy('Telefon', 'id-1'), isTrue);
    await t.add('Telefon', 'id-1', 'fp-a');
    expect(t.items, hasLength(1), reason: 'eski kayıt anahtarlıyla değişti');
    expect(t.isTrusted('Başka ad', 'id-9', 'fp-a'), isTrue);
    expect(t.isTrusted('Telefon', 'id-1', 'fp-b'), isFalse);
    expect(t.isTrusted('Telefon', 'id-1'), isFalse,
        reason: 'anahtarlı cihazın adını taşıyan DÜZ teklif güvenilmez');
    t.debugReset();
    await t.ensureLoaded();
    expect(t.byKey('fp-a')?.name, 'Telefon', reason: 'diske yazıldı');
  });
}
