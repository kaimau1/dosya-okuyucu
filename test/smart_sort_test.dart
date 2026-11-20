import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Akıllı düzen (2026-11-18): şema geçerliliği, yanıt → kayıt, dil bağımsız
/// ikinci ad, çok dilli arama, süzgeç ve gizleme.
void main() {
  const tr = AppStrings(AppLanguage.tr);
  const en = AppStrings(AppLanguage.en);
  const ar = AppStrings(AppLanguage.ar);

  test('şema: seçenekler API sınırında (2–255), kimlikler temiz, kaçış var', () {
    final qs = SmartTaxonomy.questions(image: true, nowYear: 2026);
    final ids = qs.map((q) => q.id).toSet();
    expect(ids.length, qs.length, reason: 'soru kimlikleri tekil');
    expect(ids, containsAll(['cat', 'month', 'year', 'blurry', 'accidental']));
    for (final q in qs) {
      if (q.kind != DecisionKind.choice) continue;
      expect(q.options.length, inInclusiveRange(2, 255), reason: q.id);
      for (final k in q.options.keys) {
        expect(k.trim(), k, reason: '${q.id}: "$k"');
        expect(k, isNotEmpty);
      }
      expect(
          q.options.keys.any((k) => k == 'other' || k == 'none'), isTrue,
          reason: '${q.id} kaçış seçeneği');
    }
    // Belgede bulanıklık sorulmaz.
    final doc = SmartTaxonomy.questions(image: false, nowYear: 2026);
    expect(doc.map((q) => q.id), isNot(contains('blurry')));
    // Belgeye (PDF) ekran görüntüsü / fotoğraf seçeneği sunulmaz.
    final docCat = doc.firstWhere((q) => q.id == 'cat');
    expect(docCat.options.keys, isNot(contains('screenshot')));
    expect(docCat.options.keys, contains('email'));
  });

  test('her kategori ve alt türün üç dilde adı var', () {
    for (final s in [tr, en, ar]) {
      for (final c in SmartTaxonomy.categoryIds) {
        expect(s.t('sm.c_$c'), isNot('sm.c_$c'));
      }
      for (final m in SmartTaxonomy.subtypes.values) {
        for (final sub in m.keys.where((k) => k != 'other')) {
          expect(s.t('sm.s_$sub'), isNot('sm.s_$sub'), reason: sub);
        }
      }
    }
  });

  DecisionAnswer choice(String id, String value, double conf) => DecisionAnswer(
        question: DecisionQuestion.choice(id, id, id, const {'a': 'a', 'b': 'b'}),
        choice: value,
        confidence: conf,
      );

  const entry = FsEntry(
      path: '/s/Download/fatura.pdf',
      name: 'fatura.pdf',
      isDir: false,
      sizeBytes: 100,
      modifiedMs: 5);

  test('yanıt → kayıt; düşük güvenli tarih ve alt tür alınmaz', () {
    final rec = SmartSort.fromAnswers(
      entry,
      DecisionResult([
        choice('cat', 'invoice', 0.92),
        choice('sub_invoice', 'electricity', 0.8),
        choice('month', '10', 0.7),
        choice('year', '2026', 0.3),
        choice('bank_name', 'ziraat', 0.9),
      ]),
    )!;
    expect(rec.cat, 'invoice');
    expect(rec.sub, 'electricity');
    expect(rec.month, 10);
    expect(rec.year, 0, reason: 'güven 0,3');
    expect(rec.bank, '', reason: 'banka yalnız banka belgesinde');
  });

  test('ikinci ad dil bağımsız kimlikten kurulur', () {
    const r = SmartRecord(
      path: '/a.pdf', size: 1, modifiedMs: 1, cat: 'bank', conf: 0.9,
      sub: 'transfer', bank: 'ziraat', month: 10, year: 2026,
    );
    expect(SmartSort.render(r, tr), 'Dekont · Ziraat Bankası · Ekim 2026');
    expect(SmartSort.render(r, en), 'Transfer receipt · Ziraat Bankası · October 2026');
    expect(SmartSort.render(r, ar), contains('2026'));
    // Kişisel fotoğraf ve düşük güven: ad yok.
    const photo = SmartRecord(
        path: '/b.jpg', size: 1, modifiedMs: 1, cat: 'photo_people', conf: 0.99);
    expect(SmartSort.render(photo, tr), '');
    const weak = SmartRecord(
        path: '/c.pdf', size: 1, modifiedMs: 1, cat: 'invoice', conf: 0.3);
    expect(SmartSort.render(weak, tr), '');
  });

  test('arama üç dilde ve eşanlamla bulur; süzgeç ve gizleme', () {
    SmartSort.debugReset(const [
      SmartRecord(path: '/x/f.pdf', size: 1, modifiedMs: 1, cat: 'invoice', conf: 0.9),
      SmartRecord(
          path: '/x/g.jpg', size: 1, modifiedMs: 1, cat: 'greeting', conf: 0.9,
          hidden: true),
      SmartRecord(path: '/x/h.jpg', size: 1, modifiedMs: 1, cat: 'photo_other', blurry: true),
    ]);
    final k = SmartSort.keywordsOf('/x/f.pdf');
    for (final word in ['fatura', 'invoice', 'فاتورة', 'bill']) {
      expect(k, contains(word), reason: word);
    }
    expect(SmartSort.isHidden('/x/g.jpg'), isTrue);
    expect(SmartSort.counts().containsKey('greeting'), isFalse,
        reason: 'gizliler sayılmaz');
    expect(SmartSort.clutter().map((r) => r.path), ['/x/h.jpg']);
    expect(SmartSort.clutter().single.clutterReason, 'blurry');
    // U4 dilim 2: bulanık belge fotoğrafı (fiş, kimlik) Ayıkla'ya önerilmez;
    // fotoğraf belgeye düzeltilince de çıkar.
    const shot = SmartRecord(
        path: '/x/r.jpg', size: 1, modifiedMs: 1, cat: 'receipt', blurry: true,
        accidental: true);
    expect(shot.clutter, isFalse);
    expect(shot.clutterReason, isNull);
    expect(shot.copyWith(cat: 'photo_other').clutterReason, 'accidental');

    FmFilter.smartCatOf = SmartSort.categoryOf;
    addTearDown(() => FmFilter.smartCatOf = null);
    final f = FmFilter.none.toggleSmartCat('invoice');
    FsEntry e(String path) => FsEntry(
        path: path, name: path.split('/').last, isDir: false, sizeBytes: 1, modifiedMs: 1);
    expect(f.matches(e('/x/f.pdf')), isTrue);
    expect(f.matches(e('/x/h.jpg')), isFalse);
    expect(f.activeCount, 1);
    expect(f.signature, isNot(FmFilter.none.signature));
  });

  test('kayıt JSON gidiş-dönüş', () {
    const r = SmartRecord(
      path: '/a.pdf', size: 9, modifiedMs: 7, cat: 'health', conf: 0.81,
      sub: 'lab_result', month: 3, year: 2025, user: true, hidden: true,
    );
    final back = SmartRecord.fromJson(r.toJson())!;
    expect(back.cat, 'health');
    expect(back.sub, 'lab_result');
    expect(back.conf, closeTo(0.81, 0.01));
    expect(back.month, 3);
    expect(back.year, 2025);
    expect(back.user, isTrue);
    expect(back.hidden, isTrue);
  });

  // ── Şema 2.0 (2026-11-18, PLAN §1.1 m.1) ──────────────────────────────
  group('şema 2.0', () {
    final today = DateTime(2026, 11, 18);
    final day = SmartDates.dayOf(today);

    test('tek istek: soru sayısı sınırda, bugün istekte, türe göre sorular', () {
      final img = SmartTaxonomy.questions(image: true, today: today);
      final doc = SmartTaxonomy.questions(image: false, today: today);
      expect(img.length, lessThanOrEqualTo(GeminiDecisions.maxQuestions));
      expect(doc.length, lessThan(img.length));
      final ids = doc.map((q) => q.id).toSet();
      expect(ids, containsAll([
        'sub_receipt', 'sub_tax_salary', 'sub_contract', 'sub_official',
        'sub_insurance_vehicle', 'sub_work', 'sub_manual', 'provider',
        'due', 'valid', 'amount',
      ]));
      // Görsele özgü alt türler belgede sorulmaz; kurulum sorusu yalnız
      // APK/arşivde.
      expect(ids, isNot(contains('sub_screenshot')));
      expect(ids, isNot(contains('sub_package')));
      expect(img.map((q) => q.id),
          containsAll(['sub_screenshot', 'sub_photo_other']));
      final due = doc.firstWhere((q) => q.id == 'due');
      expect(due.instructions, contains('Today is 2026-11-18'));
      final amount = doc.firstWhere((q) => q.id == 'amount');
      expect(amount.options.keys,
          [...SmartTaxonomy.amountOrder, 'none']);
      // APK/arşiv: tek soru.
      final meta = SmartTaxonomy.questions(image: false, meta: true);
      expect(meta.map((q) => q.id), ['sub_package']);
      expect(meta.single.options.keys,
          containsAll(['installer', 'backup', 'download', 'other']));
    });

    test('alt tür kimlikleri bütün kategorilerde tekil', () {
      final seen = <String, String>{};
      for (final e in SmartTaxonomy.subtypes.entries) {
        for (final sub in e.value.keys.where((k) => k != 'other')) {
          expect(seen.containsKey(sub), isFalse,
              reason: '$sub hem ${seen[sub]} hem ${e.key}');
          seen[sub] = e.key;
          expect(SmartTaxonomy.categoryOfSub(sub), e.key);
        }
      }
      expect(SmartTaxonomy.categoryIds, contains(SmartTaxonomy.package));
    });

    test('kurum yalnız faturada ve alt türüyle uyumluysa', () {
      expect(SmartTaxonomy.providerFits('enerjisa', 'invoice', 'electricity'),
          isTrue);
      expect(SmartTaxonomy.providerFits('turkcell', 'invoice', 'electricity'),
          isFalse, reason: 'elektrik faturasına GSM yazılmaz');
      expect(SmartTaxonomy.providerFits('igdas', 'invoice', ''), isTrue);
      expect(SmartTaxonomy.providerFits('igdas', 'receipt', ''), isFalse);
      expect(SmartTaxonomy.providerFits('other', 'invoice', ''), isFalse);
      expect(SmartTaxonomy.providerName('enerjisa'), 'Enerjisa');
      expect(SmartTaxonomy.providerName('other'), '');
      // Her kurumun hizmet grubu tanımlı (kaçış hariç).
      for (final id in SmartTaxonomy.providers.keys.where((k) => k != 'other')) {
        expect(SmartTaxonomy.providerFits(id, 'invoice', ''), isTrue,
            reason: id);
      }
    });

    test('yanıt → kayıt: kurum, tarih aralığı, tutar, sorulduğu gün', () {
      final rec = SmartSort.fromAnswers(
        entry,
        DecisionResult([
          choice('cat', 'invoice', 0.9),
          choice('sub_invoice', 'electricity', 0.8),
          choice('provider', 'enerjisa', 0.7),
          choice('due', 'week', 0.8),
          choice('valid', 'past', 0.9),
          choice('amount', '500_2000', 0.6),
        ]),
        today: today,
      )!;
      expect(rec.provider, 'enerjisa');
      expect(rec.due, 'week');
      expect(rec.valid, '', reason: 'fatura süresi dolan kategori değil');
      expect(rec.amount, '500_2000');
      expect(rec.asked, day);
      expect(SmartSort.render(rec, tr), 'Elektrik faturası · Enerjisa');

      // Uyumsuz kurum, düşük güven ve "none" alınmaz.
      final weak = SmartSort.fromAnswers(
        entry,
        DecisionResult([
          choice('cat', 'invoice', 0.9),
          choice('sub_invoice', 'water', 0.8),
          choice('provider', 'vodafone', 0.9),
          choice('due', 'past', 0.3),
          choice('amount', 'none', 0.9),
        ]),
        today: today,
      )!;
      expect(weak.provider, '');
      expect(weak.due, '');
      expect(weak.amount, '');

      // Kimlik: geçerlilik alınır, tutar alınmaz.
      final id = SmartSort.fromAnswers(
        entry,
        DecisionResult([
          choice('cat', 'id', 0.9),
          choice('valid', 'past', 0.8),
          choice('amount', 'gt2000', 0.9),
        ]),
        today: today,
      )!;
      expect(id.valid, 'past');
      expect(id.amount, '');
      expect(id.expiredAt(day), isTrue);
    });

    test('APK/arşiv: kategori sabit, yalnız alt tür', () {
      const apk = FsEntry(
          path: '/s/Download/oyun.apk',
          name: 'oyun.apk',
          isDir: false,
          sizeBytes: 5000,
          modifiedMs: 9);
      final rec = SmartSort.fromAnswers(
        apk,
        DecisionResult([choice('sub_package', 'installer', 0.8)]),
        today: today,
      )!;
      expect(rec.cat, SmartTaxonomy.package);
      expect(rec.sub, 'installer');
      expect(SmartSort.render(rec, tr), 'Kurulum dosyası');
      final unsure = SmartSort.fromAnswers(
        apk,
        DecisionResult([choice('sub_package', 'backup', 0.2)]),
      )!;
      expect(unsure.sub, '');
      expect(SmartSort.render(unsure, en), 'Installer / archive');
      expect(SmartSort.fromAnswers(apk, const DecisionResult([])), isNull);
    });

    test('rozet tarihi: aralık zamanla geçmişe döner', () {
      const a = 20000; // sorulduğu gün
      expect(SmartDates.overdue('past', a, a), isTrue);
      expect(SmartDates.overdue('week', a, a + 7), isFalse);
      expect(SmartDates.overdue('week', a, a + 8), isTrue);
      expect(SmartDates.overdue('month', a, a + 31), isFalse);
      expect(SmartDates.overdue('month', a, a + 32), isTrue);
      expect(SmartDates.overdue('later', a, a + 400), isFalse);
      expect(SmartDates.overdue('week', 0, a), isFalse,
          reason: 'sorulduğu gün bilinmiyorsa yalnız "geçmiş" sayılır');
      expect(SmartDates.overdue('', a, a), isFalse);
      expect(SmartDates.expired('year', a, a + 366), isFalse);
      expect(SmartDates.expired('year', a, a + 367), isTrue);
      expect(SmartDates.expired('none', a, a + 9999), isFalse);
      expect(SmartDates.dayOf(DateTime(2026, 11, 19)) - day, 1);

      SmartSort.debugReset([
        SmartRecord(
            path: '/o.pdf', size: 1, modifiedMs: 1, cat: 'invoice', conf: 0.9,
            due: 'week', asked: day, amount: 'lt100'),
        SmartRecord(
            path: '/e.pdf', size: 1, modifiedMs: 2, cat: 'insurance_vehicle',
            conf: 0.9, valid: 'past', asked: day),
        SmartRecord(
            path: '/h.pdf', size: 1, modifiedMs: 3, cat: 'invoice', conf: 0.9,
            due: 'past', asked: day, amount: 'lt100', hidden: true),
        // Fiş kategorisinde "geçmiş" son ödeme rozet vermez.
        SmartRecord(
            path: '/r.pdf', size: 1, modifiedMs: 4, cat: 'receipt', conf: 0.9,
            due: 'past', asked: day, amount: 'gt2000'),
      ]);
      expect(SmartSort.overdue(today), isEmpty);
      expect(SmartSort.overdue(today.add(const Duration(days: 8)))
          .map((r) => r.path), ['/o.pdf']);
      expect(SmartSort.expired(today).map((r) => r.path), ['/e.pdf']);
      expect(SmartSort.amountCounts(), {'lt100': 1, 'gt2000': 1},
          reason: 'gizli dosya sayılmaz');
      expect(SmartSort.withAmount('gt2000').map((r) => r.path), ['/r.pdf']);
    });

    test('geriye uyum: alt tür/yeni alan olmayan eski kayıt bozulmadan okunur',
        () {
      final old = SmartRecord.fromJson(const {
        'p': '/eski.pdf', 's': 3, 'm': 4, 'c': 'invoice', 'f': 80,
      })!;
      expect(old.sub, '');
      expect(old.provider, '');
      expect(old.due, '');
      expect(old.asked, 0);
      expect(old.overdueAt(SmartDates.dayOf(today)), isFalse);
      expect(SmartSort.render(old, tr), 'Fatura');
      // Bozuk türlü alanlar düşmez, boş sayılır.
      final odd = SmartRecord.fromJson(const {
        'p': '/x.pdf', 'c': 'bank', 'st': 5, 'du': 1, 'ad': 'x', 'mo': '3',
      })!;
      expect(odd.sub, '');
      expect(odd.due, '');
      expect(odd.asked, 0);
      expect(odd.month, 0);
      // Yeni alanlar gidiş-dönüş.
      final r = SmartRecord(
          path: '/n.pdf', size: 1, modifiedMs: 1, cat: 'invoice', conf: 0.9,
          sub: 'natural_gas', provider: 'igdas', due: 'past', valid: '',
          amount: '100_500', asked: day);
      final back = SmartRecord.fromJson(r.toJson())!;
      expect(back.provider, 'igdas');
      expect(back.due, 'past');
      expect(back.amount, '100_500');
      expect(back.asked, day);
      expect(r.toJson().containsKey('va'), isFalse);
      // Kategori düzeltilince kurum düşer, tarih aralığı kalır.
      final moved = r.copyWith(cat: 'receipt', user: true);
      expect(moved.provider, '');
      expect(moved.due, 'past');
      expect(moved.overdueAt(day), isFalse, reason: 'fiş son ödeme almaz');
    });

    test('usage: girdi belirteci yanıttan okunur', () {
      const q = [
        DecisionQuestion.choice('cat', 'cat', 'x', {'a': 'a', 'other': 'o'}),
      ];
      final r = DecisionResult.parse(
          '{"answers":{"cat":{"choice":"a","confidence":0.9}},'
          '"usage":{"input_tokens":1234}}',
          q);
      expect(r.inputTokens, 1234);
      expect(
          DecisionResult.parse(
                  '{"answers":{},"usageMetadata":{"promptTokenCount":77}}', q)
              .inputTokens,
          77);
      expect(DecisionResult.parse('{"answers":{}}', q).inputTokens, isNull);
      const u = SmartUsage(4, 4100, 100);
      expect(u.tokensPerFile, 1025);
      expect(u.questionsPerFile, 25);
    });
  });

  test('taşınan dosya/klasör kategorisini korur, çöpe giden eski yolda kalır',
      () async {
    SmartSort.debugReset(const [
      SmartRecord(path: '/d/a.pdf', size: 1, modifiedMs: 1, cat: 'invoice'),
      SmartRecord(path: '/d/k/b.pdf', size: 1, modifiedMs: 1, cat: 'id'),
      SmartRecord(path: '/d/k2/c.pdf', size: 1, modifiedMs: 1, cat: 'id'),
    ]);
    await SmartSort.movePath('/d/a.pdf', '/e/a.pdf');
    expect(SmartSort.categoryOf('/e/a.pdf'), 'invoice');
    expect(SmartSort.of('/d/a.pdf'), isNull);
    await SmartSort.movePath('/d/k', '/e/k');
    expect(SmartSort.categoryOf('/e/k/b.pdf'), 'id');
    expect(SmartSort.categoryOf('/d/k2/c.pdf'), 'id', reason: 'sınır');
    await SmartSort.movePath('/e/a.pdf', '/x/.dosya-okuyucu-cop/1_a.pdf');
    expect(SmartSort.categoryOf('/e/a.pdf'), 'invoice');
    SmartSort.debugReset();
  });

  test('hayalet kayıt düşer; çöpteki ve takılı olmayan birimdeki kalır (U4)',
      () async {
    final tmp = Directory.systemTemp.createTempSync('sprune_');
    final root0 = FmEnv.primaryRoot;
    FmEnv.primaryRoot = tmp.path;
    try {
      final live = File('${tmp.path}/a.pdf')..writeAsStringSync('x');
      final gone = '${tmp.path}/silindi.pdf';
      final trashed = '${tmp.path}/copte.pdf';
      const sd = '/yok-sd-kart/c.pdf';
      SmartSort.debugReset([
        SmartRecord(path: live.path, size: 1, modifiedMs: 1, cat: 'invoice'),
        SmartRecord(path: gone, size: 1, modifiedMs: 1, cat: 'invoice'),
        SmartRecord(path: trashed, size: 1, modifiedMs: 1, cat: 'id'),
        const SmartRecord(path: sd, size: 1, modifiedMs: 1, cat: 'id'),
      ]);
      final n = await SmartSort.pruneMissing(trashed: () async => {trashed});
      expect(n, 1);
      expect(SmartSort.of(gone), isNull);
      expect(SmartSort.of(live.path), isNotNull);
      expect(SmartSort.of(trashed), isNotNull, reason: 'geri yüklenince yerinde');
      expect(SmartSort.of(sd), isNotNull, reason: 'SD çıkarılmış olabilir');
      expect(SmartSort.counts()['invoice'], 1);
      // Çöp okunamazsa hiçbir şey silinmez.
      SmartSort.debugReset([
        SmartRecord(path: gone, size: 1, modifiedMs: 1, cat: 'invoice'),
      ]);
      expect(
          await SmartSort.pruneMissing(
              trashed: () async => throw StateError('bozuk')),
          0);
      expect(SmartSort.of(gone), isNotNull);
    } finally {
      FmEnv.primaryRoot = root0;
      SmartSort.debugReset();
      tmp.deleteSync(recursive: true);
    }
  });

  test('taşıma kuralı: varsayılan boş, hedefte duran ve gizli atlanır', () {
    SmartSort.debugReset(const [
      SmartRecord(path: '/d/a.pdf', size: 1, modifiedMs: 1, cat: 'invoice'),
      SmartRecord(path: '/F/b.pdf', size: 1, modifiedMs: 1, cat: 'invoice'),
      SmartRecord(
          path: '/d/c.pdf', size: 1, modifiedMs: 1, cat: 'invoice',
          hidden: true),
      SmartRecord(path: '/d/e.pdf', size: 1, modifiedMs: 1, cat: 'id'),
    ]);
    expect(SmartSort.pendingRuleMoves(const {}), isEmpty);
    expect(SmartSort.pendingRuleMoves(const {'invoice': '/F'}), {
      '/F': ['/d/a.pdf'],
    });
    SmartSort.debugReset();
  });

  test('Ayıkla: 30 günden eski ekran görüntüsü önerilir, yenisi önerilmez', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    const day = Duration.millisecondsPerDay;
    final old = SmartRecord(
        path: '/s1.png', size: 1, modifiedMs: now - 40 * day, cat: 'screenshot');
    final fresh = SmartRecord(
        path: '/s2.png', size: 1, modifiedMs: now - 2 * day, cat: 'screenshot');
    final photo = SmartRecord(
        path: '/p.jpg', size: 1, modifiedMs: now - 400 * day, cat: 'photo_people');
    expect(old.clutter, isTrue);
    expect(old.clutterReason, 'old_shot');
    expect(fresh.clutter, isFalse);
    expect(photo.clutter, isFalse);
    expect(tr.t('sm.r_old_shot'), isNot('sm.r_old_shot'));
  });
}
