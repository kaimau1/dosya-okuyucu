import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import 'scan_text_fix.dart' show ScanTextFix;
import 'voice/neural_engine.dart';
import 'voice/neural_voices.dart';

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

  /// Tercih edilen Android TTS motoru paket adı (boş = sistem varsayılanı).
  final String engineName;

  const TtsPrefs({
    this.voiceName = '',
    this.voiceLocale = '',
    this.rate = 1.0,
    this.pitch = 1.0,
    this.engineName = '',
  });

  static const defaults = TtsPrefs();

  TtsPrefs copyWith({
    String? voiceName,
    String? voiceLocale,
    double? rate,
    double? pitch,
    String? engineName,
  }) =>
      TtsPrefs(
        voiceName: voiceName ?? this.voiceName,
        voiceLocale: voiceLocale ?? this.voiceLocale,
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
        engineName: engineName ?? this.engineName,
      );

  /// `ad|yerel|hız|perde|motor` — tek bir tercih dizesi (SharedPreferences).
  String encode() => '$voiceName|$voiceLocale|$rate|$pitch|$engineName';

  static TtsPrefs decode(String? source) {
    if (source == null || source.isEmpty) return defaults;
    final parts = source.split('|');
    if (parts.length < 4) return defaults;
    return TtsPrefs(
      voiceName: parts[0],
      voiceLocale: parts[1],
      rate: double.tryParse(parts[2])?.clamp(0.5, 2.0) ?? 1.0,
      pitch: double.tryParse(parts[3])?.clamp(0.5, 2.0) ?? 1.0,
      engineName: parts.length >= 5 ? parts[4] : '',
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

  /// Cihazda kurulu Android konuşma motorları (paket adları).
  static Future<List<String>> engines() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    try {
      final raw = await FlutterTts().getEngines;
      if (raw is! List) return const [];
      final out = <String>{
        for (final entry in raw)
          if (entry != null && '$entry'.trim().isNotEmpty) '$entry'.trim(),
      }.toList()
        ..sort();
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Paket adından okunaklı motor etiketi.
  static String engineLabel(String pkg) => switch (pkg) {
        'com.google.android.tts' => 'Google TTS ($pkg)',
        'com.samsung.SMT' => 'Samsung TTS ($pkg)',
        _ => pkg,
      };

  /// Cihazda kurulu sesler; [languagePrefix] verilirse yalnız o dile ait
  /// olanlar (`tr`, alt çizgili `tr_TR` dahil). [engineName] verilirse önce
  /// ilgili Android motoru seçilir.
  static Future<List<TtsVoiceInfo>> voices({
    String? languagePrefix,
    String? engineName,
  }) async {
    if (kIsWeb) return const [];
    try {
      final tts = FlutterTts();
      if (engineName != null &&
          engineName.isNotEmpty &&
          defaultTargetPlatform == TargetPlatform.android) {
        await tts.setEngine(engineName);
      }
      final raw = await tts.getVoices;
      if (raw is! List) return const [];
      final wantPrefix = languagePrefix?.replaceAll('_', '-').toLowerCase();
      final out = <TtsVoiceInfo>{};
      for (final entry in raw) {
        if (entry is! Map) continue;
        final name = '${entry['name'] ?? ''}';
        final locale = '${entry['locale'] ?? ''}';
        if (name.isEmpty || locale.isEmpty) continue;
        if (wantPrefix != null &&
            !locale
                .replaceAll('_', '-')
                .toLowerCase()
                .startsWith(wantPrefix)) {
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
    if (prefs.engineName.isNotEmpty &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _tts.setEngine(prefs.engineName);
      } catch (_) {
        // Bilinçli: seçilen motor kaldırılmışsa varsayılan motorla sürer.
      }
    }
    try {
      final locale = prefs.voiceLocale.isNotEmpty ? prefs.voiceLocale : 'tr-TR';
      if (await _tts.isLanguageAvailable(locale) == true) {
        await _tts.setLanguage(locale);
      }
    } catch (_) {
      // Bilinçli: motor bu dili desteklemiyor — varsayılan dille okur.
    }
    if (prefs.voiceName.isNotEmpty &&
        prefs.voiceLocale.isNotEmpty &&
        NeuralVoiceId.parse(prefs.voiceName) == null) {
      try {
        await _tts
            .setVoice({'name': prefs.voiceName, 'locale': prefs.voiceLocale});
      } catch (_) {
        // Bilinçli: seçilen ses bu cihazda yok — varsayılan sesle okur.
      }
    }
    try {
      await _tts.setSpeechRate(platformRate(prefs.rate));
      await _tts.setPitch(prefs.pitch.clamp(0.5, 2.0));
    } catch (_) {
      // Bilinçli: motor hız/perde ayarını reddetti — varsayılanla okur.
    }
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

  /// [text]i cihazın motoruyla **WAV dosyasına** yazar (sesli kitap,
  /// 2026-10-22). Motorun tek seferlik sınırı ~4000 karakter: çağıran
  /// parçalar. Dosya oluştuysa true.
  Future<bool> synthesizeToFile(String text, String path) async {
    await _applyPrefs();
    try {
      await _tts.awaitSynthCompletion(true);
      final r = await _tts.synthesizeToFile(text, path, true);
      final file = File(path);
      return r == 1 && file.existsSync() && file.lengthSync() > 44;
    } catch (_) {
      return false;
    }
  }

  /// Seçilen sesi kısa bir cümleyle dinletir (ayar sayfasındaki "Dene").
  Future<void> preview(String sample) async {
    final neural = _neuralVoice;
    if (neural != null) {
      await stop();
      _chunks = [sample];
      _index = 0;
      _playing = true;
      _previewOnly = true;
      await _speakCurrent();
      return;
    }
    await _applyPrefs();
    await _tts.stop();
    await _tts.speak(sample);
  }

  /// [text] boşsa hiçbir şey yapmaz. [startAt] ile kaldığı yerden sürdürülür.
  Future<void> start(String text, {int startAt = 0}) async {
    _previewOnly = false;
    _neuralFailed = false;
    _clearNeural();
    // Yapay ses parça başına ısınma maliyeti taşır: parçalar daha uzun.
    final chunks = splitForSpeech(cleanForSpeech(text),
        maxLength: _neuralVoice != null ? 400 : 240);
    if (chunks.isEmpty) return;
    _chunks = chunks;
    _index = startAt.clamp(0, chunks.length - 1);
    if (_neuralVoice != null) {
      _playing = true;
      await _speakCurrent();
      return;
    }
    await _applyPrefs();
    await _tts.awaitSpeakCompletion(true);
    _playing = true;
    await _speakCurrent();
  }

  Future<void> pause() async {
    _playing = false;
    _gen++;
    await _player?.pause();
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
    _gen++;
    await _disposePlayer();
    await _tts.stop();
    _notify();
  }

  Future<void> dispose() async {
    _playing = false;
    _gen++;
    await _disposePlayer();
    _clearNeural();
    if (_engine != null) {
      _engine = null;
      NeuralVoiceEngine.release();
    }
    await _tts.stop();
  }

  Future<void> _speakCurrent() async {
    if (!_playing || _index >= _chunks.length) return;
    _notify();
    if (_neuralVoice != null) {
      await _speakNeural();
      return;
    }
    await _tts.speak(_chunks[_index]);
  }

  // ── Yapay zekâ sesi (2026-10-23) ─────────────────────────────────────────
  // Kullanıcı: *"yapay zeka sesleri iniyor ama seçemiyorum, sadece sesli
  // kitapta seçiliyor"*. Okuma ayarında `neural:<ses>` seçiliyse parçalar
  // kökteki paylaşılan motorla WAV'a çevrilip çalınır; bir parça çalarken
  // sonraki üretilir (parçalar arası boşluk kısa kalsın). Ses kurulu değilse
  // ya da motor açılamazsa okuma DURMAZ: cihazın sesine düşülür.

  /// Seçili ve kullanılabilir yapay ses (yoksa null → cihaz sesi).
  NeuralVoice? get _neuralVoice {
    if (_neuralFailed || kIsWeb) return null;
    final v = NeuralVoiceId.parse(prefs.voiceName);
    if (v == null || !NeuralVoiceStore.instance.isInstalled(v)) return null;
    return v;
  }

  NeuralVoiceEngine? _engine;
  VideoPlayerController? _player;
  bool _neuralFailed = false;
  bool _previewOnly = false;

  /// Her durdurma/duraklatma kuşağı artırır: geç gelen sentez sonucu ya da
  /// çalma bitişi eski bir kuşağa aitse yok sayılır.
  int _gen = 0;
  final Map<int, Future<String>> _files = {};
  static int _fileSeq = 0;

  Future<String> _fileFor(int i) => _files[i] ??= _synth(i);

  Future<String> _synth(int i) async {
    final voice = _neuralVoice!;
    final engine = _engine ??= await NeuralVoiceEngine.acquire();
    final bytes = await engine.synthesize(voice, _chunks[i],
        speed: prefs.rate.clamp(0.5, 2.0));
    final dir = Directory(p.join(Directory.systemTemp.path, 'tts_neural'));
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, 'p${_fileSeq++}.wav'));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  void _clearNeural() {
    for (final f in _files.values) {
      f.then<void>((path) => File(path).delete(), onError: (_) {}).ignore();
    }
    _files.clear();
  }

  Future<void> _disposePlayer() async {
    final pl = _player;
    _player = null;
    if (pl == null) return;
    try {
      await pl.pause();
    } catch (_) {
      // Bilinçli: kapatma/durdurma — zaten durmuşsa ya da yerel taraf yoksa yapılacak bir şey yok.
    }
    await pl.dispose();
  }

  Future<void> _speakNeural() async {
    final gen = ++_gen;
    final i = _index;
    String path;
    try {
      path = await _fileFor(i);
    } catch (_) {
      _files.remove(i);
      if (gen != _gen) return;
      // Motor açılamadı / ses yüklenemedi: cihazın sesiyle sürdür.
      _neuralFailed = true;
      await _applyPrefs();
      await _tts.awaitSpeakCompletion(true);
      await _speakCurrent();
      return;
    }
    if (gen != _gen || !_playing) return;
    // Sonraki parça şimdiden üretilsin.
    if (i + 1 < _chunks.length) _fileFor(i + 1).ignore();
    await _disposePlayer();
    if (gen != _gen || !_playing) return;
    final pl = _player = VideoPlayerController.file(File(path),
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true));
    var finished = false;
    pl.addListener(() {
      if (finished || gen != _gen) return;
      final v = pl.value;
      if (v.hasError || v.isCompleted) {
        finished = true;
        // Çalınan parçanın dosyası artık gerekmiyor.
        _files.remove(i)?.then((f) => File(f).delete()).ignore();
        if (_previewOnly) {
          _previewOnly = false;
          stop();
          return;
        }
        _speakNext();
      }
    });
    try {
      await pl.initialize();
      if (gen != _gen || !_playing) return;
      await pl.play();
    } catch (_) {
      if (gen == _gen && _playing && !finished) {
        finished = true;
        _speakNext();
      }
    }
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

/// Sesli okuma / sesli kitap öncesi metin temizleme seçenekleri.
class SpeechCleanOptions {
  final bool stripPageNumbers;
  final bool stripParentheticals;
  final bool stripSymbolsAndUrls;
  final bool expandAbbreviations;
  final bool preserveParagraphs;

  const SpeechCleanOptions({
    this.stripPageNumbers = true,
    this.stripParentheticals = true,
    this.stripSymbolsAndUrls = true,
    this.expandAbbreviations = true,
    this.preserveParagraphs = true,
  });
}

/// Sesli kitap için parça ve arkasından eklenecek doğal sessizlik süresi.
class SpeechSegment {
  final String text;
  final int pauseAfterMs;
  const SpeechSegment(this.text, this.pauseAfterMs);
}

final RegExp _pageFractionRe = RegExp(
  r'^(sayfa|page|s\.|p\.)?\s*\d{1,4}\s*(/|of)\s*\d{1,4}$',
  caseSensitive: false,
);
final RegExp _pageLabelRe = RegExp(
  r'^[-–—\[\(\s]*(sayfa|page|s\.|p\.)\s*\d{1,4}[-–—\]\)\s]*$',
  caseSensitive: false,
);
final RegExp _decorRuleRe = RegExp(r'^[\-=_\*~#\|•·\.]{3,}$');
final RegExp _urlRe = RegExp(r'https?://\S+|www\.\S+', caseSensitive: false);
final RegExp _mdPrefixRe = RegExp(r'^(?:#{1,6}\s+|>\s+|[-*•▪◦►→]+\s+)');
final RegExp _footnoteBracketRe = RegExp(r'\[\s*\d+(?:\s*[,\-–]\s*\d+)*\s*\]');
final RegExp _shortRefParenRe = RegExp(
  r'\(\s*(?:bkz\.?|cf\.?|s\.|p\.|pp\.|tablo|şekil|not)?\s*[\d,\-–\s]{0,16}\s*\)',
  caseSensitive: false,
);

const List<(String pattern, String expansion)> _abbrExpansions = [
  (r'\bT\.C\.?', 'Türkiye Cumhuriyeti'),
  (r'\bM\.Ö\.?', 'milattan önce'),
  (r'\bM\.S\.?', 'milattan sonra'),
  (r'\bProf\.', 'Profesör'),
  (r'\bDoç\.', 'Doçent'),
  (r'\bDr\.', 'Doktor'),
  (r'\bAv\.', 'Avukat'),
  (r'\bMüh\.', 'Mühendis'),
  (r'\bvb\.', 've benzeri'),
  (r'\bvs\.', 'vesaire'),
  (r'\bvd\.', 've diğerleri'),
  (r'\bbkz\.', 'bakınız'),
  (r'\börn\.', 'örneğin'),
  (r'\bör\.', 'örneğin'),
  (r'\byy\.', 'yüzyıl'),
  (r'\be\.g\.', 'for example'),
  (r'\bi\.e\.', 'that is'),
  (r'\betc\.', 'et cetera'),
];

/// Sesli okumadan ÖNCE metni temizler.
///
/// Yalnız sayfa numaralarını ve satır sonu hece tiresini değil; TTS motorunun
/// kelimelere çevirip okuduğu dekoratif çizgileri, dipnot köşeli parantezlerini,
/// URL'leri, parantez içi kısa atıfları ve kısaltmaları temizler. Saf -> testli.
String cleanForSpeech(
  String text, {
  SpeechCleanOptions options = const SpeechCleanOptions(),
}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rawLines = normalized.split('\n');
  final kept = <String?>[]; // null = paragraf boş satırı

  for (var raw in rawLines) {
    final line = raw.trim();
    if (line.isEmpty) {
      if (options.preserveParagraphs && kept.isNotEmpty && kept.last != null) {
        kept.add(null);
      }
      continue;
    }
    if (options.stripPageNumbers &&
        (ScanTextFix.looksLikePageNumber(line) ||
            _pageFractionRe.hasMatch(line) ||
            _pageLabelRe.hasMatch(line))) {
      continue;
    }
    if (options.stripSymbolsAndUrls && _decorRuleRe.hasMatch(line)) {
      continue;
    }
    var cleanLine = line;
    if (options.stripSymbolsAndUrls) {
      cleanLine = cleanLine
          .replaceFirst(_mdPrefixRe, '')
          .replaceAll(_urlRe, ' ')
          .replaceAll(RegExp(r'\*{1,3}|_{2,}|`+'), '')
          .replaceAll(RegExp(r'[|•▪◦★☆►▶→←↔※†‡§]'), ' ')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .trim();
    }
    if (cleanLine.isEmpty) continue;
    kept.add(cleanLine);
  }
  while (kept.isNotEmpty && kept.last == null) {
    kept.removeLast();
  }

  // Satır sonu hece tiresini birleştir ve paragraf akışını koru.
  final buf = StringBuffer();
  for (var i = 0; i < kept.length; i++) {
    final item = kept[i];
    if (item == null) {
      buf.write('\n\n');
      continue;
    }
    final prevWasPara = i > 0 && kept[i - 1] == null;
    if (i > 0 && !prevWasPara) {
      // Önceki satır birleştirildi (tire) veya satır ayracı gerekiyor.
      final prev = kept[i - 1]!;
      if (prev.endsWith('-') &&
          prev.length >= 2 &&
          RegExp(r'^[a-zçğıöşü]').hasMatch(item)) {
        // Tire önceki adımda silinmedi; geriye gidip değiştir.
        final s = buf.toString();
        buf
          ..clear()
          ..write(s.substring(0, s.length - 1))
          ..write(item);
        continue;
      }
      final endsSentence = RegExp(r'[.!?…:]$').hasMatch(prev);
      buf.write(endsSentence ? '\n' : ' ');
    }
    buf.write(item);
  }

  var out = buf.toString();
  if (options.stripParentheticals) {
    out = out.replaceAll(_footnoteBracketRe, '');
    out = out.replaceAll(_shortRefParenRe, ' ');
    // Kısa/uzun düz parantezleri doğal duraklamaya (virgül) çevir.
    out = out.replaceAllMapped(
      RegExp(r'\(([^()\n]{1,160})\)'),
      (m) {
        final inner = m.group(1)!.trim();
        if (inner.isEmpty) return '';
        return ', $inner,';
      },
    );
    out = out.replaceAll(RegExp(r'[()\[\]]'), '');
  }
  if (options.expandAbbreviations) {
    for (final (pat, exp) in _abbrExpansions) {
      out = out.replaceAll(RegExp(pat, caseSensitive: false), exp);
    }
  }
  if (options.stripSymbolsAndUrls) {
    out = out
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'!{2,}'), '!')
        .replaceAll(RegExp(r'\?{2,}'), '?')
        .replaceAll(RegExp(r',{2,}'), ',');
  }
  out = out
      .replaceAllMapped(RegExp(r'[ \t]+([,.;:!?])'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return out;
}

/// Metni sesli kitap bölümlerine uygun doğal duraklamalı parçalara böler.
/// Paragraf geçişleri (650 ms), kısa başlık satırları (800 ms), cümle sonları
/// (350 ms) ve uzun cümle içi bölünmeler (180 ms) için ayrı duraklama üretir.
List<SpeechSegment> splitForAudiobook(
  String text, {
  int maxLength = 320,
  SpeechCleanOptions options = const SpeechCleanOptions(),
}) {
  final cleaned = cleanForSpeech(text, options: options);
  if (cleaned.isEmpty) return const [];
  final paragraphs = [
    for (final p in cleaned.split(RegExp(r'\n\s*\n')))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  final out = <SpeechSegment>[];
  for (final para in paragraphs) {
    final isShortHeading = para.length < 70 &&
        !para.contains('\n') &&
        !RegExp(r'[.!?…]$').hasMatch(para);
    if (para.length <= maxLength) {
      out.add(SpeechSegment(para, isShortHeading ? 800 : 650));
      continue;
    }
    final pieces = splitForSpeech(para, maxLength: maxLength);
    final buf = StringBuffer();
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (buf.isNotEmpty && buf.length + 1 + piece.length > maxLength) {
        final chunk = buf.toString();
        final ended = RegExp(r'[.!?…]$').hasMatch(chunk);
        out.add(SpeechSegment(chunk, ended ? 350 : 180));
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(piece);
    }
    if (buf.isNotEmpty) {
      out.add(SpeechSegment(buf.toString(), 650));
    }
  }
  return out;
}

/// Metni konuşma parçalarına böler: önce cümle sonlarından, uzun kalırsa
/// virgül/boşluktan. Motorlar çok uzun metinde kesiliyor, çok kısa parçada da
/// tonlama bozuluyor — [maxLength] ikisinin arası.
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

  // Hâlâ uzun olanları virgül/kelime sınırından kes (motor ortadan kesmesin).
  final out = <String>[];
  for (final s in sentences) {
    if (s.length <= maxLength) {
      out.add(s);
      continue;
    }
    var rest = s;
    while (rest.length > maxLength) {
      var cut = rest.lastIndexOf(', ', maxLength);
      if (cut <= maxLength ~/ 2) cut = rest.lastIndexOf(' ', maxLength);
      if (cut <= 0) cut = maxLength; // boşluksuz dev kelime
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
  }
  return out;
}
