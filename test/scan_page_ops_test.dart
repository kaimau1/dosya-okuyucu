import 'dart:io';

import 'package:dosya_okuyucu/services/scan_page_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Tarama stüdyosunun geometri işleri (2026-10-18): çıktı JPEG (eskiden PNG
/// — PDF'i sayfa başına 10-20 MB şişiriyordu), kırpma dörtgenin İÇİNİ alır,
/// dev kaynak bellek taşırmasın diye küçültülür.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('scan_ops_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(img.Image image, String name) {
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(img.encodeJpg(image, quality: 95));
    return path;
  }

  test('döndürme: 90° saat yönü, ölçüler yer değiştirir, çıktı JPEG', () {
    final image = img.Image(width: 300, height: 200, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    // Sol-üst köşede kırmızı kare → döndürünce sağ-üste geçmeli.
    img.fillRect(image,
        x1: 0, y1: 0, x2: 40, y2: 40, color: img.ColorRgb8(220, 20, 20));
    final source = write(image, 'a.jpg');
    final target = p.join(dir.path, 'b.jpg');
    ScanPageOps.runRequest(ScanPageOpRequest(
        sourcePath: source, targetPath: target, quarterTurns: 1));
    final bytes = File(target).readAsBytesSync();
    expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG imzası');
    final out = img.decodeJpg(bytes)!;
    expect(out.width, 200);
    expect(out.height, 300);
    final corner = out.getPixel(out.width - 10, 10);
    expect(corner.r, greaterThan(150));
    expect(corner.g, lessThan(90));
  });

  test('kırpma: dörtgenin içi düz dikdörtgene açılır', () {
    final image = img.Image(width: 400, height: 500, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(40, 40, 40)); // masa
    img.fillRect(image,
        x1: 100,
        y1: 120,
        x2: 300,
        y2: 400,
        color: img.ColorRgb8(250, 250, 250)); // kâğıt
    final source = write(image, 'masa.jpg');
    final target = p.join(dir.path, 'kagit.jpg');
    ScanPageOps.runRequest(ScanPageOpRequest(
      sourcePath: source,
      targetPath: target,
      quad: const [100, 120, 300, 120, 300, 400, 100, 400],
    ));
    final out = img.decodeJpg(File(target).readAsBytesSync())!;
    expect(out.width, closeTo(200, 2));
    expect(out.height, closeTo(280, 2));
    // Köşelere yakın bile kâğıt — masa içeri sızmadı.
    expect(out.getPixel(3, 3).luminance, greaterThan(200));
    expect(out.getPixel(out.width - 4, out.height - 4).luminance,
        greaterThan(200));
  });

  test('dev kaynak önce küçültülür, dörtgen orantılı taşınır', () {
    final image = img.Image(width: 5000, height: 300, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final source = write(image, 'dev.jpg');
    final target = p.join(dir.path, 'out.jpg');
    ScanPageOps.runRequest(ScanPageOpRequest(
      sourcePath: source,
      targetPath: target,
      quad: const [0, 0, 5000, 0, 5000, 300, 0, 300],
    ));
    final out = img.decodeJpg(File(target).readAsBytesSync())!;
    expect(out.width, lessThanOrEqualTo(ScanPageOps.maxSourceEdge + 1));
  });

  test('geçici ad kökü kısa kalır (art arda düzenlemede 255 sınırı)', () {
    final long = '/tmp/${'sayfa_kirpildi_123456_donduruldu_789' * 4}.jpg';
    expect(ScanPageOps.shortBase(long).length, lessThanOrEqualTo(24));
    expect(ScanPageOps.shortBase('/tmp/kisa.jpg'), 'kisa');
  });
}
