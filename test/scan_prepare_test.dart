import 'dart:io';

import 'package:dosya_okuyucu/screens/scan_edit_screen.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';
import 'package:dosya_okuyucu/services/scan_prepare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Tarama hazırlığı (2026-10-17 kullanıcı: *"belge taramada kesme sorunu ve
/// direk kaydetmesi gerekli"*): tarayıcıdan gelen sayfa KIRPILMADAN
/// hazırlanmalı — ML Kit sayfayı zaten kâğıdın kenarından kırptı.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scan_prepare_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// İçinde kalın bir TABLO çerçevesi olan, kırpılmış belge sayfası. Eski
  /// `ScanDeskew` bu çerçeveyi "kâğıt" sanıp dışındaki başlığı/imzayı
  /// kesiyordu.
  String framedPage({int width = 600, int height = 840}) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(250, 250, 248));
    // Başlık (çerçevenin DIŞINDA, en üstte).
    img.fillRect(image,
        x1: 60, y1: 20, x2: 540, y2: 44, color: img.ColorRgb8(30, 30, 30));
    // İç çerçeve: sayfanın ~%70'i.
    img.drawRect(image,
        x1: 60,
        y1: 110,
        x2: 540,
        y2: 700,
        color: img.ColorRgb8(10, 10, 10),
        thickness: 6);
    for (var y = 140; y < 680; y += 28) {
      img.fillRect(image,
          x1: 90, y1: y, x2: 500, y2: y + 7, color: img.ColorRgb8(40, 40, 40));
    }
    // İmza (çerçevenin DIŞINDA, en altta).
    img.fillRect(image,
        x1: 380, y1: 770, x2: 540, y2: 800, color: img.ColorRgb8(20, 20, 90));
    final path = p.join(dir.path, 'sayfa.jpg');
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 95));
    return path;
  }

  ScanPrepareRequest request(String source, ScanFilter filter,
          {bool straighten = true}) =>
      ScanPrepareRequest(
        sourcePath: source,
        straightTarget: p.join(dir.path, 'duz.jpg'),
        displayTarget: p.join(dir.path, 'gorunen.jpg'),
        filter: filter,
        straighten: straighten,
      );

  test('netleştirilen sayfa KIRPILMAZ: boyut aynı, başlık ve imza yerinde', () {
    final source = framedPage();
    final page = ScanPrepare.runRequest(request(source, ScanFilter.auto));
    expect(page.filter, ScanFilter.auto);
    expect(page.display, isNot(source));
    final out = img.decodeJpg(File(page.display).readAsBytesSync())!;
    expect(out.width, 600);
    expect(out.height, greaterThanOrEqualTo(840));
    // Çerçevenin dışındaki başlık ve imza hâlâ koyu.
    expect(out.getPixel(300, 32).luminance, lessThan(110),
        reason: 'başlık kesilmiş/silinmiş');
    expect(out.getPixel(460, 785).luminance, lessThan(140),
        reason: 'imza kesilmiş/silinmiş');
  });

  test('"Özgün" filtrede görsel hiç yeniden kodlanmaz', () {
    final source = framedPage();
    final page = ScanPrepare.runRequest(
        request(source, ScanFilter.original, straighten: false));
    expect(page.display, source);
    expect(page.source, source);
    expect(File(p.join(dir.path, 'gorunen.jpg')).existsSync(), isFalse);
  });

  test('çözülemeyen dosya sayfayı olduğu gibi bırakır (hata atmaz)', () {
    final bad = p.join(dir.path, 'bozuk.jpg');
    File(bad).writeAsBytesSync([1, 2, 3, 4]);
    final page = ScanPrepare.runRequest(request(bad, ScanFilter.auto));
    expect(page.display, bad);
    expect(page.source, bad);
  });

  test('köşe ekranının başlangıç çerçevesi görselin TAM sınırı', () {
    // Eskiden %2 içeriden başlıyordu: dokunmadan "Uygula" her kenardan %2
    // kesiyordu.
    expect(ScanEditScreen.fullFrame(1000, 1400), const [
      Offset(0, 0),
      Offset(1000, 0),
      Offset(1000, 1400),
      Offset(0, 1400),
    ]);
  });
}
