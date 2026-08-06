import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'scan_text_fix.dart' show ScanTextFix;

/// Cihazda kurulu bir konuşma sesi.
class TtsVoiceInfo {
  /// Motorun verdiği ad (`tr-tr-x-fid-local` gibi) — seçimde anahtar budur.
  final String name;

  /// Dil/bölge (`tr-TR`).
  final String locale;

  const TtsVoiceInfo({required this.name, required this.locale});

  /// Listede gösterilecek okunur ad. Motor adları teknik olduğu için
  /// (`tr-tr-x-fid-local`) ayıklanıp "Türkçe · fid (yerel)" gibi yazılır.
  String get label {
    var body = name;
    final prefix = '${locale.toLowerCase()}-';
    if (body.toLowerCase().startsWith(prefix)) {
      body = body.substring(prefix.length);
    }
    body = body.replaceAll(RegExp(r'^x-'), '');
    body = body.replaceAll('-local', ' (cihazda)');
    body = body.replaceAll('-network', ' (çevrimiçi)');
    return body.isEmpty ? name : body;
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoiceInfo && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// Sesli okuma tercihleri — ses, hız, perde.
///
/// Kullanıcı isteği 2026-08-06: *"sesli okuma çok kalitesiz, ses seçimi
/// olmalı notlar uygulamadaki gibi."* Kalitenin asıl kaynağı motor değil
/// **seçilen ses**: cihazda genelde birden çok Türkçe ses kurulu olur ve
/// varsayılan çoğu zaman en robotik olanıdır. Seçimi kullanıcıya bırakıp
/// hatırlıyoruz.
class TtsPrefs {
  /// Boşsa motorun varsayılan sesi kullanılır.
  final String voiceName;
  final String voiceLocale;

  /// Konuşma hızı çarpanı (1.0 = normal). Platform farkı [TtsService] içinde.
  final double rate;

  /// Ses perdesi (1.0 = normal).
  final double pitch;

  const TtsPrefs({
    this.voiceName = '',
    this.voiceLocale = '',
    this.rate = 1.0,
    this.pitch = 1.0,
  });

  static const defaults = TtsPrefs();

  TtsPrefs copyWith({
    String? voiceName,
    String? voiceLocale,
    double? rate,
    double? pitch,
  }) =>
      TtsPrefs(
        voiceName: voiceName ?? this.voiceName,
        voiceLocale: voiceLocale ?? this.voiceLocale,
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
      );

  /// `ad|yerel|hız|perde` — tek bir tercih dizesi (SharedPreferences).
  String encode() => '$voiceName|$voiceLocale|$rate|$pitch';

  static TtsPrefs decode(String? source) {
    if (source == null || source.isEmpty) return defaults;
    final parts = source.split('|');
    if (parts.length < 4) return defaults;
    return TtsPrefs(
      voiceName: parts[0],
      voiceLocale: parts[1],
      rate: double.tryParse(parts[2])?.clamp(0.5, 2.0) ?? 1.0,
      pitch: double.tryParse(parts[3])?.clamp(0.5, 2.0) ?? 1.0,
    );
  }
}

/// Belgeyi cihazın kendi konuşma motoruyla **sesli okur** (internet gerekmez).
///
/// Metin parçalara bölünüp sırayla okunur: motor uzun metni tek seferde alsa
/// bile durdurma/duraklatma gecikir ve nerede kalındığı bilinmez. Parça parça
/// okuyunca hem anında durur hem "3 / 128" ilerlemesi gösterilebilir.
class TtsService {
  TtsService({this.prefs = TtsPrefs.defaults}) {
    _tts.setCompletionHandler(_speakNext);
    // Motor hata verirse takılı kalmayalım (kilitli sıra = sessiz uygulama).
    _tts.setErrorHandler((_) => stop());
  }

  final FlutterTts _tts = FlutterTts();

  /// Ses/hız/perde tercihleri. Değiştirilirse sonraki [start]'ta uygulanır.
  TtsPrefs prefs;

  List<String> _chunks = const [];
  int _index = 0;
  bool _playing = false;

  /// Okunan parçanın sırası değiştiğinde çağrılır (arayüz ilerlemeyi gösterir).
  void Function(int index, int total, bool playing)? onProgress;

  bool get isPlaying => _playing;
  int get index => _index;
  int get total => _chunks.length;

  /// Cihazda kurulu sesler; [languagePrefix] verilirse yalnız o dile ait
  /// olanlar (`tr`). Motor listeyi vermezse boş liste (arayüz "varsayılan ses"
  /// der, hata göstermez).
  static Future<List<TtsVoiceInfo>> voices({String? languagePrefix}) async {
    if (kIsWeb) return const [];
    try {
      final raw = await FlutterTts().getVoices;
      if (raw is! List) return const [];
      final out = <TtsVoiceInfo>{};
      for (final entry in raw) {
        if (entry is! Map) continue;
        final name = '${entry['name'] ?? ''}';
        final locale = '${entry['locale'] ?? ''}';
        if (name.isEmpty || locale.isEmpty) continue;
        if (languagePrefix != null &&
            !locale.toLowerCase().startsWith(languagePrefix.toLowerCase())) {
          continue;
        }
        out.add(TtsVoiceInfo(name: name, locale: locale));
      }
      final list = out.toList()..sort((a, b) => a.label.compareTo(b.label));
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Tercihleri motora yazar. Motor bir ayarı desteklemiyorsa sessizce
  /// atlanır — tek bir ayar yüzünden okumanın hiç başlamaması saçma olurdu.
  Future<void> _applyPrefs() async {
    try {
      final locale = prefs.voiceLocale.isNotEmpty ? prefs.voiceLocale : 'tr-TR';
      if (await _tts.isLanguageAvailable(locale) == true) {
        await _tts.setLanguage(locale);
      }
    } catch (_) {}
    if (prefs.voiceName.isNotEmpty && prefs.voiceLocale.isNotEmpty) {
      try {
        await _tts.setVoice(
            {'name': prefs.voiceName, 'locale': prefs.voiceLocale});
      } catch (_) {}
    }
    try {
      await _tts.setSpeechRate(platformRate(prefs.rate));
      await _tts.setPitch(prefs.pitch.clamp(0.5, 2.0));
    } catch (_) {}
  }

  /// Hız çarpanını platformun beklediği değere çevirir.
  ///
  /// **TUZAK:** `flutter_tts`ta 1.0 her yerde "normal" değil — Android'de
  /// normal 1.0 iken iOS'ta normal 0.5'tir (0.5 üstü hızlanır). Çarpanı
  /// olduğu gibi geçirmek iOS'ta iki kat hızlı konuşmaya yol açardı.
  static double platformRate(double multiplier) {
    final m = multiplier.clamp(0.5, 2.0);
    final isApple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    return isApple ? (m * 0.5).clamp(0.0, 1.0) : m;
  }

  /// Seçilen sesi kısa bir cümleyle dinletir (ayar sayfasındaki "Dene").
  Future<void> preview(String sample) async {
    await _applyPrefs();
    await _tts.stop();
    await _tts.speak(sample);
  }

  /// [text] boşsa hiçbir şey yapmaz. [startAt] ile kaldığı yerden sürdürülür.
  Future<void> start(String text, {int startAt = 0}) async {
    final chunks = splitForSpeech(cleanForSpeech(text));
    if (chunks.isEmpty) return;
    _chunks = chunks;
    _index = startAt.clamp(0, chunks.length - 1);
    await _applyPrefs();
    await _tts.awaitSpeakCompletion(true);
    _playing = true;
    await _speakCurrent();
  }

  Future<void> pause() async {
    _playing = false;
    await _tts.stop();
    _notify();
  }

  Future<void> resume() async {
    if (_chunks.isEmpty || _playing) return;
    _playing = true;
    await _speakCurrent();
  }

  Future<void> stop() async {
    _playing = false;
    _index = 0;
    await _tts.stop();
    _notify();
  }

  Future<void> dispose() async {
    _playing = false;
    await _tts.stop();
  }

  Future<void> _speakCurrent() async {
    if (!_playing || _index >= _chunks.length) return;
    _notify();
    await _tts.speak(_chunks[_index]);
  }

  Future<void> _speakNext() async {
    if (!_playing) return;
    if (_index + 1 >= _chunks.length) {
      await stop();
      return;
    }
    _index++;
    await _speakCurrent();
  }

  void _notify() => onProgress?.call(_index, _chunks.length, _playing);
}

/// Sesli okumadan ÖNCE metni temizler.
///
/// Kullanıcı isteği 2026-08-06: *"sayfadaki sayfa numaralarının okunmaması
/// lazım."* Taranmış kitapta sayfa numarası metnin ortasında kendi satırı
/// olarak durur ve motor onu "otuz beş" diye okuyup cümleyi böler. Aynı
/// mantıkla satır sonu tiresi de birleştirilir — yoksa "ener… jiye" diye iki
/// parça duyulur.
///
/// Saf fonksiyon → birim testli.
String cleanForSpeech(String text) {
  final lines = text.split('\n');
  final kept = <String>[];
  for (var raw in lines) {
    final line = raw.trim();
    // Sayfa numarası / "Sayfa 35" / "- 35 -": tek başına duran satır atılır.
    // Cümlenin İÇİNDEKİ sayılara dokunulmaz (looksLikePageNumber tüm satırı
    // arar), yoksa "35 kişi geldi" de kaybolurdu.
    if (line.isEmpty || ScanTextFix.looksLikePageNumber(line)) continue;
    kept.add(line);
  }

  final buffer = StringBuffer();
  for (var i = 0; i < kept.length; i++) {
    final line = kept[i];
    if (line.endsWith('-') && i + 1 < kept.length) {
      buffer.write(line.substring(0, line.length - 1)); // hece birleşir
      continue;
    }
    buffer.write(line);
    if (i + 1 < kept.length) buffer.write('\n');
  }
  return buffer.toString().trim();
}

/// Metni konuşma parçalarına böler: önce cümle sonlarından, uzun kalırsa
/// virgül/boşluktan. Motorlar çok uzun metinde kesiliyor, çok kısa parçada da
/// tonlama bozuluyor — [maxLength] ikisinin arası.
///
/// Bölme sezgiseldir: noktalama + boşluk + büyük harf. Kısaltmadan sonra
/// büyük harf gelirse ("Dr. Ahmet") erken böler — okunan metin aynı kalır,
/// yalnız duraklama bir kelime öne kayar. Doğruluk için değer vermeye değmez;
/// ponytail: şikayet gelirse kısaltma sözlüğü eklenir.
List<String> splitForSpeech(String text, {int maxLength = 240}) {
  final clean = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  if (clean.isEmpty) return const [];

  final sentences = <String>[];
  var start = 0;
  final pattern = RegExp(r'[.!?…:;]\s+(?=[A-ZÇĞİÖŞÜ0-9])|\n+');
  for (final m in pattern.allMatches(clean)) {
    final piece = clean.substring(start, m.end).trim();
    if (piece.isNotEmpty) sentences.add(piece);
    start = m.end;
  }
  final tail = clean.substring(start).trim();
  if (tail.isNotEmpty) sentences.add(tail);

  // Hâlâ uzun olanları kelime sınırından kes (motor ortadan kesmesin).
  final out = <String>[];
  for (final s in sentences) {
    if (s.length <= maxLength) {
      out.add(s);
      continue;
    }
    var rest = s;
    while (rest.length > maxLength) {
      var cut = rest.lastIndexOf(' ', maxLength);
      if (cut <= 0) cut = maxLength; // boşluksuz dev kelime
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
  }
  return out;
}
