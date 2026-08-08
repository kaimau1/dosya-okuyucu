import 'dart:io';

import 'package:dosya_okuyucu/services/fm/activity_log.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/temp_dir.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('activity');
    FmEnv.appSupportDir = dir.path;
    ActivityLog.resetCache();
    await ActivityLog.clear();
  });

  tearDown(() {
    removeTempDir(dir);
  });

  test('kayıt yazılır, diskten geri okunur, en yeni başta', () async {
    await ActivityLog.add(ActivityKind.videoResize, '/a.mp4',
        detail: '48 MB → 12 MB', whenMs: 1000);
    await ActivityLog.add(ActivityKind.pdfEdit, '/b.pdf', whenMs: 2000);
    ActivityLog.resetCache(); // diskten okumaya zorla
    final all = await ActivityLog.load();
    expect(all.map((r) => r.path), ['/b.pdf', '/a.mp4']);
    expect(all.last.detail, '48 MB → 12 MB');
    expect(all.last.kind, ActivityKind.videoResize);
  });

  test('aynı dosyayı yeniden kaydetmek TEK satır bırakır', () async {
    // Word'de üç kez "Kaydet" demek üç ayrı "yaptım" değil.
    await ActivityLog.add(ActivityKind.documentEdit, '/rapor.docx',
        whenMs: 1000);
    await ActivityLog.add(ActivityKind.documentEdit, '/rapor.docx',
        whenMs: 2000);
    final all = await ActivityLog.load();
    expect(all.length, 1);
    expect(all.single.whenMs, 2000);
  });

  test('türe göre gruplanır, boş grup dönmez', () async {
    await ActivityLog.add(ActivityKind.videoResize, '/a.mp4');
    await ActivityLog.add(ActivityKind.videoResize, '/b.mp4');
    await ActivityLog.add(ActivityKind.scan, '/c.pdf');
    final groups = ActivityLog.group(await ActivityLog.load());
    expect(groups.keys, [ActivityKind.videoResize, ActivityKind.scan]);
    expect(groups[ActivityKind.videoResize]!.length, 2);
    expect(groups.containsKey(ActivityKind.pdfEdit), isFalse);
  });

  test('SİLİNMİŞ dosyanın kaydı listelenmez', () async {
    final real = File('${dir.path}/var.pdf')..writeAsStringSync('x');
    await ActivityLog.add(ActivityKind.pdfEdit, real.path);
    await ActivityLog.add(ActivityKind.pdfEdit, '${dir.path}/yok.pdf');
    final shown = ActivityLog.existing(await ActivityLog.load());
    expect(shown.map((r) => r.path), [real.path]);
  });

  test('liste üst sınırda kırpılır (defter sonsuz büyümez)', () async {
    for (var i = 0; i < ActivityLog.maxRecords + 20; i++) {
      await ActivityLog.add(ActivityKind.other, '/f$i.txt', whenMs: i);
    }
    final all = await ActivityLog.load();
    expect(all.length, ActivityLog.maxRecords);
    // En yeniler korunur.
    expect(all.first.path, '/f${ActivityLog.maxRecords + 19}.txt');
  });

  test('temizlemek yalnız DEFTERİ siler, dosyaya dokunmaz', () async {
    final real = File('${dir.path}/durur.pdf')..writeAsStringSync('x');
    await ActivityLog.add(ActivityKind.pdfEdit, real.path);
    await ActivityLog.clear();
    expect(await ActivityLog.load(), isEmpty);
    expect(real.existsSync(), isTrue);
  });
}
