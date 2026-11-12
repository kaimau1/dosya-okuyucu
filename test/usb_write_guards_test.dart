import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/exfat_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/fat_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_fs_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';

/// **Yazma bekçileri (2026-11-12 denetimi).** Her biri gerçek bir veri kaybı
/// yolunu kapatıyor: klasörün dosyayla ezilmesi, çift ad, geçersiz ad,
/// 4 GB üstü dosya, bitişiklik bayrağının düşmesi.
UsbEntry find(List<UsbEntry> list, String name) =>
    list.firstWhere((e) => e.name == name);

Future<Uint8List> readAll(Stream<Uint8List> stream) async {
  final b = BytesBuilder();
  await for (final chunk in stream) {
    b.add(chunk);
  }
  return b.takeBytes();
}

void main() {
  final hello = List<int>.generate(300, (i) => i % 256);

  test('ad denetimi', () {
    for (final bad in ['', '.', '..', 'a:b', 'a/b', 'soru?', 'son.', 'son ', 'x' * 256]) {
      expect(() => UsbNames.validate(bad), throwsA(isA<UsbFsException>()),
          reason: bad);
    }
    UsbNames.validate('çok uzun türkçe ad ğüşiöç.txt');
    UsbNames.validate('x' * 255);
  });

  group('FAT32', () {
    late FatFileSystem fs;

    setUp(() async {
      fs = await FatFileSystem.open(MemoryBlockDevice(UsbImage.fat32(
        files: [ImgFile('rapor.pdf', hello), ImgFile('diger.txt', hello)],
        dirs: [
          ImgDir('Belgelerim', [ImgFile('ic.txt', hello)]),
        ],
      )));
    });

    test('aynı adlı klasör dosyayla EZİLMEZ', () async {
      await expectLater(
          fs.writeFile(fs.rootId, 'belgelerim', Uint8List.fromList(hello)),
          throwsA(isA<UsbFsException>()));
      final root = await fs.listDir(fs.rootId);
      final inside = await fs.listDir(find(root, 'Belgelerim').id);
      expect(inside.map((e) => e.name), contains('ic.txt'));
    });

    test('aynı adla klasör açılmaz, var olan ada yeniden adlandırılmaz',
        () async {
      await expectLater(fs.createDirectory(fs.rootId, 'RAPOR.PDF'),
          throwsA(isA<UsbFsException>()));
      final root = await fs.listDir(fs.rootId);
      await expectLater(
          fs.renameEntry(fs.rootId, find(root, 'rapor.pdf'), 'diger.txt'),
          throwsA(isA<UsbFsException>()));
      // İkisi de yerinde ve okunuyor.
      final after = await fs.listDir(fs.rootId);
      expect(await readAll(fs.openRead(find(after, 'rapor.pdf'))), hello);
      expect(await readAll(fs.openRead(find(after, 'diger.txt'))), hello);
    });

    test('yeniden adlandırma içeriği korur; yalnız harf değişimi de olur',
        () async {
      var root = await fs.listDir(fs.rootId);
      await fs.renameEntry(fs.rootId, find(root, 'rapor.pdf'), 'Rapor.PDF');
      root = await fs.listDir(fs.rootId);
      await fs.renameEntry(
          fs.rootId, find(root, 'Rapor.PDF'), 'yeni uzun ad 2026.pdf');
      root = await fs.listDir(fs.rootId);
      expect(root.where((e) => e.name.toLowerCase() == 'rapor.pdf'), isEmpty);
      expect(await readAll(fs.openRead(find(root, 'yeni uzun ad 2026.pdf'))),
          hello);
    });

    test('4 GB üstü dosya ve geçersiz ad yazmadan reddedilir', () async {
      await expectLater(
          fs.writeFileStream(
              fs.rootId, 'dev.bin', const Stream.empty(), 0x100000000),
          throwsA(isA<UsbFsException>()));
      await expectLater(
          fs.writeFile(fs.rootId, 'a:b.txt', Uint8List.fromList(hello)),
          throwsA(isA<UsbFsException>()));
      expect((await fs.listDir(fs.rootId)).length, 3);
    });
  });

  test('exFAT girdi kümesi bitişiklik bayrağını taşır', () {
    Uint8List build(bool flag) => ExfatFileSystem.buildEntrySet(
          'a.txt',
          isDir: false,
          firstCluster: 9,
          size: 10,
          nameHash: 0,
          timestamp: DateTime(2026, 11, 12),
          noFatChain: flag,
        );
    expect(build(true)[33], 0x03);
    expect(build(false)[33], 0x01);
  });
}
