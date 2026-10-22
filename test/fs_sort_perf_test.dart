import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Büyük klasör açılışında sıralama ana izleği tutmasın (2026-10-23 telefonda
/// 2.764 fotoğraflı klasör açılırken tek kare 242 ms build ölçüldü).
void main() {
  test('3.000 öğe ada göre sıralama hızlı ve doğru', () {
    final entries = [
      for (var i = 0; i < 3000; i++)
        FsEntry(
          path: '/x/IMG_${(i * 7919) % 3000}_Işık.jpg',
          name: 'IMG_${(i * 7919) % 3000}_Işık.jpg',
          isDir: false,
          sizeBytes: i,
          modifiedMs: i,
        ),
    ];
    final sw = Stopwatch()..start();
    final sorted = FsScan.sort(entries, FmSort.name);
    sw.stop();
    // ignore: avoid_print
    print('sıralama: ${sw.elapsedMilliseconds} ms');
    expect(sorted.first.name, 'IMG_0_Işık.jpg');
    expect(sorted[10].name, 'IMG_10_Işık.jpg');
    expect(sw.elapsedMilliseconds, lessThan(100));
  });
}
