import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_ignore.dart';
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
}
