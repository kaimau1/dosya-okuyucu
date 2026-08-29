/// **Ayar aramasının çekirdeği** — saf fonksiyonlar, testlenebilir.
///
/// ## Niçin ayrı bir dosya (2026-08-29)
/// Kullanıcı: *"ayar arama iyi çalışmalı"*. Eski arama `context.t(başlık)`
/// içinde düz `contains` yapıyordu ve üç yerde kırılıyordu:
///
/// 1. **Türkçe harfler.** "sifre" yazan kullanıcı "şifre"yi bulamıyordu;
///    "gizlilik" ararken CapsLock'lu "GİZLİLİK" eşleşmiyordu (`toLowerCase`
///    Türkçe'de `İ`yi `i̇` yapıyor, tek karakter değil).
/// 2. **Yalnız SEÇİLİ dil.** Arayüz Türkçe'yken "thumbnail" yazan kullanıcı
///    hiçbir şey bulamıyordu — oysa aynı ayarın İngilizce adı tabloda duruyor.
/// 3. **Yalnız BAŞLIK.** Ayarın ne işe yaradığını anlatan alt satır aramaya
///    hiç girmiyordu: "kaç gün" yazan kullanıcı çöp kutusu ayarını bulamazdı.
///
/// Buradaki [fold] üç sorunun ilkini, [matches] diğer ikisini çözüyor.
abstract final class SettingsSearch {
  /// Metni **karşılaştırılabilir** hâle indirger: küçük harf + Türkçe harfler
  /// temel karşılıklarına + noktalama atılır.
  ///
  /// `İ`/`I` özel olarak ele alınıyor: Dart'ın `toLowerCase`i `İ` için iki kod
  /// birimi üretiyor (`i` + birleşen nokta) ve karşılaştırmayı bozuyor.
  static String fold(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = switch (ch) {
        'ı' || 'I' || 'İ' || 'i' => 'i',
        'ş' || 'Ş' => 's',
        'ğ' || 'Ğ' => 'g',
        'ü' || 'Ü' => 'u',
        'ö' || 'Ö' => 'o',
        'ç' || 'Ç' => 'c',
        'â' || 'Â' => 'a',
        'î' || 'Î' => 'i',
        'û' || 'Û' => 'u',
        _ => ch.toLowerCase(),
      };
      // Noktalama/simge atılır ("api anahtarı" ↔ "api-anahtari").
      if (RegExp(r'[a-z0-9؀-ۿ ]').hasMatch(mapped)) {
        buffer.write(mapped);
      } else if (mapped.trim().isEmpty) {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [haystack] parçalarından herhangi biri [query]yi içeriyor mu?
  ///
  /// Sorgu **kelimelere bölünür** ve HEPSİ bulunmalıdır ("koyu tema" hem
  /// "koyu" hem "tema" geçen satırı bulur, sıralamaları önemli değil).
  static bool matches(Iterable<String> haystack, String query) =>
      score(haystack, query) > 0;

  /// Eşleşme gücü — 0 = eşleşme yok. Büyük olan listede önce gelir.
  ///
  /// Sıralama neden gerekli: "tema" araması hem "Tema ailesi" (başlık) hem de
  /// "arka plan rengi"nin açıklamasını tutuyor; kullanıcının aradığı ilki.
  /// Puan, eşleşmenin NEREDE olduğuna bakar: başlığın başı > başlık içi >
  /// diğer alanlar.
  static int score(Iterable<String> haystack, String query) {
    final q = fold(query);
    if (q.isEmpty) return 1;
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 1;
    final fields = [for (final h in haystack) fold(h)];
    if (fields.isEmpty) return 0;

    var total = 0;
    for (final word in words) {
      var best = 0;
      for (var i = 0; i < fields.length; i++) {
        final field = fields[i];
        if (!field.contains(word)) continue;
        // İlk alan başlıktır (çağıran öyle sıralar).
        final base = i == 0 ? 100 : 30;
        final bonus = field.startsWith(word) ? 40 : 0;
        // Tam kelime eşleşmesi, kelime ortasında geçmekten iyidir.
        final whole = RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(field)
            ? 20
            : 0;
        final value = base + bonus + whole;
        if (value > best) best = value;
      }
      // Sorgudaki HER kelime bir yerde geçmeli.
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }
}
