import 'dart:convert';

import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `http.get` paketin zon tabanlı [http.runWithClient] mekanizmasıyla
/// yakalanır — GeminiService kendi Client'ını enjekte edilebilir yapmadan
/// (basit REST sarmalayıcı, bkz. HAFIZA "düz REST çağrısı") gerçek ağa
/// çıkmadan test edilebilir.
Future<T> _withMock<T>(
  Future<T> Function() body, {
  required int status,
  required Object jsonBody,
}) {
  return http.runWithClient(
    body,
    () => MockClient((req) async =>
        http.Response(jsonEncode(jsonBody), status)),
  );
}

void main() {
  group('GeminiService.listModels', () {
    test('yalnızca generateContent destekleyenleri döner, en yeni önde', () {
      return _withMock(
        () => GeminiService.listModels('test-key'),
        status: 200,
        jsonBody: {
          'models': [
            {
              'name': 'models/embedding-001',
              'supportedGenerationMethods': ['embedContent'],
            },
            {
              'name': 'models/gemini-1.5-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-2.0-flash',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-2.5-pro',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        },
      ).then((models) {
        // embedding (generateContent desteklemiyor) elenir.
        expect(models, isNot(contains('embedding-001')));
        // "models/" öneki temizlenir.
        expect(models, contains('gemini-2.5-pro'));
        // En yeni sürüm (2.5) en yeteneklisi (pro) önde.
        expect(models.first, 'gemini-2.5-pro');
        expect(models.length, 3);
      });
    });

    test('boş anahtar GeminiException fırlatır (ağa çıkmadan)', () {
      expect(
        () => GeminiService.listModels(''),
        throwsA(isA<GeminiException>()),
      );
    });

    test('API hata döndürünce mesajı GeminiException içinde taşır', () {
      return _withMock(
        () => GeminiService.listModels('bad-key'),
        status: 400,
        jsonBody: {
          'error': {'message': 'API key not valid'},
        },
      ).then(
        (_) => fail('exception bekleniyordu'),
        onError: (e) {
          expect(e, isA<GeminiException>());
          expect(e.toString(), contains('API key not valid'));
        },
      );
    });

    test('models alanı boşsa boş liste döner (fırlatmaz)', () {
      return _withMock(
        () => GeminiService.listModels('test-key'),
        status: 200,
        jsonBody: {'models': []},
      ).then((models) => expect(models, isEmpty));
    });
  });
}
