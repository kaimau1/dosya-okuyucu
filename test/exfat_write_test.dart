import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/exfat_fs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';

/// **exFAT'a YAZMA** — 64 GB üstü bellekler ve SDXC kartlar bu biçimde.
///
/// exFAT'ın FAT'tan üç farkı var ve üçü de atlanırsa bellek Windows'ta bozuk
/// görünür: ayırma haritası, ad karması (büyük harf tablosuyla) ve girdi
/// kümesi sağlaması. Testlerin ölçütü yine "imaj yeniden okunduğunda tutarlı".
Future<Uint8List> readAll(Stream<Uint8List> s) async {
  final b = BytesBuilder();
  await for (final chunk in s) {
    b.add(chunk);
  }
  return b.takeBytes();
}

void main() {
  late Uint8List image;
  late ExfatFileSystem fs;

  Future<void> reopen() async {
    fs = await ExfatFileSystem.open(MemoryBlockDevice(image));
  }

  setUp(() async {
    image = UsbImage.exfat(files: [ImgFile('mevcut.txt', [1, 2, 3])]);
    await reopen();
  });

  test('yazılan dosya yeniden açıldığında listede ve birebir', () async {
    final data = Uint8List.fromList(
        List<int>.generate(1500, (i) => (i * 5) % 256));
    await fs.writeFileStream(
        fs.rootId, 'video kaydı.mp4', Stream.value(data), data.length);

    await reopen();
    final root = await fs.listDir(fs.rootId);
    final entry = root.firstWhere((e) => e.name == 'video kaydı.mp4');
    expect(entry.sizeBytes, 1500);
    expect(await readAll(fs.openRead(entry)), data);
  });

  test('mevcut dosya ve etiket bozulmaz', () async {
    await fs.writeFile(fs.rootId, 'yeni.bin', Uint8List.fromList([7, 7]));
    await reopen();
    expect(fs.label, 'TYPEC 64');
    final root = await fs.listDir(fs.rootId);
    final old = root.firstWhere((e) => e.name == 'mevcut.txt');
    expect(await readAll(fs.openRead(old)), [1, 2, 3]);
  });

  test('silinen dosya listeden çıkar, KÜMELERİ haritada boşa döner',
      () async {
    await fs.writeFile(
        fs.rootId, 'gecici.bin', Uint8List.fromList(List<int>.filled(1200, 3)));
    await reopen();
    var root = await fs.listDir(fs.rootId);
    final entry = root.firstWhere((e) => e.name == 'gecici.bin');
    await fs.deleteEntry(fs.rootId, entry);

    await reopen();
    root = await fs.listDir(fs.rootId);
    expect(root.any((e) => e.name == 'gecici.bin'), isFalse);
    // Boşalan yer yeniden dağıtılabiliyor mu? (Harita güncellenmediyse
    // "bellekte yer yok" derdi.)
    await fs.writeFile(fs.rootId, 'ikinci.bin', Uint8List.fromList([1]));
    await reopen();
    root = await fs.listDir(fs.rootId);
    expect(root.any((e) => e.name == 'ikinci.bin'), isTrue);
  });

  test('SİLİNEN girdinin arkasındaki dosyalar KAYBOLMAZ', () async {
    // Girdiyi sıfırlamak "dizin sonu" demektir; arkasındaki her şey görünmez
    // olurdu. Doğrusu yalnız "kullanımda" bitini düşürmek.
    await fs.writeFile(fs.rootId, 'bir.txt', Uint8List.fromList([1]));
    await fs.writeFile(fs.rootId, 'iki.txt', Uint8List.fromList([2]));
    await reopen();
    var root = await fs.listDir(fs.rootId);
    await fs.deleteEntry(
        fs.rootId, root.firstWhere((e) => e.name == 'bir.txt'));
    await reopen();
    root = await fs.listDir(fs.rootId);
    expect(root.map((e) => e.name), contains('iki.txt'));
    expect(root.map((e) => e.name), contains('mevcut.txt'));
  });

  test('klasör açılır, içine yazılır ve gezilir', () async {
    final dir = await fs.createDirectory(fs.rootId, 'Kayıtlar');
    await fs.writeFile(dir.id, 'not.txt', Uint8List.fromList([5, 6]));
    await reopen();
    final root = await fs.listDir(fs.rootId);
    final found = root.firstWhere((e) => e.name == 'Kayıtlar');
    expect(found.isDir, isTrue);
    final children = await fs.listDir(found.id);
    expect(children.map((e) => e.name), ['not.txt']);
    expect(await readAll(fs.openRead(children.single)), [5, 6]);
  });

  test('yeniden adlandırma veriyi taşımaz', () async {
    final data = Uint8List.fromList(List<int>.generate(700, (i) => i % 256));
    await fs.writeFile(fs.rootId, 'eski.bin', data);
    await reopen();
    var root = await fs.listDir(fs.rootId);
    final entry = root.firstWhere((e) => e.name == 'eski.bin');
    final cluster = (entry.id as ExfatLocation).firstCluster;
    await fs.renameEntry(fs.rootId, entry, 'yeni türkçe ad.bin');

    await reopen();
    root = await fs.listDir(fs.rootId);
    final renamed = root.firstWhere((e) => e.name == 'yeni türkçe ad.bin');
    expect((renamed.id as ExfatLocation).firstCluster, cluster);
    expect(await readAll(fs.openRead(renamed)), data);
  });

  group('saf çözümleyiciler', () {
    test('girdi kümesi sağlaması 2-3. baytları ATLAR', () {
      // Atlamasaydı değer kendisine bağımlı olur ve hiçbir zaman tutmazdı.
      final entries = ExfatFileSystem.buildEntrySet(
        'deneme.txt',
        isDir: false,
        firstCluster: 5,
        size: 10,
        nameHash: 0x1234,
        timestamp: DateTime(2020, 1, 1, 12),
      );
      final stored =
          ByteData.sublistView(entries).getUint16(2, Endian.little);
      expect(ExfatFileSystem.setChecksum(entries), stored);
    });

    test('büyük harf tablosunun SIKIŞTIRMASI çözülür', () {
      // 0xFFFF + N = "N karakter kendisi gibi kalır".
      final raw = Uint8List(10);
      final d = ByteData.sublistView(raw);
      d.setUint16(0, 0xFFFF, Endian.little);
      d.setUint16(2, 3, Endian.little); // 0,1,2 kimlik
      d.setUint16(4, 0x0041, Endian.little); // 3 → 'A'
      d.setUint16(6, 0xFFFF, Endian.little);
      d.setUint16(8, 2, Endian.little); // 4,5 kimlik
      final table = ExfatFileSystem.decodeUpcase(raw);
      expect(table.sublist(0, 3), [0, 1, 2]);
      expect(table[3], 0x41);
      expect(table.sublist(4, 6), [4, 5]);
    });

    test('girdi kümesinde ad parçaları 15 karakterlik bölünür', () {
      final entries = ExfatFileSystem.buildEntrySet(
        'çok uzun bir dosya adı örneği.docx', // 33 karakter → 3 ad girdisi
        isDir: false,
        firstCluster: 2,
        size: 0,
        nameHash: 0,
        timestamp: DateTime(2020),
      );
      expect(entries.length, 32 * (2 + 3));
      expect(entries[1], 4, reason: 'ikincil girdi sayısı: 1 akış + 3 ad');
    });
  });
}
