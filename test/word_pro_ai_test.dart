import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile/word_format_ui.dart';
import 'package:dosya_okuyucu/services/dictation.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 6 + 10 — sesle yazma kancası, AI istem/ayrıştırma; Araçlar
/// sekmesinin bütün düğmelerinin çevirisi var.
void main() {
  test('dikte: test kancası dil koduyla çağrılır', () async {
    String? asked;
    Dictation.testHook = (lang) async {
      asked = lang;
      return 'merhaba dünya';
    };
    expect(await Dictation.listen(lang: 'tr-TR'), 'merhaba dünya');
    expect(asked, 'tr-TR');
    Dictation.testHook = null;
  });

  test('AI istemi metni sınırlar arasında taşır, yanıt temizlenir', () {
    final p = DocxAi.prompt('Özetle.', 'Uzun metin');
    expect(p, contains('---\nUzun metin\n---'));
    expect(DocxAi.clean('```\nSonuç\n```'), 'Sonuç');
    expect(DocxAi.clean('"Sonuç"'), 'Sonuç');
  });

  test('yazım önerileri: kod çiti, metinde olmayan/aynı öneri atılır', () {
    const text = 'Bu cümlede bir yanlışlik var ve birşey eksik.';
    const answer = '```json\n[{"wrong":"yanlışlik","right":"yanlışlık","reason":"yazım"},'
        '{"wrong":"birşey","right":"bir şey","reason":"ayrı yazılır"},'
        '{"wrong":"yok","right":"var","reason":"x"},'
        '{"wrong":"var","right":"var","reason":"aynı"}]\n```';
    final s = DocxAi.parseProof(answer, text);
    expect(s.map((x) => x.right), ['yanlışlık', 'bir şey']);
    expect(DocxAi.parseProof('bozuk', text), isEmpty);
  });

  test('Araçlar sekmesi ve AI görevleri çevrili', () {
    final keys = AppStrings.keys;
    for (final g in kWordProTools) {
      for (final (id, _) in g) {
        expect(keys, contains('wp.$id'), reason: id);
      }
    }
    for (final id in const ['tbl_merge', 'tbl_split', 'tbl_borders', 'tbl_autofit', 'tbl_sort']) {
      expect(keys, contains('wp.$id'));
    }
    for (final t in kWordAiTasks) {
      expect(keys, contains('wp.ai_$t'));
      expect(keys, contains('wp.ai_p_$t'));
    }
  });
}
