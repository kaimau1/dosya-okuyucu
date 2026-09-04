import 'dart:io';

import 'package:dosya_okuyucu/services/fm/folder_size_cache.dart';
import 'package:dosya_okuyucu/services/fm/fs_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// **Listede klasör boyutu** (KALANLAR maddesi, 2026-09-04'te kapandı).
///
/// Ölçüm pahalı olduğu için kurallar önemli: yalnız istenen klasör ölçülür,
/// ölçülemeyen yol bir daha denenmez, dosya sistemi değişince ölçüler düşer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('folder_size');
    FolderSizeCache.debugReset();
  });

  tearDown(() => removeTempDir(dir));

  test('istenen klasör ölçülür ve sonuç saklanır', () async {
    File('${dir.path}/a.bin').writeAsBytesSync(List.filled(1000, 7));
    Directory('${dir.path}/alt').createSync();
    File('${dir.path}/alt/b.bin').writeAsBytesSync(List.filled(500, 7));

    expect(FolderSizeCache.sizeOf(dir.path), isNull);
    FolderSizeCache.request(dir.path);
    // Ölçüm izolatta koşuyor; sonucu bekle.
    while (FolderSizeCache.pendingCount > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(FolderSizeCache.sizeOf(dir.path), 1500,
        reason: 'alt klasörler de sayılmalı');
  });

  test('aynı klasör iki kez kuyruğa girmez', () {
    FolderSizeCache.request(dir.path);
    FolderSizeCache.request(dir.path);
    expect(FolderSizeCache.pendingCount, 1);
  });

  test('dosya sistemi değişince ölçüler düşer', () async {
    File('${dir.path}/a.bin').writeAsBytesSync(List.filled(100, 1));
    FolderSizeCache.request(dir.path);
    while (FolderSizeCache.pendingCount > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(FolderSizeCache.sizeOf(dir.path), 100);

    FsEvents.changed();
    expect(FolderSizeCache.sizeOf(dir.path), isNull,
        reason: 'kopyalama/silme sonrası bayat boyut gösterilmemeli');
  });
}
