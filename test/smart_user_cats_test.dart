import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_input.dart';
import 'package:dosya_okuyucu/services/fm/smart_user_cats.dart';
import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı düzen 2.0 — kullanıcı kategorileri (PLAN §1.1 m.3): ayrı `noul`
/// sorusu (eşik 0,7, çoklu eşleşme), "Dene" kapısı, geriye dönük uygula,
/// süzgeç / akıllı klasör / arama / ikinci ad. Model yanıtı sahte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tr = AppStrings(AppLanguage.tr);
  const creds = AiCredentials(keys: ['k']);
  const scope = AiScope(settings: AiScopeSettings());

  const rent = SmartUserCat(
      id: 'u:a', name: 'Kira', about: 'Kira sözleşmesi ve kira dekontları');
  const cat = SmartUserCat(
      id: 'u:b', name: 'Kedim', about: 'Kedimin fotoğrafları', icon: 'star');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartUserCats.debugReset();
    SmartSort.debugReset();
  });
  tearDown(() {
    SmartUserCats.debugReset();
    SmartSort.debugReset();
  });

  FsEntry entry(String path, {int size = 1, int mtime = 1}) => FsEntry(
      path: path,
      name: path.split('/').last,
      isDir: false,
      sizeBytes: size,
      modifiedMs: mtime);

  DecisionResult yesAnswer(DecisionQuestion q, double yes) =>
      DecisionResult([DecisionAnswer(question: q, yes: yes, confidence: 0.9)]);

  test('soru: ayrı evet/hayır, kimlik uc_, cümle talimatta, tırnak temiz', () {
    final q = SmartUserCats.questionFor('uc_a', 'Kira "ev"', 'Kira\ndekontu');
    expect(q.kind, DecisionKind.noul);
    expect(q.id, 'uc_a');
    final json = q.toJson();
    expect(json['type'], 'noul');
    final ins = json['instructions'] as String;
    expect(ins, contains("Does this file match the user's category"));
    expect(ins, contains('Kira  ev'));
    expect(ins, contains('Kira dekontu'));
    expect(ins.contains('\n'), isFalse);
    expect(rent.questionId, 'uc_a');
    expect(rent.question.id, 'uc_a');
  });

  test('kategori JSON gidiş-dönüş; bozuk kayıt düşer', () {
    final back = SmartUserCat.fromJson(cat.toJson())!;
    expect(back.id, 'u:b');
    expect(back.name, 'Kedim');
    expect(back.icon, 'star');
    expect(back.color, 'blue');
    expect(SmartUserCat.fromJson({'id': 'x', 'n': 'A', 'a': 'b'}), isNull,
        reason: 'önek yok');
    expect(SmartUserCat.fromJson({'id': 'u:x', 'n': ' ', 'a': 'b'}), isNull);
    expect(
        SmartUserCat.fromJson({'id': 'u:x', 'n': 'A', 'a': 'b', 'i': 'yok'})!
            .icon,
        'folder');
  });

  test('yanıt: eşik 0,7, çoklu eşleşme, sorulanlar kayıtta; JSON uyumlu', () {
    SmartUserCats.debugReset([rent, cat]);
    final r = DecisionResult([
      DecisionAnswer(question: rent.question, yes: 0.7),
      DecisionAnswer(question: cat.question, yes: 0.69),
      // Bilinmeyen kullanıcı sorusu yok sayılır.
      DecisionAnswer(
          question: SmartUserCats.questionFor('uc_zz', 'x', 'y'), yes: 1),
    ]);
    final yes = SmartUserCats.answersIn(r);
    expect(yes.keys, unorderedEquals(['u:a', 'u:b']));
    const base = SmartRecord(
        path: '/d/a.pdf', size: 1, modifiedMs: 1, cat: 'contract', conf: 0.9);
    final rec = base.withUserAnswers(yes);
    expect(rec.uc, {'u:a': 70});
    expect(rec.uq, ['u:a', 'u:b']);
    // İkisi de eşleşirse ikisinde de durur.
    final both = rec.withUserAnswers({'u:b': 0.95});
    expect(both.uc.keys, unorderedEquals(['u:a', 'u:b']));
    // Sonradan "hayır" eşleşmeyi kaldırır.
    expect(both.withUserAnswers({'u:a': 0.1}).uc.keys, ['u:b']);
    // JSON gidiş-dönüş + eski kayıt (alan yok) boş.
    final back = SmartRecord.fromJson(both.toJson())!;
    expect(back.uc, both.uc);
    expect(back.uq, both.uq);
    final old = SmartRecord.fromJson(base.toJson())!;
    expect(old.uc, isEmpty);
    expect(old.uq, isEmpty);
    expect(base.toJson().containsKey('uc'), isFalse);
    // Kopyalar (gizle/düzelt) yanıtları korur.
    expect(both.copyWith(hidden: true).uc, both.uc);
    expect(both.copyWith(cat: 'invoice', user: true).uq, both.uq);
  });

  test('normal tur: kullanıcı soruları bütçe içinde, kimlikler tekil', () {
    SmartUserCats.debugReset([
      for (var i = 0; i < SmartUserCats.maxCats; i++)
        SmartUserCat(id: 'u:c$i', name: 'K$i', about: 'A$i'),
    ]);
    final today = DateTime(2026, 11, 18);
    for (final path in ['/d/a.jpg', '/d/b.pdf', '/d/c.docx', '/d/d.apk']) {
      final qs = SmartSort.questionsFor(path, today: today, learned: '');
      expect(qs.length, lessThanOrEqualTo(GeminiDecisions.maxQuestions),
          reason: path);
      final ids = qs.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length, reason: path);
      expect(ids, contains('uc_c0'), reason: path);
    }
    // Kategori yoksa soru listesi değişmez.
    SmartUserCats.debugReset();
    final plain =
        SmartSort.questionsFor('/d/b.pdf', today: today, learned: '');
    expect(plain.where((q) => q.id.startsWith('uc_')), isEmpty);
  });

  test('akıllı klasör, sayı, süzgeç, arama ve ikinci ad aynı yoldan', () {
    SmartUserCats.debugReset([rent, cat]);
    SmartSort.debugReset(const [
      SmartRecord(
          path: '/d/kira.pdf',
          size: 1,
          modifiedMs: 1,
          cat: 'contract',
          conf: 0.9,
          month: 10,
          year: 2026,
          uc: {'u:a': 95},
          uq: ['u:a', 'u:b']),
      SmartRecord(
          path: '/d/kedi.jpg',
          size: 1,
          modifiedMs: 2,
          cat: 'photo_other',
          conf: 0.99,
          uc: {'u:b': 80},
          uq: ['u:a', 'u:b']),
      SmartRecord(
          path: '/d/fatura.pdf',
          size: 1,
          modifiedMs: 3,
          cat: 'invoice',
          conf: 0.9,
          uc: {'u:a': 75},
          uq: ['u:a']),
      SmartRecord(
          path: '/d/yeni.pdf', size: 1, modifiedMs: 4, cat: 'invoice', conf: 0.9),
    ]);
    expect(SmartSort.pathsOf('u:a'),
        unorderedEquals(['/d/kira.pdf', '/d/fatura.pdf']));
    expect(SmartSort.userCounts(), {'u:a': 2, 'u:b': 1});
    expect(SmartUserCats.pendingCount('u:b'), 2);
    expect(SmartSort.pendingFor('u:b').map((r) => r.path),
        ['/d/yeni.pdf', '/d/fatura.pdf']);

    // İkinci ad: kullanıcı kategorisi baskınsa (95 > 90) onun adı + tarih;
    // kişisel fotoğrafta da yazılır; yerleşik güven yüksekse yerleşik.
    expect(SmartSort.render(SmartSort.of('/d/kira.pdf')!, tr), 'Kira · Ekim 2026');
    expect(SmartSort.render(SmartSort.of('/d/kedi.jpg')!, tr), 'Kedim');
    expect(SmartSort.render(SmartSort.of('/d/fatura.pdf')!, tr), 'Fatura');

    // Arama kullanıcı kategorisinin adını bulur.
    expect(SmartSort.matches('kedim').map((r) => r.path), ['/d/kedi.jpg']);

    // Süzgeç: yerleşikle aynı kümede, çoklu eşleşme.
    FmFilter.smartCatOf = SmartSort.categoryOf;
    FmFilter.smartUserCatsOf = SmartSort.userCatsOf;
    addTearDown(() {
      FmFilter.smartCatOf = null;
      FmFilter.smartUserCatsOf = null;
    });
    final f = FmFilter.none.toggleSmartCat('u:a');
    expect(f.matches(entry('/d/kira.pdf')), isTrue);
    expect(f.matches(entry('/d/fatura.pdf')), isTrue);
    expect(f.matches(entry('/d/kedi.jpg')), isFalse);
    expect(f.matches(entry('/d/yeni.pdf')), isFalse);
    final mixed = f.toggleSmartCat('invoice');
    expect(mixed.matches(entry('/d/yeni.pdf')), isTrue);
  });

  test('silinen kategori: izi düşer, ad ve süzgeçten kalkar', () async {
    SmartUserCats.debugReset([rent]);
    SmartSort.debugReset(const [
      SmartRecord(
          path: '/d/kira.pdf',
          size: 1,
          modifiedMs: 1,
          cat: 'other',
          uc: {'u:a': 95},
          uq: ['u:a']),
    ]);
    expect(SmartSort.render(SmartSort.of('/d/kira.pdf')!, tr), 'Kira');
    await SmartUserCats.remove('u:a');
    final r = SmartSort.of('/d/kira.pdf')!;
    expect(r.uc, isEmpty);
    expect(r.uq, isEmpty);
    expect(SmartSort.userCatsOf('/d/kira.pdf'), isEmpty);
    expect(SmartSort.render(r, tr), '');
  });

  test('kaydetme kapısı: deneme + ≥1 eşleşme + onay + aynı cümle', () {
    final hit = SmartTrialHit(entry('/d/a.pdf'), 0.9);
    final miss = SmartTrialHit(entry('/d/b.pdf'), 0.2);
    final ok = SmartTrial('Kira', 'Kira dekontu', [hit, miss]);
    final none = SmartTrial('Kira', 'Kira dekontu', [miss]);
    bool gate(SmartTrial? t, {bool confirmed = true, String about = 'Kira dekontu'}) =>
        SmartUserCats.canSave(
            name: 'Kira', about: about, trial: t, confirmed: confirmed);
    expect(gate(null), isFalse, reason: 'denenmedi');
    expect(gate(none), isFalse, reason: 'eşleşme yok');
    expect(gate(ok, confirmed: false), isFalse, reason: 'onay yok');
    expect(gate(ok, about: 'Kira dekontları'), isFalse,
        reason: 'cümle değişti');
    expect(gate(ok), isTrue);
    expect(gate(ok, about: '  Kira dekontu '), isTrue, reason: 'boşluk önemsiz');
  });

  test('Dene: son 20 dosyada tek soru, eşleşenler üstte, kayda yazmaz',
      () async {
    final files = [for (var i = 0; i < 25; i++) entry('/d/f$i.pdf', mtime: i)];
    final asked = <String>[];
    SmartUserCats.candidates = (_) async => files;
    SmartUserCats.prepare = (e, keys) async =>
        SmartPrepared({'text': e.path}, keys);
    SmartUserCats.ask = (keys, input, qs) async {
      expect(qs, hasLength(1));
      expect(qs.single.kind, DecisionKind.noul);
      final path = input.single['text'] as String;
      asked.add(path);
      return yesAnswer(qs.single, path.endsWith('3.pdf') ? 0.9 : 0.1);
    };
    var lastTotal = 0;
    final t = await SmartUserCats.trial(
        name: 'Kira',
        about: 'Kira dekontu',
        credentials: creds,
        scope: scope,
        onProgress: (d, n) => lastTotal = n);
    expect(asked, hasLength(SmartUserCats.trialFiles));
    expect(lastTotal, SmartUserCats.trialFiles);
    expect(t.hits, hasLength(20));
    expect(t.matches.map((h) => h.entry.path), ['/d/f3.pdf', '/d/f13.pdf']);
    expect(t.hits.first.match, isTrue);
    expect(t.isFor('Kira', 'Kira dekontu'), isTrue);
    expect(SmartUserCats.all, isEmpty, reason: 'deneme kaydetmez');
  });

  test('Dene: kota (429) erken durdurur', () async {
    SmartUserCats.candidates =
        (_) async => [for (var i = 0; i < 5; i++) entry('/d/f$i.pdf')];
    SmartUserCats.prepare = (e, keys) async => SmartPrepared(const {}, keys);
    SmartUserCats.ask = (keys, input, qs) async =>
        throw GeminiException('kota', statusCode: 429);
    final t = await SmartUserCats.trial(
        name: 'Kira', about: 'x', credentials: creds, scope: scope);
    // U4: ham API iletisi değil, kullanıcı dilinde ne oldu + ne yapmalı.
    expect(t.stoppedBy, AppStrings.current.t('uerr.ai_quota'));
    expect(t.hits, isEmpty);
    expect(t.failed, lessThanOrEqualTo(2), reason: 'iki işçi, ilk hatada durur');
  });

  test('Dene: ağ kopunca (kod 0) durur; ortak durma kuralı (U4 dilim 2)', () async {
    SmartUserCats.candidates =
        (_) async => [for (var i = 0; i < 8; i++) entry('/d/f$i.pdf')];
    SmartUserCats.prepare = (e, keys) async => SmartPrepared(const {}, keys);
    var asked = 0;
    SmartUserCats.ask = (keys, input, qs) async {
      asked++;
      throw GeminiException('Ağ hatası: x');
    };
    final t = await SmartUserCats.trial(
        name: 'Kira', about: 'x', credentials: creds, scope: scope);
    expect(t.stoppedBy, AppStrings.current.t('uerr.offline'));
    expect(asked, lessThanOrEqualTo(2), reason: 'iki işçi, ilk hatada durur');

    // Kural: ağ/kota/yetki durdurur; sunucu hatası ve okunamayan yanıt
    // (dosyaya özgü) durdurmaz.
    expect(SmartSort.stopsRun(const SocketException('x')), isTrue);
    expect(SmartSort.stopsRun(GeminiException('x', statusCode: 403)), isTrue);
    expect(SmartSort.stopsRun(GeminiException('x', statusCode: 500)), isFalse);
    expect(SmartSort.stopsRun(GeminiException('x', statusCode: 400)), isFalse);
    Object? parse;
    try {
      DecisionResult.parse('bozuk', const []);
    } catch (e) {
      parse = e;
    }
    expect(parse, isA<GeminiException>());
    expect(SmartSort.stopsRun(parse!), isFalse,
        reason: 'yanıt geldi ama okunamadı — bağlantı yok değil');
  });

  test('Dene: anahtar yoksa nedeni söylenir, istek atılmaz (U4)', () async {
    var asked = 0;
    SmartUserCats.candidates = (_) async => [entry('/d/f0.pdf')];
    SmartUserCats.ask = (keys, input, qs) async {
      asked++;
      throw GeminiException('x', statusCode: 500);
    };
    final t = await SmartUserCats.trial(
        name: 'Kira',
        about: 'x',
        credentials: const AiCredentials(keys: []),
        scope: scope);
    expect(t.stoppedBy, AppStrings.current.t('uerr.ai_key'));
    expect(asked, 0);
  });

  test('ekle: deneme yanıtları kayda yazılır; en çok 30 kategori', () async {
    SmartSort.debugReset(const [
      SmartRecord(path: '/d/a.pdf', size: 1, modifiedMs: 1, cat: 'contract', conf: 0.5),
      // Denemeden sonra değişmiş dosya: yazılmaz (normal tur yeniden sorar).
      SmartRecord(path: '/d/b.pdf', size: 9, modifiedMs: 1, cat: 'contract', conf: 0.5),
    ]);
    final t = SmartTrial('Kira', 'Kira dekontu', [
      SmartTrialHit(entry('/d/a.pdf'), 0.9),
      SmartTrialHit(entry('/d/b.pdf'), 0.9),
      SmartTrialHit(entry('/d/c.pdf'), 0.9),
    ]);
    final c = await SmartUserCats.add(
        name: ' Kira ', about: 'Kira dekontu', trial: t, nowMs: 1000);
    expect(c, isNotNull);
    expect(c!.name, 'Kira');
    expect(SmartUserCats.isUserId(c.id), isTrue);
    expect(SmartSort.of('/d/a.pdf')!.uc.keys, [c.id]);
    expect(SmartSort.of('/d/b.pdf')!.uq, isEmpty);
    expect(SmartSort.of('/d/c.pdf'), isNull);

    for (var i = 1; i < SmartUserCats.maxCats; i++) {
      expect(await SmartUserCats.add(name: 'K$i', about: 'A', nowMs: 1000),
          isNotNull);
    }
    expect(SmartUserCats.all.map((c) => c.id).toSet(),
        hasLength(SmartUserCats.maxCats),
        reason: 'aynı anda eklenenler de tekil kimlik alır');
    expect(SmartUserCats.isFull, isTrue);
    expect(await SmartUserCats.add(name: 'Fazla', about: 'A'), isNull);
  });

  test('düzenle: cümle değişince eski yanıtlar silinir, simge değişince kalır',
      () async {
    SmartUserCats.debugReset([rent]);
    SmartSort.debugReset(const [
      SmartRecord(
          path: '/d/a.pdf',
          size: 1,
          modifiedMs: 1,
          cat: 'contract',
          uc: {'u:a': 90},
          uq: ['u:a']),
    ]);
    await SmartUserCats.update(rent.copyWith(icon: 'home'));
    expect(SmartUserCats.byId('u:a')!.icon, 'home');
    expect(SmartSort.of('/d/a.pdf')!.uc, {'u:a': 90});
    await SmartUserCats.update(rent.copyWith(about: 'Yalnız kira sözleşmesi'));
    expect(SmartSort.of('/d/a.pdf')!.uq, isEmpty);
    expect(SmartUserCats.pendingCount('u:a'), 1);
  });

  test('geriye dönük uygula: yalnız o soru, ilerlemeli, sorulmuşa tekrar yok',
      () async {
    final dir = Directory.systemTemp.createTempSync('suc');
    addTearDown(() => dir.deleteSync(recursive: true));
    final records = <SmartRecord>[];
    for (var i = 0; i < 4; i++) {
      final f = File('${dir.path}/b$i.pdf')..writeAsStringSync('x' * (i + 1));
      final st = f.statSync();
      records.add(SmartRecord(
          path: f.path,
          size: st.size,
          modifiedMs: st.modified.millisecondsSinceEpoch,
          cat: 'contract',
          conf: 0.8,
          // Biri zaten sorulmuş.
          uq: i == 0 ? const ['u:a'] : const []));
    }
    SmartUserCats.debugReset([rent, cat]);
    SmartSort.debugReset(records);
    final asked = <String>[];
    final progress = <int>[];
    void listen() {
      final p = SmartUserCats.applying.value;
      if (p != null) progress.add(p.done);
    }

    SmartUserCats.applying.addListener(listen);
    addTearDown(() => SmartUserCats.applying.removeListener(listen));
    SmartUserCats.prepare = (e, keys) async =>
        SmartPrepared({'text': e.path}, keys);
    SmartUserCats.ask = (keys, input, qs) async {
      expect(qs.single.id, 'uc_a', reason: 'yalnız o kategorinin sorusu');
      final path = input.single['text'] as String;
      asked.add(path);
      return yesAnswer(qs.single, path.endsWith('b2.pdf') ? 0.8 : 0.3);
    };
    final r = await SmartUserCats.apply('u:a', credentials: creds, scope: scope);
    expect(r.asked, 3);
    expect(r.matched, 1);
    expect(asked, hasLength(3));
    expect(progress, contains(3));
    expect(SmartUserCats.applying.value, isNull);
    expect(SmartUserCats.pendingCount('u:a'), 0);
    expect(SmartUserCats.pendingCount('u:b'), 4, reason: 'öteki kategori ayrı');
    expect(SmartSort.pathsOf('u:a'), ['${dir.path}/b2.pdf']);
    // İkinci uygulama hiç istek atmaz.
    asked.clear();
    final again =
        await SmartUserCats.apply('u:a', credentials: creds, scope: scope);
    expect(again.asked, 0);
    expect(asked, isEmpty);
  });
}
