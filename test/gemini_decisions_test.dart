import 'dart:convert';

import 'package:dosya_okuyucu/services/gemini_decisions.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Gemini Decisions API istemcisi (2026-11-18): gövde biçimi, yanıt çözme,
/// anahtar devri.
void main() {
  const questions = [
    DecisionQuestion.yesNo('signed', 'İmzalı mı?', 'Is it signed?'),
    DecisionQuestion.choice('doc_type', 'Tür', 'What is it?',
        {'invoice': 'An invoice.', 'other': 'Something else.'}),
    DecisionQuestion.score('quality', 'Kalite', 'How clear?',
        ['Poor', 'Acceptable', 'Good']),
  ];

  tearDown(() => GeminiService.debugClient = null);

  test('gövde: model, girdi ve soru türleri API adlarıyla', () {
    final body = GeminiDecisions.body(
        [GeminiDecisions.textBlock('merhaba')], questions);
    expect(body['model'], 'gemini-decision-1');
    expect((body['input'] as List).single, {'type': 'text', 'text': 'merhaba'});
    final q = body['questions'] as Map;
    expect(q['signed'], {'type': 'noul', 'instructions': 'Is it signed?'});
    expect((q['doc_type'] as Map)['criteria'],
        {'invoice': 'An invoice.', 'other': 'Something else.'});
    expect((q['quality'] as Map)['criteria'], ['Poor', 'Acceptable', 'Good']);
  });

  test('uzantıdan blok türü', () {
    expect(GeminiDecisions.mediaFor('/a/b.PDF')?.type, 'document');
    expect(GeminiDecisions.mediaFor('/a/b.jpg')?.mime, 'image/jpeg');
    expect(GeminiDecisions.mediaFor('/a/b.mp3')?.type, 'audio');
    expect(GeminiDecisions.mediaFor('/a/b.mp4')?.type, 'video');
    expect(GeminiDecisions.mediaFor('/a/b.docx'), isNull);
  });

  test('yanıt çözülür; soru sırası korunur', () {
    final r = DecisionResult.parse(
        jsonEncode({
          'answers': {
            'quality': {'type': 'score', 'score': 1.8, 'confidence': 0.7},
            'signed': {'type': 'noul', 'noul': 0.92, 'confidence': 0.92},
            'doc_type': {
              'type': 'choice',
              'choice': 'invoice',
              'confidence': 0.8,
            },
          },
        }),
        questions);
    expect(r.answers.map((a) => a.question.id),
        ['signed', 'doc_type', 'quality']);
    expect(r.answers[0].isYes, isTrue);
    expect(r.answers[1].choiceText, 'An invoice.');
    expect(r.answers[2].levelText, 'Good');
    expect(r.blockReason, isNull);
  });

  test('engellenen içerik', () {
    final r = DecisionResult.parse(
        jsonEncode({
          'answers': {},
          'prompt_feedback': {'block_reason': 'safety'},
        }),
        questions);
    expect(r.answers, isEmpty);
    expect(r.blockReason, 'safety');
  });

  test('kota hatasında sıradaki anahtar denenir', () async {
    final seen = <String>[];
    GeminiService.debugClient = MockClient((req) async {
      seen.add(req.headers['x-goog-api-key']!);
      expect(req.url.path, endsWith('/v1beta/decisions'));
      if (seen.length == 1) {
        return http.Response('{"error":{"message":"quota"}}', 429);
      }
      return http.Response(
          jsonEncode({
            'answers': {
              'signed': {'type': 'noul', 'noul': 0.1, 'confidence': 0.9},
            },
          }),
          200);
    });
    final r = await GeminiDecisions.ask(
      keys: ['k1', 'k2'],
      input: [GeminiDecisions.textBlock('x')],
      questions: [questions.first],
    );
    expect(seen, ['k1', 'k2']);
    expect(r.answers.single.isYes, isFalse);
  });
}
