import 'dart:io';

import 'package:dosya_okuyucu/services/fm/pdf_thumbnail.dart';
import 'package:dosya_okuyucu/services/fm/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// KALANLAR: *"Küçük resim yalnız görsellerde — video/PDF küçük resmi yok"*.
/// Video tarafı 2026-07-25'te kapandı; PDF kapağı 2026-08-08'de.
///
/// **Ne test edilebilir, ne edilemez:** gerçek çizim pdfium'a (yerel kod)
/// gider ve `flutter test` içinde yoktur — üretilen görüntünün *kendisi*
/// cihazda görülmeli. Buradaki testler çizim ÇEVRESİNDEKİ sözleşmeyi
/// sabitliyor: bozuk dosyada çökmeme, aynı dosya için tek iş, önbellek
/// anahtarının dosya değişince değişmesi.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pdf_thumb');
    PdfThumbnail.debugReset();
  });

  tearDown(() {
    PdfThumbnail.debugReset();
    removeTempDir(dir);
  });

  test('PDF olmayan/bozuk dosya null döner ve ÇÖKMEZ', () async {
    final fake = File(p.join(dir.path, 'sahte.pdf'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);
    expect(await PdfThumbnail.forPdf(fake.path), isNull);
  });

  test('başarısız dosya ikinci kez DENENMEZ', () async {
    // Bozuk bir PDF her kaydırmada pdfium'u yeniden çalıştırmamalı.
    final fake = File(p.join(dir.path, 'bozuk.pdf'))..writeAsBytesSync([0]);
    expect(await PdfThumbnail.forPdf(fake.path), isNull);
    // İkinci çağrı anında (senkron tamamlanan future) null dönmeli.
    final second = PdfThumbnail.forPdf(fake.path);
    expect(await second, isNull);
  });

  test('aynı dosya için paralel istekler TEK işe indirgenir', () async {
    final fake = File(p.join(dir.path, 'a.pdf'))..writeAsBytesSync([0]);
    final a = PdfThumbnail.forPdf(fake.path);
    final b = PdfThumbnail.forPdf(fake.path);
    expect(identical(a, b), isTrue,
        reason: 'ikinci istek süren işe bağlanmalı, yenisini başlatmamalı');
    await Future.wait([a, b]);
  });

  test('önbellek anahtarı dosya DEĞİŞİNCE değişir', () {
    // Video küçük resimleriyle aynı kural: yol + değişiklik zamanı + boy.
    final a = ThumbnailCache.cacheName('/a/rapor.pdf', 1000, 256);
    final b = ThumbnailCache.cacheName('/a/rapor.pdf', 2000, 256);
    final c = ThumbnailCache.cacheName('/a/rapor.pdf', 1000, 512);
    expect(a, isNot(b), reason: 'belge güncellenince kapak tazelenmeli');
    expect(a, isNot(c), reason: 'farklı boy ayrı kayıt');
    expect(a, ThumbnailCache.cacheName('/a/rapor.pdf', 1000, 256),
        reason: 'aynı girdi aynı ad — önbellek işe yaramalı');
  });
}
