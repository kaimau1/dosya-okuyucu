import 'package:dosya_okuyucu/services/fm/remote/ble_nearby.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('çekme daveti (telefon) gidip gelir', () {
    const invite = BleInvite(
        from: 'Tel', fromId: 'a1b2c3d4', url: 'http://10.0.0.2:8080/x', count: 2, totalBytes: 10, names: ['a.jpg']);
    final back = BleInvite.decode(invite.encode())!;
    expect(back.url, invite.url);
    expect(back.push, false);
    expect(back.names, ['a.jpg']);
  });

  test('push daveti (Windows Dosya Aktar) adressiz kabul edilir', () {
    final back = BleInvite.decode('{"v":1,"f":"sena (PC)","i":"pc000001","p":1,"n":3,"s":42,"a":["x.pdf"]}')!;
    expect(back.push, true);
    expect(back.url, '');
    expect(back.from, 'sena (PC)');
    expect(back.count, 3);
  });

  test('ne adres ne push: reddedilir', () {
    expect(BleInvite.decode('{"v":1,"f":"x"}'), isNull);
    expect(BleInvite.decode('bozuk'), isNull);
  });
}
