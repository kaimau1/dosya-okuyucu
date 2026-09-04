import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/apk_icon.dart';
import 'package:dosya_okuyucu/services/fm/apk_resources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fm_apk_icon_test.dart' show realPng;
import 'support/apk_binaries.dart';
import 'support/temp_dir.dart';

/// **APK simgesi: manifest + `resources.arsc` yolu** (kullanıcı 2026-09-03:
/// *"bizim uygulamanın simgesi görülmüyor, başka uygulamalarda da
/// görünmeyenler var"*).
///
/// Kök neden: simge dosya ADINA bakılarak aranıyordu; kaynak küçültmesiyle
/// derlenen APK'larda (bizimki dahil) AAPT2 yolları `res/o-.png` gibi
/// kısaltıyor. Ada bakmayan yedek ise "en büyük kare PNG"yi seçtiği için
/// uyarlanabilir simgenin düz renkli ZEMİN katmanını buluyordu — ekranda
/// görünen boş turkuaz kare buydu.
///
/// Buradaki testler doğru yolu sürüyor: manifest'teki `application@icon`
/// kimliği → tablo → dosya. İkili biçimler `support/apk_binaries.dart`ta elle
/// üretiliyor (gerçek bir APK fikstürü tek başına 400 KB olurdu).
void main() {
  // Tür kimliği 1 = `mipmap` (tablo türleri 1'den başlar; gerçek APK'da da
  // öyle). Girdi kimliği düşük tutuluyor: üreteç o indise kadar yer ayırıyor.
  const iconId = 0x7F010000;

  group('ikili XML (AndroidManifest)', () {
    test('application@icon kaynak kimliği okunur', () {
      final elements =
          AndroidBinaryXml.parse(ApkBinaries.manifest(iconResId: iconId));
      final app = elements.firstWhere((e) => e.name == 'application');
      final icon = app.byResId[AndroidBinaryXml.attrIcon];
      expect(icon, isNotNull);
      expect(icon!.isReference, isTrue);
      expect(icon.data, iconId);
    });

    test('öznitelik adı da çözülür (havuz kısaltılmamışsa)', () {
      final elements =
          AndroidBinaryXml.parse(ApkBinaries.manifest(iconResId: iconId));
      final app = elements.firstWhere((e) => e.name == 'application');
      expect(app.byName['icon']?.data, iconId);
    });

    test('bozuk baytlar çökmez, boş liste döner', () {
      expect(AndroidBinaryXml.parse(Uint8List.fromList([1, 2, 3])), isEmpty);
      expect(AndroidBinaryXml.parse(Uint8List(0)), isEmpty);
    });
  });

  group('kaynak tablosu (resources.arsc)', () {
    test('kimlik dosya yoluna çevrilir', () {
      final table = ArscTable.parse(ApkBinaries.table(files: {
        iconId: [(160, 'res/a.png'), (640, 'res/o-.png')],
      }));
      expect(table, isNotNull);
      expect(table!.bestFile(iconId), 'res/o-.png');
    });

    test('EN YÜKSEK yoğunluk seçilir (bulanık simge gelmesin)', () {
      final table = ArscTable.parse(ApkBinaries.table(files: {
        iconId: [
          (160, 'res/mdpi.png'),
          (480, 'res/xxhdpi.png'),
          (320, 'res/xhdpi.png'),
        ],
      }));
      expect(table!.bestFile(iconId), 'res/xxhdpi.png');
    });

    test('raster varken anydpi XML seçilmez', () {
      final table = ArscTable.parse(ApkBinaries.table(files: {
        iconId: [
          (640, 'res/o-.png'),
          (ArscTable.anyDensity, 'res/BW.xml'),
        ],
      }));
      expect(table!.bestFile(iconId), 'res/o-.png');
      // XML'i açıkça isteyen (uyarlanabilir simge) yine bulabilmeli.
      expect(table.bestFile(iconId, xml: false), 'res/o-.png');
    });

    test('yalnız XML varsa o döner', () {
      final table = ArscTable.parse(ApkBinaries.table(files: {
        iconId: [(ArscTable.anyDensity, 'res/BW.xml')],
      }));
      expect(table!.bestFile(iconId), 'res/BW.xml');
      expect(table.bestFile(iconId, xml: false), isNull);
    });

    test('kaynak adı kısaltılmış yolda bile korunur', () {
      final table = ArscTable.parse(ApkBinaries.table(files: {
        iconId: [(640, 'res/o-.png')],
      }));
      expect(table!.lookup(iconId).first.name, 'ic_launcher');
      expect(table.lookup(iconId).first.type, 'mipmap');
    });

    test('bozuk tablo null döner', () {
      expect(ArscTable.parse(Uint8List.fromList([9, 9, 9, 9])), isNull);
    });
  });

  group('uçtan uca: kısaltılmış yollu APK', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('apk_resources');
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

    /// **Kullanıcının bildirdiği hatanın birebir kurgusu:** hiçbir dosya adı
    /// `ic_launcher` içermiyor ve en büyük kare PNG simge DEĞİL (zemin
    /// katmanı). Ad eşlemesi ve kare-PNG yedeği ikisi de yanlış cevabı
    /// verirdi; tablo doğrusunu veriyor.
    test('simge, en büyük kare PNG değil TABLODAKİ kaynaktır', () {
      final path = writeApk('kisaltilmis.apk', {
        'AndroidManifest.xml': ApkBinaries.manifest(iconResId: iconId),
        'resources.arsc': ApkBinaries.table(files: {
          iconId: [(640, 'res/o-.png')],
        }),
        'res/o-.png': realPng(192, 192), // gerçek simge
        'res/zz.png': realPng(432, 432), // zemin katmanı: daha BÜYÜK ve kare
        'classes.dex': Uint8List.fromList([9, 9, 9]),
      });
      final bytes = ApkIcon.readIconBytes(path);
      expect(bytes, isNotNull);
      expect(ApkIcon.pngSize(bytes!), (192, 192),
          reason: 'tablo "res/o-.png" diyor; 432lik zemin seçilmemeli');
    });

    test('tablo yoksa eski ad eşlemesi çalışmaya devam eder', () {
      final path = writeApk('eski.apk', {
        'AndroidManifest.xml': Uint8List.fromList([1, 2, 3]),
        'res/mipmap-xxxhdpi/ic_launcher.png': realPng(192, 192),
      });
      expect(ApkIcon.pngSize(ApkIcon.readIconBytes(path)!), (192, 192));
    });

    /// Uyarlanabilir simge: kimlik XML'e çıkıyor, katmanlar birleştiriliyor.
    /// Sonuç kare ve **ortadan kırpılmış** (108 dp tuvalin görünen 72 dp'si).
    test('uyarlanabilir simge katmanları birleştirilir', () {
      const backgroundId = 0x7F020000;
      const foregroundId = 0x7F020001;
      final path = writeApk('uyarlanabilir.apk', {
        'AndroidManifest.xml': ApkBinaries.manifest(iconResId: iconId),
        'resources.arsc': ApkBinaries.table(files: {
          iconId: [(ArscTable.anyDensity, 'res/ic.xml')],
          backgroundId: [(640, 'res/bg.png')],
          foregroundId: [(640, 'res/fg.png')],
        }),
        'res/ic.xml': ApkBinaries.adaptiveIcon(
          backgroundResId: backgroundId,
          foregroundResId: foregroundId,
        ),
        'res/bg.png': realPng(108, 108),
        'res/fg.png': realPng(108, 108),
      });
      final bytes = ApkIcon.readIconBytes(path);
      expect(bytes, isNotNull);
      final size = ApkIcon.pngSize(bytes!);
      expect(size, isNotNull);
      expect(size!.$1, size.$2, reason: 'simge kare olmalı');
      expect(size.$1, 72, reason: '108 dp tuvalin görünen 72 dp\'si');
    });

    /// Ön plan çizilemiyorsa (vektör katman) BİRLEŞTİRME yapılmaz: elde
    /// kalan tek şey zemin katmanıdır ve onu "simge" diye sunmak tam da
    /// düzeltmeye çalıştığımız görüntü olurdu. Akış eski sezgisel yola
    /// düşüyor — bilinen sınır, sessiz bir yanlış değil.
    test('ön plan çözülemezse birleştirme yapılmaz', () {
      const backgroundId = 0x7F020000;
      const foregroundId = 0x7F020001;
      final path = writeApk('vektor.apk', {
        'AndroidManifest.xml': ApkBinaries.manifest(iconResId: iconId),
        'resources.arsc': ApkBinaries.table(files: {
          iconId: [(ArscTable.anyDensity, 'res/ic.xml')],
          backgroundId: [(640, 'res/bg.png')],
          foregroundId: [(ArscTable.anyDensity, 'res/fg.xml')],
        }),
        'res/ic.xml': ApkBinaries.adaptiveIcon(
          backgroundResId: backgroundId,
          foregroundResId: foregroundId,
        ),
        'res/bg.png': realPng(108, 108),
        'res/fg.xml': Uint8List.fromList([3, 0, 8, 0]),
      });
      final bytes = ApkIcon.readIconBytes(path);
      // Birleştirme yapılmadığının kanıtı: sonuç 72 px'lik kırpılmış simge
      // DEĞİL, eski yedeğin bulduğu 108 px'lik ham katman.
      expect(ApkIcon.pngSize(bytes!), (108, 108));
    });

    /// **Kullanıcının 2026-09-03'te bildirdiği kalan hata:** ön plan bir
    /// VEKTÖR çizim olduğunda (Android Studio'nun ürettiği her varsayılan
    /// simge böyle) birleştirme vazgeçiyor, geriye zemin katmanı ya da
    /// hiçbir şey kalıyordu — listede boş kare. Artık vektör çiziliyor.
    test('vektör ön planlı uyarlanabilir simge çizilir', () {
      const backgroundId = 0x7F020000;
      const foregroundId = 0x7F020001;
      final path = writeApk('vektor_on_plan.apk', {
        'AndroidManifest.xml': ApkBinaries.manifest(iconResId: iconId),
        'resources.arsc': ApkBinaries.table(files: {
          iconId: [(ArscTable.anyDensity, 'res/ic.xml')],
          backgroundId: [(640, 'res/bg.png')],
          foregroundId: [(ArscTable.anyDensity, 'res/fg.xml')],
        }),
        'res/ic.xml': ApkBinaries.adaptiveIcon(
          backgroundResId: backgroundId,
          foregroundResId: foregroundId,
        ),
        'res/bg.png': realPng(108, 108),
        'res/fg.xml': ApkBinaries.vectorDrawable(
          pathData: 'M4,4 L20,4 L20,20 L4,20 Z',
          fillColor: 0xFFFF0000,
        ),
      });
      final bytes = ApkIcon.readIconBytes(path);
      expect(bytes, isNotNull);
      final size = ApkIcon.pngSize(bytes!);
      expect(size, isNotNull);
      expect(size!.$1, size.$2, reason: 'simge kare olmalı');
      // Kırpılmış uyarlanabilir simge: 192'nin görünen 72/108'i = 128.
      expect(size.$1, 128, reason: 'vektör ön plan 192 px çizilip kırpıldı');
    });

    /// Simge kimliği doğrudan bir vektöre çıkıyorsa (uyarlanabilir simge
    /// katmanı değil, simgenin kendisi) o da çizilmeli.
    test('doğrudan vektör simge çizilir', () {
      final path = writeApk('duz_vektor.apk', {
        'AndroidManifest.xml': ApkBinaries.manifest(iconResId: iconId),
        'resources.arsc': ApkBinaries.table(files: {
          iconId: [(ArscTable.anyDensity, 'res/ic.xml')],
        }),
        'res/ic.xml': ApkBinaries.vectorDrawable(
          pathData: 'M2,2 L22,2 L22,22 L2,22 Z',
        ),
      });
      final bytes = ApkIcon.readIconBytes(path);
      expect(bytes, isNotNull);
      expect(ApkIcon.pngSize(bytes!), (192, 192));
    });
  });
}
