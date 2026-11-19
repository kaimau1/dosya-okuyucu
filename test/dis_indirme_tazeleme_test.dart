import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fs_events.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Başka uygulamanın indirdiği dosya (Claude, Notlar "Farklı kaydet",
/// tarayıcı) arkadan dönüşte ayakta duran listelerde görünmeli
/// (kullanıcı 2026-11-17; kök: `FsEvents.returned` belgesi).
void main() {
  FsEntry e(String path, {int mtime = 1, int size = 1}) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: mtime,
      );

  group('FsEvents.returned', () {
    test('yalnız gerçekten arkaya gidip dönünce artar', () {
      final start = FsEvents.returned.value;
      // `inactive` → `resumed` (izin penceresi, paylaşım sayfası): artmaz.
      FsEvents.cameBack();
      expect(FsEvents.returned.value, start);
      // `hidden` → `resumed`: bir kez artar.
      FsEvents.wentAway();
      FsEvents.cameBack();
      expect(FsEvents.returned.value, start + 1);
      // İkinci `resumed` (arada gizlenmeden) yeniden artırmaz.
      FsEvents.cameBack();
      expect(FsEvents.returned.value, start + 1);
    });
  });

  group('FsScan.sameListing', () {
    test('aynı yol, tarih ve boyut → aynı', () {
      expect(
        FsScan.sameListing([e('/d/a.pdf'), e('/d/b.pdf')],
            [e('/d/a.pdf'), e('/d/b.pdf')]),
        isTrue,
      );
    });

    test('uzunluk aynı ama ortaya yeni dosya girmiş → farklı', () {
      // Eski karşılaştırma (uzunluk + ilk yol) bunu "aynı" sanıyordu.
      expect(
        FsScan.sameListing([e('/d/a'), e('/d/b'), e('/d/c')],
            [e('/d/a'), e('/d/yeni.pdf'), e('/d/b')]),
        isFalse,
      );
    });

    test('tarih ya da boyut değişti → farklı', () {
      expect(FsScan.sameListing([e('/d/a')], [e('/d/a', mtime: 2)]), isFalse);
      expect(FsScan.sameListing([e('/d/a')], [e('/d/a', size: 9)]), isFalse);
      expect(FsScan.sameListing([e('/d/a')], [e('/d/a'), e('/d/b')]), isFalse);
    });
  });

  // Bekçi: ayakta kalan listeler dönüş sinyalini dinlemeli, kanca bağlı olmalı.
  test('İndirilenler, Yeni dosyalar ve gezgin dönüşte tazelenir', () {
    String src(String p) => File(p).readAsStringSync();
    expect(src('lib/screens/fm/downloads_screen.dart'),
        contains('FsEvents.returned.addListener'));
    expect(src('lib/screens/fm/new_files_screen.dart'),
        contains('FsEvents.returned.addListener'));
    expect(src('lib/screens/fm/browser_screen.dart'),
        contains('FsEvents.returned.addListener'));
    final main = src('lib/main.dart');
    expect(main, contains('onHide: FsEvents.wentAway'));
    expect(main, contains('FsEvents.cameBack()'));
    // Pano: gerçek dönüşte yakalama kısıtı atlanır.
    expect(src('lib/screens/fm/dashboard_screen.dart'),
        contains('_catchUp(force: _wentBackground)'));
  });
}
