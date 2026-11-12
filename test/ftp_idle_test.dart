import 'package:dosya_okuyucu/services/fm/remote/ftp_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// G4.8: ağ paylaşımı 30 dk etkinlik yoksa kendini kapatır.
void main() {
  final t0 = DateTime(2026, 11, 12, 10);

  test('bağlı istemci varken kapanmaz', () {
    expect(
        FtpService.shouldAutoStop(
            now: t0.add(const Duration(hours: 2)), lastActivity: t0, clients: 1),
        isFalse);
  });

  test('30 dk dolmadan kapanmaz, dolunca kapanır', () {
    expect(
        FtpService.shouldAutoStop(
            now: t0.add(const Duration(minutes: 29)),
            lastActivity: t0,
            clients: 0),
        isFalse);
    expect(
        FtpService.shouldAutoStop(
            now: t0.add(FtpService.idleLimit), lastActivity: t0, clients: 0),
        isTrue);
  });
}
