import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/apk_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Tek pikselli geçerli bir PNG (baytları önemli değil, gerçek zip girdisi
/// olması yeterli).
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
]);

void main() {
  group('APK simgesi yolu puanlaması', () {
    /// Kullanıcı 2026-08-17: *"apkların kendi simgeleri görülmeli"*.
    test('yalnız res/ altındaki png/webp aday olur', () {
      expect(ApkIcon.scoreIconPath('res/mipmap-hdpi/ic_launcher.png'),
          greaterThan(0));
      expect(ApkIcon.scoreIconPath('res/drawable-xhdpi/icon.webp'),
          greaterThan(0));
      // Aday değil: yanlış klasör, yanlış uzantı, alakasız ad.
      expect(ApkIcon.scoreIconPath('assets/ic_launcher.png'), 0);
      expect(ApkIcon.scoreIconPath('res/mipmap-anydpi-v26/ic_launcher.xml'), 0);
      expect(ApkIcon.scoreIconPath('res/drawable/arka_plan.png'), 0);
    });

    test('en yüksek yoğunluk kazanır (bulanık simge seçilmesin)', () {
      final xxxhdpi =
          ApkIcon.scoreIconPath('res/mipmap-xxxhdpi/ic_launcher.png');
      final mdpi = ApkIcon.scoreIconPath('res/mipmap-mdpi/ic_launcher.png');
      expect(xxxhdpi, greaterThan(mdpi));
    });

    test('düz ic_launcher, foreground/round varyantlarını yener', () {
      final plain = ApkIcon.scoreIconPath('res/mipmap-hdpi/ic_launcher.png');
      expect(plain,
          greaterThan(
              ApkIcon.scoreIconPath('res/mipmap-hdpi/ic_launcher_round.png')));
      expect(
          plain,
          greaterThan(ApkIcon.scoreIconPath(
              'res/mipmap-hdpi/ic_launcher_foreground.png')));
    });

    test('ic_launcher, genel icon.png\'den önce gelir', () {
      expect(ApkIcon.scoreIconPath('res/mipmap-mdpi/ic_launcher.png'),
          greaterThan(ApkIcon.scoreIconPath('res/drawable-xxxhdpi/icon.png')));
    });
  });

  group('APK zip\'inden simge çıkarma', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('apk_icon');
      ApkIcon.debugReset();
    });

    tearDown(() => removeTempDir(dir));

    String writeApk(String name, Map<String, Uint8List> entries) {
      final archive = Archive();
      for (final e in entries.entries) {
        archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
      }
      final path = p.join(dir.path, name);
      File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);
      return path;
    }

    test('en iyi aday çıkarılır', () {
      final path = writeApk('uygulama.apk', {
        'AndroidManifest.xml': Uint8List.fromList([1, 2, 3]),
        'res/mipmap-mdpi/ic_launcher.png': _png,
        'res/mipmap-xxxhdpi/ic_launcher.png': _png,
        'classes.dex': Uint8List.fromList([9, 9, 9]),
      });
      expect(ApkIcon.readIconBytes(path), isNotNull);
    });

    test('simgesiz APK null döner (çağıran glife düşer)', () {
      final path = writeApk('simgesiz.apk', {
        'AndroidManifest.xml': Uint8List.fromList([1, 2, 3]),
        'classes.dex': Uint8List.fromList([9, 9, 9]),
      });
      expect(ApkIcon.readIconBytes(path), isNull);
    });

    test('bozuk/zip olmayan dosya çökmez', () {
      final path = p.join(dir.path, 'bozuk.apk');
      File(path).writeAsBytesSync([0, 1, 2, 3, 4, 5]);
      expect(ApkIcon.readIconBytes(path), isNull);
    });

    test('olmayan dosya null döner', () {
      expect(ApkIcon.readIconBytes(p.join(dir.path, 'yok.apk')), isNull);
    });
  });
}
