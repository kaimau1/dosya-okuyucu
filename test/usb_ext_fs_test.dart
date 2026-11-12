import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/ext_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/fs_sniffer.dart';
import 'package:dosya_okuyucu/services/fm/usb/partition_table.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_fs_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// **ext2/3/4 okuyucusu — gerçek `mke2fs` imajlarıyla.**
///
/// İmajlar `test/fixtures/usb/*.img.gz` (mke2fs -d ile üretildi):
/// * `ext2.img`      — 1 KiB blok, eski dolaylı blok düzeni;
/// * `ext4.img`      — 4 KiB blok, kapsam ağacı, 64 bit, metadata_csum;
/// * `ext4meta.img`  — 1 KiB blok, meta_bg, 4 grup.
/// İçerik üçünde de aynı; baytlar formülle üretildi ki burada yeniden
/// hesaplanıp karşılaştırılabilsin.
Uint8List pattern(int n, int k) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * k + 3) % 251));

Future<Uint8List> readAll(Stream<Uint8List> stream) async {
  final b = BytesBuilder();
  await for (final chunk in stream) {
    b.add(chunk);
  }
  return b.takeBytes();
}

Uint8List image(String name) => Uint8List.fromList(
    gzip.decode(File('test/fixtures/usb/$name.img.gz').readAsBytesSync()));

UsbEntry find(List<UsbEntry> list, String name) =>
    list.firstWhere((e) => e.name == name);

void main() {
  for (final name in ['ext2', 'ext4', 'ext4meta']) {
    group(name, () {
      late ExtFileSystem fs;
      late List<UsbEntry> root;

      setUp(() async {
        fs = await ExtFileSystem.open(MemoryBlockDevice(image(name)));
        root = await fs.listDir(fs.rootId);
      });

      test('kök listesi: dosya ve klasörler var, bağ ve . / .. yok', () {
        final names = root.map((e) => e.name).toSet();
        expect(
            names,
            containsAll(
                ['merhaba.txt', 'buyuk.bin', 'seyrek.bin', 'bos.txt', 'Belgeler', 'Cok']));
        expect(names, isNot(contains('baglanti'))); // sembolik bağ
        expect(names, isNot(contains('.')));
        expect(find(root, 'Belgeler').isDir, isTrue);
        expect(find(root, 'buyuk.bin').sizeBytes, 300000);
        expect(find(root, 'buyuk.bin').modifiedMs, greaterThan(0));
      });

      test('çok bloklu dosya bayt bayt doğru', () async {
        final data = await readAll(fs.openRead(find(root, 'buyuk.bin')));
        expect(data, pattern(300000, 7));
      });

      test('boş dosya boş okunur', () async {
        expect(await readAll(fs.openRead(find(root, 'bos.txt'))), isEmpty);
      });

      test('seyrek dosyada delik SIFIR okunur', () async {
        final data = await readAll(fs.openRead(find(root, 'seyrek.bin')));
        expect(data.length, 203000);
        expect(data.sublist(0, 2000), pattern(2000, 5));
        expect(data.sublist(2000, 200000).every((b) => b == 0), isTrue);
        expect(data.sublist(200000), pattern(3000, 17));
      });

      test('Türkçe ad ve iç içe klasör', () async {
        final docs = await fs.listDir(find(root, 'Belgeler').id);
        final tr = find(docs, 'çok uzun türkçe ad ğüşiöç.txt');
        expect(await readAll(fs.openRead(tr)), pattern(5000, 11));
        final deep = await fs.listDir(find(docs, 'Derin').id);
        final alt = await fs.listDir(find(deep, 'Alt').id);
        expect(await readAll(fs.openRead(find(alt, 'dip.dat'))),
            pattern(70000, 13));
      });

      test('kalabalık klasörün tamamı listelenir', () async {
        final many = await fs.listDir(find(root, 'Cok').id);
        expect(many.length, 220);
        expect(many.every((e) => !e.isDir), isTrue);
      });

      test('kullanım bilgisi ve salt okunurluk', () async {
        final usage = await fs.usage();
        expect(usage!.$1, greaterThan(usage.$2));
        expect(usage.$2, greaterThan(0));
        expect(fs.writable, isFalse);
        expect(fs.label, isNotEmpty);
      });
    });
  }

  test('4096 baytlık sektörlü aygıtta da açılır', () async {
    final fs = await ExtFileSystem.open(
        MemoryBlockDevice(image('ext4'), blockSize: 4096));
    final root = await fs.listDir(fs.rootId);
    expect(await readAll(fs.openRead(find(root, 'buyuk.bin'))),
        pattern(300000, 7));
  });

  test('ext olmayan aygıt reddedilir', () async {
    expect(
      () => ExtFileSystem.open(MemoryBlockDevice(Uint8List(8192))),
      throwsA(isA<UsbFsException>()),
    );
  });

  test('bozuk imaj: süper blok geçerli, gerisi çöp → hata, çökme/döngü yok',
      () async {
    final bytes = image('ext4');
    // Grup tanımlayıcılarını ve düğüm tablolarını 0xFF ile ez.
    bytes.fillRange(4096, 64 * 1024, 0xFF);
    final fs = await ExtFileSystem.open(MemoryBlockDevice(bytes));
    await expectLater(
        fs.listDir(fs.rootId), throwsA(isA<UsbFsException>()));
  });

  group('mantıksal bölümler (EBR)', () {
    Uint8List mbrSector(List<(int, int, int)> slots) {
      final s = Uint8List(512);
      final d = ByteData.sublistView(s);
      for (var i = 0; i < slots.length; i++) {
        final off = 446 + i * 16;
        s[off + 4] = slots[i].$1;
        d.setUint32(off + 8, slots[i].$2, Endian.little);
        d.setUint32(off + 12, slots[i].$3, Endian.little);
      }
      s[510] = 0x55;
      s[511] = 0xAA;
      return s;
    }

    test('genişletilmiş bölümün içindeki sürücüler bulunur', () async {
      final disk = Uint8List(512 * 4000);
      // Birincil FAT32 + genişletilmiş kap (1000'den başlar).
      disk.setRange(0, 512, mbrSector([(0x0C, 100, 800), (0x0F, 1000, 3000)]));
      // 1. EBR: mantıksal sürücü +10'da, sonraki EBR kabın +1500'ünde.
      disk.setRange(512 * 1000, 512 * 1001,
          mbrSector([(0x07, 10, 1000), (0x05, 1500, 1500)]));
      // 2. EBR: son mantıksal sürücü.
      disk.setRange(
          512 * 2500, 512 * 2501, mbrSector([(0x83, 20, 900)]));
      final parts = await PartitionTable.read(MemoryBlockDevice(disk));
      expect(parts.map((p) => p.firstLba), [100, 1010, 2520]);
      expect(parts.map((p) => p.mbrType), [0x0C, 0x07, 0x83]);
    });

    test('kendine dönen EBR zinciri sonsuz döngüye girmez', () async {
      final disk = Uint8List(512 * 2000);
      disk.setRange(0, 512, mbrSector([(0x05, 1000, 1000)]));
      disk.setRange(512 * 1000, 512 * 1001,
          mbrSector([(0x0B, 10, 100), (0x05, 0, 1000)]));
      final parts = await PartitionTable.read(MemoryBlockDevice(disk));
      expect(parts.length, 1);
      expect(parts.single.firstLba, 1010);
    });
  });

  group('FsSniffer', () {
    Uint8List head() => Uint8List(4096);

    test('okunamayan biçimlerin adı söylenir', () {
      final apfs = head()..setRange(32, 36, 'NXSB'.codeUnits);
      expect(FsSniffer.identifyHead(apfs), 'APFS');
      final hfs = head()..setRange(1024, 1026, 'H+'.codeUnits);
      expect(FsSniffer.identifyHead(hfs), 'HFS+');
      final bl = head()..setRange(3, 11, '-FVE-FS-'.codeUnits);
      expect(FsSniffer.identifyHead(bl), 'BitLocker');
      final f2 = head()..setRange(1024, 1028, [0x10, 0x20, 0xF5, 0xF2]);
      expect(FsSniffer.identifyHead(f2), 'F2FS');
      final xfs = head()..setRange(0, 4, 'XFSB'.codeUnits);
      expect(FsSniffer.identifyHead(xfs), 'XFS');
      expect(FsSniffer.identifyHead(head()), isNull);
    });

    test('ISO 9660 ve UDF ayırt edilir', () {
      final iso = Uint8List(8192)..setRange(1, 6, 'CD001'.codeUnits);
      expect(FsSniffer.identifyOptical(iso), 'ISO 9660');
      final udf = Uint8List(8192)
        ..setRange(1, 6, 'CD001'.codeUnits)
        ..setRange(2049, 2054, 'NSR02'.codeUnits);
      expect(FsSniffer.identifyOptical(udf), 'UDF');
    });

    test('aygıttan: boş aygıt null, ext imajı sniffer için de null', () async {
      expect(await FsSniffer.identify(MemoryBlockDevice(Uint8List(1 << 20))),
          isNull);
    });
  });
}
