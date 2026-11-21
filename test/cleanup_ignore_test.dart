import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_ignore.dart';
import 'package:dosya_okuyucu/services/fm/installed_apps_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-20: Yer aç "Bir daha önerme" — tür ve tek dosya düzeyinde.
void main() {
  FsEntry f(String path, int size) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: 0,
      );

  final list = [
    CleanupSuggestion(
        id: 'apk',
        titleKey: 't',
        detailKey: 'd',
        bytes: 30,
        files: [f('/a/1.apk', 10), f('/a/2.apk', 20)]),
    const CleanupSuggestion(id: 'trash', titleKey: 't', detailKey: 'd', bytes: 5),
  ];

  test('gizlenen tür düşer', () {
    final out = CleanupIgnore.applyTo(list, ids: {'trash'}, paths: {});
    expect(out.map((s) => s.id), ['apk']);
  });

  test('gizlenen dosya düşer, boyut yeniden hesaplanır', () {
    final out = CleanupIgnore.applyTo(list, ids: {}, paths: {'/a/2.apk'});
    expect(out.first.files.length, 1);
    expect(out.first.bytes, 10);
  });

  test('bütün dosyaları gizlenen öneri düşer', () {
    final out = CleanupIgnore.applyTo(list,
        ids: {}, paths: {'/a/1.apk', '/a/2.apk'});
    expect(out.map((s) => s.id), ['trash']);
  });

  group('appTipFor (Uygulamalar öneri kartı)', () {
    const day = 86400000;
    const now = 100 * day;
    const mb = 1 << 20;
    InstalledAppEntry app(String pkg,
            {int lastUsed = now, int total = 0, int cache = 0, bool known = true}) =>
        InstalledAppEntry(
          name: pkg,
          packageName: pkg,
          versionName: '1',
          icon: null,
          installedAtMs: 0,
          lastUsedMs: lastUsed,
          usageKnown: known,
          size: AppStorageSize(appBytes: total, dataBytes: 0, cacheBytes: cache),
        );

    final apps = [
      app('eski.buyuk', lastUsed: now - 40 * day, total: 200 * mb),
      app('eski.kucuk', lastUsed: now - 40 * day, total: 10 * mb),
      app('yeni.onbellek', total: 900 * mb, cache: 400 * mb),
    ];

    test('kullanılmayan büyük uygulama önbellekten önce gelir', () {
      final t = appTipFor(apps, now)!;
      expect(t.app.packageName, 'eski.buyuk');
      expect(t.kind, AppTipKind.uninstall);
    });

    test('gizlenen atlanır, sıradaki öneri gelir', () {
      final t = appTipFor(apps, now, ignored: {'eski.buyuk'})!;
      expect(t.app.packageName, 'yeni.onbellek');
      expect(t.kind, AppTipKind.clearCache);
      expect(t.bytes, 400 * mb);
    });

    test('kullanım bilinmiyorsa öneri yok', () {
      final unknown = [app('x', lastUsed: 0, total: 900 * mb, cache: 900 * mb, known: false)];
      expect(appTipFor(unknown, now), isNull);
    });
  });
}
