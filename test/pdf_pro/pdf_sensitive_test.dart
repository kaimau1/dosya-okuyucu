// PDF Pro Faz 64 / 2: kişisel veri desenleri (saf Dart). Sayılar burada
// ALGORİTMAYLA üretilir — gerçek kişiye ait değildir (KVKK).
import 'package:dosya_okuyucu/services/pdf/pro/pdf_sensitive.dart';
import 'package:flutter_test/flutter_test.dart';

/// İlk dokuz haneden geçerli bir TC kimlik no kurar.
String tckn(String nine) {
  final d = [for (final c in nine.codeUnits) c - 0x30];
  final odd = d[0] + d[2] + d[4] + d[6] + d[8];
  final even = d[1] + d[3] + d[5] + d[7];
  final d10 = ((odd * 7 - even) % 10 + 10) % 10;
  final d11 = (d.reduce((a, b) => a + b) + d10) % 10;
  return '$nine$d10$d11';
}

/// Uydurma banka/hesap hanelerinden geçerli bir TR IBAN kurar.
String iban(String bban22) {
  final moved = '${bban22}TR00';
  var rem = 0;
  for (final c in moved.codeUnits) {
    final v = c >= 0x41 ? c - 55 : c - 0x30;
    rem = v > 9 ? (rem * 100 + v) % 97 : (rem * 10 + v) % 97;
  }
  return 'TR${(98 - rem).toString().padLeft(2, '0')}$bban22';
}

void main() {
  final id = tckn('123456789');
  final acct = iban('0000100000000000000001');

  test('TC kimlik no sağlaması', () {
    expect(PdfSensitive.validTckn(id), isTrue);
    final wrong = '${id.substring(0, 10)}${(int.parse(id[10]) + 1) % 10}';
    expect(PdfSensitive.validTckn(wrong), isFalse);
    expect(PdfSensitive.validTckn('0${id.substring(1)}'), isFalse);
    expect(PdfSensitive.validTckn('12345'), isFalse);
  });

  test('IBAN mod 97; boşluklu yazım kabul', () {
    expect(PdfSensitive.validIban(acct), isTrue);
    final spaced = acct.replaceAllMapped(RegExp('.{4}'), (m) => '${m[0]} ').trim();
    expect(PdfSensitive.validIban(spaced), isTrue);
    expect(PdfSensitive.validIban(acct.replaceRange(10, 11, '9')), isFalse);
    expect(PdfSensitive.validIban('TR00'), isFalse);
  });

  test('metinde bulur: sıra, tür, örtüşmesiz; geçersiz sayı atlanır', () {
    final spaced = acct.replaceAllMapped(RegExp('.{4}'), (m) => '${m[0]} ').trim();
    final t = 'Kimlik $id, hesap $spaced. Ara: 0532 123 45 67 ya da '
        'a.b@ornek.com.tr — sipariş no 12345678901 değil.';
    final found = PdfSensitive.find(t);
    expect(found.map((m) => m.kind), [
      PdfSensitiveKind.tckn,
      PdfSensitiveKind.iban,
      PdfSensitiveKind.phone,
      PdfSensitiveKind.email,
    ]);
    expect(t.substring(found[0].start, found[0].end), id);
    expect(t.substring(found[1].start, found[1].end), spaced);
    expect(t.substring(found[3].start, found[3].end), 'a.b@ornek.com.tr');
    for (var i = 1; i < found.length; i++) {
      expect(found[i].start, greaterThanOrEqualTo(found[i - 1].end));
    }
  });

  test('özel sözcük ve tür süzgeci', () {
    const t = 'Proje Kartal gizlidir; KARTAL ekibi bilgilendirildi.';
    final found = PdfSensitive.find(t, kinds: const {}, custom: ['kartal', 'x']);
    expect(found, hasLength(2));
    expect(found.every((m) => m.kind == PdfSensitiveKind.custom), isTrue);
    expect(PdfSensitive.find('a@b.co', kinds: const {PdfSensitiveKind.phone}),
        isEmpty);
  });
}
