/// **Taranmış sayfa metnini cihaz içinde düzeltme** — internetsiz, ücretsiz.
///
/// Kullanıcı isteği 2026-08-06: *"editöre düzenle ve AI ile düzenle butonu
/// koyalım, taranan sayfaları ikisi de mükemmelleştirmeye çalışsın."*
/// Buradaki "Düzelt", ikilinin cihaz-içi olanı: OCR'ın Türkçe metinde yaptığı
/// **belirli ve tanımlanabilir** hataları düzeltir. Sözlük yok, model yok —
/// yalnız kuralları yazılabilen, ters gitmesi neredeyse imkânsız düzeltmeler.
/// Emin olunamayan hiçbir şeye dokunulmaz: yanlış "düzeltme", düzeltmemekten
/// kötüdür.
///
/// ## Kurallar ve *niye*leri
/// * **Word-initial `I` → `İ`.** Türkçede büyük `I`, `ı`'nın büyüğüdür; OCR
///   Latin modelinde `İ` üstündeki noktayı sıkça kaçırır (ekran görüntüsünde
///   "Iki metre boyunda"). Körlemesine çevirmiyoruz: **ünlü uyumuna** bakılır —
///   kelimenin kalanında ince ünlü (e/i/ö/ü) varsa ilk hece `ı` olamaz, demek
///   ki `İ`'dir ("Iki" → "İki"). Kalın ünlülü kelimeye dokunulmaz ("Işık",
///   "Irak"). Uyuma uymayan sık özel adlar için küçük bir liste var
///   (İstanbul, İzmir…).
/// * **Harf içindeki rakam.** İki harf ARASINDA kalan `0/1/5/8` gerçek rakam
///   olamaz; harf karşılığına çevrilir (`Ç0CUK` → `ÇOCUK`). Kelimenin ucundaki
///   rakama dokunulmaz ("A4", "3.").
/// * **Satır sonu tiresi.** `-` ile biten satır, küçük harfle başlayan sonraki
///   satırla birleştirilir (kitapta hece bölmesi).
/// * **Noktalama boşlukları.** Noktalamadan önceki boşluk atılır, sonrasına
///   eksikse boşluk konur.
///
/// Hepsi saf fonksiyon → birim testli (bkz. `test/scan_text_fix_test.dart`).
library;

abstract final class ScanTextFix {
  /// Tek satırı düzeltir.
  static String line(String input) {
    var text = input.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.isEmpty) return text;
    text = _fixWords(text);
    text = _fixPunctuationSpacing(text);
    return text;
  }

  /// Satır listesini birlikte düzeltir: tek tek [line] düzeltmesine ek olarak
  /// **satır sonu tiresi** birleştirilir. Çıktı giriş ile aynı uzunluktadır —
  /// satır kutuları PDF'te sabit olduğu için satır SAYISI değişemez; birleşen
  /// hecenin kalanı bir üst satıra taşınır, alt satırın başından silinir.
  static List<String> lines(List<String> input) {
    final out = [for (final l in input) line(l)];
    for (var i = 0; i + 1 < out.length; i++) {
      final current = out[i];
      if (!current.endsWith('-') || current.length < 2) continue;
      final next = out[i + 1];
      final match = RegExp(r'^(\S+)(\s*)(.*)$').firstMatch(next);
      if (match == null) continue;
      final head = match.group(1)!;
      // Yalnız küçük harfle başlayan devam birleştirilir: büyük harf yeni
      // cümle/özel ad demektir ve oradaki `-` gerçek bir tiredir
      // ("Türk-", "İslam" satırları gibi).
      if (head.isEmpty || head[0] != head[0].toLowerCase()) continue;
      out[i] = current.substring(0, current.length - 1) + head;
      out[i + 1] = match.group(3)!;
    }
    return out;
  }

  /// Yalnız sayfa numarası (ya da "Sayfa 12" / "- 35 -") olan satır mı?
  ///
  /// Sesli okuma bunları atlar (kullanıcı isteği: *"sayfadaki sayfa
  /// numaralarının okunmaması lazım"*); metin düzeltme ise DOKUNMAZ — sayfada
  /// duran bir şeyi sessizce silmek düzeltme değil, veri kaybıdır.
  static bool looksLikePageNumber(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 24) return false;
    final bare = t.replaceAll(RegExp(r'^[\-–—\[\(\|]+|[\-–—\]\)\|]+$'), '').trim();
    if (bare.isEmpty) return false;
    if (RegExp(r'^\d{1,4}$').hasMatch(bare)) return true;
    // Roma rakamı — yalnız ÖN SAYFA aralığı (i … lxxxix).
    //
    // İki kez daraltıldı: harf kümesine bakmak ("yalnız I/V/X/L/C/M
    // harfleri") "civil" ve "mix" gibi GERÇEK kelimeleri sayfa numarası
    // sayıyordu; geçerli roma dizilişi aramak da "mix"i (=1009) kurtarmıyor.
    // Kitapların roma rakamlı ön sayfaları 90'ı geçmediği için C/D/M
    // tamamen dışarıda: kaybettiğimiz yok, kazandığımız çok.
    if (RegExp(r'^(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$', caseSensitive: false)
            .hasMatch(bare) &&
        bare.length <= 6) {
      return true;
    }
    if (RegExp(r'^(sayfa|page|s\.)\s*\d{1,4}$', caseSensitive: false)
        .hasMatch(bare)) {
      return true;
    }
    return false;
  }

  // ── kelime düzeyi ────────────────────────────────────────────────────────

  static String _fixWords(String text) {
    final buffer = StringBuffer();
    var index = 0;
    for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text)) {
      buffer.write(text.substring(index, m.start));
      buffer.write(_fixWord(m.group(0)!));
      index = m.end;
    }
    buffer.write(text.substring(index));
    return buffer.toString();
  }

  static String _fixWord(String word) {
    var out = _digitsInsideLetters(word);
    out = _initialDottedI(out);
    return out;
  }

  /// İki HARF arasında kalan rakamı harfe çevirir.
  static String _digitsInsideLetters(String word) {
    if (word.length < 3 || !RegExp(r'\d').hasMatch(word)) return word;
    final letters = RegExp(r'\p{L}', unicode: true);
    // Baştan sona rakam olan bir belirteç (yıl, madde numarası) korunur.
    if (!letters.hasMatch(word)) return word;
    final chars = word.split('');
    for (var i = 1; i + 1 < chars.length; i++) {
      final replacement = _digitLetter[chars[i]];
      if (replacement == null) continue;
      if (!letters.hasMatch(chars[i - 1]) || !letters.hasMatch(chars[i + 1])) {
        continue;
      }
      // Büyük/küçük komşuya uydurulur: `ÇOCUK` ile `çocuk` aynı kuralla.
      final neighbour = chars[i - 1];
      chars[i] = neighbour == neighbour.toUpperCase()
          ? replacement.toUpperCase()
          : replacement.toLowerCase();
    }
    return chars.join();
  }

  static const _digitLetter = <String, String>{
    '0': 'O',
    '1': 'l',
    '5': 'S',
    '8': 'B',
  };

  /// Kelime başındaki `I` gerçekten `İ` mi? (bkz. sınıf açıklaması)
  static String _initialDottedI(String word) {
    if (!word.startsWith('I') || word.length < 2) return word;
    // TAMAMI büyük harfse (başlık, kısaltma) karar verilemez — dokunma.
    if (word == word.toUpperCase() && word.length > 1) {
      final lower = word.toLowerCase();
      if (_dottedUppercaseWords.contains(lower)) {
        return 'İ${word.substring(1)}';
      }
      return word;
    }
    final rest = word.substring(1).toLowerCase();
    if (_dottedWords.any((w) => rest.startsWith(w))) {
      return 'İ${word.substring(1)}';
    }
    // Ünlü uyumu: ilk hecede `ı` varsa kelimenin kalanı KALIN ünlü ister.
    // İnce ünlü görürsek ilk harf `ı` olamaz → `İ`.
    for (final rune in rest.runes) {
      final c = String.fromCharCode(rune);
      if (_frontVowels.contains(c)) return 'İ${word.substring(1)}';
      if (_backVowels.contains(c)) return word; // ilk ünlü kalın → `Işık`
    }
    return word; // hiç ünlü yok: karar verme
  }

  static const _frontVowels = 'eiöü';
  static const _backVowels = 'aıou';

  /// Ünlü uyumuna UYMAYAN, `İ` ile başlayan sık kelimeler (alıntı sözcükler ve
  /// özel adlar). Uyum kuralı bunları "kalın" sayıp elinden kaçırırdı.
  static const _dottedWords = <String>[
    'stanbul', 'spanya', 'sviçre', 'srail', 'sveç', 'skoç', 'slam', 'slâm',
    'talya', 'ngiliz', 'ngiltere', 'rlanda', 'zmir', 'zmit', 'znik',
  ];

  /// Tamamı büyük harfle yazılmış hâlde de `İ` olduğu kesin olanlar.
  static const _dottedUppercaseWords = <String>{
    'istanbul', 'izmir', 'ingiltere', 'italya', 'islam', 'ispanya',
  };

  // ── noktalama ────────────────────────────────────────────────────────────

  static String _fixPunctuationSpacing(String text) {
    var out = text.replaceAllMapped(
        RegExp(r'\s+([,;:!?%])'), (m) => m.group(1)!);
    // Noktadan önceki boşluk: yalnız cümle sonu noktası için (üç nokta ve
    // "3 . madde" gibi diziliş bozulmasın diye tek nokta arıyoruz).
    out = out.replaceAllMapped(
        RegExp(r'\s+\.(\s|$)'), (m) => '.${m.group(1)!}');
    // Noktalamadan sonra boşluk: rakam-nokta-rakam (tarih, ondalık) korunur.
    out = out.replaceAllMapped(
      RegExp(r'([,;:!?])(?=[\p{L}])', unicode: true),
      (m) => '${m.group(1)!} ',
    );
    return out.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  }
}
