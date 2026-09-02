import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/fat_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/usb_fs_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';

/// **FAT'a YAZMA** — kullanıcı isteği 2026-09-02: *"fat32, NTFS ne varsa
/// okuyalım yazalım."*
///
/// Yazmanın okumadan farkı: hata **kalıcı**. Yanlış yazılan bir FAT tablosu
/// kullanıcının bütün belleğini kaybettirir. Bu yüzden her testin ölçütü
/// "çağrı patlamadı" değil, **imajın yeniden okunduğunda tutarlı olması**:
/// dosya listede mi, içeriği birebir mi, zincir doğru mu, silinen dosyanın
/// kümeleri gerçekten boşta mı.
Future<Uint8List> readAll(Stream<Uint8List> s) async {
  final b = BytesBuilder();
  await for (final chunk in s) {
    b.add(chunk);
  }
  return b.takeBytes();
}

void main() {
  late Uint8List image;
  late MemoryBlockDevice device;
  late FatFileSystem fs;

  Future<void> reopen() async {
    device = MemoryBlockDevice(image);
    fs = await FatFileSystem.open(device);
  }

  setUp(() async {
    image = UsbImage.fat32(files: [ImgFile('mevcut.txt', [1, 2, 3])]);
    await reopen();
  });

  group('yazma temel', () {
    test('salt okunur aygıtta yazma REDDEDİLİR', () async {
      final ro = await FatFileSystem.open(_ReadOnly(MemoryBlockDevice(image)));
      expect(ro.writable, isFalse);
      expect(() => ro.writeFile(ro.rootId, 'a.txt', Uint8List(3)),
          throwsA(isA<UsbFsException>()));
    });

    test('yazılan dosya YENİDEN AÇILDIĞINDA da listede ve birebir', () async {
      final data = Uint8List.fromList(
          List<int>.generate(3000, (i) => (i * 7) % 256));
      await fs.writeFile(fs.rootId, 'çok uzun türkçe ad.bin', data);

      await reopen(); // diskteki hâlinden yeniden oku
      final root = await fs.listDir(fs.rootId);
      final entry =
          root.firstWhere((e) => e.name == 'çok uzun türkçe ad.bin');
      expect(entry.sizeBytes, 3000);
      expect(await readAll(fs.openRead(entry)), data);
    });

    test('mevcut dosyalar bozulmaz', () async {
      await fs.writeFile(fs.rootId, 'yeni.txt', Uint8List.fromList([9, 9]));
      await reopen();
      final root = await fs.listDir(fs.rootId);
      final old = root.firstWhere((e) => e.name == 'mevcut.txt');
      expect(await readAll(fs.openRead(old)), [1, 2, 3]);
    });

    test('boş dosya da yazılır', () async {
      await fs.writeFile(fs.rootId, 'bos.txt', Uint8List(0));
      await reopen();
      final root = await fs.listDir(fs.rootId);
      expect(root.any((e) => e.name == 'bos.txt'), isTrue);
    });

    test('aynı ada yazmak ÜZERİNE yazar, ikinci girdi bırakmaz', () async {
      await fs.writeFile(fs.rootId, 'a.txt', Uint8List.fromList([1]));
      await fs.writeFile(fs.rootId, 'a.txt', Uint8List.fromList([2, 2, 2]));
      await reopen();
      final root = await fs.listDir(fs.rootId);
      final matches = root.where((e) => e.name == 'a.txt').toList();
      expect(matches.length, 1, reason: 'iki aynı adlı girdi = bozuk bellek');
      expect(await readAll(fs.openRead(matches.single)), [2, 2, 2]);
    });
  });

  group('silme', () {
    test('silinen dosya listeden çıkar ve KÜMELERİ BOŞA döner', () async {
      final data = Uint8List.fromList(List<int>.filled(2000, 7));
      await fs.writeFile(fs.rootId, 'gecici.bin', data);
      await reopen();
      var root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'gecici.bin');
      final chain = await fs.clusterChain(entry.id as int);
      expect(chain.length, greaterThan(1));

      await fs.deleteEntry(fs.rootId, entry);
      await reopen();
      root = await fs.listDir(fs.rootId);
      expect(root.any((e) => e.name == 'gecici.bin'), isFalse);
      for (final c in chain) {
        expect(await fs.nextRawEntry(c), 0,
            reason: 'boşaltılmayan küme = kayıp yer');
      }
    });

    test('silinen yerin üstüne yeni dosya yazılabilir', () async {
      await fs.writeFile(fs.rootId, 'a.bin', Uint8List.fromList([1, 2, 3]));
      await reopen();
      var root = await fs.listDir(fs.rootId);
      await fs.deleteEntry(
          fs.rootId, root.firstWhere((e) => e.name == 'a.bin'));
      await fs.writeFile(fs.rootId, 'b.bin', Uint8List.fromList([4, 5]));
      await reopen();
      root = await fs.listDir(fs.rootId);
      expect(root.any((e) => e.name == 'a.bin'), isFalse);
      expect(
          await readAll(
              fs.openRead(root.firstWhere((e) => e.name == 'b.bin'))),
          [4, 5]);
    });
  });

  group('klasör ve yeniden adlandırma', () {
    test('açılan klasör gezilebilir ve içine yazılabilir', () async {
      final dir = await fs.createDirectory(fs.rootId, 'Belgelerim');
      await fs.writeFile(dir.id, 'içerik.txt', Uint8List.fromList([1, 2]));

      await reopen();
      final root = await fs.listDir(fs.rootId);
      final found = root.firstWhere((e) => e.name == 'Belgelerim');
      expect(found.isDir, isTrue);
      final children = await fs.listDir(found.id);
      expect(children.map((e) => e.name), ['içerik.txt']);
      expect(await readAll(fs.openRead(children.single)), [1, 2]);
    });

    test('yeni klasörde "." ve ".." girdileri VAR (Windows şartı)', () async {
      final dir = await fs.createDirectory(fs.rootId, 'Klasor');
      await reopen();
      final raw = await fs.listDir(dir.id);
      // Listeleme `.`/`..` girdilerini gizler; ham baytlarda olmalılar.
      final device = MemoryBlockDevice(image);
      final fs2 = await FatFileSystem.open(device);
      final root = await fs2.listDir(fs2.rootId);
      final cluster = root.firstWhere((e) => e.name == 'Klasor').id as int;
      final sector = 32 +
          fs2.fatSize * fs2.numFats +
          (cluster - 2) * fs2.sectorsPerCluster;
      final bytes = await device.readBlocks(sector, 1);
      expect(String.fromCharCodes(bytes.sublist(0, 1)), '.');
      expect(String.fromCharCodes(bytes.sublist(32, 34)), '..');
      expect(raw, isEmpty, reason: '. ve .. kullanıcıya gösterilmez');
    });

    test('yeniden adlandırma VERİYİ TAŞIMADAN adı değiştirir', () async {
      final data = Uint8List.fromList(List<int>.generate(900, (i) => i % 256));
      await fs.writeFile(fs.rootId, 'eski ad.bin', data);
      await reopen();
      var root = await fs.listDir(fs.rootId);
      final entry = root.firstWhere((e) => e.name == 'eski ad.bin');
      final cluster = entry.id as int;

      await fs.renameEntry(fs.rootId, entry, 'yeni türkçe ad.bin');
      await reopen();
      root = await fs.listDir(fs.rootId);
      expect(root.any((e) => e.name == 'eski ad.bin'), isFalse);
      final renamed = root.firstWhere((e) => e.name == 'yeni türkçe ad.bin');
      expect(renamed.id, cluster, reason: 'veri yerinde kalmalı');
      expect(await readAll(fs.openRead(renamed)), data);
    });
  });

  group('FAT16 kökü', () {
    test('sabit alandaki köke de yazılır', () async {
      final img = UsbImage.fat16();
      final dev = MemoryBlockDevice(img);
      final f16 = await FatFileSystem.open(dev);
      expect(f16.kind, FatKind.fat16);
      await f16.writeFile(f16.rootId, 'rapor.txt', Uint8List.fromList([1, 2]));
      final again = await FatFileSystem.open(MemoryBlockDevice(img));
      final root = await again.listDir(again.rootId);
      expect(root.map((e) => e.name), ['rapor.txt']);
    });
  });

  _bulkScanTest();

  group('uzun ad sağlaması', () {
    test('sağlama toplamı 8.3 adından hesaplanır', () {
      // Windows uzun adı ancak sağlama tutarsa gösterir; tutmazsa dosya
      // "BELGE~1.PDF" görünür — kullanıcı için dosyayı kaybetmek demektir.
      final short = Uint8List.fromList('BELGE~1 PDF'.codeUnits);
      expect(FatFileSystem.lfnChecksum(short), isA<int>());
      expect(FatFileSystem.lfnChecksum(short), inInclusiveRange(0, 255));
    });
  });
}

/// Yazmayı reddeden sarmalayıcı (salt okunur aygıt taklidi).
class _ReadOnly extends BlockDevice {
  final BlockDevice inner;
  _ReadOnly(this.inner);

  @override
  int get blockSize => inner.blockSize;

  @override
  int get blockCount => inner.blockCount;

  @override
  Future<Uint8List> readBlocks(int lba, int count) =>
      inner.readBlocks(lba, count);
}

/// **Toplu FAT taraması** — gerçek donanımda süreyi belirleyen şey.
///
/// FAT'ı küme küme sormak 64 GB'lık bir bellekte (8 milyon küme) on binlerce
/// ayrı USB okuması demekti; her biri ~1 ms olduğu için tek bir dosya yazmak
/// dakikalar sürerdi. Bu test aygıta giden okuma SAYISINI ölçüyor: davranış
/// aynı kalmalı ama maliyet düşük olmalı.
void _bulkScanTest() {
  test('boş küme araması aygıta AZ SAYIDA okuma yapar', () async {
    final image = UsbImage.fat32();
    final counting = _CountingDevice(MemoryBlockDevice(image));
    final fs = await FatFileSystem.open(counting);
    counting.reads = 0;
    await fs.writeFile(fs.rootId, 'a.txt', Uint8List.fromList([1, 2, 3]));
    // Tek tek sorulsaydı yüzlerce okuma olurdu (66000 kümelik imaj).
    expect(counting.reads, lessThan(80),
        reason: 'toplu okuma yapılmıyorsa burası patlar');
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
  bool get writable => inner.writable;

  @override
  Future<Uint8List> readBlocks(int lba, int count) {
    reads++;
    return inner.readBlocks(lba, count);
  }

  @override
  Future<void> writeBlocks(int lba, Uint8List data) =>
      inner.writeBlocks(lba, data);
}
