import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/models/file_age.dart';
import 'package:dosya_okuyucu/models/photo_group.dart';

/// **Kullanıcı hatası 2026-08-25:** *"bugün dün kısmı 24 saate göre yapılıyor,
/// gece 00'a göre olmalı"*.
///
/// Eski hesap iki damga arasındaki milisaniyeyi 86.400.000'e bölüyordu, yani
/// "kaç kez 24 saat geçti" sorusunu cevaplıyordu. İnsanın sorduğu soru bu
/// değil: gece yarısı geçildiyse dünkü dosya "dün"dür, arada 9 saat olsa bile.
void main() {
  group('takvim günü hesabı', () {
    test('dün 23:00 → bugün 08:00 arası BİR gündür (24 saat dolmasa da)', () {
      final dunAksam = DateTime(2026, 8, 24, 23, 0);
      final bugunSabah = DateTime(2026, 8, 25, 8, 0);
      // Aradaki gerçek süre 9 saat; eski hesap 0 ("bugün") derdi.
      expect(bugunSabah.difference(dunAksam).inHours, 9);
      expect(calendarDaysBetween(dunAksam, bugunSabah), 1);
      expect(
        relativeDays(daysBetween(
          dunAksam.millisecondsSinceEpoch,
          bugunSabah.millisecondsSinceEpoch,
        )),
        'dün',
      );
    });

    test('aynı günün 01:00 ve 23:00 saatleri AYNI gündür (22 saat)', () {
      final sabah = DateTime(2026, 8, 25, 1, 0);
      final aksam = DateTime(2026, 8, 25, 23, 0);
      expect(calendarDaysBetween(sabah, aksam), 0);
      expect(
        relativeDays(daysBetween(
          sabah.millisecondsSinceEpoch,
          aksam.millisecondsSinceEpoch,
        )),
        'bugün',
      );
    });

    test('dün 09:00 → bugün 23:00 arası 38 saat ama yine BİR gündür', () {
      final dun = DateTime(2026, 8, 24, 9, 0);
      final bugun = DateTime(2026, 8, 25, 23, 0);
      // Eski hesap 38/24 = 1 verirdi; burada da 1 — ama sebebi doğru.
      expect(calendarDaysBetween(dun, bugun), 1);
    });

    test('iki gece yarısı geçilirse iki gün', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 8, 23, 23, 59),
          DateTime(2026, 8, 25, 0, 1),
        ),
        2,
      );
    });

    test('ay ve yıl sınırını doğru geçer', () {
      expect(
        calendarDaysBetween(DateTime(2025, 12, 31, 20), DateTime(2026, 1, 1, 3)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 7, 31, 20), DateTime(2026, 8, 1, 3)),
        1,
      );
    });

    test('geçersiz damgalar null döner (davranış korundu)', () {
      expect(daysBetween(0, 1000), isNull);
      expect(daysBetween(1000, 0), isNull);
      expect(daysBetween(2000, 1000), isNull); // gelecek tarih
    });
  });

  group('fotoğraf grup başlığı aynı kuralı kullanır', () {
    test('dün gece çekilen kare bu sabah "Dün" başlığına düşer', () {
      final dunGece = DateTime(2026, 8, 24, 23, 30);
      final bugunSabah = DateTime(2026, 8, 25, 8, 0);
      expect(
        photoGroupTitle(
          dunGece.millisecondsSinceEpoch,
          PhotoGroup.day,
          now: bugunSabah,
        ),
        'Dün',
      );
    });

    test('bu sabah çekilen kare "Bugün"', () {
      final sabah = DateTime(2026, 8, 25, 1, 15);
      expect(
        photoGroupTitle(
          sabah.millisecondsSinceEpoch,
          PhotoGroup.day,
          now: DateTime(2026, 8, 25, 22, 0),
        ),
        'Bugün',
      );
    });
  });
}
