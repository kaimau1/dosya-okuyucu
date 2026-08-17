import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/apk_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Gerçek bir PNG üretir (IHDR ölçüsü okunabilsin diye baytlar sahte olamaz).
Uint8List realPng(int w, int h) {
  final ihdr = BytesBuilder()
    ..add(_be32(w))
    ..add(_be32(h))
    ..add([8, 6, 0, 0, 0]);
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    for (var x = 0; x < w; x++) {
      raw.add([255, 0, 0, 255]);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', ihdr.toBytes()))
    ..add(_chunk('IDAT', const ZLibEncoder().encode(raw.toBytes())))
    ..add(_chunk('IEND', const []));
  return out.toBytes();
}

List<int> _be32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

List<int> _chunk(String type, List<int> data) {
  final body = <int>[...type.codeUnits, ...data];
  return [
    ..._be32(data.length),
    ...body,
    ..._be32(getCrc32(body)),
  ];
}

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

  group('ad eşleşmeyince KARE PNG yedeği', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('apk_icon_fb');
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

    test('PNG ölçüsü başlıktan okunur', () {
      expect(ApkIcon.pngSize(realPng(192, 192)), (192, 192));
      expect(ApkIcon.pngSize(realPng(320, 120)), (320, 120));
      // PNG olmayan bayt dizisi
      expect(ApkIcon.pngSize(Uint8List.fromList(List.filled(64, 7))), isNull);
    });

    /// `shrinkResources` açık derlenmiş APK'larda AAPT2 kaynak yollarını
    /// KISALTIYOR (`res/mipmap-xxxhdpi-v4/ic_launcher.png` → `res/hQ.png`);
    /// ada bakan eşleme o zaman boşa çıkıyor.
    test('kısaltılmış yolda bile kare simge bulunur', () {
      final path = writeApk('kisaltilmis.apk', {
        'res/hQ.png': realPng(192, 192),
        'res/aB.png': realPng(320, 120), // afiş — kare değil, elenmeli
        'classes.dex': Uint8List.fromList([9, 9, 9]),
      });
      final bytes = ApkIcon.readIconBytes(path);
      expect(bytes, isNotNull);
      expect(ApkIcon.pngSize(bytes!), (192, 192));
    });

    test('en KESKİN kare simge seçilir', () {
      final path = writeApk('coklu.apk', {
        'res/a.png': realPng(48, 48),
        'res/b.png': realPng(192, 192),
        'res/c.png': realPng(96, 96),
      });
      expect(ApkIcon.pngSize(ApkIcon.readIconBytes(path)!), (192, 192));
    });

    test('kare olmayan / ölçü dışı görseller seçilmez', () {
      final path = writeApk('afis.apk', {
        'res/banner.png': realPng(320, 120),
        'res/kucuk.png': realPng(16, 16), // 48 altı: simge değil
        'res/dev.png': realPng(1024, 1024), // 512 üstü: ekran görüntüsü
      });
      expect(ApkIcon.readIconBytes(path), isNull);
    });

    test('res/ DIŞINDAKİ kare PNG seçilmez', () {
      final path = writeApk('assets.apk', {
        'assets/flutter_assets/logo.png': realPng(192, 192),
      });
      expect(ApkIcon.readIconBytes(path), isNull);
    });

    test('ad eşleşmesi yedeğe TERCİH edilir', () {
      final path = writeApk('adli.apk', {
        'res/mipmap-xxxhdpi-v4/ic_launcher.png': realPng(96, 96),
        'res/zz.png': realPng(192, 192), // daha büyük ama adsız
      });
      // Ad eşleşen 96'lık kazanmalı: dosyanın kendi beyanı, tahminden üstün.
      expect(ApkIcon.pngSize(ApkIcon.readIconBytes(path)!), (96, 96));
    });
  });
}
