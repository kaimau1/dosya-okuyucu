import 'dart:io';

import 'package:dosya_okuyucu/services/fm/paste_conflict.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'support/temp_dir.dart';

/// Yapıştırma eskiden çakışmayı SESSİZCE "yeniden adlandır" ile geçiyordu:
/// aynı dosyanın yeni sürümünü yapıştıran kullanıcı klasörde iki kopya
/// buluyor, hangisinin güncel olduğunu bilemiyordu. Artık çakışma varsa
/// soruluyor — ama YALNIZ varsa; boş yere çıkan bir soru penceresi gürültü.
void main() {
  group('PasteConflict.collisionsIn (saf)', () {
    test('çakışma yoksa boş liste döner', () {
      expect(
        PasteConflict.collisionsIn(
          ['/a/rapor.pdf', '/a/foto.jpg'],
          {'baska.txt'},
        ),
        isEmpty,
      );
    });

    test('yalnız çakışan adlar döner, sıra korunur', () {
      expect(
        PasteConflict.collisionsIn(
          ['/a/rapor.pdf', '/a/foto.jpg', '/a/not.txt'],
          {'not.txt', 'rapor.pdf'},
        ),
        ['rapor.pdf', 'not.txt'],
      );
    });

    test('karşılaştırma YOL değil AD üzerinden', () {
      // Kaynak başka klasörde olsa da hedefte aynı ad varsa çakışır.
      expect(
        PasteConflict.collisionsIn(['/bambaska/yer/rapor.pdf'], {'rapor.pdf'}),
        ['rapor.pdf'],
      );
    });
  });

  group('PasteConflict.collisions (disk)', () {
    late Directory dir;
    late Directory dest;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('paste_conflict');
      dest = Directory(p.join(dir.path, 'hedef'))..createSync();
    });

    tearDown(() {
      try {
        removeTempDir(dir);
      } catch (_) {}
    });

    test('hedefteki dosyayla çakışan kaynak bulunur', () {
      File(p.join(dest.path, 'rapor.pdf')).writeAsStringSync('eski');
      final sources = [
        p.join(dir.path, 'rapor.pdf'),
        p.join(dir.path, 'yeni.pdf'),
      ];
      expect(PasteConflict.collisions(sources, dest.path), ['rapor.pdf']);
    });

    test('KLASÖR çakışması da sayılır', () {
      // Aynı adlı bir klasörün üzerine yazmak dosyadan daha yıkıcı — sorunun
      // sorulmadığı bir yol bırakılamaz.
      Directory(p.join(dest.path, 'Belgeler')).createSync();
      expect(
        PasteConflict.collisions([p.join(dir.path, 'Belgeler')], dest.path),
        ['Belgeler'],
      );
    });

    test('boş hedefte hiç çakışma yok', () {
      expect(
        PasteConflict.collisions([p.join(dir.path, 'a.txt')], dest.path),
        isEmpty,
      );
    });
  });
}
