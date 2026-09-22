import 'dart:io';

import 'package:dosya_okuyucu/services/fm/incoming_files.dart';
import 'package:dosya_okuyucu/services/fm/save_to_downloads.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SaveToDownloads.isPrivateCopy', () {
    const roots = ['/storage/emulated/0', '/storage/1A2B-3C4D'];

    test('başka uygulamadan gelen önbellek kopyası özeldir', () {
      expect(
          SaveToDownloads.isPrivateCopy(
              '/data/user/0/com.dosyaokuyucu.dosya_okuyucu/cache/rapor.pdf',
              roots),
          isTrue);
    });

    test('depolamadaki dosya özel değildir (İndir düğmesi çıkmaz)', () {
      expect(
          SaveToDownloads.isPrivateCopy(
              '/storage/emulated/0/Download/rapor.pdf', roots),
          isFalse);
      expect(
          SaveToDownloads.isPrivateCopy(
              '/storage/1A2B-3C4D/Belgeler/a.docx', roots),
          isFalse);
    });

    test('Android/data altı kullanıcıya kapalı → özel', () {
      expect(
          SaveToDownloads.isPrivateCopy(
              '/storage/emulated/0/Android/data/com.x/files/a.pdf', roots),
          isTrue);
    });

    test('adı kökle başlayan ama kökün içinde olmayan yol', () {
      expect(
          SaveToDownloads.isPrivateCopy('/storage/emulated/00/a.pdf', roots),
          isTrue);
    });
  });

  group('SaveToDownloads.uniqueName', () {
    test('boşsa aynı ad, doluysa (1), (2)…', () {
      final taken = {'rapor.pdf', 'rapor (1).pdf'};
      expect(SaveToDownloads.uniqueName('yeni.pdf', taken.contains),
          'yeni.pdf');
      expect(SaveToDownloads.uniqueName('rapor.pdf', taken.contains),
          'rapor (2).pdf');
    });
  });

  group('SaveToDownloads kaydetme', () {
    late Directory tmp;
    late Directory downloads;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('dl_test');
      downloads = Directory(p.join(tmp.path, 'Download'));
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('kopyalar; aynı içerik ikinci kez kopya üretmez', () async {
      final src = File(p.join(tmp.path, 'rapor.pdf'))
        ..writeAsBytesSync([1, 2, 3]);
      final a = await SaveToDownloads.saveFile(src.path,
          intoDir: downloads.path);
      expect(a.alreadyThere, isFalse);
      expect(p.basename(a.path), 'rapor.pdf');
      expect(File(a.path).readAsBytesSync(), [1, 2, 3]);

      final b = await SaveToDownloads.saveFile(src.path,
          intoDir: downloads.path);
      expect(b.alreadyThere, isTrue);
      expect(b.path, a.path);
      expect(downloads.listSync(), hasLength(1));
    });

    test('aynı ad farklı içerik → (1) eki, özgün ezilmez', () async {
      downloads.createSync();
      File(p.join(downloads.path, 'rapor.pdf')).writeAsBytesSync([9, 9, 9]);
      final src = File(p.join(tmp.path, 'rapor.pdf'))
        ..writeAsBytesSync([1, 2, 3]);
      final saved = await SaveToDownloads.saveFile(src.path,
          intoDir: downloads.path);
      expect(p.basename(saved.path), 'rapor (1).pdf');
      expect(File(p.join(downloads.path, 'rapor.pdf')).readAsBytesSync(),
          [9, 9, 9]);
    });

    test('editör baytları yazılır; aynıysa tekrar yazılmaz', () async {
      final a = await SaveToDownloads.saveBytes('tablo.xlsx', [4, 5],
          intoDir: downloads.path);
      final b = await SaveToDownloads.saveBytes('tablo.xlsx', [4, 5],
          intoDir: downloads.path);
      final c = await SaveToDownloads.saveBytes('tablo.xlsx', [4, 6],
          intoDir: downloads.path);
      expect(a.alreadyThere, isFalse);
      expect(b.alreadyThere, isTrue);
      expect(p.basename(c.path), 'tablo (1).xlsx');
    });
  });

  group('IncomingFiles.isBrowserPackage', () {
    test('bilinen tarayıcılar ve adında browser geçenler', () {
      expect(IncomingFiles.isBrowserPackage('com.android.chrome'), isTrue);
      expect(IncomingFiles.isBrowserPackage('org.mozilla.firefox'), isTrue);
      expect(IncomingFiles.isBrowserPackage('com.duckduckgo.mobile.android'),
          isTrue);
      expect(IncomingFiles.isBrowserPackage('com.example.SuperBrowser'),
          isTrue);
    });

    test('mesajlaşma / e-posta / bilinmeyen tarayıcı değil', () {
      expect(IncomingFiles.isBrowserPackage('com.whatsapp'), isFalse);
      expect(IncomingFiles.isBrowserPackage('com.google.android.gm'), isFalse);
      expect(IncomingFiles.isBrowserPackage(null), isFalse);
      expect(IncomingFiles.isBrowserPackage(''), isFalse);
    });
  });
}
