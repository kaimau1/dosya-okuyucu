import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/folder_sort_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FolderSortMemory.instance.debugReset();
  });

  test('klasör kendi sıralamasını hatırlar; öteki klasör global kalır',
      () async {
    final m = FolderSortMemory.instance;
    await m.ensureLoaded();
    await m.set('/sdcard/Download/', FmSort.date, true);
    expect(m.of('/sdcard/Download'), (FmSort.date, true));
    expect(m.of('/sdcard/Music'), isNull);

    // Diskten yeniden okunur.
    m.debugReset();
    await m.ensureLoaded();
    expect(m.of('/sdcard/Download'), (FmSort.date, true));

    await m.clear('/sdcard/Download');
    expect(m.of('/sdcard/Download'), isNull);
  });

  test('bilinmeyen ölçüt adı (eski sürüm) sessizce düşer', () async {
    SharedPreferences.setMockInitialValues({
      'fm_folder_sort': ['/a\tnope\t1', '/b\tname\t0'],
    });
    final m = FolderSortMemory.instance;
    await m.ensureLoaded();
    expect(m.of('/a'), isNull);
    expect(m.of('/b'), (FmSort.name, false));
  });

  test('kayıt sayısı tavanı: en eski klasör düşer', () async {
    final m = FolderSortMemory.instance;
    await m.ensureLoaded();
    for (var i = 0; i <= FolderSortMemory.maxEntries; i++) {
      await m.set('/d$i', FmSort.size, false);
    }
    expect(m.of('/d0'), isNull);
    expect(m.of('/d${FolderSortMemory.maxEntries}'), isNotNull);
  });
}
