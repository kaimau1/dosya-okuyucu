import 'dart:convert';

import 'package:dosya_okuyucu/core/pii.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// **G10.2 hassas veri maskesi** (2026-11-12). Örnekler uydurma: sağlaması
/// tutan ama kimseye ait olmayan sayılar (test kartı 4111…, örnek IBAN).
void main() {
  const tc = '12345678950';
  const iban = 'TR330006100519786457841326';
  const card = '4111111111111111';

  final table = <(String, String)>[
    ('TC: $tc', 'TC: [TC]'),
    ('IBAN $iban', 'IBAN [IBAN]'),
    ('IBAN TR33 0006 1005 1978 6457 8413 26.', 'IBAN [IBAN].'),
    ('kart 4111 1111 1111 1111', 'kart [KART]'),
    ('kart $card', 'kart [KART]'),
    ('tel 0532 123 45 67', 'tel [TEL]'),
    ('tel +90 532 123 45 67', 'tel [TEL]'),
    ('tel (532) 123-45-67', 'tel [TEL]'),
    ('e-posta ornek.kisi@example.com', 'e-posta [EPOSTA]'),
  ];
  for (final (input, want) in table) {
    test('maskelenir: $input', () => expect(Pii.mask(input), want));
  }

  final untouched = <String>[
    '12345678901', // TC sağlaması tutmaz
    'Sipariş 4111111111111112', // Luhn tutmaz
    'TR330006100519786457841327', // IBAN mod 97 tutmaz
    'Hemoglobin 13,5 g/dL, trombosit 250000',
    'Tarih 12.11.2026 saat 06:40',
    'Fatura no 2026-000123',
  ];
  for (final s in untouched) {
    test('dokunulmaz: $s', () => expect(Pii.mask(s), s));
  }

  test('Gemini gövdesinde yalnız text alanları maskelenir', () {
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': 'Belge: TC $tc'}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'ara $card'},
            {
              'inlineData': {'mimeType': 'image/png', 'data': tc}
            },
          ]
        }
      ],
    });
    final out = jsonDecode(GeminiService.maskBody(body)) as Map;
    expect(out['systemInstruction']['parts'][0]['text'], 'Belge: TC [TC]');
    final parts = out['contents'][0]['parts'] as List;
    expect(parts[0]['text'], 'ara [KART]');
    expect(parts[1]['inlineData']['data'], tc, reason: 'görsel verisi değişmez');
  });
}
