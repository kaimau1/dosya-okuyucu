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
}
