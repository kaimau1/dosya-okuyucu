import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/apk_export.dart';
import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **Niye bu test var (kullanıcı isteği 2026-08-29: *"yüklü bir uygulamayı
/// APK'ya dönüştürüp başka birisine yükleyebilmek için paylaşma özelliği"*):**
///
/// İki şey sessizce yanlış gidebilir:
/// 1. **Ad üretimi.** Uygulama adları nokta, boşluk, eğik çizgi ve emoji
///    taşıyor ("Google Play Hizmetleri."); üretilen ad dosya sistemine
///    yazılamazsa paylaşma akışı en sonda patlar.
/// 2. **Parçalı (App Bundle) kurulum.** Yalnız `base.apk` paylaşılırsa karşı
///    tarafta "uygulama yüklenmedi" çıkar. Parçalı kaynakta çıktının BÜTÜN
///    parçaları taşıdığı burada ölçülüyor.
void main() {
  group('fileNameFor', () {
    test('ad + sürüm, tek parçada .apk uzantısı', () {
      expect(
        ApkExport.fileNameFor(
          appName: 'WhatsApp',
          versionName: '2.24.1',
          packageName: 'com.whatsapp',
          split: false,
        ),
        'WhatsApp 2.24.1.apk',
      );
    });

    test('parçalı kurulumda .apks uzantısı', () {
      expect(
        ApkExport.fileNameFor(
          appName: 'WhatsApp',
          versionName: '2.24.1',
          packageName: 'com.whatsapp',
          split: true,
        ),
        'WhatsApp 2.24.1.apks',
      );
    });

    test('sürüm bilinmiyorsa ada boşluk eklenmez', () {
      expect(
        ApkExport.fileNameFor(
          appName: 'Kamera',
          versionName: '   ',
          packageName: 'com.android.camera',
          split: false,
        ),
        'Kamera.apk',
      );
    });

    test('eğik çizgi ve nokta yığını dosya adını bozmaz', () {
      final name = ApkExport.fileNameFor(
        appName: 'Google Play Hizmetleri...',
        versionName: '24.1 / beta',
        packageName: 'com.google.android.gms',
        split: false,
      );
      expect(name.contains('/'), isFalse);
      expect(name.contains('\\'), isFalse);
      expect(name, 'Google Play Hizmetleri 24.1beta.apk');
    });

    test('ad tamamen eriyorse paket adına düşülür', () {
      expect(
        ApkExport.fileNameFor(
          appName: '///',
          versionName: '',
          packageName: 'com.example.app',
          split: false,
        ),
        'com.example.app.apk',
      );
    });
  });

  group('extract', () {
    late Directory tmp;

    setUp(() async {
      // `testWidgets` gövdesinde createTemp testi asar (bkz. HAFIZA
      // 2026-07-25 §F); düz `test` içinde de kurulum setUp'ta yapılıyor.
      tmp = await Directory.systemTemp.createTemp('apk_export');
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    Future<ApkSource> fakeInstall({required int splits}) async {
      final appDir = Directory(p.join(tmp.path, 'data', 'app', 'pkg-1'))
        ..createSync(recursive: true);
      final base = File(p.join(appDir.path, 'base.apk'))
        ..writeAsBytesSync(List<int>.filled(2048, 7));
      final parts = <String>[];
      for (var i = 0; i < splits; i++) {
        final f = File(p.join(appDir.path, 'split_config.$i.apk'))
          ..writeAsBytesSync(List<int>.filled(1024, i));
        parts.add(f.path);
      }
      return ApkSource(
        sourcePath: base.path,
        splitPaths: parts,
        label: 'Örnek',
        versionName: '1.2',
      );
    }

    test('parçasız kurulum: APK bit bit kopyalanır', () async {
      final source = await fakeInstall(splits: 0);
      final dest = p.join(tmp.path, 'cikti');
      final out = await ApkExport.extract(source, dest, packageName: 'a.b');

      expect(p.basename(out), 'Örnek 1.2.apk');
      // Özgün APK'nın aynısı olmalı: yeniden paketleme yok, imza bozulmaz.
      expect(File(out).readAsBytesSync(),
          File(source.sourcePath).readAsBytesSync());
    });

    test('parçalı kurulum: BÜTÜN parçalar .apks içine girer', () async {
      final source = await fakeInstall(splits: 2);
      final dest = p.join(tmp.path, 'cikti');
      final out = await ApkExport.extract(source, dest, packageName: 'a.b');

      expect(p.basename(out), 'Örnek 1.2.apks');
      // ZIP GERÇEKTEN açılıyor ve üç dosyanın İÇERİĞİ birebir duruyor —
      // ad aramak yetmez, karşı taraf dosyayı açacak.
      final zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
      final names = [for (final f in zip.files) p.basename(f.name)];
      expect(names, containsAll(<String>[
        'base.apk',
        'split_config.0.apk',
        'split_config.1.apk',
      ]));
      final base = zip.files.firstWhere((f) => f.name.endsWith('base.apk'));
      expect(base.content, File(source.sourcePath).readAsBytesSync());
    });

    test('parçalı kurulumda yalnız base.apk istenebilir', () async {
      final source = await fakeInstall(splits: 2);
      final dest = p.join(tmp.path, 'cikti');
      final out = await ApkExport.extract(source, dest,
          includeSplits: false, packageName: 'a.b');

      expect(p.basename(out), 'Örnek 1.2.apk');
      expect(File(out).lengthSync(), 2048);
    });

    test('aynı APK iki kez çıkarılınca üstüne YAZILMAZ', () async {
      final source = await fakeInstall(splits: 0);
      final dest = p.join(tmp.path, 'cikti');
      final first = await ApkExport.extract(source, dest, packageName: 'a.b');
      final second = await ApkExport.extract(source, dest, packageName: 'a.b');

      expect(first, isNot(second));
      expect(File(first).existsSync(), isTrue);
      expect(File(second).existsSync(), isTrue);
    });
  });
}
