import 'dart:io';

import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/smart_bench.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akıllı düzen 2.0 — doğruluk ölçüm tezgâhı (PLAN §1.1 m.4): etiket ↔
/// model karşılaştırması, kapılar, eşik önerisi, dosya adsız rapor, ölçüm
/// sorusu (sahte model).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SmartBenchItem item(String path, String cat,
          {String? sub, bool dated = false, int month = 0, int year = 0}) =>
      SmartBenchItem(
          path: path,
          size: 1,
          modifiedMs: 1,
          cat: cat,
          sub: sub,
          dated: dated,
          month: month,
          year: year);

  SmartBenchGuess guess(String cat,
          {String sub = '', double conf = 0.9, int month = 0, int year = 0}) =>
      SmartBenchGuess(
          cat: cat, sub: sub, conf: conf, month: month, year: year);

  setUp(() {
    SmartBench.debugReset();
    SmartSort.debugReset();
  });

  test('kategori / alt tür / tarih doğruluğu ve kapılar', () {
    final rows = <(SmartBenchItem, SmartBenchGuess?)>[
      for (var i = 0; i < 9; i++)
        (
          item('/d/f$i.pdf', 'invoice', sub: 'electricity'),
          guess('invoice', sub: 'electricity')
        ),
      // Kategori yanlış → alt türü de yanlış sayılır.
      (item('/d/x.pdf', 'invoice', sub: 'water'), guess('receipt')),
      // Yanıtsız: ölçülmez.
      (item('/d/y.pdf', 'contract'), null),
      // Uzantıdan kesin kategori kategori oranına girmez, alt tür girer.
      (item('/d/a.mp3', 'audio', sub: 'voice_note'), guess('audio')),
      // Tarih: ay + yıl birlikte.
      (
        item('/d/t1.pdf', 'contract', dated: true, month: 3, year: 2025),
        guess('contract', month: 3, year: 2025)
      ),
      (
        item('/d/t2.pdf', 'contract', dated: true, month: 4, year: 2025),
        guess('contract', month: 5, year: 2025)
      ),
    ];
    final m = SmartBench.compute(rows);
    expect(m.labelled, 14);
    expect(m.measured, 13);
    expect(m.category.correct, 11);
    expect(m.category.total, 12);
    expect(m.categoryPasses, isTrue); // 11/12 = %91,7
    expect(m.subtype.correct, 9);
    expect(m.subtype.total, 11);
    expect(m.subtypePasses, isTrue); // 9/11 = %81,8
    expect(m.date.correct, 1);
    expect(m.date.total, 2);
    expect(m.confusions, [('invoice', 'receipt', 1)]);
  });

  test('örnek yoksa kapı geçmez, oran null', () {
    final m = SmartBench.compute(const []);
    expect(m.category.rate, isNull);
    expect(m.categoryPasses, isFalse);
    expect(m.subtypePasses, isFalse);
    expect(m.suggested, isNull);
  });

  test('alt tür "hiçbiri" de puanlanır, "puanlama" puanlanmaz', () {
    final m = SmartBench.compute([
      (item('/d/a.pdf', 'contract', sub: ''), guess('contract')),
      (item('/d/b.pdf', 'contract', sub: ''), guess('contract', sub: 'rental')),
      (item('/d/c.pdf', 'contract'), guess('contract', sub: 'rental')),
    ]);
    expect(m.subtype.correct, 1);
    expect(m.subtype.total, 2);
  });

  test('eşik önerisi: kapıyı geçen en düşük eşik, en az 5 dosya', () {
    final rows = <(SmartBenchItem, SmartBenchGuess?)>[
      // Yüksek güvenli 6 doğru.
      for (var i = 0; i < 6; i++)
        (item('/d/h$i.pdf', 'bank'), guess('bank', conf: 0.85)),
      // Düşük güvenli 4 yanlış.
      for (var i = 0; i < 4; i++)
        (item('/d/l$i.pdf', 'bank'), guess('receipt', conf: 0.5)),
    ];
    final m = SmartBench.compute(rows);
    expect(m.categoryPasses, isFalse); // 6/10
    expect(m.suggested, 0.55);
    final at = m.cuts.firstWhere((c) => c.threshold == 0.55);
    expect(at.kept, 6);
    expect(at.accuracy, 1.0);
    // 4 dosyalık örnekle öneri yok.
    final few = SmartBench.compute([
      for (var i = 0; i < 4; i++)
        (item('/d/q$i.pdf', 'bank'), guess('bank', conf: 0.9)),
    ]);
    expect(few.suggested, isNull);
  });

  test('model yanıtı: ölçüm sorusu önce; elle düzeltilmiş ya da değişmiş '
      'kayıt sayılmaz', () {
    final i = item('/d/a.pdf', 'invoice');
    const rec = SmartRecord(
        path: '/d/a.pdf', size: 1, modifiedMs: 1, cat: 'receipt', conf: 0.7);
    expect(SmartBench.guessFor(i, rec)!.cat, 'receipt');
    expect(SmartBench.guessFor(i, rec.copyWith(user: true)), isNull);
    expect(
        SmartBench.guessFor(
            i,
            const SmartRecord(
                path: '/d/a.pdf', size: 2, modifiedMs: 1, cat: 'receipt')),
        isNull);
    expect(SmartBench.guessFor(i.withProbe(guess('invoice')), rec)!.cat,
        'invoice');
  });

  test('rapor dosya adı/yolu içermez', () {
    final m = SmartBench.compute([
      (item('/storage/emulated/0/Download/Ahmet_Yilmaz_kimlik.pdf', 'id'),
          guess('official')),
      (item('/storage/emulated/0/Download/fatura_ekim.pdf', 'invoice'),
          guess('invoice')),
    ]);
    final r = SmartBench.report(m, date: DateTime(2026, 11, 18));
    expect(r, contains('2026-11-18'));
    expect(r, contains('id -> official: 1'));
    expect(r, isNot(contains('storage')));
    expect(r, isNot(contains('Download')));
    expect(r, isNot(contains('Ahmet')));
    expect(r, isNot(contains('fatura_ekim')));
    expect(r, isNot(contains('.pdf')));
  });

  test('JSON gidiş-dönüş; puanlanmayan alt tür ile "hiçbiri" ayrışır', () {
    final a = item('/d/a.pdf', 'invoice',
            sub: '', dated: true, month: 10, year: 2026)
        .withProbe(guess('invoice', sub: 'water', conf: 0.42, year: 2026));
    final b = SmartBenchItem.fromJson(a.toJson())!;
    expect(b.sub, '');
    expect(b.dated, isTrue);
    expect(b.month, 10);
    expect(b.year, 2026);
    expect(b.probe!.sub, 'water');
    expect(b.probe!.conf, 0.42);
    final c = SmartBenchItem.fromJson(item('/d/c.pdf', 'note').toJson())!;
    expect(c.sub, isNull);
    expect(c.dated, isFalse);
    expect(c.probe, isNull);
    expect(SmartBenchItem.fromJson({'p': 1}), isNull);
  });

  test('en çok 100 etiket; aynı dosya güncellenir', () async {
    for (var i = 0; i < SmartBench.maxItems; i++) {
      expect(await SmartBench.put(item('/d/$i.pdf', 'note')), isTrue);
    }
    expect(await SmartBench.put(item('/d/new.pdf', 'note')), isFalse);
    expect(await SmartBench.put(item('/d/0.pdf', 'contract')), isTrue);
    expect(SmartBench.items.length, SmartBench.maxItems);
    expect(SmartBench.of('/d/0.pdf')!.cat, 'contract');
    await SmartBench.remove('/d/0.pdf');
    expect(SmartBench.of('/d/0.pdf'), isNull);
  });

  test('ölçüm sorusu: yanıtsızlara sorar, düzen kaydına yazmaz, 429 durdurur',
      () async {
    final dir = Directory.systemTemp.createTempSync('sbench');
    addTearDown(() => dir.deleteSync(recursive: true));
    final items = <SmartBenchItem>[];
    for (var i = 0; i < 3; i++) {
      final f = File('${dir.path}/b$i.pdf')..writeAsStringSync('x' * (i + 1));
      final st = f.statSync();
      items.add(SmartBenchItem(
          path: f.path,
          size: st.size,
          modifiedMs: st.modified.millisecondsSinceEpoch,
          cat: 'contract'));
    }
    // Biri zaten düzenlenmiş: sorulmaz.
    SmartSort.debugReset([
      SmartRecord(
          path: items[0].path,
          size: items[0].size,
          modifiedMs: items[0].modifiedMs,
          cat: 'contract',
          conf: 0.9),
    ]);
    SmartBench.debugReset(items);
    final asked = <String>[];
    final old = SmartBench.ask;
    addTearDown(() => SmartBench.ask = old);
    SmartBench.ask = (e, c) async {
      asked.add(e.path);
      return SmartRecord(
          path: e.path,
          size: e.sizeBytes,
          modifiedMs: e.modifiedMs,
          cat: 'official',
          conf: 0.6);
    };
    const creds = AiCredentials(keys: ['k']);
    const scope = AiScope(settings: AiScopeSettings());
    final (ok, failed, stopped) =
        await SmartBench.askModel(credentials: creds, scope: scope);
    expect(ok, 2);
    expect(failed, 0);
    expect(stopped, isNull);
    expect(asked.toSet(), {items[1].path, items[2].path});
    expect(SmartSort.of(items[1].path), isNull);
    expect(SmartBench.of(items[1].path)!.probe!.cat, 'official');
    final m = SmartBench.current();
    expect(m.measured, 3);
    expect(m.category.correct, 1);

    SmartBench.ask = (e, c) async =>
        throw GeminiException('kota', statusCode: 429);
    final (ok2, failed2, stopped2) =
        await SmartBench.askModel(credentials: creds, scope: scope, all: true);
    expect(ok2, 0);
    expect(failed2, greaterThan(0));
    expect(stopped2, 'kota');
    expect(SmartBench.asking.value, isNull);
  });
}
