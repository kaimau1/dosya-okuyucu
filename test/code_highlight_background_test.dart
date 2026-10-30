import 'package:dosya_okuyucu/core/edit/code_highlight.dart';
import 'package:dosya_okuyucu/core/edit/code_text_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 30 kalanı: 1 MB üstü metinde renklendirme arka planda (izolatta),
/// yazma durunca; o ana kadar düz çizilir (kaymış belirteç boyamaz).
void main() {
  tearDown(() => CodeTextController.backgroundTokenize =
      (t, l) async => tokenizeCode(t, l));

  test('büyük metin: önce düz, gecikmeden sonra belirteçler gelir', () async {
    var runs = 0;
    CodeTextController.backgroundTokenize = (t, l) async {
      runs++;
      return tokenizeCode(t, l);
    };
    final line = 'final x = "dize"; // yorum\n';
    final big = line * ((codeHighlightMaxChars ~/ line.length) + 10);
    final c = CodeTextController(text: big, lang: CodeLang.dart);
    expect(c.highlighting, isTrue);
    expect(c.backgroundHighlighting, isTrue);
    var notified = 0;
    c.addListener(() => notified++);
    expect(c.tokens, isEmpty, reason: 'henüz hesaplanmadı → düz');
    await Future<void>.delayed(
        CodeTextController.backgroundDelay + const Duration(milliseconds: 100));
    expect(runs, 1);
    expect(notified, 1);
    expect(c.tokens, isNotEmpty);
    expect(c.tokens.any((t) => t.kind == CodeTokenKind.keyword), isTrue);
    // Yazınca belirteçler bayatlar: tekrar düz, sonra yeniden hesap.
    c.text = 'var y = 1;\n$big';
    expect(c.tokens, isEmpty);
    await Future<void>.delayed(
        CodeTextController.backgroundDelay + const Duration(milliseconds: 100));
    expect(runs, 2);
    expect(c.tokens.first.start, 0);
    c.dispose();
  });

  test('4 MB üstünde renklendirme kapalı', () {
    final c = CodeTextController(
        text: 'a' * (codeHighlightIsolateMaxChars + 1), lang: CodeLang.dart);
    expect(c.highlighting, isFalse);
    c.dispose();
  });
}
