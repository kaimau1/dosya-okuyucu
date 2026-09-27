import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/hidden_vault.dart';
import 'package:dosya_okuyucu/services/fm/home_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Dosya gizleme (2026-09-27) ve ana ekran kısayolu simgesi.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('vault');
    HiddenVault.debugRoot = root.path;
    FmEnv.primaryRoot = root.path;
  });

  tearDown(() {
    HiddenVault.debugRoot = null;
    root.deleteSync(recursive: true);
  });

  test('gizle → kasada, .nomedia var; geri yükle → özgün yerinde', () async {
    final dir = Directory(p.join(root.path, 'Download'))..createSync();
    final file = File(p.join(dir.path, 'kimlik.pdf'))..writeAsStringSync('x');

    final result = await HiddenVault.hide([file.path]);
    expect(result.transfers, hasLength(1));
    expect(file.existsSync(), isFalse);
    expect(File(p.join(HiddenVault.root, '.nomedia')).existsSync(), isTrue);

    final items = await HiddenVault.list();
    expect(items, hasLength(1));
    expect(items.single.original, file.path);
    expect(items.single.name, 'kimlik.pdf');

    expect(await HiddenVault.restore(items), 1);
    expect(file.existsSync(), isTrue);
    expect(await HiddenVault.list(), isEmpty);
  });

  test('aynı adlı iki dosya çakışmadan gizlenir ve özgün adlarına döner',
      () async {
    final a = Directory(p.join(root.path, 'A'))..createSync();
    final b = Directory(p.join(root.path, 'B'))..createSync();
    final fa = File(p.join(a.path, 'not.txt'))..writeAsStringSync('a');
    final fb = File(p.join(b.path, 'not.txt'))..writeAsStringSync('b');
    await HiddenVault.hide([fa.path]);
    await HiddenVault.hide([fb.path]);
    final items = await HiddenVault.list();
    expect(items, hasLength(2));
    await HiddenVault.restore(items);
    expect(fa.readAsStringSync(), 'a');
    expect(fb.readAsStringSync(), 'b');
  });

  test('kasanın içindeki öğe ikinci kez gizlenmez', () async {
    Directory(HiddenVault.root).createSync(recursive: true);
    final inside = File(p.join(HiddenVault.root, 'x.txt'))
      ..writeAsStringSync('x');
    final r = await HiddenVault.hide([inside.path]);
    expect(r.transfers, isEmpty);
    expect(inside.existsSync(), isTrue);
  });

  testWidgets('kısayol simgesi PNG olarak çizilir', (tester) async {
    final png = await tester.runAsync(() => HomeShortcuts.renderIcon(
        Icons.picture_as_pdf_rounded, const Color(0xFFC50F1F)));
    expect(png, isNotNull);
    // PNG imzası.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
