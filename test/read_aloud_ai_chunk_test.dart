import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:dosya_okuyucu/services/read_aloud_ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sahte model: her çağrıyı sayar; [failFrom]'dan itibaren hata atar.
class _FakeGemini extends GeminiService {
  _FakeGemini({this.failFrom}) : super(apiKey: 'k', model: 'm');

  final int? failFrom;
  int calls = 0;

  @override
  Future<String> chat({
    required List<ChatTurn> history,
    String? fileContext,
    List<String> memory = const [],
  }) async {
    calls++;
    if (failFrom != null && calls >= failFrom!) {
      throw GeminiException('kota', statusCode: 429);
    }
    final prompt = history.last.text;
    final start = prompt.indexOf('"""\n') + 4;
    final end = prompt.lastIndexOf('\n"""');
    return prompt.substring(start, end);
  }
}

String _para(int i) => 'Paragraf $i ${'kelime ' * 300}'.trim();

void main() {
  test('uzun metin paragraf sınırında sınırı aşmayan parçalara bölünür', () {
    final text = [for (var i = 0; i < 12; i++) _para(i)].join('\n\n');
    final parts = ReadAloudAi.splitForTidy(text, max: 5000);
    expect(parts.length, greaterThan(1));
    for (final part in parts) {
      expect(part.length, lessThanOrEqualTo(5000));
    }
    // Sözcük kaybı yok.
    expect(parts.join(' ').split(RegExp(r'\s+')).length,
        text.split(RegExp(r'\s+')).length);
  });

  test('tek dev paragraf sözcük sınırında bölünür', () {
    final text = 'söz ' * 5000;
    final parts = ReadAloudAi.splitForTidy(text.trim(), max: 3000);
    expect(parts.every((p) => p.length <= 3000), isTrue);
    expect(parts.every((p) => !p.startsWith(' ') && !p.endsWith(' ')), isTrue);
  });

  test('kısa metin tek parça kalır', () {
    expect(ReadAloudAi.splitForTidy('kısa metin'), ['kısa metin']);
  });

  test('AI bir parçada düşerse kalan parçalar için istek atılmaz', () async {
    final text = [for (var i = 0; i < 40; i++) _para(i)].join('\n\n');
    final fake = _FakeGemini(failFrom: 2);
    final out = await ReadAloudAi.tidyOrOriginal(fake, text);
    expect(fake.calls, 2);
    expect(out.split(RegExp(r'\s+')).length,
        text.split(RegExp(r'\s+')).length);
  });

  test('parçalar sırayla düzeltilip birleştirilir', () async {
    final text = [for (var i = 0; i < 40; i++) _para(i)].join('\n\n');
    final fake = _FakeGemini();
    final out = await ReadAloudAi.tidyOrOriginal(fake, text);
    expect(fake.calls, ReadAloudAi.splitForTidy(text).length);
    expect(out.indexOf('Paragraf 0 '), lessThan(out.indexOf('Paragraf 39 ')));
  });

  test('düşünme yalnız 2.5 Flash ailesinde kapatılır', () {
    expect(GeminiService.thinkingFor('gemini-2.5-flash'),
        {'thinkingBudget': 0});
    expect(GeminiService.thinkingFor('gemini-2.5-flash-lite'),
        {'thinkingBudget': 0});
    expect(GeminiService.thinkingFor('gemini-2.5-pro'), isNull);
    expect(GeminiService.thinkingFor('gemini-2.0-flash'), isNull);
    expect(GeminiService.thinkingFor('gemini-3-pro-preview'), isNull);
  });
}
