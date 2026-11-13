import 'package:dosya_okuyucu/services/fm/remote/peer_share.dart';
import 'package:dosya_okuyucu/services/fm/remote/tile_receiver.dart';
import 'package:dosya_okuyucu/services/fm/remote/transfer_history.dart';
import 'package:dosya_okuyucu/services/fm/remote/trusted_peers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Dosya al" kutucuğu (2026-11-13): ekran yok → yalnız şifreli + anahtarıyla
/// güvenilen teklif kabul; geçmiş iki motor arasında ezilmez.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TrustedPeers.instance.debugReset();
    TransferHistory.instance.debugReset();
  });

  test('kutucuk kipinde yalnız şifreli ve anahtarı güvenilen teklif', () async {
    final t = TrustedPeers.instance;
    await t.add('Telefon', 'id', 'fp-1');
    await t.add('Eski PC');
    PeerOffer offer(String from, [String fp = '']) =>
        PeerOffer(from: from, firstName: 'a', count: 1, totalBytes: 1, fingerprint: fp, verifyCode: fp.isEmpty ? '' : '123456');
    expect(TileReceiver.accepts(offer('Telefon', 'fp-1'), t), isTrue);
    expect(TileReceiver.accepts(offer('Telefon', 'fp-2'), t), isFalse);
    expect(TileReceiver.accepts(offer('Eski PC'), t), isFalse, reason: 'düz protokol ekransız kabul edilmez');
  });

  test('geçmiş: başka motorun yazdığı satır eklemede korunur', () async {
    final h = TransferHistory.instance;
    TransferRecord rec(String n) => TransferRecord(
        incoming: true, path: '/x/$n', name: n, size: 1, peer: 'p', at: DateTime(2026));
    await h.add([rec('bir')]);
    // Kutucuk motoru aynı tercih dosyasına yazdı (ayrı bellek).
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('transfer_history_v1')!;
    await prefs.setString('transfer_history_v1',
        raw.replaceFirst('[', '[{"i":true,"p":"/x/iki","n":"iki","s":1,"k":"p","t":0},'));
    await h.add([rec('uc')]);
    expect(h.items.map((e) => e.name), contains('uc'));
    expect(h.items.map((e) => e.name), contains('bir'));
    expect(h.items.map((e) => e.name), contains('iki'), reason: 'öteki motorun satırı ezilmedi');
  });
}
