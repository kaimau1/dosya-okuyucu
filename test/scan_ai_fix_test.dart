import 'package:dosya_okuyucu/services/scan_ai_fix.dart';
import 'package:flutter_test/flutter_test.dart';

/// **AI ile sayfa düzeltme sözleşmesi.** Düzeltilen metin sabit OCR
/// kutularına yazıldığı için satır SAYISI değişemez; model fazladan/eksik
/// satır getirirse metin yanlış kutulara düşer. Bu yüzden eksik yanıt
/// tümüyle reddediliyor — yarım uygulanan düzeltme, hiç düzeltmemekten kötü.
void main() {
  const original = ['Iki metre boyunda', 've Ç0CUK gibi', 'sarışın.'];

  test('numaralı yanıt satır satır çözülür', () {
    final out = ScanAiFix.parseAnswer('''
1| İki metre boyunda
2| ve ÇOCUK gibi
3| sarışın.''', original);
    expect(out, ['İki metre boyunda', 've ÇOCUK gibi', 'sarışın.']);
  });

  test('araya karışan açıklama satırları yok sayılır', () {
    final out = ScanAiFix.parseAnswer('''
İşte düzeltilmiş hâli:
1| İki metre boyunda
2| ve ÇOCUK gibi
3| sarışın.
Umarım yardımcı olur.''', original);
    expect(out.length, 3);
    expect(out.first, 'İki metre boyunda');
  });

  test('eksik satır TÜM düzeltmeyi reddeder', () {
    expect(
      () => ScanAiFix.parseAnswer('1| İki metre boyunda\n2| ve ÇOCUK gibi',
          original),
      throwsA(isA<ScanAiFixRefused>()),
    );
  });

  test('aralık dışı numara yok sayılır (satır hizası bozulmaz)', () {
    // Model sona bir cümle daha eklerse onu ALMAYIZ: kutu sayısı sabit ve
    // 1..N aralığı eksiksiz geldiği için hizalama güvende.
    expect(
      ScanAiFix.parseAnswer('1| a\n2| b\n3| c\n4| fazladan cümle', original),
      ['a', 'b', 'c'],
    );
  });

  test('boş dönen satır özgün hâlini korur', () {
    final out = ScanAiFix.parseAnswer('1| \n2| ve ÇOCUK gibi\n3| sarışın.',
        original);
    expect(out.first, original.first);
  });

  test('istem satır sayısını ve numaralamayı taşır', () {
    final prompt = ScanAiFix.buildPrompt(original);
    expect(prompt, contains('Tam\n  3 satır döndür.'));
    expect(prompt, contains('1| Iki metre boyunda'));
    expect(prompt, contains('3| sarışın.'));
  });
}
