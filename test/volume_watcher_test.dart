import 'dart:io';

import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:dosya_okuyucu/services/fm/volume_watcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **Harici bellek izleme** — kullanıcı isteği 2026-09-01: *"harici USB
/// taktığımda göremiyorum onu uygulamamızda görebilmeliyiz, otomatik
/// tanımalı."*
///
/// Burada test edilen, izlemenin ucuz yoklama tarafı: bağlama noktalarının
/// ADLARI. Pahalı tarama (`df`, `FmEnv`) yalnız bu küme değişince koşuyor;
/// beş saniyede bir süreç açmamanın tek güvencesi bu.
void main() {
  test('mountNames var olmayan kökleri sessizce atlar', () {
    // Test ortamında /storage, /mnt/media_rw, /mnt/usb yok — çökmemeli.
    expect(VolumeWatcher.mountNames(roots: const ['/kesinlikle/yok']), isEmpty);
  });

  test('kopyalama hedef klasörü birimin kökü DEĞİL', () {
    const usb = StorageVolume(
        path: '/storage/1A2B-3C4D', isPrimary: false, kind: StorageKind.usb);
    final target = VolumeWatcher.targetFolder(usb);
    expect(p.dirname(target), usb.path);
    expect(target, isNot(usb.path));
  });

  group('VolumeChange', () {
    test('boş değişim boş sayılır', () {
      expect(const VolumeChange().isEmpty, isTrue);
    });

    test('takılan birim varsa boş değil', () {
      const change = VolumeChange(attached: [
        StorageVolume(path: '/storage/X', isPrimary: false),
      ]);
      expect(change.isEmpty, isFalse);
    });

    test('çıkarılan birim varsa boş değil', () {
      const change = VolumeChange(detached: ['/storage/X']);
      expect(change.isEmpty, isFalse);
    });
  });

  test('gerçek bir dizinde bağlama adları okunur', () async {
    final root = await Directory.systemTemp.createTemp('vol_root');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory(p.join(root.path, 'USB1')).createSync();
    Directory(p.join(root.path, 'self')).createSync(); // atlanmalı

    final names = VolumeWatcher.mountNames(roots: [root.path]);
    expect(names, contains('${root.path}/USB1'));
    expect(names, isNot(contains('${root.path}/self')));
  });
}
