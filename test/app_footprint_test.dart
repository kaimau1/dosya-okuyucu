import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/docs_home.dart';
import 'package:dosya_okuyucu/services/fm/app_footprint.dart';
import 'package:dosya_okuyucu/services/fm/disk_housekeeping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// 2026-09-26 — kullanıcı: *"uygulamamız yüklenince 550 MB okuyor"*.
/// Uygulamanın kendi klasörlerinin ölçümü, temizliği ve eklenti kopyalarının
/// süpürülmesi.
void main() {
  late Directory data;
  late FootprintRoots roots;

  setUp(() {
    data = Directory.systemTemp.createTempSync('footprint');
    roots = FootprintRoots(
      dataDir: data.path,
      cacheDir: p.join(data.path, 'cache'),
      supportDir: p.join(data.path, 'files'),
      docsDir: p.join(data.path, 'app_flutter'),
    );
  });

  tearDown(() => removeTempDir(data));

  File make(String relative, int bytes, {Duration age = Duration.zero}) {
    final file = File(p.join(data.path, relative))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(bytes, 7));
    file.setLastModifiedSync(DateTime.now().subtract(age));
    return file;
  }

  const old = Duration(hours: 1);

  void makeTree() {
    make('cache/WhatsApp Video 2026.mp4', 1000, age: old); // paylaşım kopyası
    make('cache/file_picker/1700000000/rapor.pdf', 200, age: old);
    make('cache/video_thumbs/a.jpg', 30, age: old);
    make('cache/pdf_thumbs/b.png', 20, age: old);
    make('cache/ocr_page_ab_1.png', 40, age: old); // bizim ara dosyamız
    make('cache/WebView/Default/cache.bin', 50, age: old);
    make('files/drive/abc123/sunum.pptx', 300, age: old);
    make('files/search_index.json', 10, age: old);
    make('app_flutter/Tarama 2026.pdf', 500, age: old);
    make('no_backup/com.google.mlkit.translate.models/tr/model.bin', 400,
        age: old);
    make('shared_prefs/FlutterSharedPreferences.xml', 5, age: old);
  }

  test('her klasör doğru kovaya düşer', () {
    makeTree();
    final r = AppFootprint.measureSync(roots);
    expect(r.of(FootprintBucket.shared), 1000);
    expect(r.of(FootprintBucket.picker), 200);
    expect(r.of(FootprintBucket.thumbs), 50);
    expect(r.of(FootprintBucket.temp), 90); // ocr ara dosyası + WebView
    expect(r.of(FootprintBucket.drive), 300);
    expect(r.of(FootprintBucket.docs), 500);
    expect(r.of(FootprintBucket.models), 400);
    expect(r.of(FootprintBucket.other), 15);
    expect(r.total, 2555);
    // Belgeler ve ayarlar "temizlenebilir" sayılmaz.
    expect(r.clearable, 2555 - 500 - 15);
  });

  test('temizlik yalnız istenen kovalara dokunur; belgeler ve modeller kalır',
      () {
    makeTree();
    final freed = AppFootprint.cleanSync(
      roots,
      {
        FootprintBucket.shared,
        FootprintBucket.picker,
        FootprintBucket.thumbs,
        FootprintBucket.temp,
        FootprintBucket.drive,
      },
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    expect(freed, 1000 + 200 + 50 + 90 + 300);
    final r = AppFootprint.measureSync(roots);
    expect(r.of(FootprintBucket.docs), 500);
    expect(r.of(FootprintBucket.models), 400);
    expect(r.of(FootprintBucket.other), 15);
    expect(r.clearable, 400); // yalnız modeller (onları ML Kit siler)
    // Küçük resim klasörünün KENDİSİ kalır — servis yolunu bellekte tutuyor.
    expect(Directory(p.join(roots.cacheDir, 'video_thumbs')).existsSync(),
        isTrue);
  });

  test('yeni dosyaya ve korunan yedeğe dokunulmaz', () {
    final fresh = make('cache/az_once_acilan.pdf', 10);
    final backup =
        make('cache/dosya_okuyucu_edit7/belge.pdf', 10, age: old);
    AppFootprint.cleanSync(roots, {FootprintBucket.shared, FootprintBucket.temp},
        nowMs: DateTime.now().millisecondsSinceEpoch, keep: {backup.path});
    expect(fresh.existsSync(), isTrue);
    expect(backup.existsSync(), isTrue);
  });

  test('önbellek kökündeki adlar', () {
    expect(AppFootprint.cacheBucketOf('rapor.pdf', isDir: false),
        FootprintBucket.shared);
    expect(AppFootprint.cacheBucketOf('ocr_page_x_2.png', isDir: false),
        FootprintBucket.temp);
    expect(AppFootprint.cacheBucketOf('file_picker', isDir: true),
        FootprintBucket.picker);
    expect(AppFootprint.cacheBucketOf('apk_icons', isDir: true),
        FootprintBucket.thumbs);
  });

  test('her kovanın üç dilde metni var', () {
    for (final b in FootprintBucket.values) {
      expect(AppStrings.keys, contains(b.labelKey), reason: b.name);
      expect(AppStrings.keys, contains(b.subKey), reason: b.name);
    }
  });

  group('TempSweep — eklenti kopyaları', () {
    int now() => DateTime.now().millisecondsSinceEpoch;

    test('7 günden eski paylaşım/seçici kopyası YALNIZ önbellek kökünde silinir',
        () {
      const week = Duration(days: 8);
      final shared = make('cache/WhatsApp Video.mp4', 10, age: week);
      final picked = make('cache/file_picker/1/rapor.pdf', 10, age: week);
      final recentShared = make('cache/yeni.pdf', 10,
          age: const Duration(days: 2));
      final foreignDir = make('cache/WebView/x.bin', 10, age: week);

      // Önbellek kökü olarak işaretlenmeden: hiçbirine dokunulmaz.
      TempSweep.sweepSync(roots.cacheDir, now());
      expect(shared.existsSync(), isTrue);
      expect(picked.existsSync(), isTrue);

      TempSweep.sweepSync(roots.cacheDir, now(), pluginCopies: true);
      expect(shared.existsSync(), isFalse);
      expect(picked.parent.existsSync(), isFalse);
      expect(recentShared.existsSync(), isTrue);
      // Yabancı KLASÖR (WebView) onun işi.
      expect(foreignDir.existsSync(), isTrue);
    });
  });

  group('DocsHome', () {
    tearDown(() => DocsHome.debugPublicRoot = null);

    test('yazılabilen ana bellekte Belgeler/Dosya Okuyucu kurulur', () async {
      DocsHome.debugPublicRoot = p.join(data.path, 'emulated0');
      final dir = await DocsHome.resolve();
      expect(dir.path,
          p.join(data.path, 'emulated0', 'Documents', DocsHome.folderName));
      expect(dir.existsSync(), isTrue);
      // Yazma denemesinin dosyası geride kalmaz.
      expect(dir.listSync(), isEmpty);
    });
  });
}
