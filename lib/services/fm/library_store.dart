import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fm_env.dart';
import 'pdf_thumbnail.dart';

/// **Kitaplık** (2026-11-01, kullanıcı: *"istediğim PDF'leri veya e-kitap
/// olabilecek türleri seçip kitaplığa ekleyebilelim"*).
///
/// Dosyalar TAŞINMAZ — kitaplık yalnız yol listesidir (appSupport içinde
/// `library.json`). Dosya silinir/taşınırsa kitap "bulunamadı" görünür,
/// kullanıcı kaldırır; sessizce düşürmek SD kart çıkarılınca kitaplığı
/// boşaltırdı.
abstract final class LibraryStore {
  static const _fileName = 'library.json';

  /// Kitap sayılan uzantılar (küçük harf, noktasız).
  static const bookExtensions = {
    'pdf', 'epub', 'mobi', 'azw', 'azw3', 'fb2', 'djvu', 'cbz', 'cbr',
  };

  static bool isBook(String path) => bookExtensions
      .contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  /// Değişince artar — ekranlar dinler.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// yol → eklenme zamanı (ms).
  static final Map<String, int> _added = {};
  static Future<void>? _loadFuture;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  static Future<void> _load() async {
    if (FmEnv.appSupportDir.isEmpty) {
      try {
        await FmEnv.ensureInit();
      } catch (_) {
        // Bilinçli: ortam hazırlanamadı (testte yol sağlayıcı yok) — ardından gelen okuma boş sonuçla sürer.
      }
    }
    if (FmEnv.appSupportDir.isEmpty) {
      _loadFuture = null;
      return;
    }
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return;
      for (final e in raw) {
        if (e is Map && e['p'] is String) {
          _added[e['p'] as String] = (e['t'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {
      // Bozuk dosya: boş kitaplıkla devam (bir sonraki kayıt üstüne yazar).
    }
  }

  /// Eklenme sırasıyla (en yeni önce) kitap yolları.
  static List<String> get paths => _added.keys.toList()
    ..sort((a, b) => _added[b]!.compareTo(_added[a]!));

  static int get count => _added.length;

  static bool contains(String path) => _added.containsKey(path);

  static int addedAt(String path) => _added[path] ?? 0;

  /// Kitap olmayanlar ve zaten ekli olanlar atlanır; eklenen sayısı döner.
  static Future<int> add(Iterable<String> paths) async {
    await ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    var n = 0;
    for (final path in paths) {
      if (!isBook(path) || _added.containsKey(path)) continue;
      _added[path] = now + n; // aynı anda eklenenler seçim sırasını korur
      n++;
    }
    if (n > 0) await _save();
    return n;
  }

  static Future<void> remove(Iterable<String> paths) async {
    await ensureLoaded();
    var changed = false;
    for (final path in paths) {
      changed = _added.remove(path) != null || changed;
    }
    if (changed) await _save();
  }

  static Future<void> _save() async {
    revision.value++;
    if (FmEnv.appSupportDir.isEmpty) return;
    final list = [
      for (final e in _added.entries) {'p': e.key, 't': e.value},
    ];
    try {
      await File(_path).writeAsString(jsonEncode(list));
    } catch (_) {
      // Yazılamadı: bellekteki liste oturum boyunca geçerli kalır.
    }
  }

  /// Kapak resmi (dosya yolu) — PDF ilk sayfası, EPUB'un kendi kapağı;
  /// yoksa null (ekran tür renginde kapak çizer).
  static Future<String?> coverOf(String path) async {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') return PdfThumbnail.forPdf(path, size: 420);
    if (ext == '.epub') return _epubCover(path);
    return null;
  }

  static final Map<String, Future<String?>> _epubInFlight = {};

  static Future<String?> _epubCover(String path) {
    return _epubInFlight[path] ??= () async {
      try {
        final stat = File(path).statSync();
        final dir = Directory(
            p.join((await getTemporaryDirectory()).path, 'book_covers'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final key = '${path.hashCode}_${stat.modified.millisecondsSinceEpoch}';
        final out = File(p.join(dir.path, '$key.img'));
        if (out.existsSync()) return out.path;
        final bytes = await compute(epubCoverBytes, path);
        if (bytes == null) return null;
        await out.writeAsBytes(bytes);
        return out.path;
      } catch (_) {
        return null;
      }
    }();
  }

  /// EPUB'un kapak görseli: OPF'te `properties="cover-image"` ya da
  /// `<meta name="cover">`; ikisi de yoksa adında "cover" geçen ilk görsel.
  @visibleForTesting
  static Uint8List? epubCoverBytes(String path) {
    final input = InputFileStream(path);
    try {
      final zip = ZipDecoder().decodeStream(input);
      String text(String name) {
        final f = zip.findFile(name);
        return f == null ? '' : utf8.decode(f.content as List<int>,
            allowMalformed: true);
      }

      bool isImage(String n) =>
          RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false).hasMatch(n);
      final opfPath = RegExp(r'full-path="([^"]+)"')
          .firstMatch(text('META-INF/container.xml'))
          ?.group(1);
      String? href;
      if (opfPath != null) {
        final opf = text(opfPath);
        final items = RegExp(r'<item\b[^>]*>').allMatches(opf).map((m) => m[0]!);
        String? attr(String tag, String name) =>
            RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);
        for (final tag in items) {
          if ((attr(tag, 'properties') ?? '').contains('cover-image')) {
            href = attr(tag, 'href');
            break;
          }
        }
        if (href == null) {
          final meta = RegExp(r'<meta\b[^>]*name="cover"[^>]*>').firstMatch(opf);
          final id = meta == null ? null : attr(meta[0]!, 'content');
          if (id != null) {
            for (final tag in items) {
              if (attr(tag, 'id') == id) href = attr(tag, 'href');
            }
          }
        }
        if (href != null) {
          href = p.posix.normalize(
              p.posix.join(p.posix.dirname(opfPath), Uri.decodeFull(href)));
        }
      }
      var file = href == null ? null : zip.findFile(href);
      file ??= zip.files.cast<ArchiveFile?>().firstWhere(
          (f) => f!.isFile &&
              isImage(f.name) &&
              f.name.toLowerCase().contains('cover'),
          orElse: () => null);
      if (file == null || !isImage(file.name)) return null;
      return Uint8List.fromList(file.content as List<int>);
    } catch (_) {
      return null;
    } finally {
      input.closeSync();
    }
  }

  @visibleForTesting
  static void debugReset() {
    _added.clear();
    _loadFuture = null;
    _epubInFlight.clear();
  }
}
