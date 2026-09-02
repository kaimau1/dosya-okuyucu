import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/usb_fs.dart';
import 'package:dosya_okuyucu/services/fm/usb/block_device.dart';
import 'package:dosya_okuyucu/services/fm/usb/fat_fs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/usb_image.dart';
import 'support/temp_dir.dart';

/// **Ham USB yığınının UÇTAN UCA testi** — Kotlin köprüsü hariç her katman.
///
/// `UsbFs` gezgin ekranının gördüğü yüzdür: listeleme, indirme, yükleme,
/// silme, yeniden adlandırma. Aşağıdaki testler sentetik bir FAT32 imajı
/// üstünde bu yüzü sürüyor; yani ekranın çağırdığı yolun tamamı (RemoteFs →
/// UsbFs → FatFileSystem → BlockDevice) gerçek verilerle çalışıyor.
void main() {
  late Uint8List image;
  late UsbFs fs;
  late Directory tmp;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('usbfs');
    image = UsbImage.fat32(
      label: 'GEZI',
      files: [
        ImgFile('rapor.pdf', List<int>.generate(400, (i) => i % 256)),
      ],
      dirs: [
        ImgDir('Fotoğraflar', [ImgFile('kedi.jpg', [1, 2, 3, 4])]),
      ],
    );
    final device = CachedBlockDevice(MemoryBlockDevice(image));
    fs = UsbFs(
      fs: await FatFileSystem.open(device),
      device: device,
      label: 'GEZI',
    );
    await fs.connect();
  });

  tearDown(() => removeTempDir(tmp));

  test('kök listelenir; klasörler önce gelir', () async {
    final entries = await fs.list('/');
    expect(entries.first.isDir, isTrue);
    expect(entries.map((e) => e.name), containsAll(['Fotoğraflar', 'rapor.pdf']));
  });

  test('alt klasör gezilir', () async {
    await fs.list('/');
    final children = await fs.list('/Fotoğraflar');
    expect(children.single.name, 'kedi.jpg');
  });

  test('GEZİLMEMİŞ klasör açılamaz (tutamak yoldan hesaplanamaz)', () async {
    // FAT'ta bir klasörün tutamağı ilk kümesidir; yoldan türetilemez. Ekran
    // yalnız gezerek öğrendiği klasörleri açabilir — uydurma bir tutamakla
    // rastgele bir kümeyi dizin sanmak felaket olurdu.
    expect(() => fs.list('/HicGorulmedi'),
        throwsA(isA<RemoteException>()));
  });

  test('dosya telefona indirilir (içerik birebir)', () async {
    final entries = await fs.list('/');
    final entry = entries.firstWhere((e) => e.name == 'rapor.pdf');
    final local = await fs.download(entry, '${tmp.path}/rapor.pdf');
    expect(local.readAsBytesSync().length, 400);
    expect(local.readAsBytesSync().first, 0);
  });

  test('telefondan yükleme belleğe YAZILIR ve listede görünür', () async {
    await fs.list('/');
    final local = File('${tmp.path}/yeni.txt')..writeAsStringSync('merhaba');
    await fs.upload(local, '/');
    final entries = await fs.list('/');
    final added = entries.firstWhere((e) => e.name == 'yeni.txt');
    expect(added.sizeBytes, 7);

    final back = await fs.download(added, '${tmp.path}/geri.txt');
    expect(back.readAsStringSync(), 'merhaba');
  });

  test('klasör açılır, dosya silinir, ad değişir', () async {
    await fs.list('/');
    await fs.makeDirectory('/Yedek');
    var entries = await fs.list('/');
    expect(entries.any((e) => e.name == 'Yedek' && e.isDir), isTrue);

    final entry = entries.firstWhere((e) => e.name == 'rapor.pdf');
    await fs.rename(entry, 'sunum.pdf');
    entries = await fs.list('/');
    expect(entries.any((e) => e.name == 'sunum.pdf'), isTrue);
    expect(entries.any((e) => e.name == 'rapor.pdf'), isFalse);

    await fs.delete(entries.firstWhere((e) => e.name == 'sunum.pdf'));
    entries = await fs.list('/');
    expect(entries.any((e) => e.name == 'sunum.pdf'), isFalse);
  });

  test('FAT bellek YAZILABİLİR sayılır (arayüz düğmeleri açık)', () {
    expect(fs.canWrite, isTrue);
  });

  test('doluluk okunur ve akla yatkın', () async {
    final usage = await fs.usage();
    expect(usage, isNotNull);
    final (total, free) = usage!;
    expect(total, greaterThan(0));
    expect(free, greaterThan(0));
    expect(free, lessThanOrEqualTo(total));
  });
}
