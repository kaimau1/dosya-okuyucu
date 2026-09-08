import 'dart:io';

import 'package:path/path.dart' as p;

/// **M3U çalma listesi** — okuma ve yazma.
///
/// ## Niye (2026-09-06 denetim turu)
/// Oynatıcı bir "çalma listesi" tutuyor ama o liste **uygulama kapanınca
/// yok oluyordu**: kullanıcı 40 parçalık bir sırayı elle kurup ertesi gün
/// yeniden kuruyordu. M3U bu işin evrensel ve en basit biçimi — VLC, Poweramp,
/// Winamp, araba teypleri, hepsi okuyor. Yeni bir dosya biçimi uydurmak
/// yerine var olanı kullanmak, listeyi bilgisayarda da açılabilir kılıyor.
///
/// ## Göreli yollar — taşınabilirlik
/// Yazarken yollar **listenin bulunduğu klasöre göre** göreli yazılıyor
/// (`../Müzik/parca.mp3`). Mutlak yol yazmak listeyi telefona bağlar:
/// `/storage/emulated/0/...` bilgisayarda da, başka bir telefonda da yoktur.
/// Aynı birimde olmayan dosyalar (USB bellekteki bir parça) mutlak kalır —
/// göreli yol oraya ulaşamaz.
///
/// `#EXTINF` satırları (süre ve başlık) yazılıyor ve okunuyor: onlar
/// olmadan başka oynatıcılar listeyi "adsız" gösteriyor.
class PlaylistEntry {
  /// Çözülmüş **mutlak** yol.
  final String path;

  /// Görünen ad (`#EXTINF` başlığı). Yoksa dosya adı.
  final String title;

  /// Saniye cinsinden süre; bilinmiyorsa -1 (M3U geleneği).
  final int seconds;

  const PlaylistEntry({
    required this.path,
    required this.title,
    this.seconds = -1,
  });
}

abstract final class PlaylistM3u {
  static const extension = '.m3u8';

  /// M3U metnini çözümler. [baseDir] göreli yolların çözüleceği klasör.
  ///
  /// **Var olmayan satırlar atılmaz** — dosya taşınmış olabilir ve
  /// kullanıcıya "listende 12 parça vardı, 3'ü bulunamadı" demek, listeyi
  /// sessizce kısaltmaktan iyidir. Ayıklama çağıranın işi.
  static List<PlaylistEntry> parse(String content, {required String baseDir}) {
    final out = <PlaylistEntry>[];
    String? pendingTitle;
    var pendingSeconds = -1;
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        if (line.startsWith('#EXTINF:')) {
          final body = line.substring(8);
          final comma = body.indexOf(',');
          if (comma > 0) {
            pendingSeconds =
                int.tryParse(body.substring(0, comma).split('.').first) ?? -1;
            pendingTitle = body.substring(comma + 1).trim();
          }
        }
        continue;
      }
      // `file://` ön eki bazı masaüstü oynatıcılarının yazdığı biçim.
      final cleaned =
          line.startsWith('file://') ? line.substring(7) : line;
      final absolute =
          p.isAbsolute(cleaned) ? cleaned : p.normalize(p.join(baseDir, cleaned));
      out.add(PlaylistEntry(
        path: absolute,
        title: (pendingTitle == null || pendingTitle.isEmpty)
            ? p.basenameWithoutExtension(absolute)
            : pendingTitle,
        seconds: pendingSeconds,
      ));
      pendingTitle = null;
      pendingSeconds = -1;
    }
    return out;
  }

  /// Çalma listesini M3U metnine çevirir.
  static String build(List<PlaylistEntry> entries, {required String baseDir}) {
    final sb = StringBuffer('#EXTM3U\n');
    for (final entry in entries) {
      sb.writeln('#EXTINF:${entry.seconds},${entry.title}');
      sb.writeln(_relativeIfPossible(entry.path, baseDir));
    }
    return sb.toString();
  }

  /// Dosyayı okur (UTF-8; bozuk baytlara takılmadan).
  static Future<List<PlaylistEntry>> read(String path) async {
    final content = await File(path).readAsString();
    return parse(content, baseDir: p.dirname(path));
  }

  /// Listeyi diske yazar ve yolu döner.
  static Future<String> write(
    String path,
    List<PlaylistEntry> entries,
  ) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(build(entries, baseDir: p.dirname(path)),
        flush: true);
    return path;
  }

  /// Aynı kök altındaysa göreli, değilse mutlak yol.
  ///
  /// Göreli yol ancak aynı birimde anlamlı: liste dahili bellekte, parça USB
  /// bellekteyse `../../..` zinciri hiçbir yere çıkmaz.
  static String _relativeIfPossible(String path, String baseDir) {
    try {
      final relative = p.relative(path, from: baseDir);
      // `..` ile başlayan uzun zincirler (birim değişimi) taşınabilir değil.
      if (relative.startsWith('../../..')) return path;
      return relative;
    } catch (_) {
      return path;
    }
  }
}
