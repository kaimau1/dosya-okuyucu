/// **Altyazı desteği** — film oynatıcısının yanındaki `.srt` / `.vtt` /
/// `.ass` dosyalarını bulur, kod çözer ve zamanlanmış satırlara ayırır.
///
/// Kullanıcı isteği 2026-08-09: *"film oynatıcısı altyazı desteği lazım"*.
///
/// **Neden elle ayrıştırıcı (paket değil):** `video_player` kutudan yalnız
/// SubRip ve WebVTT çözüyor; indirilen filmlerin bir kısmı `.ass`/`.ssa` ile
/// geliyor ve — daha önemlisi — hiçbiri **kodlama** sorununu çözmüyor:
/// Türkçe altyazıların büyük bölümü UTF-8 değil Windows-1254'tür ve
/// `utf8.decode(allowMalformed: true)` onları "Ã§ok gÃ¼zel"e çevirir. Ayrıca
/// buradaki her şey saf Dart → Flutter kurmadan birim testi yazılabiliyor.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Zamanlanmış tek bir altyazı satırı.
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  String toString() => '[$start→$end] $text';
}

/// Bulunmuş bir altyazı dosyası.
class SubtitleTrack {
  final String path;

  /// Ekranda gösterilecek ad: dosya adının videodan ARTAN kısmı ("Türkçe",
  /// "eng", "forced"…). Artan bir şey yoksa dosyanın kendi adı.
  final String label;

  const SubtitleTrack({required this.path, required this.label});
}

abstract final class Subtitles {
  /// Ayrıştırılabildiğimiz uzantılar. `.sub` bilerek YOK: MicroDVD (kare
  /// numaralı, video kare hızını bilmeden zamana çevrilemez) ya da VobSub
  /// (ikili görüntü + ayrı `.idx`) olabiliyor — ikisi de bu ayrıştırıcının
  /// işi değil, yarım destek vermektense hiç listelememek dürüst.
  static const extensions = {'srt', 'vtt', 'ass', 'ssa'};

  /// Altyazının video dosyasının yanında aranacağı alt klasör adları.
  static const _subFolders = {'subs', 'subtitles', 'subtitle', 'altyazi'};

  /// [videoPath] için yanındaki altyazı dosyaları.
  ///
  /// Aynı klasörde adı videoyla başlayan (`Film.srt`, `Film.tr.srt`,
  /// `Film_eng.ass`) dosyalar ve varsa `Subs/` alt klasörünün tamamı.
  static List<SubtitleTrack> findFor(String videoPath) {
    final dir = Directory(p.dirname(videoPath));
    final base = p.basenameWithoutExtension(videoPath);
    final found = <String, SubtitleTrack>{};

    void consider(File file, {required bool requirePrefix}) {
      final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
      if (!extensions.contains(ext)) return;
      final name = p.basenameWithoutExtension(file.path);
      if (requirePrefix && !_matchesBase(name, base)) return;
      found[file.path] ??=
          SubtitleTrack(path: file.path, label: _labelFor(name, base, ext));
    }

    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File) {
          consider(entity, requirePrefix: true);
        } else if (entity is Directory &&
            _subFolders.contains(p.basename(entity.path).toLowerCase())) {
          try {
            for (final child in entity.listSync(followLinks: false)) {
              // Alt klasördeki her altyazı kabul edilir: "Subs/Turkish.srt"
              // dosya adında filmin adını taşımaz.
              if (child is File) consider(child, requirePrefix: false);
            }
          } catch (_) {
            // okunamayan alt klasör: yoksay
          }
        }
      }
    } catch (_) {
      // klasör okunamıyor (izin/SD kart) → altyazı yok sayılır
    }

    final list = found.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  /// `Film.tr` adı `Film` videosuna ait mi?
  ///
  /// Ayraç şart: `Film2.srt` dosyası `Film` videosunun altyazısı DEĞİLDİR.
  static bool _matchesBase(String name, String base) {
    if (name == base) return true;
    if (!name.startsWith(base)) return false;
    final rest = name.substring(base.length);
    return rest.startsWith('.') || rest.startsWith('_') || rest.startsWith('-');
  }

  static String _labelFor(String name, String base, String ext) {
    if (name.startsWith(base) && name.length > base.length) {
      final rest = name.substring(base.length + 1).trim();
      if (rest.isNotEmpty) return rest;
    }
    return '$name.$ext';
  }

  /// Dosyayı okur ve satırlara ayırır. Okunamaz/tanınmazsa boş liste.
  static Future<List<SubtitleCue>> load(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final text = decodeBytes(bytes);
      return parse(text, p.extension(path).replaceFirst('.', ''));
    } catch (_) {
      return const [];
    }
  }

  /// Baytları metne çevirir.
  ///
  /// Sıra: BOM → katı UTF-8 → **Windows-1254**. Katı UTF-8'in başarısız
  /// olması burada bilgidir: geçerli UTF-8 olmayan bir bayt dizisi neredeyse
  /// her zaman tek baytlık bir Batı/Türkçe kod sayfasıdır. `allowMalformed`
  /// ile zorlamak hatayı yutup ekrana bozuk karakter basardı.
  static String decodeBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), bigEndian: false);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), bigEndian: true);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return _decodeWindows1254(bytes);
    }
  }

  static String _decodeUtf16(List<int> bytes, {required bool bigEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i]);
    }
    return String.fromCharCodes(units);
  }

  /// 0x80–0x9F aralığının Windows-1254 karşılıkları. 0xA0 üstü latin-1 ile
  /// aynıdır; **Türkçe harflerin** oturduğu altı kod noktası ayrıksa da
  /// (0xD0 Ğ, 0xDD İ, 0xDE Ş, 0xF0 ğ, 0xFD ı, 0xFE ş) tablodan geliyor.
  static const _cp1254High = <int, int>{
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
    0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC,
    0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9F: 0x0178,
    0xD0: 0x011E, 0xDD: 0x0130, 0xDE: 0x015E,
    0xF0: 0x011F, 0xFD: 0x0131, 0xFE: 0x015F,
  };

  static String _decodeWindows1254(List<int> bytes) {
    final out = <int>[];
    for (final b in bytes) {
      out.add(_cp1254High[b] ?? b);
    }
    return String.fromCharCodes(out);
  }

  /// Metni satırlara ayırır. [format] uzantı (srt/vtt/ass/ssa); boş/bilinmeyen
  /// olursa içerikten sezilir.
  static List<SubtitleCue> parse(String text, [String format = '']) {
    final kind = format.toLowerCase();
    if (kind == 'ass' || kind == 'ssa') return parseAss(text);
    if (kind == 'srt' || kind == 'vtt') return parseSrtOrVtt(text);
    // Sezgi: ASS'in `[Script Info]`/`Dialogue:` imzası benzersiz.
    if (text.contains('[Events]') || text.contains('Dialogue:')) {
      return parseAss(text);
    }
    return parseSrtOrVtt(text);
  }

  /// `-->` içeren her satırı zaman satırı sayan ortak SubRip/WebVTT
  /// ayrıştırıcısı.
  ///
  /// **Neden ortak:** iki biçim yalnız ondalık ayracında (`,` / `.`), isteğe
  /// bağlı başlıkta (`WEBVTT`) ve zaman satırının sonundaki yerleşim
  /// ayarlarında (`align:start position:10%`) ayrılıyor. Numaralı/numarasız
  /// blok, `\r\n`, eksik boş satır gibi gerçek dünyadaki bozuklukları tek
  /// yerde hoşgörmek iki ayrı ayrıştırıcıdan sağlam çıktı.
  static List<SubtitleCue> parseSrtOrVtt(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <SubtitleCue>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('-->')) continue;
      final times = _parseTimeLine(line);
      if (times == null) continue;
      // Zamanın ALTINDAKİ satırlar, bir sonraki boş satıra ya da bir sonraki
      // zaman satırına kadar metindir.
      final buffer = <String>[];
      var j = i + 1;
      while (j < lines.length) {
        final next = lines[j];
        if (next.trim().isEmpty) break;
        if (next.contains('-->')) break;
        buffer.add(next);
        j++;
      }
      // Numaralı SubRip'te sıradaki bloğun numarası metnin son satırı gibi
      // görünebilir; boş satır ayracı varsa bu olmaz, yoksa son satır salt
      // sayıysa ve ardından zaman satırı geliyorsa geri verilir.
      if (buffer.length > 1 &&
          j < lines.length &&
          lines[j].contains('-->') &&
          RegExp(r'^\d+$').hasMatch(buffer.last.trim())) {
        buffer.removeLast();
        j--;
      }
      final body = _stripTags(buffer.join('\n')).trim();
      if (body.isNotEmpty) {
        out.add(SubtitleCue(start: times.$1, end: times.$2, text: body));
      }
      i = j - 1;
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  /// `[Events]` bölümündeki `Dialogue:` satırları.
  static List<SubtitleCue> parseAss(String text) {
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    // `Format:` satırı alan sırasını verir; Text alanı çoğunlukla 10. ama
    // garanti değil — SSA v4'te bir alan eksiktir. Sırayı okumak, sabit
    // 9 varsaymaktan güvenli.
    var textField = 9;
    var startField = 1;
    var endField = 2;
    final out = <SubtitleCue>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.toLowerCase().startsWith('format:')) {
        final names = line
            .substring(line.indexOf(':') + 1)
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .toList();
        final t = names.indexOf('text');
        final s = names.indexOf('start');
        final e = names.indexOf('end');
        if (t >= 0) textField = t;
        if (s >= 0) startField = s;
        if (e >= 0) endField = e;
        continue;
      }
      if (!line.toLowerCase().startsWith('dialogue:')) continue;
      // Metin alanı virgül İÇEREBİLİR → yalnız ilk `textField` virgülden böl.
      final body = line.substring(line.indexOf(':') + 1);
      final parts = body.split(',');
      if (parts.length <= textField) continue;
      final start = _parseTimestamp(parts[startField].trim());
      final end = _parseTimestamp(parts[endField].trim());
      if (start == null || end == null) continue;
      final content =
          _stripAssTags(parts.sublist(textField).join(',')).trim();
      if (content.isEmpty) continue;
      out.add(SubtitleCue(start: start, end: end, text: content));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static (Duration, Duration)? _parseTimeLine(String line) {
    final idx = line.indexOf('-->');
    final start = _parseTimestamp(line.substring(0, idx).trim());
    // Zaman satırının sonunda WebVTT yerleşim ayarları olabilir; ilk boşluğa
    // kadar okumak yeter.
    var tail = line.substring(idx + 3).trim();
    final space = tail.indexOf(' ');
    if (space > 0) tail = tail.substring(0, space);
    final end = _parseTimestamp(tail);
    if (start == null || end == null) return null;
    return (start, end);
  }

  /// `00:01:02,500` · `00:01:02.500` · `01:02.500` · `0:00:01.00` (ASS,
  /// santisaniye) biçimlerinin hepsini okur.
  static Duration? _parseTimestamp(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length > 3) return null;
    var hours = 0, minutes = 0;
    String secondsPart;
    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? -1;
      minutes = int.tryParse(parts[1]) ?? -1;
      secondsPart = parts[2];
    } else if (parts.length == 2) {
      minutes = int.tryParse(parts[0]) ?? -1;
      secondsPart = parts[1];
    } else {
      secondsPart = parts[0];
    }
    if (hours < 0 || minutes < 0) return null;
    final dot = secondsPart.indexOf('.');
    final wholeText = dot < 0 ? secondsPart : secondsPart.substring(0, dot);
    final seconds = int.tryParse(wholeText.trim());
    if (seconds == null || seconds < 0) return null;
    var millis = 0;
    if (dot >= 0) {
      // ASS santisaniye (2 hane), SubRip milisaniye (3 hane) — hane sayısına
      // göre ölçeklenir, sabit "1000 böl" ikisini karıştırırdı.
      final frac = secondsPart.substring(dot + 1).trim();
      final digits = frac.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        final value = int.tryParse(digits) ?? 0;
        millis = switch (digits.length) {
          1 => value * 100,
          2 => value * 10,
          3 => value,
          _ => (value / _pow10(digits.length - 3)).round(),
        };
      }
    }
    return Duration(
        hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// `<i>`, `<b>`, `<font color="…">` gibi biçim etiketlerini atar.
  /// Metnin kendisi korunur — altyazıda italik "kaybolan bilgi" değildir.
  static String _stripTags(String text) =>
      text.replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), '');

  /// ASS geçersiz kılma bloklarını (`{\pos(…)}`, `{\i1}`) ve satır sonu
  /// kaçışlarını (`\N`, `\n`, `\h`) çevirir.
  static String _stripAssTags(String text) => text
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\\[Nn]'), '\n')
      .replaceAll(r'\h', ' ');
}
