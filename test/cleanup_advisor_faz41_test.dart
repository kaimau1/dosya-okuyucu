import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 5: yeni akıllı temizlik önerileri.
void main() {
  final now = DateTime(2026, 11, 5);
  FsEntry f(String path, int mb, DateTime when) => FsEntry(
      path: path,
      name: path.split('/').last,
      isDir: false,
      sizeBytes: mb * 1024 * 1024,
      modifiedMs: when.millisecondsSinceEpoch,
      accessedMs: when.millisecondsSinceEpoch);

  test('eski ekran görüntüleri, bir yıldır açılmamış büyükler, boş klasörler',
      () {
    final index = StorageIndex(
      stats: const {},
      byCategory: {
        FmCategory.image: [
          f('/s/DCIM/Screenshots/Screenshot_1.png', 1, DateTime(2026, 1, 1)),
          f('/s/DCIM/Screenshots/Screenshot_2.png', 1, DateTime(2026, 11, 1)),
          f('/s/DCIM/Camera/IMG_1.jpg', 3, DateTime(2024, 1, 1)),
        ],
        FmCategory.archive: [
          f('/s/Download/yedek.zip', 600, DateTime(2024, 6, 1)),
          f('/s/Download/yeni.zip', 600, DateTime(2026, 10, 1)),
        ],
        FmCategory.document: [
          f('/s/Belge/kucuk.pdf', 2, DateTime(2020, 1, 1)),
        ],
      },
      largest: const [],
      recent: const [],
      totalFiles: 0,
      totalBytes: 0,
      skipped: 0,
    );
    final list = adviseCleanup(
      index: index,
      downloads: const [],
      duplicates: const [],
      trashBytes: 0,
      trashCount: 0,
      now: now,
      emptyFolders: ['/s/Bos', '/s/Eski/Bos2'],
    );
    final shots = list.firstWhere((s) => s.id == 'old_screenshots');
    expect(shots.files.map((e) => e.name), ['Screenshot_1.png']);
    expect(shots.safeByDefault, isFalse);
    final big = list.firstWhere((s) => s.id == 'old_large');
    expect(big.files.single.name, 'yedek.zip');
    expect(big.safeByDefault, isFalse);
    final empty = list.firstWhere((s) => s.id == 'empty_folders');
    expect(empty.files, hasLength(2));
    expect(empty.files.every((e) => e.isDir), isTrue);
    expect(empty.safeByDefault, isTrue);
  });

  test('ekran görüntüsü tanıma', () {
    FsEntry e(String p) => FsEntry(
        path: p, name: p.split('/').last, isDir: false, sizeBytes: 1, modifiedMs: 0);
    expect(isScreenshot(e('/s/Pictures/Ekran görüntüleri/a.png')), isTrue);
    expect(isScreenshot(e('/s/x/Screenshot_2026.jpg')), isTrue);
    expect(isScreenshot(e('/s/DCIM/Camera/IMG.jpg')), isFalse);
  });
}
