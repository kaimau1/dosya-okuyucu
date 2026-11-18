import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
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

  final entry = FsEntry(
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
}
