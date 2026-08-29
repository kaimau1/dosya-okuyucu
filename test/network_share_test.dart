import 'package:dosya_okuyucu/services/fm/notification_hub.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Ağdan erişim" turunun iki kilitlenen davranışı (2026-08-29):
///
/// 1. Kullanıcıya gösterilen adres, telefonun YEREL AĞ adresi olmalı —
///    hotspot/mobil arayüz başa geçerse kullanıcı PC'ye yanlış adresi yazar.
/// 2. Ön plan servisi **sayılarak** paylaşılmalı: paylaşımı kapatmak, süren
///    bir işin arka plan korumasını düşürmemeli (ve tersi).
void main() {
  group('adres sıralaması', () {
    test('yerel ağ adresi başa alınır', () {
      final sorted = FtpService.sortAddresses([
        'ftp://100.115.92.2:2121', // CGNAT/sanal arayüz
        'ftp://10.0.2.15:2121',
        'ftp://192.168.1.68:2121',
      ]);
      expect(sorted.first, 'ftp://192.168.1.68:2121');
      expect(sorted.last, 'ftp://100.115.92.2:2121');
    });

    test('172.16–172.31 özel aralığı yerel sayılır, 172.32 sayılmaz', () {
      final sorted = FtpService.sortAddresses([
        'ftp://172.32.0.5:2121',
        'ftp://172.20.0.5:2121',
      ]);
      expect(sorted.first, 'ftp://172.20.0.5:2121');
    });

    test('sıralama girdi listesini bozmaz', () {
      final input = ['ftp://10.0.0.1:2121', 'ftp://192.168.0.2:2121'];
      FtpService.sortAddresses(input);
      expect(input.first, 'ftp://10.0.0.1:2121');
    });
  });

  group('ön plan servisi sahipliği', () {
    late NotificationHub hub;

    FgNotice notice(int id) => FgNotice(
          id: id,
          title: 't',
          body: 'b',
          details: const AndroidNotificationDetails('c', 'C'),
        );

    setUp(() {
      hub = NotificationHub.instance;
      hub.debugReset();
      // Android eklentisi testte çözülemiyor (`_android` null) → platform
      // çağrıları sessizce atlanıyor; ölçülen şey SAHİPLİK MANTIĞI.
      hub.debugMarkReady();
    });

    tearDown(() => hub.debugReset());

    test('ilk sahip servisi başlatır, son sahip durdurur', () async {
      await hub.acquireService('jobs', notice(1));
      expect(hub.serviceRunning, isTrue);
      await hub.releaseService('jobs');
      expect(hub.serviceRunning, isFalse);
      expect(hub.serviceOwners, isEmpty);
    });

    test('paylaşımı kapatmak SÜREN İŞİN servisini düşürmez', () async {
      await hub.acquireService('jobs', notice(1));
      await hub.acquireService(FtpService.owner, notice(2));
      expect(hub.serviceOwners, containsAll(['jobs', FtpService.owner]));

      await hub.releaseService(FtpService.owner);
      // İş hâlâ koşuyor → servis ayakta kalmalı.
      expect(hub.serviceRunning, isTrue);
      expect(hub.serviceOwners, ['jobs']);
    });

    test('servisi BAŞLATAN sahip çekilince sahiplik devredilir', () async {
      await hub.acquireService('jobs', notice(1));
      await hub.acquireService(FtpService.owner, notice(2));
      await hub.releaseService('jobs');
      // Ağ paylaşımı sürüyor: servis durmamalı, kalan sahiple sürmeli.
      expect(hub.serviceRunning, isTrue);
      expect(hub.serviceOwners, [FtpService.owner]);

      await hub.releaseService(FtpService.owner);
      expect(hub.serviceRunning, isFalse);
    });

    test('sahip olmayanın bırakması bir şeyi bozmaz', () async {
      await hub.acquireService('jobs', notice(1));
      await hub.releaseService('bilinmeyen');
      expect(hub.serviceRunning, isTrue);
      expect(hub.serviceOwners, ['jobs']);
    });
  });
}
