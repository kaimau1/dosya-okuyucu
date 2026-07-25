import 'package:flutter_tts/flutter_tts.dart';

/// Belgeyi cihazın kendi konuşma motoruyla **sesli okur** (internet gerekmez).
///
/// Metin parçalara bölünüp sırayla okunur: motor uzun metni tek seferde alsa
/// bile durdurma/duraklatma gecikir ve nerede kalındığı bilinmez. Parça parça
/// okuyunca hem anında durur hem "3 / 128" ilerlemesi gösterilebilir.
class TtsService {
  TtsService() {
    _tts.setCompletionHandler(_speakNext);
    // Motor hata verirse takılı kalmayalım (kilitli sıra = sessiz uygulama).
    _tts.setErrorHandler((_) => stop());
  }

  final FlutterTts _tts = FlutterTts();

  List<String> _chunks = const [];
  int _index = 0;
  bool _playing = false;

  /// Okunan parçanın sırası değiştiğinde çağrılır (arayüz ilerlemeyi gösterir).
  void Function(int index, int total, bool playing)? onProgress;

  bool get isPlaying => _playing;
  int get index => _index;
  int get total => _chunks.length;

  /// [text] boşsa hiçbir şey yapmaz. [startAt] ile kaldığı yerden sürdürülür.
  Future<void> start(String text, {int startAt = 0}) async {
    final chunks = splitForSpeech(text);
    if (chunks.isEmpty) return;
    _chunks = chunks;
    _index = startAt.clamp(0, chunks.length - 1);
    // Türkçe motor kuruluysa onu kullan; yoksa cihaz varsayılanı okur.
    if (await _tts.isLanguageAvailable('tr-TR') == true) {
      await _tts.setLanguage('tr-TR');
    }
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
