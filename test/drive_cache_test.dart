import 'dart:io';

import 'package:dosya_okuyucu/models/drive_file.dart';
import 'package:dosya_okuyucu/services/fm/drive_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

/// Drive önbelleği (2026-08-06 kullanıcı bulgusu: "her açma istediğimde
/// tekrar tekrar indiriyor") — taze kopya varken indirme atlanmalı, bulut
/// değişince yeniden inmeli.
void main() {
  group('DriveCache.isFresh', () {
    test('dosya yoksa ya da boşsa taze değildir', () {
      expect(
        DriveCache.isFresh(
          exists: false,
          localSizeBytes: 0,
          localModifiedMs: 0,
          remoteSizeBytes: 100,
          remoteModifiedMs: 100,
        ),
        isFalse,
      );
      expect(
        DriveCache.isFresh(
          exists: true,
          localSizeBytes: 0,
          localModifiedMs: 200,
          remoteSizeBytes: 100,
          remoteModifiedMs: 100,
        ),
        isFalse,
      );
    });

    test('boyut tutmuyorsa (yarım inmiş kopya) taze değildir', () {
      expect(
        DriveCache.isFresh(
          exists: true,
          localSizeBytes: 50,
          localModifiedMs: 200,
          remoteSizeBytes: 100,
          remoteModifiedMs: 100,
        ),
        isFalse,
      );
    });

    test('bulut kopya daha yeniyse taze değildir', () {
      expect(
        DriveCache.isFresh(
          exists: true,
          localSizeBytes: 100,
          localModifiedMs: 100,
          remoteSizeBytes: 100,
          remoteModifiedMs: 200,
        ),
        isFalse,
      );
    });

    test('boyut tutuyor ve yerel daha yeniyse tazedir', () {
      expect(
        DriveCache.isFresh(
          exists: true,
          localSizeBytes: 100,
          localModifiedMs: 300,
          remoteSizeBytes: 100,
          remoteModifiedMs: 200,
        ),
        isTrue,
      );
    });

    test('Google biçimi: boyut bilinmez (0), yalnız tarih karşılaştırılır', () {
      expect(
        DriveCache.isFresh(
          exists: true,
          localSizeBytes: 12345,
          localModifiedMs: 300,
          remoteSizeBytes: 0,
          remoteModifiedMs: 200,
        ),
        isTrue,
      );
    });
  });

  group('DriveCache.freshFile', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('drive_cache');
    });

    tearDown(() => removeTempDir(root));

    test('taze kopya bulunur, ikinci "aç" indirme istemez', () {
      const file = DriveFile(
        id: 'abc',
        name: 'rapor.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 3,
        modifiedAtMs: 1000, // geçmişte — yerel kopya indirme anıyla daha yeni
      );
      expect(DriveCache.freshFile(file, root.path), isNull);

      File(DriveCache.pathFor(file, root.path))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      expect(DriveCache.freshFile(file, root.path), isNotNull);
    });

    test('boyut tutmayan (yarım) kopya kullanılmaz', () {
      const file = DriveFile(
        id: 'abc',
        name: 'rapor.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 999,
        modifiedAtMs: 1000,
      );
      File(DriveCache.pathFor(file, root.path))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      expect(DriveCache.freshFile(file, root.path), isNull);
    });

    test('aynı adlı FARKLI dosyalar (ayrı kimlik) çakışmaz', () {
      const a = DriveFile(
          id: 'a', name: 'Rapor.pdf', mimeType: 'application/pdf');
      const b = DriveFile(
          id: 'b', name: 'Rapor.pdf', mimeType: 'application/pdf');
      expect(DriveCache.pathFor(a, root.path),
          isNot(DriveCache.pathFor(b, root.path)));
    });
  });

  group('DriveCache.prune', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('drive_prune');
    });

    tearDown(() {
      if (root.existsSync()) removeTempDir(root);
    });

    File write(String id, String name, int bytes, DateTime at) {
      final f = File('${root.path}/$id/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(bytes, 0));
      f.setLastModifiedSync(at);
      return f;
    }

    test('sınır aşılınca EN ESKİ dokunulan klasörler silinir', () {
      final old = write('eski', 'a.pdf', 60, DateTime(2026, 1, 1));
      final fresh = write('yeni', 'b.pdf', 60, DateTime(2026, 6, 1));
      DriveCache.prune(root.path, limitBytes: 100);
      expect(old.existsSync(), isFalse, reason: 'eski klasör gitmeli');
      expect(fresh.existsSync(), isTrue, reason: 'yeni klasör kalmalı');
    });

    test('sınırın altındayken hiçbir şey silinmez', () {
      final a = write('x', 'a.pdf', 10, DateTime(2026, 1, 1));
      DriveCache.prune(root.path, limitBytes: 100);
      expect(a.existsSync(), isTrue);
    });

    test('eski düz düzenin artık dosyaları temizlenir', () {
      final legacy = File('${root.path}/eski-ad.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      DriveCache.prune(root.path);
      expect(legacy.existsSync(), isFalse);
    });

    test('kök yoksa sessizce döner', () {
      expect(() => DriveCache.prune('${root.path}/yok'), returnsNormally);
    });
  });
}
