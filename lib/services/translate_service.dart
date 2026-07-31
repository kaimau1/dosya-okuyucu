import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaz-içi çeviri (Google ML Kit). Dil modeli bir kez indirilir (dil başına
/// ~30 MB), sonrası tamamen çevrimdışı çalışır — Gemini'den farklı olarak API
/// anahtarı ve internet gerekmez.
class TranslateService {
  /// Tek ML Kit çağrısına verilecek en fazla karakter. Uzun metinlerde tek
  /// çağrı sessizce kırpılabildiği için satırlar bu sınıra göre bölünür.
  static const maxChunk = 1000;

  /// Arayüzde sunulan diller. ML Kit ~50 dil destekler ama hepsini listelemek
  /// için elle Türkçe ad haritası gerekir; yaygın olanlar yeter.
  /// ponytail: liste elle tutuluyor, arama kutusu gerekirse TranslateLanguage.values'a geç.
  static const languages = <TranslateLanguage, String>{
    TranslateLanguage.turkish: 'Türkçe',
    TranslateLanguage.english: 'İngilizce',
    TranslateLanguage.german: 'Almanca',
    TranslateLanguage.french: 'Fransızca',
    TranslateLanguage.spanish: 'İspanyolca',
    TranslateLanguage.italian: 'İtalyanca',
    TranslateLanguage.russian: 'Rusça',
    TranslateLanguage.arabic: 'Arapça',
    TranslateLanguage.persian: 'Farsça',
    TranslateLanguage.chinese: 'Çince',
    TranslateLanguage.japanese: 'Japonca',
    TranslateLanguage.korean: 'Korece',
    TranslateLanguage.portuguese: 'Portekizce',
    TranslateLanguage.dutch: 'Felemenkçe',
  };

  static final _models = OnDeviceTranslatorModelManager();

  static Future<bool> isModelReady(TranslateLanguage lang) =>
      _models.isModelDownloaded(lang.bcpCode);

  /// Dil modelini indirir (Wi-Fi şartı yok). Zaten varsa hızlıca döner.
  static Future<void> downloadModel(TranslateLanguage lang) =>
      _models.downloadModel(lang.bcpCode);

  /// [text]'i satır yapısını (paragraf/boş satır) koruyarak çevirir.
  /// [onProgress] her satır öncesi (işlenen, toplam) ile çağrılır.
  /// [cancelled] her satır öncesi yoklanır; true dönerse çevrilen satırlar
  /// döner (kalanlar atılır) — kullanıcı durdurduğunda yarım çeviri yine de
  /// gösterilebilsin.
  static Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final translator =
        OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try {
      return await translateWith(
        translator,
        text,
        onProgress: onProgress,
        cancelled: cancelled,
      );
    } finally {
      await translator.close();
    }
  }

  /// Hazır bir çeviriciyle çevirir — **çok sayfalı belgede** her sayfa için
  /// yeni çevirici açmamak içindir: `OnDeviceTranslator` açılışı dil modelini
  /// belleğe yüklüyor, 180 sayfalık bir belgede bunu 180 kez yapmak süreyi
  /// katlıyordu.
  static Future<String> translateWith(
    OnDeviceTranslator translator,
    String text, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final lines = text.split('\n');
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (cancelled?.call() ?? false) break;
      onProgress?.call(i, lines.length);
      out.add(await _translateLine(translator, lines[i]));
    }
    return out.join('\n');
  }

  /// Çevirici üretir (akış katmanı ML Kit tipini kendi kurmasın diye).
  static OnDeviceTranslator translator({
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) =>
      OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);

  static Future<String> _translateLine(
      OnDeviceTranslator t, String line) async {
    if (line.trim().isEmpty) return line; // boş satır = paragraf ayracı, korunur
    final parts = splitLong(line);
    if (parts.length == 1) return t.translateText(parts.first);
    final done = <String>[];
    for (final p in parts) {
      done.add(await t.translateText(p));
    }
    return done.join(' ');
  }

  /// [maxChunk]'tan uzun bir satırı çeviri parçalarına böler: önce cümle sonu,
  /// olmazsa boşluk, o da yoksa sert kesme. Kısa satır tek parça döner.
  /// (Saf fonksiyon — ML Kit'siz test edilebilir, bkz. test/translate_test.dart)
  static List<String> splitLong(String line, [int max = maxChunk]) {
    if (line.length <= max) return [line];
    final out = <String>[];
    var rest = line;
    while (rest.length > max) {
      final window = rest.substring(0, max);
      var cut = window.lastIndexOf(RegExp(r'[.!?…]\s'));
      if (cut > 0) {
        cut += 1; // noktalama parçada kalsın
      } else {
        cut = window.lastIndexOf(' ');
        if (cut <= 0) cut = max; // tek parça dev sözcük: sert kes
      }
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trimLeft();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  // --- son kullanılan dil çifti (kullanıcı her seferinde seçmesin) ---

  static const _kFrom = 'translate_from';
  static const _kTo = 'translate_to';

  static Future<(TranslateLanguage from, TranslateLanguage to)>
      lastPair() async {
    final p = await SharedPreferences.getInstance();
    return (
      _byCode(p.getString(_kFrom)) ?? TranslateLanguage.english,
      _byCode(p.getString(_kTo)) ?? TranslateLanguage.turkish,
    );
  }

  static Future<void> savePair(
      TranslateLanguage from, TranslateLanguage to) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFrom, from.bcpCode);
    await p.setString(_kTo, to.bcpCode);
  }

  static TranslateLanguage? _byCode(String? code) {
    if (code == null) return null;
    for (final l in languages.keys) {
      if (l.bcpCode == code) return l;
    }
    return null;
  }
}
