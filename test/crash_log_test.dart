import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/core/app_version.dart';
import 'package:dosya_okuyucu/services/crash_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// **Hata (çökme) günlüğü — 2026-08-28.**
///
/// Uygulama GitHub Releases'ten dağıtılıyor ve hiçbir hata bildirimi yoktu:
/// kullanıcının telefonundaki çökmeyi öğrenmenin yolu yoktu. Bu dosya kaydın
/// taşıyıcı sözlerini kilitler: kayıt tutulur, tekrar eden hata listeyi
/// doldurmaz, sınır aşılmaz ve **kaydedici hiçbir koşulda fırlatmaz**.
void main() {
  late Directory dir;

  setUp(() {
    // `setUp` içinde: `testWidgets`/test gövdesinde `createTemp()` çağırmak
    // sahte saat zonunda testi askıya alıyor (HAFIZA 2026-07-25 §F tuzağı).
    dir = Directory.systemTemp.createTempSync('crashlog');
    CrashLog.dirOverride = dir.path;
  });

  tearDown(() {
    CrashLog.dirOverride = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('kayıt yoksa boş liste döner (dosya hiç yokken de)', () async {
    expect(await CrashLog.load(), isEmpty);
  });

  test('hata kaydedilir ve geri okunur', () async {
    await CrashLog.record(
        StateError('bozuk sayfa'), StackTrace.fromString('#0 a\n#1 b'),
        context: 'building Foo');
    final records = await CrashLog.load();
    expect(records, hasLength(1));
    expect(records.first.error, contains('bozuk sayfa'));
    expect(records.first.stack, contains('#0 a'));
    expect(records.first.context, 'building Foo');
    expect(records.first.count, 1);
  });

  test('AYNI hata tekrarlarsa yeni satır açılmaz, sayaç artar', () async {
    final stack = StackTrace.fromString('#0 aynı');
    await CrashLog.record(StateError('döngü'), stack);
    await CrashLog.record(StateError('döngü'), stack);
    await CrashLog.record(StateError('döngü'), stack);
    final records = await CrashLog.load();
    expect(records, hasLength(1), reason: 'tekrar tek kayıtta toplanmalı');
    expect(records.first.count, 3);
  });

  test('en yeni kayıt başta ve sınır aşılmaz', () async {
    for (var i = 0; i < CrashLog.maxRecords + 5; i++) {
      await CrashLog.record(StateError('hata $i'), StackTrace.fromString('#$i'));
    }
    final records = await CrashLog.load();
    expect(records, hasLength(CrashLog.maxRecords));
    expect(records.first.error, contains('hata ${CrashLog.maxRecords + 4}'));
  });

  test('uzun yığın izi kırpılır (dosya sessizce büyümesin)', () async {
    final long = List.generate(200, (i) => '#$i frame').join('\n');
    await CrashLog.record(Exception('x'), StackTrace.fromString(long));
    final stack = (await CrashLog.load()).first.stack;
    expect(stack.split('\n').length, lessThanOrEqualTo(CrashLog.maxStackLines + 1));
    expect(stack, contains('satır daha'));
  });

  test('bozuk JSON çökertmez, boş liste döner', () async {
    File(p.join(dir.path, 'crash_log.json')).writeAsStringSync('{bu json değil');
    expect(await CrashLog.load(), isEmpty);
  });

  test('temizle kaydı siler', () async {
    await CrashLog.record(Exception('x'), StackTrace.current);
    expect(await CrashLog.load(), isNotEmpty);
    await CrashLog.clear();
    expect(await CrashLog.load(), isEmpty);
  });

  test('yazılamayan dizinde bile FIRLATMAZ (kaydedici çökertmemeli)', () async {
    CrashLog.dirOverride = p.join(dir.path, 'olmayan', 'derin', 'yol');
    await expectLater(
        CrashLog.record(Exception('x'), StackTrace.current), completes);
  });

  test('paylaşım metni sürümü ve tüm kayıtları içerir', () async {
    await CrashLog.record(StateError('görünür hata'), StackTrace.fromString('#0'));
    final text = CrashLog.asShareText(await CrashLog.load());
    expect(text, contains(appVersionFull));
    expect(text, contains('görünür hata'));
  });

  group('görülmemiş kayıt sayacı (panodaki uyarı satırı)', () {
    test('hiç kayıt yoksa 0', () async {
      expect(await CrashLog.unseenCount(), 0);
    });

    test('yeni kayıtlar görülmemiş sayılır', () async {
      await CrashLog.record(StateError('bir'), StackTrace.fromString('#0 a'));
      await CrashLog.record(StateError('iki'), StackTrace.fromString('#0 b'));
      expect(await CrashLog.unseenCount(), 2);
    });

    test('görüldü işaretinden sonra sıfırlanır', () async {
      await CrashLog.record(StateError('bir'), StackTrace.fromString('#0 a'));
      await CrashLog.markSeen();
      expect(await CrashLog.unseenCount(), 0);
    });

    test('işaretten SONRA gelen kayıt yine görünür', () async {
      await CrashLog.record(StateError('eski'), StackTrace.fromString('#0 a'));
      await CrashLog.markSeen();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await CrashLog.record(StateError('yeni'), StackTrace.fromString('#0 b'));
      expect(await CrashLog.unseenCount(), 1);
    });

    test('temizlemek işareti de siler (sonraki kayıt görülmüş sayılmaz)',
        () async {
      await CrashLog.record(StateError('bir'), StackTrace.fromString('#0 a'));
      await CrashLog.markSeen();
      await CrashLog.clear();
      await CrashLog.record(StateError('iki'), StackTrace.fromString('#0 b'));
      expect(await CrashLog.unseenCount(), 1);
    });
  });

  test('JSON biçimi ileri/geri dönüşümlüdür', () {
    // `DateTime` const olamaz → kayıt da const değil.
    final record = CrashRecord(
      time: _t,
      kind: 'flutter',
      error: 'e',
      stack: 's',
      context: 'c',
      count: 4,
    );
    final back = CrashRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>);
    expect(back.kind, 'flutter');
    expect(back.count, 4);
    expect(back.context, 'c');
    expect(back.time, record.time);
  });
}

final _t = DateTime.utc(2026, 8, 28, 12, 30);
