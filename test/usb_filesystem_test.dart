import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/exfat_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/fat_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/ntfs_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/partition_table.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_fs_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';

/// **Ham USB sürücüsünün cihazsız doğrulaması.**
///
/// Kullanıcı 2026-09-02: "kendi USB yığın depolama sürücümüzü yazalım mı?"
/// Sürücünün riskli yanı Kotlin tarafı değil (o ince bir köprü), FAT/exFAT
/// çözümlemesi: yanlış okunan bir zincir kullanıcıya bozuk dosya verir.
/// Bu yüzden çözümleyicilerin tamamı saf Dart ve burada **gerçek yapıların
/// birebir aynısı** sentetik imajlarla sınanıyor.
Future<Uint8List> readAll(Stream<Uint8List> stream) async {
  final b = BytesBuilder();
  await for (final chunk in stream) {
    b.add(chunk);
  }
  return b.takeBytes();
}

void main() {
  final hello = List<int>.generate(300, (i) => i % 256);
  final big = List<int>.generate(3000, (i) => (i * 7) % 256); // 6 küme

  group('FAT32', () {
    late FatFileSystem fs;

    setUp(() async {
      final image = UsbImage.fat32(
        label: 'TYPEC 64',
        files: [ImgFile('rapor.pdf', hello), ImgFile('BUYUK.BIN', big)],
        dirs: [
          ImgDir('Belgelerim', [ImgFile('çok uzun türkçe ad.txt', hello)]),
        ],
      );
      fs = await FatFileSystem.open(MemoryBlockDevice(image));
    });

    test('sürüm küme sayısından FAT32 çıkar', () {
      expect(fs.kind, FatKind.fat32);
      expect(fs.label, 'TYPEC 64');
    });

    test('kök listelenir, uzun adlar korunur', () async {
      final entries = await fs.listDir(fs.rootId);
      final names = entries.map((e) => e.name).toList();
      expect(names, containsAll(['rapor.pdf', 'BUYUK.BIN', 'Belgelerim']));
      expect(entries.firstWhere((e) => e.name == 'Belgelerim').isDir, isTrue);
      expect(entries.firstWhere((e) => e.name == 'rapor.pdf').sizeBytes, 300);
    });

    test('alt klasör gezilir; Türkçe uzun ad bozulmaz', () async {
      final root = await fs.listDir(fs.rootId);
      final dir = root.firstWhere((e) => e.name == 'Belgelerim');
      final children = await fs.listDir(dir.id);
      expect(children.map((e) => e.name), ['çok uzun türkçe ad.txt']);
    });

    test('tek kümeden küçük dosya birebir okunur', () async {
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'rapor.pdf');
      expect(await readAll(fs.openRead(entry)), hello);
    });

    test('ÇOK KÜMELİ dosya zinciri izlenerek birebir okunur', () async {
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'BUYUK.BIN');
      final data = await readAll(fs.openRead(entry));
      expect(data.length, big.length, reason: 'boyut kadar okunur, fazlası değil');
      expect(data, big);
    });

    test('değiştirilme tarihi çözülür', () async {
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'rapor.pdf');
      final dt = DateTime.fromMillisecondsSinceEpoch(entry.modifiedMs);
      expect(dt.year, 2020);
      expect(dt.month, 1);
      expect(dt.day, 1);
    });
  });

  group('FAT16', () {
    test('kök SABİT ALANDA okunur (FAT32 ile aynı arayüz)', () async {
      final image = UsbImage.fat16(files: [ImgFile('a.txt', hello)]);
      final fs = await FatFileSystem.open(MemoryBlockDevice(image));
      expect(fs.kind, FatKind.fat16);
      final entries = await fs.listDir(fs.rootId);
      expect(entries.map((e) => e.name), ['a.txt']);
      expect(await readAll(fs.openRead(entries.first)), hello);
    });
  });

  group('exFAT', () {
    test('etiket, listeleme ve okuma (bitişik dosya — FAT okunmaz)',
        () async {
      final image = UsbImage.exfat(
        label: 'TYPEC 64',
        files: [ImgFile('video.mp4', big)],
        dirs: [ImgDir('DCIM', [ImgFile('foto.jpg', hello)])],
      );
      final fs = await ExfatFileSystem.open(MemoryBlockDevice(image));
      expect(fs.label, 'TYPEC 64');
      final root = await fs.listDir(fs.rootId);
      expect(root.map((e) => e.name), containsAll(['video.mp4', 'DCIM']));
      final video = root.firstWhere((e) => e.name == 'video.mp4');
      expect(video.sizeBytes, big.length);
      expect(await readAll(fs.openRead(video)), big);
      final dir = root.firstWhere((e) => e.name == 'DCIM');
      final children = await fs.listDir(dir.id);
      expect(children.map((e) => e.name), ['foto.jpg']);
      expect(await readAll(fs.openRead(children.first)), hello);
    });

    test('ZİNCİRLİ (parçalı) dosya da okunur', () async {
      final image = UsbImage.exfat(
        contiguous: false,
        files: [ImgFile('parcali.bin', big)],
      );
      final fs = await ExfatFileSystem.open(MemoryBlockDevice(image));
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'parcali.bin');
      expect(await readAll(fs.openRead(entry)), big);
    });

    test('FAT imajı exFAT olarak açılmaz (sıra sonraki çözümleyiciye geçsin)',
        () async {
      final image = UsbImage.fat32(files: [ImgFile('a.txt', hello)]);
      expect(() => ExfatFileSystem.open(MemoryBlockDevice(image)),
          throwsA(isA<UsbFsException>()));
    });
  });

  _ntfsTests();

  group('PartitionTable', () {
    test('süper disket: tablo YOK, dosya sistemi 0. sektörde', () async {
      final image = UsbImage.fat32(files: [ImgFile('a.txt', hello)]);
      final parts = await PartitionTable.read(MemoryBlockDevice(image));
      expect(parts.length, 1);
      expect(parts.single.firstLba, 0);
    });

    test('MBR girdileri çözülür', () {
      final sector = Uint8List(512);
      final view = ByteData.sublistView(sector);
      sector[510] = 0x55;
      sector[511] = 0xAA;
      sector[446 + 4] = 0x0C; // FAT32 LBA
      view.setUint32(446 + 8, 2048, Endian.little);
      view.setUint32(446 + 12, 100000, Endian.little);
      final parts = PartitionTable.parseMbr(sector);
      expect(parts.length, 1);
      expect(parts.single.firstLba, 2048);
      expect(parts.single.blockCount, 100000);
      expect(parts.single.isUsable, isTrue);
    });

    test('imzasız sektör bölüm SAYILMAZ (rastgele veriden okuma yapılmaz)',
        () {
      expect(PartitionTable.parseMbr(Uint8List(512)), isEmpty);
    });

    test('genişletilmiş ve koruyucu girdiler elenir', () {
      final sector = Uint8List(512);
      final view = ByteData.sublistView(sector);
      sector[510] = 0x55;
      sector[511] = 0xAA;
      sector[446 + 4] = 0xEE; // GPT koruyucu
      view.setUint32(446 + 8, 1, Endian.little);
      view.setUint32(446 + 12, 100, Endian.little);
      sector[462 + 4] = 0x05; // genişletilmiş kap
      view.setUint32(462 + 8, 200, Endian.little);
      view.setUint32(462 + 12, 100, Endian.little);
      final parts = PartitionTable.parseMbr(sector);
      expect(parts.where((p) => p.isUsable), isEmpty);
    });

    test('GPT girdileri çözülür (ad dahil)', () {
      const entrySize = 128;
      final entries = Uint8List(entrySize * 2);
      final view = ByteData.sublistView(entries);
      entries[0] = 0xA2; // tür GUID'i sıfır değil
      view.setUint64(32, 2048, Endian.little);
      view.setUint64(40, 4095, Endian.little);
      for (var i = 0; i < 3; i++) {
        view.setUint16(56 + i * 2, 'USB'.codeUnitAt(i), Endian.little);
      }
      final parts = PartitionTable.parseGptEntries(entries,
          entryCount: 2, entrySize: entrySize);
      expect(parts.length, 1, reason: 'boş girdi atlanır');
      expect(parts.single.firstLba, 2048);
      expect(parts.single.blockCount, 2048);
      expect(parts.single.name, 'USB');
    });
  });

  group('PartitionBlockDevice', () {
    test('bölümün dışına okuma REDDEDİLİR', () async {
      final dev = MemoryBlockDevice(Uint8List(512 * 100));
      final part = PartitionBlockDevice(dev, 10, 5);
      expect(() => part.readBlocks(4, 2),
          throwsA(isA<BlockDeviceException>()));
    });

    test('bölüm 0. sektörünü aygıtın doğru yerine çevirir', () async {
      final bytes = Uint8List(512 * 100);
      bytes[10 * 512] = 0x42;
      final part = PartitionBlockDevice(MemoryBlockDevice(bytes), 10, 5);
      final data = await part.readBlocks(0, 1);
      expect(data[0], 0x42);
    });
  });

  group('CachedBlockDevice', () {
    test('aynı sektör ikinci kez aygıttan OKUNMAZ', () async {
      final counting = _CountingDevice(MemoryBlockDevice(Uint8List(512 * 10)));
      final cached = CachedBlockDevice(counting);
      await cached.readBlocks(3, 1);
      await cached.readBlocks(3, 1);
      expect(counting.reads, 1);
    });

    test('çok sektörlü okuma önbelleği süpürmez', () async {
      final counting = _CountingDevice(MemoryBlockDevice(Uint8List(512 * 10)));
      final cached = CachedBlockDevice(counting);
      await cached.readBlocks(0, 4);
      await cached.readBlocks(0, 4);
      expect(counting.reads, 2, reason: 'toplu okuma her seferinde aygıttan');
    });
  });
}

class _CountingDevice extends BlockDevice {
  final BlockDevice inner;
  var reads = 0;

  _CountingDevice(this.inner);

  @override
  int get blockSize => inner.blockSize;

  @override
  int get blockCount => inner.blockCount;

  @override
  Future<Uint8List> readBlocks(int lba, int count) {
    reads++;
    return inner.readBlocks(lba, count);
  }
}

/// **NTFS okuma** — kullanıcı isteği 2026-09-02: *"NTFS bile okuyalım."*
/// Harici diskler (USB kutular) fabrikadan çoğu zaman NTFS gelir.
void _ntfsTests() {
  final small = List<int>.generate(200, (i) => (i * 3) % 256);
  final big = List<int>.generate(2500, (i) => (i * 11) % 256);

  group('NTFS', () {
    test('etiket okunur ve kök listelenir', () async {
      final image = NtfsImage.build(
        label: 'SEYAHAT DISK',
        files: [ImgFile('rapor.pdf', small), ImgFile('film.mkv', big)],
      );
      final fs = await NtfsFileSystem.open(MemoryBlockDevice(image));
      expect(fs.label, 'SEYAHAT DISK');
      final root = await fs.listDir(fs.rootId);
      expect(root.map((e) => e.name), containsAll(['rapor.pdf', 'film.mkv']));
      expect(
          root.firstWhere((e) => e.name == 'film.mkv').sizeBytes, big.length);
    });

    test('çalıştırma listesinden dosya birebir okunur', () async {
      final image = NtfsImage.build(files: [ImgFile('film.mkv', big)]);
      final fs = await NtfsFileSystem.open(MemoryBlockDevice(image));
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'film.mkv');
      expect(await readAll(fs.openRead(entry)), big);
    });

    test('KAYDIN İÇİNDE duran küçük dosya da okunur (resident \$DATA)',
        () async {
      final image =
          NtfsImage.build(resident: true, files: [ImgFile('not.txt', small)]);
      final fs = await NtfsFileSystem.open(MemoryBlockDevice(image));
      final root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'not.txt');
      expect(await readAll(fs.openRead(entry)), small);
    });

    test('Türkçe uzun ad bozulmaz', () async {
      final image = NtfsImage.build(
          files: [ImgFile('çok uzun türkçe belge adı.docx', small)]);
      final fs = await NtfsFileSystem.open(MemoryBlockDevice(image));
      final root = await fs.listDir(fs.rootId);
      expect(root.single.name, 'çok uzun türkçe belge adı.docx');
    });

    test('değiştirilme tarihi FILETIME\'dan çözülür', () async {
      final image = NtfsImage.build(files: [ImgFile('a.txt', small)]);
      final fs = await NtfsFileSystem.open(MemoryBlockDevice(image));
      final root = await fs.listDir(fs.rootId);
      final dt = DateTime.fromMillisecondsSinceEpoch(root.single.modifiedMs)
          .toUtc();
      expect(dt.year, 2020);
      expect(dt.month, 1);
    });

    test('FAT imajı NTFS olarak açılmaz', () {
      final image = UsbImage.fat32(files: [ImgFile('a.txt', small)]);
      expect(() => NtfsFileSystem.open(MemoryBlockDevice(image)),
          throwsA(isA<UsbFsException>()));
    });
  });

  group('NTFS saf çözümleyiciler', () {
    test('çalıştırma listesi GÖRELİ ve İŞARETLİ konum çözer', () {
      // 0x21 0x08 0x00 0x14 → 8 küme, LCN 0x1400; sonra 0x11 0x04 0xF0 →
      // 4 küme, önceki LCN - 16. Mutlak sanılsaydı dosya diskin bambaşka
      // yerinden okunurdu.
      final bytes = Uint8List.fromList(
          [0x21, 0x08, 0x00, 0x14, 0x11, 0x04, 0xF0, 0x00]);
      final runs = NtfsFileSystem.parseRunList(bytes, 0);
      expect(runs.length, 2);
      expect(runs[0].lcn, 0x1400);
      expect(runs[0].clusters, 8);
      expect(runs[1].lcn, 0x1400 - 16);
      expect(runs[1].clusters, 4);
    });

    test('konum alanı yoksa öbek SEYREKTİR (diskten okunmaz)', () {
      final runs =
          NtfsFileSystem.parseRunList(Uint8List.fromList([0x01, 0x05, 0x00]), 0);
      expect(runs.single.sparse, isTrue);
      expect(runs.single.clusters, 5);
    });

    test('düzeltme dizisi (fixup) sektör sonlarını GERİ YAZAR', () {
      final record = Uint8List(1024);
      record.setRange(0, 4, 'FILE'.codeUnits);
      final d = ByteData.sublistView(record);
      d.setUint16(4, 48, Endian.little); // dizi ofseti
      d.setUint16(6, 3, Endian.little); // sıra + 2 sektör
      record[48] = 0xAA; // sıra numarası
      record[49] = 0xBB;
      record[50] = 0x11; // 1. sektörün gerçek son iki baytı
      record[51] = 0x22;
      record[52] = 0x33;
      record[53] = 0x44;
      record[510] = 0xAA; // diskteki hâli: sıra numarası yazılı
      record[511] = 0xBB;
      record[1022] = 0xAA;
      record[1023] = 0xBB;
      final fixed =
          NtfsFileSystem.applyFixups(record, bytesPerSector: 512);
      expect([fixed[510], fixed[511]], [0x11, 0x22]);
      expect([fixed[1022], fixed[1023]], [0x33, 0x44]);
    });

    test('FILETIME epoch ms\'ye çevrilir', () {
      // 1601'den 1970'e 11.644.473.600 saniye.
      expect(NtfsFileSystem.fileTimeToMs(116444736000000000), 0);
      expect(NtfsFileSystem.fileTimeToMs(0), 0);
    });
  });
}
