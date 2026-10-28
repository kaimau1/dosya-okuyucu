import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/core/edit/code_editing.dart';
import 'package:dosya_okuyucu/core/edit/code_highlight.dart';
import 'package:dosya_okuyucu/core/edit/code_text_controller.dart';
import 'package:dosya_okuyucu/core/edit/markdown_edit.dart';
import 'package:dosya_okuyucu/core/text_replace.dart';
import 'package:dosya_okuyucu/widgets/code_gutter.dart';

TextEditingValue v(String t, [int? a, int? b]) => TextEditingValue(
    text: t,
    selection: a == null
        ? TextSelection.collapsed(offset: t.length)
        : TextSelection(baseOffset: a, extentOffset: b ?? a));

String kinds(String src, CodeLang l) => tokenizeCode(src, l)
    .map((t) => '${t.kind.name}:${src.substring(t.start, t.end)}')
    .join('|');

void main() {
  group('sözdizimi', () {
    test('dart: anahtar sözcük, dize, yorum, sayı', () {
      const s = "final x = 'a'; // not\nFoo y = 42;";
      final k = kinds(s, CodeLang.dart);
      expect(k, contains('keyword:final'));
      expect(k, contains("string:'a'"));
      expect(k, contains('comment:// not'));
      expect(k, contains('number:42'));
      expect(k, contains('type:Foo'));
    });
    test('python üç tırnak ve # yorum; url#parça yorum değil', () {
      const s = 'x = """a\nb"""\n# c\nu = "http://a#b"';
      final k = kinds(s, CodeLang.python);
      expect(k, contains('string:"""a\nb"""'));
      expect(k, contains('comment:# c'));
      expect(k, isNot(contains('comment:#b')));
    });
    test('kapanmamış dize satırda biter, kapanmamış yorum sona kadar', () {
      expect(kinds('a = "x\nb = 1', CodeLang.dart), contains('string:"x'));
      expect(kinds('/* x\ny', CodeLang.dart), contains('comment:/* x\ny'));
    });
    test('xml/html etiket, öznitelik dizesi, yorum', () {
      const s = '<a href="x">t</a><!-- c -->';
      final k = kinds(s, CodeLang.markup);
      expect(k, contains('tag:<a'));
      expect(k, contains('string:"x"'));
      expect(k, contains('comment:<!-- c -->'));
    });
    test('json ve uzantı eşleme; düz metin / dev metin boş', () {
      expect(kinds('{"a": true, "b": 1}', CodeLang.json),
          allOf(contains('keyword:true'), contains('number:1')));
      expect(codeLangFor('.YML'), CodeLang.yaml);
      expect(codeLangFor('.txt'), CodeLang.plain);
      expect(tokenizeCode('x' * (codeHighlightMaxChars + 1), CodeLang.dart),
          isEmpty);
    });
  });

  group('düzenleme kuralları', () {
    const f = CodeInputFormatter(indentWidth: 2);
    TextEditingValue type(String before, int pos, String ch) =>
        f.formatEditUpdate(
            v(before, pos),
            v(before.replaceRange(pos, pos, ch), pos + 1));

    test('Enter girintiyi korur', () {
      final r = type('  foo', 5, '\n');
      expect(r.text, '  foo\n  ');
      expect(r.selection.baseOffset, 8);
    });
    test('{ sonrası Enter girinti artırır; {|} arası iki satır açar', () {
      var r = type('a {', 3, '\n');
      expect(r.text, 'a {\n  ');
      r = type('a {}', 3, '\n');
      expect(r.text, 'a {\n  \n}');
      expect(r.selection.baseOffset, 6);
    });
    test('otomatik kapatma, üzerinden atlama, çiftli silme', () {
      var r = type('f', 1, '(');
      expect(r.text, 'f()');
      expect(r.selection.baseOffset, 2);
      r = type('f()', 2, ')');
      expect(r.text, 'f()');
      expect(r.selection.baseOffset, 3);
      r = f.formatEditUpdate(v('f()', 2), v('f)', 1));
      expect(r.text, 'f');
    });
    test('kelime içinde tırnak kapatılmaz', () {
      expect(type("don", 3, "'").text, "don'");
      expect(type('x = ', 4, '"').text, 'x = ""');
    });
    test('IME birleştirme sürerken dokunulmaz', () {
      const nv = TextEditingValue(
          text: 'ş(',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2));
      expect(f.formatEditUpdate(v('ş', 1), nv), nv);
    });
    test('girinti / girinti kaldır (çok satır)', () {
      var r = indentSelection(v('a\nb', 0, 3), 2);
      expect(r.text, '  a\n  b');
      r = outdentSelection(r, 2);
      expect(r.text, 'a\nb');
      expect(indentSelection(v('ab', 1), 4).text, 'a    b');
    });
    test('parantez eşleme', () {
      expect(matchBracket('f(a[b])', 2), (1, 6));
      expect(matchBracket('f(a[b])', 7), (6, 1));
      expect(matchBracket('abc', 1), isNull);
    });
    test('imleç ve ekleme', () {
      final r = insertAtCursor(v('ab', 1), '{}', cursorBack: 1);
      expect(r.text, 'a{}b');
      expect(r.selection.baseOffset, 2);
      expect(moveCursor(v('ab', 0), -1).selection.baseOffset, 0);
    });
  });

  group('düzenli ifade bul/değiştir', () {
    test('eşleşmeler ve geçersiz ifade', () {
      expect(TextReplace.regexMatches('a1 b22 c', r'\d+'), [(1, 2), (4, 6)]);
      expect(TextReplace.regexMatches('abc', '('), isNull);
      expect(TextReplace.regexMatches('Abc', 'abc', matchCase: true), isEmpty);
    });
    test('tümünü değiştir grup başvurusuyla', () {
      final r = TextReplace.regexReplaceAll('ad soyad', r'(\w+) (\w+)', r'$2 $1');
      expect(r.text, 'soyad ad');
      expect(r.count, 1);
    });
  });

  group('Markdown', () {
    test('kalın sar / geri al', () {
      var r = mdWrap(v('abc', 0, 3), '**');
      expect(r.text, '**abc**');
      r = mdWrap(r, '**');
      expect(r.text, 'abc');
    });
    test('başlık ve liste önekleri aç/kapa', () {
      var r = mdHeading(v('Merhaba', 0), 2);
      expect(r.text, '## Merhaba');
      expect(mdHeading(r, 2).text, 'Merhaba');
      r = mdLinePrefix(v('a\nb', 0, 3), '', numbered: true);
      expect(r.text, '1. a\n2. b');
      r = mdLinePrefix(v('- x', 0), '- [ ] ');
      expect(r.text, '- [ ] x');
    });
    test('bağlantı, kod, tablo', () {
      expect(mdLink(v('site', 0, 4)).text, '[site](https://)');
      expect(mdCode(v('x', 0, 1)).text, '`x`');
      expect(mdCode(v('a\nb', 0, 3)).text, '```\na\nb\n```');
      expect(mdTable(v('')).text, contains('| --- | --- |'));
    });
    test('Enter listeyi sürdürür, boş maddede çıkar', () {
      const f = MarkdownEnterFormatter();
      var r = f.formatEditUpdate(v('- a', 3), v('- a\n', 4));
      expect(r.text, '- a\n- ');
      r = f.formatEditUpdate(v('1. a', 4), v('1. a\n', 5));
      expect(r.text, '1. a\n2. ');
      r = f.formatEditUpdate(v('- a\n- ', 6), v('- a\n- \n', 7));
      expect(r.text, '- a\n');
    });
  });

  group('satır numaraları', () {
    const style = TextStyle(fontSize: 14, height: 1.5);
    test('sarılmayan: sabit adım', () {
      expect(codeLineTops('a\nb\nc', style, 200, wrap: false), [0, 21, 42]);
    });
    test('sarmalı: uzun satırın ardındaki numara aşağı kayar (TX2)', () {
      final long = 'kelime ' * 40;
      final tops = codeLineTops('$long\nson', style, 120, wrap: true);
      expect(tops.length, 2);
      expect(tops[1], greaterThan(21 * 3));
    });
    testWidgets('görünen aralığı boyar, çökmez', (tester) async {
      final ctl = TextEditingController(text: List.generate(500, (i) => 'x$i').join('\n'));
      final sc = ScrollController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  controller: sc,
                  child: CodeGutter(
                      controller: ctl,
                      scroll: sc,
                      size: 14,
                      textWidth: 300,
                      wrap: true)))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      sc.jumpTo(3000);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('CodeTextController renklendirir ve metni değiştirmez',
      (tester) async {
    final c = CodeTextController(text: 'final a = (1);', lang: CodeLang.dart);
    late TextSpan span;
    await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
      c.selection = const TextSelection.collapsed(offset: 12);
      span = c.buildTextSpan(
          context: ctx, style: const TextStyle(), withComposing: false);
      return const SizedBox();
    })));
    expect(span.toPlainText(), 'final a = (1);');
    final colored = (span.children ?? []).whereType<TextSpan>().where(
        (s) => s.style?.color != null).length;
    expect(colored, greaterThanOrEqualTo(2));
  });
}
