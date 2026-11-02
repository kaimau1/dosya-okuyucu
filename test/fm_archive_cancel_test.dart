import 'dart:io';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart' show JobCancelled;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **Arşiv çıkarmada "Durdur"** (2026-11-02). Eskiden çıkarma `Isolate.run`
/// içindeydi ve durdurulamıyordu (büyük solid RAR'da dakikalar). Artık
/// [ArchiveOps.extract] `isCancelled` alıyor: izolat öldürülür, yarım hedef
/// klasör silinir, [JobCancelled] atılır.
void main() {
  late Directory tmp;
  late String archive;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('fm_archive_cancel');
    final src = Directory(p.join(tmp.path, 'kaynak'))..createSync();
    // Çıkarması bir süre tutsun: çok sayıda küçük dosya (her biri ayrı
    // aç/yaz/kapat) — 150 ms'lik yoklama araya girebilsin.
    for (var i = 0; i < 4000; i++) {
      File(p.join(src.path, 'dosya_$i.txt'))
          .writeAsStringSync('içerik $i ' * 40);
    }
    archive =
        await ArchiveOps.compress([src.path], tmp.path, archiveName: 'buyuk');
  });

  tearDownAll(() => removeTempDir(tmp));

  test('durdurulmayan çıkarma durdurulabilir yoldan da tamamlanır', () async {
    var reports = 0;
    final target = await ArchiveOps.extract(archive,
        destDir: p.join(tmp.path, 'tam'),
        onProgress: (_) => reports++,
        isCancelled: () => false);
    expect(File(p.join(target, 'kaynak', 'dosya_3999.txt')).existsSync(),
        isTrue);
    expect(reports, greaterThan(0), reason: 'ilerleme izolattan gelmeli');
  });

  test('ilk ilerlemeden sonra durdurulunca yarım klasör silinir', () async {
    var stop = false;
    final dest = p.join(tmp.path, 'yarim');
    await expectLater(
      ArchiveOps.extract(archive,
          destDir: dest,
          onProgress: (_) => stop = true,
          isCancelled: () => stop),
      throwsA(isA<JobCancelled>()),
    );
    final left = Directory(dest).existsSync()
        ? Directory(dest).listSync()
        : const <FileSystemEntity>[];
    expect(left, isEmpty, reason: 'yarım hedef klasör kalmamalı');
  },
      // Windows'ta aralıklı (≈1/6): öldürülen izolatın yarıda kalan dosya
      // tanıtıcısı kapanmıyor ve Windows açık dosyanın klasörünü silmiyor
      // (errno 32; izolat çıkışı ≤1 ms'de geliyor — ölçüldü 2026-11-02).
      // Linux/Android açık dosyayı silebilir; uygulama yalnız Android (K10).
      skip: Platform.isWindows ? 'Windows dosya kilidi (bkz. not)' : false);

  test('başlamadan durdurulmuşsa izolat hiç kurulmaz', () async {
    final dest = p.join(tmp.path, 'hic');
    await expectLater(
      ArchiveOps.extract(archive, destDir: dest, isCancelled: () => true),
      throwsA(isA<JobCancelled>()),
    );
    expect(
        Directory(dest).existsSync() && Directory(dest).listSync().isNotEmpty,
        isFalse);
  });

  test('bozuk arşivde hata tiplenmiş kalır (durdurulabilir yol)', () async {
    final bad = File(p.join(tmp.path, 'bozuk.zip'))
      ..writeAsBytesSync(List.filled(64, 7));
    await expectLater(
      ArchiveOps.extract(bad.path,
          destDir: p.join(tmp.path, 'b'), isCancelled: () => false),
      throwsA(isA<ArchiveError>()),
    );
  });
}
