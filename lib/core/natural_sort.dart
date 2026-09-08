/// **Doğal (sayı duyarlı) sıralama.**
///
/// ## Kök neden (2026-09-06 denetim turu)
/// Listeler adları harf harf karşılaştırıyordu: `'1' < '9'` olduğu için
/// `Bölüm 10` sıralamada `Bölüm 9`'un ÖNÜNE düşüyordu. Kullanıcının
/// telefonundaki gerçek dosyalar tam olarak böyle adlandırılıyor —
/// `IMG_9.jpg`, `IMG_10.jpg`, `Ders 2`, `Ders 11`, `bölüm-3.mp4` — yani
/// numaralı her klasör yanlış sırada görünüyordu. Sıralamanın "adı" doğruydu
/// ama sonucu insanın beklediği sıra değildi.
///
/// Çözüm: adı **harf ve sayı bloklarına** ayırıp sayı bloklarını SAYI olarak
/// karşılaştırmak. `dosya9` ile `dosya10` karşılaştırılırken `9 < 10`.
///
/// Baştaki sıfırlar (`img_007`) sayı değerini değiştirmez ama sıra
/// kararlılığı için eşitlikte metin karşılaştırmasına düşülür: `007` ile `7`
/// aynı sayıdır, listede yer değiştirip durmasınlar.
///
/// Çok uzun sayılar (`int` taşması) metin olarak karşılaştırılır — bir dosya
/// adında 19 haneden uzun sayı görülmesi beklenmez ama taşma bir çökme
/// olurdu.
int naturalCompare(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final aDigit = _isDigit(a.codeUnitAt(i));
    final bDigit = _isDigit(b.codeUnitAt(j));
    if (aDigit && bDigit) {
      final aEnd = _digitsEnd(a, i);
      final bEnd = _digitsEnd(b, j);
      final aNum = int.tryParse(a.substring(i, aEnd));
      final bNum = int.tryParse(b.substring(j, bEnd));
      if (aNum == null || bNum == null) {
        // Taşma: blokları metin olarak karşılaştır.
        final r = a.substring(i, aEnd).compareTo(b.substring(j, bEnd));
        if (r != 0) return r;
      } else if (aNum != bNum) {
        return aNum < bNum ? -1 : 1;
      }
      i = aEnd;
      j = bEnd;
      continue;
    }
    if (a.codeUnitAt(i) != b.codeUnitAt(j)) {
      return a.codeUnitAt(i) < b.codeUnitAt(j) ? -1 : 1;
    }
    i++;
    j++;
  }
  // Buraya kadar aynı: kısa olan önce. ("Ders 2" < "Ders 2 ek")
  if (i < a.length) return 1;
  if (j < b.length) return -1;
  // Tamamen aynı görünüyor (ör. "007" ile "7"): ham metinle kararlı sırala.
  return a.compareTo(b);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

int _digitsEnd(String s, int from) {
  var i = from;
  while (i < s.length && _isDigit(s.codeUnitAt(i))) {
    i++;
  }
  return i;
}
