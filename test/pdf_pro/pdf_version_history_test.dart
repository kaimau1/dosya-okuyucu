// PDF Pro Faz 54 / 3: sürüm geçmişi — 14 gün, önceki sürüme dön.
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String doc;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_versions_test');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    doc = p.join(tmp.path, 'belge.pdf');
    File(doc).writeAsStringSync('surum-1');
  });

  tearDown(() {
    PdfVersionHistory.rootOverride = null;
    tmp.deleteSync(recursive: true);
  });

  final t0 = DateTime(2026, 11, 1, 10);

  test('kayıt öncesi hâl geçmişe girer, en yeni üstte listelenir', () async {
    final v1 = await PdfVersionHistory.push(doc, now: t0);
    expect(v1, isNotNull);
    expect(v1!.file.readAsStringSync(), 'surum-1');
    File(doc).writeAsStringSync('surum-2');
    await PdfVersionHistory.push(doc, now: t0.add(const Duration(hours: 1)));
    final all = await PdfVersionHistory.list(doc,
        now: t0.add(const Duration(hours: 2)));
    expect([for (final v in all) v.file.readAsStringSync()],
        ['surum-2', 'surum-1']);
    expect(all.first.savedAt, t0.add(const Duration(hours: 1)));
    expect(all.first.size, 7);
  });

  test('değişmemiş dosya ikinci kez kopyalanmaz', () async {
    await PdfVersionHistory.push(doc, now: t0);
    await PdfVersionHistory.push(doc, now: t0.add(const Duration(minutes: 5)));
    expect(await PdfVersionHistory.list(doc, now: t0), hasLength(1));
  });

  test('14 günü geçen sürüm silinir, 13 günlük kalır', () async {
    await PdfVersionHistory.push(doc, now: t0);
    File(doc).writeAsStringSync('surum-2');
    await PdfVersionHistory.push(doc, now: t0.add(const Duration(days: 2)));
    final at15 = await PdfVersionHistory.list(doc,
        now: t0.add(const Duration(days: 15)));
    expect([for (final v in at15) v.file.readAsStringSync()], ['surum-2']);
    final at17 = await PdfVersionHistory.list(doc,
        now: t0.add(const Duration(days: 17)));
    expect(at17, isEmpty);
  });

  test('önceki sürüme dön: dosya eski hâline gelir, dönüş de geri alınabilir',
      () async {
    final v1 = (await PdfVersionHistory.push(doc, now: t0))!;
    File(doc).writeAsStringSync('surum-2');
    await PdfVersionHistory.restore(doc, v1,
        now: t0.add(const Duration(hours: 1)));
    expect(File(doc).readAsStringSync(), 'surum-1');
    final all = await PdfVersionHistory.list(doc,
        now: t0.add(const Duration(hours: 2)));
    expect([for (final v in all) v.file.readAsStringSync()],
        ['surum-2', 'surum-1']);
  });

  test('belge başına sürüm sayısı sınırlı', () async {
    for (var i = 0; i < PdfVersionHistory.maxPerDocument + 5; i++) {
      File(doc).writeAsStringSync('surum-$i');
      await PdfVersionHistory.push(doc, now: t0.add(Duration(minutes: i)));
    }
    final all = await PdfVersionHistory.list(doc,
        now: t0.add(const Duration(hours: 3)));
    expect(all, hasLength(PdfVersionHistory.maxPerDocument));
    expect(all.first.file.readAsStringSync(),
        'surum-${PdfVersionHistory.maxPerDocument + 4}');
  });

  test('farklı yoldaki aynı adlı belgelerin geçmişi karışmaz', () async {
    final other = p.join(tmp.path, 'alt', 'belge.pdf');
    File(other)
      ..createSync(recursive: true)
      ..writeAsStringSync('baska');
    await PdfVersionHistory.push(doc, now: t0);
    await PdfVersionHistory.push(other, now: t0);
    final list = await PdfVersionHistory.list(other, now: t0);
    expect(list.single.file.readAsStringSync(), 'baska');
  });

  test('toplu budama süresi dolan klasörü kaldırır', () async {
    await PdfVersionHistory.push(doc, now: t0);
    await PdfVersionHistory.pruneAll(now: t0.add(const Duration(days: 30)));
    expect(Directory(PdfVersionHistory.rootOverride!).listSync(), isEmpty);
  });

  test('olmayan dosya hata vermez', () async {
    expect(await PdfVersionHistory.push(p.join(tmp.path, 'yok.pdf')), isNull);
    expect(await PdfVersionHistory.list(p.join(tmp.path, 'yok.pdf')), isEmpty);
  });
}
