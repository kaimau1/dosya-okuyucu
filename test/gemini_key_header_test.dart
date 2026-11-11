import 'dart:convert';

import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Güvenlik Faz G2.4 (B8): Gemini anahtarı URL sorgusunda (`?key=`) değil
/// `x-goog-api-key` başlığında gider. (Anahtar uydurma — gerçek sır yok.)
void main() {
  const fakeKey = 'sahte-gemini-anahtari';
  final seen = <http.BaseRequest>[];

  setUp(() {
    seen.clear();
    GeminiService.debugClient = MockClient((req) async {
      seen.add(req);
      if (req.url.path.endsWith('/models')) {
        return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-test',
                  'supportedGenerationMethods': ['generateContent'],
                }
              ]
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'tamam'}
                  ]
                }
              }
            ]
          }),
          200);
    });
  });

  tearDown(() => GeminiService.debugClient = null);

  void expectHeaderOnly(http.BaseRequest req) {
    expect(req.url.toString(), isNot(contains('key=')));
    expect(req.url.toString(), isNot(contains(fakeKey)));
    expect(req.headers['x-goog-api-key'], fakeKey);
  }

  test('sohbet isteği anahtarı başlıkta taşır', () async {
    final service = GeminiService(apiKey: fakeKey, model: 'gemini-test');
    final reply = await service.chat(
        history: [ChatTurn(fromUser: true, text: 'merhaba')]);
    expect(reply, 'tamam');
    expect(seen, hasLength(1));
    expectHeaderOnly(seen.single);
  });

  test('model listesi isteği anahtarı başlıkta taşır', () async {
    final names = await GeminiService.listModels(fakeKey);
    expect(names, ['gemini-test']);
    expect(seen, hasLength(1));
    expectHeaderOnly(seen.single);
    expect(seen.single.url.queryParameters['pageSize'], '200');
  });
}
