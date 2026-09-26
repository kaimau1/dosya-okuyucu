import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/media_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// 2026-09-26: Android 10 ve öncesinde galeri, uygulamanın dosya yoluyla
/// yaptığı değişiklikleri görmüyordu. Her dosya işlemi değişen yolları
/// `MediaScan`e bildirmeli — taşımada ESKİ yol da (galeri kaydı düşsün).
void main() {
  late Directory root;
  final requested = <String>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('media_scan');
    requested.clear();
    MediaScan.debugOnRequest = requested.addAll;
  });

  tearDown(() {
    MediaScan.debugOnRequest = null;
    removeTempDir(root);
  });

  File make(String relative) => File(p.join(root.path, relative))
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  test('taşıma eski ve yeni yolu bildirir', () async {
    final src = make('DCIM/foto.jpg');
    final dest = Directory(p.join(root.path, 'Pictures'))..createSync();
    final r = await FileOps.moveAll([src.path], dest.path);
    expect(r.succeeded, 1);
    expect(requested, containsAll([src.path, r.transfers.single.dest]));
  });

  test('kopyalama yalnız yeni yolu bildirir', () async {
    final src = make('DCIM/foto.jpg');
    final dest = Directory(p.join(root.path, 'Pictures'))..createSync();
    final r = await FileOps.copyAll([src.path], dest.path);
    expect(requested, [r.transfers.single.dest]);
  });

  test('silme ve yeniden adlandırma bildirir', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final renamed = await FileOps.rename(a.path, 'c.jpg');
    expect(requested, [a.path, renamed]);
    requested.clear();
    await FileOps.deleteAll([b.path]);
    expect(requested, [b.path]);
  });

  test('boş istek kanala gitmez', () {
    MediaScan.request(const []);
    expect(requested, isEmpty);
  });
}
