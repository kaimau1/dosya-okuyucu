import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// **İnternetten altyazı** — OpenSubtitles REST API (v1).
///
/// Kullanıcı isteği 2026-11-02: *"alt yazı buldurma"* (VLC'deki gibi).
///
/// - Arama önce **dosya özetiyle** (`moviehash`): aynı sürümün altyazısı
///   zamanlamasıyla birebir tutar. Ad sorgusu yedek.
/// - Anahtar derlemeye `--dart-define=OPENSUBTITLES_API_KEY` ile girer —
///   yalnız kişisel derlemede (CI). Anahtar yoksa menüde seçenek görünmez.
/// - Girişsiz indirme günlük kotaya tabi (OpenSubtitles: ~5–20/gün/IP);
///   kota dolunca sunucunun iletisi kullanıcıya aynen gösterilir.
abstract final class OpenSubtitles {
  static const apiKey = String.fromEnvironment('OPENSUBTITLES_API_KEY');

  /// G8.6: ağ çağrısı zaman aşımı.
  static const _timeout = Duration(seconds: 30);

  static bool get available => apiKey.isNotEmpty;

  static const _base = 'https://api.opensubtitles.com/api/v1';

  static Map<String, String> get _headers => {
        'Api-Key': apiKey,
        'User-Agent': 'DosyaOkuyucu v1',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// OpenSubtitles özeti: dosya boyu + ilk ve son 64 KB'ın 64 bitlik
  /// küçük-uçlu sözcüklerinin toplamı (2^64'te taşar), 16 onaltılık hane.
  static Future<String> movieHash(String path) async {
    const chunk = 65536;
    final file = await File(path).open();
    try {
      final size = await file.length();
      var hash = size;
      Future<void> addChunk(int from) async {
        await file.setPosition(from);
        final bytes = await file.read(chunk);
        final data = ByteData.sublistView(
            Uint8List.fromList(bytes), 0, bytes.length - bytes.length % 8);
        for (var i = 0; i < data.lengthInBytes; i += 8) {
          hash += data.getUint64(i, Endian.little); // Dart int 64 bit: taşar
        }
      }

      await addChunk(0);
      await addChunk(size > chunk ? size - chunk : 0);
      return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    } finally {
      await file.close();
    }
  }

  /// [videoPath] için altyazı arar; [languages] ör. `['tr', 'en']`.
  static Future<List<SubtitleHit>> search(
    String videoPath,
    List<String> languages,
  ) async {
    final hash = await movieHash(videoPath);
    final query = p
        .basenameWithoutExtension(videoPath)
        .replaceAll(RegExp(r'[._]+'), ' ')
        .trim();
    final uri = Uri.parse('$_base/subtitles').replace(queryParameters: {
      'languages': languages.join(','),
      'moviehash': hash,
      'query': query,
    });
    final resp = await http.get(uri, headers: _headers).timeout(_timeout);
    if (resp.statusCode != 200) throw OpenSubtitlesError(_message(resp));
    return parseSearch(resp.body);
  }

  /// Arama yanıtını sonuçlara çevirir: özet eşleşenler önce, sonra indirme
  /// sayısına göre.
  static List<SubtitleHit> parseSearch(String body) {
    final data = (jsonDecode(body) as Map)['data'];
    if (data is! List) return const [];
    final hits = <SubtitleHit>[];
    for (final item in data) {
      final a = (item as Map)['attributes'];
      if (a is! Map) continue;
      final files = a['files'];
      if (files is! List || files.isEmpty) continue;
      final f = files.first as Map;
      final id = f['file_id'];
      if (id is! int) continue;
      hits.add(SubtitleHit(
        fileId: id,
        language: '${a['language'] ?? ''}',
        name: '${f['file_name'] ?? a['release'] ?? id}',
        downloads: (a['download_count'] as num?)?.toInt() ?? 0,
        hashMatch: a['moviehash_match'] == true,
      ));
    }
    hits.sort((x, y) => x.hashMatch != y.hashMatch
        ? (x.hashMatch ? -1 : 1)
        : y.downloads.compareTo(x.downloads));
    return hits;
  }

  /// Altyazıyı indirir, filmin yanına (`Film.tr.srt`) — klasör yazılamıyorsa
  /// [fallbackDir]'e — kaydeder ve yolunu döndürür.
  static Future<String> download(
    SubtitleHit hit,
    String videoPath, {
    required String fallbackDir,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/download'),
      headers: _headers,
      body: jsonEncode({'file_id': hit.fileId, 'sub_format': 'srt'}),
    ).timeout(_timeout);
    if (resp.statusCode != 200) throw OpenSubtitlesError(_message(resp));
    final link = (jsonDecode(resp.body) as Map)['link'];
    if (link is! String) throw OpenSubtitlesError(resp.body);
    // G8.6: yalnız https bağlantı (http'ye düşüş reddedilir).
    final linkUri = Uri.tryParse(link);
    if (linkUri == null || linkUri.scheme != 'https' || linkUri.host.isEmpty) {
      throw OpenSubtitlesError('insecure link');
    }
    final file = await http.get(linkUri).timeout(_timeout);
    if (file.statusCode != 200) throw OpenSubtitlesError('HTTP ${file.statusCode}');
    final base = p.basenameWithoutExtension(videoPath);
    final lang = hit.language.isEmpty ? '' : '.${hit.language}';
    final name = '$base$lang.srt';
    for (final dir in [p.dirname(videoPath), fallbackDir]) {
      try {
        final out = File(p.join(dir, name));
        await out.writeAsBytes(file.bodyBytes, flush: true);
        return out.path;
      } on FileSystemException {
        // film klasörü yazılamıyor (SD kart / salt okunur) → yedek klasör
      }
    }
    throw OpenSubtitlesError('write failed');
  }

  static String _message(http.Response r) {
    try {
      final m = jsonDecode(r.body);
      if (m is Map && m['message'] != null) return '${m['message']}';
    } catch (_) {
      // gövde JSON değil — durum kodu yeter
    }
    return 'HTTP ${r.statusCode}';
  }
}

class SubtitleHit {
  const SubtitleHit({
    required this.fileId,
    required this.language,
    required this.name,
    required this.downloads,
    required this.hashMatch,
  });

  final int fileId;
  final String language;
  final String name;
  final int downloads;

  /// Aynı dosya sürümü (zamanlama birebir tutar).
  final bool hashMatch;
}

class OpenSubtitlesError implements Exception {
  OpenSubtitlesError(this.message);
  final String message;
  @override
  String toString() => message;
}
