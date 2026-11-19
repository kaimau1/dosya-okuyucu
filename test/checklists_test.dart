import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/fm/checklists.dart';
import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const s = AppStrings(AppLanguage.tr);
  const list = Checklist('u_1', 'Vize', ['Pasaport', 'Fotoğraf', 'Sigorta']);

  DecisionAnswer yes(int i, double p) => DecisionAnswer(
        question: Checklists.questions(list)[i],
        yes: p,
        confidence: 0.9,
      );

  test('maddeler: satır/| ayrılır, boş ve yinelenen düşer, tavan 20', () {
    expect(Checklists.parseItems(' A |B\n\nA| '), ['A', 'B']);
    expect(Checklists.parseItems(List.generate(30, (i) => 'm$i').join('\n')),
        hasLength(Checklists.maxItems));
  });

  test('hazır listeler üç dilde dolu', () {
    for (final lang in AppLanguage.values) {
      for (final c in Checklists.presets(AppStrings(lang))) {
        expect(c.items, isNotEmpty, reason: '${lang.name} ${c.id}');
        expect(c.builtIn, isTrue);
      }
    }
  });

  test('değerlendirme: en yüksek P(evet) kazanır, eksik ve yanıtsız ayrılır', () {
    final r = Checklists.evaluate(list, {
      '/a/pasaport.pdf': [yes(0, 0.92), yes(1, 0.2)],
      '/a/foto.jpg': [yes(0, 0.1), yes(1, 0.4)],
    });
    expect(r[0].ok, isTrue);
    expect(r[0].path, '/a/pasaport.pdf');
    expect(r[0].confidence, closeTo(0.92, 1e-9));
    expect(r[1].ok, isFalse);
    expect(r[1].answered, isTrue);
    expect(r[1].confidence, closeTo(0.6, 1e-9));
    expect(r[2].answered, isFalse);
    expect(r[2].confidence, 0);

    final text = Checklists.report(s, list, r, 2, DateTime(2026, 11, 19));
    expect(text, contains('19.11.2026'));
    expect(text, contains('[VAR] Pasaport — %92 (pasaport.pdf)'));
    expect(text, contains('[EKSİK] Fotoğraf — %60'));
    expect(text, contains('Eksik evrak (2)'));
    expect(text, isNot(contains('/a/')), reason: 'raporda yol yok');
  });

  test('kaydet / yükle / sil', () async {
    SharedPreferences.setMockInitialValues({});
    await Checklists.save(list);
    expect((await Checklists.loadSaved()).single.items, list.items);
    expect(await Checklists.delete(list.id), isEmpty);
  });
}
