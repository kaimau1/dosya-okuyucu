import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akıllı düzen 2.0 m.5 (2026-11-19): tur hazırlığının ağır işleri — dosya
/// okuma + base64, istek gövdesinin JSON'u, kişisel veri maskesi — izolatta;
/// sonuç ana izlekte yapılanla birebir aynı olmalı. Veriler uydurma.
void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('soff_');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    GeminiService.debugClient = null;
    tmp.deleteSync(recursive: true);
  });

  const q = [DecisionQuestion.yesNo('signed', 'İmzalı mı?', 'Is it signed?')];

  // Eşiğin üstünde (izolat yolu) sahte görsel.
  List<int> bigBytes() =>
      List<int>.generate(GeminiDecisions.isolateEncodeChars, (i) => i % 251);

  test('görsel bloğu: izolatta base64, içerik birebir', () async {
    final bytes = bigBytes();
    final f = File('${tmp.path}/a.jpg')..writeAsBytesSync(bytes);
    final block = await GeminiDecisions.fileBlock(f.path);
    expect(block['type'], 'image');
    expect(block['mime_type'], 'image/jpeg');
    expect(block['data'], base64Encode(bytes));
  });

  test('gövde: büyük satır içi veri izolatta kodlanır, sonuç aynı', () async {
    final big = [
      {'type': 'image', 'mime_type': 'image/jpeg', 'data': 'A' * 300000},
      GeminiDecisions.textBlock('ek "tırnak" ve \\ ters bölü'),
    ];
    expect(await GeminiDecisions.encodeBody(big, q),
        jsonEncode(GeminiDecisions.body(big, q)));
    final small = [GeminiDecisions.textBlock('küçük')];
    expect(await GeminiDecisions.encodeBody(small, q),
        jsonEncode(GeminiDecisions.body(small, q)));
  });

  test('büyük gövdede maske izolatta: yazı maskelenir, görsel verisi aynı',
      () async {
    final data = base64Encode(bigBytes());
    expect(data.length, greaterThan(GeminiService.isolateMaskChars));
    String? sent;
    GeminiService.debugClient = MockClient((req) async {
      sent = req.body;
      return http.Response(
          jsonEncode({
            'answers': {
              'signed': {'type': 'noul', 'noul': 0.9, 'confidence': 0.8},
            },
          }),
          200);
    });
    await GeminiDecisions.ask(keys: const ['k'], input: [
      {'type': 'image', 'mime_type': 'image/jpeg', 'data': data},
      GeminiDecisions.textBlock('TC: 12345678950'),
    ], questions: q);
    final out = jsonDecode(sent!) as Map;
    final input = out['input'] as List;
    expect((input[0] as Map)['data'], data);
    expect((input[1] as Map)['text'], 'TC: [TC]');
  });

  test('bekçi: tur girdisinde ana izlekte dosya okuma/base64 yok', () {
    for (final path in [
      'lib/services/gemini_decisions.dart',
      'lib/services/fm/smart_sort_input.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(RegExp(r'base64Encode\(\s*await').hasMatch(src), isFalse,
          reason: '$path: base64 izolatta olmalı');
      expect(src.contains('jsonEncode(body('), isFalse,
          reason: '$path: gövde encodeBody ile kodlanmalı');
    }
  });
}
