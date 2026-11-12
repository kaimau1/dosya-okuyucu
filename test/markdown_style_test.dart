import 'package:dosya_okuyucu/core/edit/code_text_controller.dart';
import 'package:dosya_okuyucu/core/edit/markdown_edit.dart';
import 'package:dosya_okuyucu/core/edit/markdown_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue v(String t, int a, [int? b]) => TextEditingValue(
    text: t, selection: TextSelection(baseOffset: a, extentOffset: b ?? a));

/// 2026-11-12 kullanıcı: Markdown'da "biçim yerine başına sonuna işaret
/// koyuyor, kodu kalıyor" — editör biçimi canlı göstermeli, kalın/eğik satır
/// önekini ve satır aşan seçimi doğru sarmalı.
void main() {
  int flagAt(String t, String needle, [int skip = 0]) =>
      markdownFlags(t)[t.indexOf(needle) + skip];

  group('canlı biçim bayrakları', () {
    test('kalın: içerik kalın, yıldızlar soluk', () {
      const t = 'a **kalın** b';
      expect(flagAt(t, 'kalın') & MdFlag.bold, isNot(0));
      expect(flagAt(t, '**') & MdFlag.mark, isNot(0));
      expect(flagAt(t, ' b'), 0);
    });

    test('başlık: işaret soluk, metin başlık + kalın', () {
      const t = '## Başlık\nnormal';
      expect(flagAt(t, '#') & MdFlag.mark, isNot(0));
      expect(flagAt(t, 'Başlık') & MdFlag.h2, isNot(0));
      expect(flagAt(t, 'normal'), 0);
    });

    test('eğik, üstü çizili, kod, bağlantı, görev', () {
      const t = '- [ ] _eğik_ ~~çiz~~ `k*o*d` [ad](https://x)';
      expect(flagAt(t, 'eğik') & MdFlag.italic, isNot(0));
      expect(flagAt(t, 'çiz') & MdFlag.strike, isNot(0));
      // Kod içindeki yıldız eğik sayılmaz.
      expect(flagAt(t, 'o*d') & MdFlag.italic, 0);
      expect(flagAt(t, 'o*d') & MdFlag.code, isNot(0));
      expect(flagAt(t, 'ad]') & MdFlag.link, isNot(0));
      expect(flagAt(t, 'https') & MdFlag.mark, isNot(0));
      expect(flagAt(t, '- [ ]') & MdFlag.bullet, isNot(0));
    });

    test('çitli kod bloğu içinde biçim yok', () {
      const t = '```\n**x**\n```\n**y**';
      expect(flagAt(t, 'x') & MdFlag.bold, 0);
      expect(flagAt(t, 'y') & MdFlag.bold, isNot(0));
    });

    test('dosya_adi_gibi sözcük içi alt çizgi eğik değil', () {
      const t = 'dosya_adi_gibi';
      expect(markdownFlags(t).every((f) => f == 0), isTrue);
    });
  });

  group('sarma düzeltmesi', () {
    test('başlık satırı seçilip kalın: önek dışarıda', () {
      final r = mdWrap(v('## Başlık', 0, 9), '**');
      expect(r.text, '## **Başlık**');
    });

    test('kenar boşlukları sarmanın dışında', () {
      expect(mdWrap(v('a kelime b', 1, 9), '**').text, 'a **kelime** b');
    });

    test('çok satır: her satır ayrı, boş satır dokunulmaz, ikinci kez kaldırır', () {
      var r = mdWrap(v('- [ ] bir\n\niki', 0, 14), '**');
      expect(r.text, '- [ ] **bir**\n\n**iki**');
      r = mdWrap(r, '**');
      expect(r.text, '- [ ] bir\n\niki');
    });
  });

  testWidgets('denetleyici metni değiştirmeden biçimli çizer', (tester) async {
    final c = CodeTextController(text: '# Ana\n**kalın**', markdown: true);
    late TextSpan span;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      span = c.buildTextSpan(
          context: ctx, style: const TextStyle(fontSize: 16), withComposing: false);
      return const SizedBox();
    })));
    expect(span.toPlainText(), c.text);
    final bold = (span.children!)
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == 'kalın');
    expect(bold.style?.fontWeight, FontWeight.w700);
  });
}
