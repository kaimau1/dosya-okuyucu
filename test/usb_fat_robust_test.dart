import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/fat_fs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';

/// Belirli sayıda yazmadan sonra "çekilen" bellek: sonraki her yazma ve
/// okuma hata verir — yarıda kesilme anının benzetimi (K8).
class _UnpluggedDevice extends MemoryBlockDevice {
  int writesLeft;
  bool gone = false;
  _UnpluggedDevice(super.bytes, this.writesLeft);

  @override
  Future<void> writeBlocks(int lba, Uint8List data) async {
    if (gone || writesLeft-- <= 0) {
      gone = true;
      throw const BlockDeviceException('bellek çekildi');
    }
    await super.writeBlocks(lba, data);
  }
}

/// Yazmayı "tamam" deyip düşüren arızalı denetleyici.
class _LyingDevice extends MemoryBlockDevice {
  _LyingDevice(super.bytes);
  bool lie = false;

  @override
  Future<void> writeBlocks(int lba, Uint8List data) async {
    if (lie) return;
    await super.writeBlocks(lba, data);
  }
}

Future<int> _freeClusters(FatFileSystem fs) async {
  final u = await fs.usage();
  return u!.$2;
}

void main() {
  final big = List<int>.generate(40000, (i) => i % 251);

  for (final kind in ['fat32', 'fat16']) {
    Uint8List image() => kind == 'fat32'
        ? UsbImage.fat32(files: [ImgFile('eski.txt', [1, 2, 3])])
        : UsbImage.fat16(files: [ImgFile('eski.txt', [1, 2, 3])]);

    group(kind, () {
      test('temiz imaj kirli sayılmaz; başarılı yazma temiz bırakır', () async {
        final dev = MemoryBlockDevice(image());
        final fs = await FatFileSystem.open(dev);
        expect(await fs.isDirty(), isFalse);
        await fs.writeFile(fs.rootId, 'yeni.bin', Uint8List.fromList(big));
        expect(await fs.isDirty(), isFalse);
        expect(await fs.checkAndRepair(), 0);
      });

      test('yazma ortasında çekilen bellek: sonraki takışta kayıp kümeler '
          'geri verilir, yarım dosya listede YOK', () async {
        final bytes = image();
        final before = await _freeClusters(
            await FatFileSystem.open(MemoryBlockDevice(bytes)));
        // Kirli bayrak + zincir + birkaç veri kümesi yazılsın, sonra kes.
        final dev = _UnpluggedDevice(bytes, 6);
        final fs = await FatFileSystem.open(dev);
        await expectLater(
            fs.writeFile(fs.rootId, 'yarim.bin', Uint8List.fromList(big)),
            throwsA(anything));

        final again = await FatFileSystem.open(MemoryBlockDevice(bytes));
        expect(await again.isDirty(), isTrue);
        final names = (await again.listDir(again.rootId)).map((e) => e.name);
        expect(names, isNot(contains('yarim.bin')));
        expect(names, contains('eski.txt'));
        final freed = await again.checkAndRepair();
        expect(freed, greaterThan(0));
        expect(await again.isDirty(), isFalse);
        expect(await _freeClusters(again), before);
        // Eski dosya sağlam.
        final old = (await again.listDir(again.rootId))
            .firstWhere((e) => e.name == 'eski.txt');
        final data = await again.openRead(old).expand((c) => c).toList();
        expect(data, [1, 2, 3]);
      });

      test('her kesilme noktasında birim tutarlı kalır', () async {
        for (var n = 0; n < 40; n++) {
          final bytes = image();
          final dev = _UnpluggedDevice(bytes, n);
          final fs = await FatFileSystem.open(dev);
          try {
            await fs.writeFile(fs.rootId, 'k.bin', Uint8List.fromList(big));
          } catch (_) {}
          final again = await FatFileSystem.open(MemoryBlockDevice(bytes));
          await again.checkAndRepair();
          // Onarımdan sonra dosya ya hiç yok ya da tam ve doğru.
          final entries = await again.listDir(again.rootId);
          final k = entries.where((e) => e.name == 'k.bin');
          if (k.isNotEmpty) {
            final data =
                await again.openRead(k.first).expand((c) => c).toList();
            expect(data, big, reason: 'kesilme $n');
          }
          expect(await again.repairLostClusters(), 0, reason: 'kesilme $n');
        }
      });

      test('geri-okuma doğrulaması yazmayı düşüren belleği yakalar', () async {
        final dev = _LyingDevice(image());
        final fs = await FatFileSystem.open(dev);
        dev.lie = true;
        await expectLater(
            fs.writeFile(fs.rootId, 'x.bin', Uint8List.fromList(big)),
            throwsA(isA<Exception>()));
      });
    });
  }
}
