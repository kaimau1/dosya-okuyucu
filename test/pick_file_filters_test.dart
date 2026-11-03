import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fm_type.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/pick_file_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// A11 (2026-11-03): dosya seçicide gezgindekiyle aynı süzgeç.
void main() {
  FsEntry f(String name, {int size = 10, int t = 0, bool dir = false}) =>
      FsEntry(
          path: '/s/$name',
          name: name,
          isDir: dir,
          sizeBytes: size,
          modifiedMs: t);

  final entries = [
    f('Belgeler', dir: true, t: 1),
    f('a.pdf', t: 5),
    f('b.jpg', t: 9, size: 600 * 1024 * 1024),
    f('c.docx', t: 7),
    f('Arsiv', dir: true, t: 3),
  ];

  test('süzgeç yokken: klasörler önce, dosyalar en yeni üstte', () {
    final out = pickVisibleEntries(entries, FmFilter.none);
    expect(out.map((e) => e.name),
        ['Arsiv', 'Belgeler', 'b.jpg', 'c.docx', 'a.pdf']);
  });

  test('tür süzgeci dosyaları daraltır, klasörlere dokunmaz', () {
    final out = pickVisibleEntries(
        entries, FmFilter.none.withTypes({FmType.of(entries[1])}));
    expect(out.where((e) => !e.isDir).map((e) => e.name), ['a.pdf']);
    expect(out.where((e) => e.isDir), hasLength(2),
        reason: 'gezinme yolu kapanmamalı');
  });

  test('boyut süzgeci büyük dosyayı bırakır', () {
    final out = pickVisibleEntries(
        entries, FmFilter.none.withSizeRange(FmSizeRange.large));
    expect(out.where((e) => !e.isDir).map((e) => e.name), ['b.jpg']);
  });

  test('ada göre ve verili sırayı koruyarak', () {
    expect(
        pickVisibleEntries(entries, FmFilter.none, byName: true)
            .map((e) => e.name),
        ['Arsiv', 'Belgeler', 'a.pdf', 'b.jpg', 'c.docx']);
    expect(
        pickVisibleEntries(entries, FmFilter.none, keepOrder: true)
            .map((e) => e.name),
        ['Belgeler', 'Arsiv', 'a.pdf', 'b.jpg', 'c.docx']);
  });
}
