import 'dart:io';

import 'package:dosya_okuyucu/core/app_colors.dart';
import 'package:dosya_okuyucu/services/fm/fm_colors_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 6: etiket + klasör rengi.
void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('fmc');
    FmColorsStore.resetForTest();
    FmColorsStore.debugDir = dir.path;
  });
  tearDown(() {
    FmColorsStore.debugDir = null;
    FmColorsStore.resetForTest();
    dir.deleteSync(recursive: true);
  });

  test('renk kaydedilir, yeniden yüklenir, taşınır, kaldırılır', () async {
    await FmColorsStore.setTag('iş', 5);
    await FmColorsStore.setFolder('/s/Faturalar', 0);
    expect(FmColorsStore.tagColor('iş'), AppHues.labels[5]);
    FmColorsStore.resetForTest();
    await FmColorsStore.ensureLoaded();
    expect(FmColorsStore.folderColor('/s/Faturalar'), AppHues.labels[0]);
    await FmColorsStore.moveFolder('/s/Faturalar', '/s/Belgeler/Faturalar');
    expect(FmColorsStore.folderColor('/s/Faturalar'), isNull);
    expect(FmColorsStore.folderIndex('/s/Belgeler/Faturalar'), 0);
    await FmColorsStore.setTag('iş', null);
    expect(FmColorsStore.tagColor('iş'), isNull);
  });

  test('geçersiz indeks atılır', () {
    final tags = <String, int>{}, folders = <String, int>{};
    FmColorsStore.decodeInto({
      'tags': {'a': 2, 'b': 999, 'c': 'x'},
      'folders': {'/x': -1},
    }, tags, folders);
    expect(tags, {'a': 2});
    expect(folders, isEmpty);
  });
}
