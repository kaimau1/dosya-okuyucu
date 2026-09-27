import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// **Kaynak dili kendiliğinden bulur** (2026-09-27, kullanıcı: *"çeviride
/// otomatik algıla olmalı"*).
///
/// Niye ML Kit'in dil tanıma eklentisi değil: yeni bir yerel eklenti APK'ya
/// model ve kütüphane ekler, sürümü de CI'daki Flutter 3.29.3 / Dart 3.7'ye
/// sabitlenmek zorunda (bkz. pubspec'teki ML Kit notları). Çevirinin sunduğu
/// 14 dil için iki ipucu yetiyor:
/// 1. **Yazı sistemi** — Arap (Arapça / Farsça ayrımı Farsça'ya özgü
///    harflerle), Kiril, Han, Kana, Hangul tek başına belirleyici.
/// 2. **Latin yazılı dillerde en sık kelimeler + ayırt edici harfler**
///    (ğ ş ı → Türkçe, ß ä → Almanca, ñ ¿ → İspanyolca, ã õ → Portekizce…).
///
/// Saf Dart, eşzamanlı, testli. Emin olamadığında (tek kelime, sayı, kısa
/// kısaltma) null döner; çağıran son kullanılan kaynak dile düşer.
abstract final class LangDetect {
  /// [text]in dili; emin değilse null.
  static TranslateLanguage? detect(String text) {
    final sample = text.length > 4000 ? text.substring(0, 4000) : text;
    var arabic = 0, persianOnly = 0, cyrillic = 0, han = 0, kana = 0;
    var hangul = 0, latin = 0;
    for (final r in sample.runes) {
      if (r >= 0x0600 && r <= 0x06FF) {
        arabic++;
        // پ چ ژ گ ی ک — Farsça'da var, Arapça'da yok.
        if (r == 0x067E ||
            r == 0x0686 ||
            r == 0x0698 ||
            r == 0x06AF ||
            r == 0x06CC ||
            r == 0x06A9) {
          persianOnly++;
        }
      } else if (r >= 0x0400 && r <= 0x04FF) {
        cyrillic++;
      } else if (r >= 0x3040 && r <= 0x30FF) {
        kana++;
      } else if (r >= 0x4E00 && r <= 0x9FFF) {
        han++;
      } else if (r >= 0xAC00 && r <= 0xD7AF) {
        hangul++;
      } else if ((r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          (r >= 0xC0 && r <= 0x24F)) {
        latin++;
      }
    }
    final letters = arabic + cyrillic + han + kana + hangul + latin;
    if (letters < 2) return null;
    if (hangul * 3 >= letters) return TranslateLanguage.korean;
    if (kana > 0 && (kana + han) * 3 >= letters) {
      return TranslateLanguage.japanese;
    }
    if (han * 3 >= letters) return TranslateLanguage.chinese;
    if (cyrillic * 2 >= letters) return TranslateLanguage.russian;
    if (arabic * 2 >= letters) {
      return persianOnly > 0
          ? TranslateLanguage.persian
          : TranslateLanguage.arabic;
    }
    if (latin * 2 < letters) return null;
    return _latin(sample);
  }

  static TranslateLanguage? _latin(String text) {
    final lower = text.toLowerCase();
    final scores = <TranslateLanguage, double>{};
    void add(TranslateLanguage l, double v) => scores[l] = (scores[l] ?? 0) + v;

    // Ayırt edici harfler (her geçiş güçlü kanıt).
    for (final r in lower.runes) {
      switch (r) {
        case 0x011F: // ğ
        case 0x0131: // ı
        case 0x015F: // ş
          add(TranslateLanguage.turkish, 3);
        case 0x00DF: // ß
          add(TranslateLanguage.german, 3);
        case 0x00E4: // ä
          add(TranslateLanguage.german, 2);
        case 0x00F1: // ñ
        case 0x00BF: // ¿
        case 0x00A1: // ¡
          add(TranslateLanguage.spanish, 3);
        case 0x00E3: // ã
        case 0x00F5: // õ
          add(TranslateLanguage.portuguese, 3);
        case 0x00E8: // è
        case 0x00EA: // ê
        case 0x0153: // œ
          add(TranslateLanguage.french, 1.5);
        case 0x00F2: // ò
        case 0x00EC: // ì
          add(TranslateLanguage.italian, 1.5);
        case 0x00E7: // ç — Türkçe, Fransızca, Portekizce ortak
          add(TranslateLanguage.turkish, 0.7);
          add(TranslateLanguage.french, 0.7);
          add(TranslateLanguage.portuguese, 0.5);
        case 0x00F6: // ö
        case 0x00FC: // ü — Türkçe ve Almanca ortak
          add(TranslateLanguage.turkish, 1);
          add(TranslateLanguage.german, 1);
      }
    }

    // En sık kelimeler.
    final words = RegExp(r"[a-zà-ɏ']+")
        .allMatches(lower)
        .map((m) => m.group(0)!)
        .toList();
    for (final w in words) {
      for (final e in _stopwords.entries) {
        if (e.value.contains(w)) add(e.key, 1);
      }
    }
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    if (best.value < 1) return null;
    // Başa baş (ör. tek ortak kelime) → emin değiliz.
    if (ranked.length > 1 && ranked[1].value >= best.value) return null;
    return best.key;
  }

  static const _stopwords = <TranslateLanguage, Set<String>>{
    TranslateLanguage.english: {
      'the',
      'and',
      'of',
      'to',
      'is',
      'in',
      'that',
      'it',
      'for',
      'with',
      'was',
      'are',
      'this',
      'you',
      'on',
      'be',
      'have',
      'not',
      'from',
      'by',
    },
    TranslateLanguage.turkish: {
      've',
      'bir',
      'bu',
      'için',
      'ile',
      'da',
      'de',
      'ki',
      'çok',
      'olarak',
      'daha',
      'gibi',
      'ne',
      'olan',
      'değil',
      'ama',
      'her',
      'şu',
      'ben',
      'sen',
      'o',
      'biz',
      'onun',
      'kadar',
      'sonra',
      'veya',
    },
    TranslateLanguage.german: {
      'und',
      'der',
      'die',
      'das',
      'nicht',
      'ist',
      'ich',
      'mit',
      'sie',
      'ein',
      'eine',
      'zu',
      'den',
      'von',
      'auf',
      'auch',
      'es',
      'sich',
    },
    TranslateLanguage.french: {
      'le',
      'la',
      'les',
      'et',
      'est',
      'des',
      'une',
      'un',
      'pour',
      'dans',
      'que',
      'qui',
      'pas',
      'sur',
      'au',
      'avec',
      'ce',
      'il',
      'du',
      'je',
    },
    TranslateLanguage.spanish: {
      'el',
      'los',
      'las',
      'que',
      'y',
      'por',
      'una',
      'con',
      'para',
      'es',
      'del',
      'se',
      'lo',
      'como',
      'pero',
      'más',
      'su',
      'al',
      'muy',
    },
    TranslateLanguage.italian: {
      'il',
      'che',
      'di',
      'della',
      'non',
      'per',
      'una',
      'sono',
      'gli',
      'del',
      'con',
      'come',
      'anche',
      'più',
      'questo',
      'nel',
      'alla',
      'è',
    },
    TranslateLanguage.portuguese: {
      'não',
      'que',
      'os',
      'em',
      'uma',
      'com',
      'para',
      'do',
      'da',
      'por',
      'mais',
      'como',
      'mas',
      'foi',
      'ele',
      'são',
      'você',
      'isso',
    },
    TranslateLanguage.dutch: {
      'de',
      'het',
      'een',
      'en',
      'van',
      'niet',
      'is',
      'dat',
      'op',
      'te',
      'zijn',
      'voor',
      'met',
      'ik',
      'je',
      'maar',
      'ook',
      'wat',
    },
  };
}
