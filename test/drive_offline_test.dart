import 'dart:io';

import 'package:dosya_okuyucu/models/drive_file.dart';
import 'package:dosya_okuyucu/services/fm/drive_cache.dart';
import 'package:dosya_okuyucu/services/fm/drive_offline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 2: Drive çevrimdışı kopya + çakışma kararı.
void main() {
  test('kim değişti kararı', () {
    DriveSyncState d(int l, int r) =>
        DriveOffline.decide(localMs: l, baseLocalMs: 1000, remoteMs: r, baseRemoteMs: 5000);
    expect(d(1000, 5000), DriveSyncState.inSync);
    expect(d(2500, 5000), DriveSyncState.inSync); // yuvarlama payı
    expect(d(90000, 5000), DriveSyncState.localChanged);
    expect(d(1000, 90000), DriveSyncState.remoteChanged);
    expect(d(90000, 90000), DriveSyncState.conflict);
  });

  test('ikisini de tut adı', () {
    expect(DriveOffline.keepBothName('Rapor.docx', 'telefon'),
        'Rapor (telefon).docx');
    expect(DriveOffline.keepBothName('Notlar', 'phone'), 'Notlar (phone)');
  });

  test('sabitlenen kopya budamada silinmez; taban kaydı durumu verir', () {
    final root = Directory.systemTemp.createTempSync('drv').path;
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    const keep = DriveFile(
        id: 'k1', name: 'a.pdf', mimeType: 'application/pdf', sizeBytes: 600, modifiedAtMs: 1000);
    const drop = DriveFile(
        id: 'd1', name: 'b.pdf', mimeType: 'application/pdf', sizeBytes: 600, modifiedAtMs: 1000);
    for (final f in [keep, drop]) {
      Directory(DriveCache.dirFor(f, root)).createSync(recursive: true);
      File(DriveCache.pathFor(f, root)).writeAsBytesSync(List.filled(600, 1));
    }
    DriveOffline.setPinned(root, 'k1', true);
    expect(DriveOffline.pins(root), {'k1'});
    DriveCache.prune(root, limitBytes: 100, keep: DriveOffline.pins(root));
    expect(File(DriveCache.pathFor(keep, root)).existsSync(), isTrue);
    expect(File(DriveCache.pathFor(drop, root)).existsSync(), isFalse);

    expect(DriveOffline.stateOf(keep, root), isNull); // taban yok
    DriveOffline.recordBase(keep, root);
    expect(DriveOffline.stateOf(keep, root), DriveSyncState.inSync);
    const newer = DriveFile(
        id: 'k1', name: 'a.pdf', mimeType: 'application/pdf', sizeBytes: 600,
        modifiedAtMs: 1000 + 60000);
    expect(DriveOffline.stateOf(newer, root), DriveSyncState.remoteChanged);
    DriveOffline.setPinned(root, 'k1', false);
    expect(DriveOffline.pins(root), isEmpty);
  });
}
