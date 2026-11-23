import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as imglib;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml_events.dart';

import '../../models/fs_entry.dart';
import '../../models/video_trim.dart';
import '../csv_codec.dart';
import '../gemini_decisions.dart';
import '../gemini_service.dart';
import '../legacy_text.dart';
import '../office_reader.dart';
import '../office_zip_guard.dart';
import '../text_decode.dart';
import '../udf_reader.dart';
import '../xls_legacy.dart';
import '../xlsx/xlsx_stream.dart';
import 'fm_env.dart';
import 'office_thumbnail.dart';
import 'video_transcode.dart';

/// Akıllı düzende dosyanın modele nasıl gideceği.
enum SmartInputKind {
  /// Görsel ya da PDF: dosyanın kendisi (satır içi blok).
  media,

  /// Word/ODT/RTF/TXT/MD/HTML/EPUB: okunan yazı.
  text,

  /// Excel/CSV/ODS: ilk sayfanın ilk satırları CSV olarak.
  sheet,

  /// PowerPoint/ODP: slayt yazıları.
  slides,

  /// APK/arşiv: içerik OKUNMAZ, yalnız ad · boyut · klasör.
  meta,

  /// Ses kaydı: `audio` bloğu (≤ 14 MB satır içi, üstü Files API).
  audio,

  /// Video: varsayılan yalnız kapak karesi (görsel blok,
  /// [SmartSortInput.videoCoverOnly]); eski yol `video` bloğu, ilk 60 sn.
  video,
}

/// Modele gidecek hazır girdi: blok + bu blokla kullanılabilecek anahtarlar.
/// Files API ile yüklenen dosya yalnız yükleyen anahtarın projesinde
/// görünür → [keys] o tek anahtardır; iş bitince [release] sunucudaki
/// kopyayı siler.
class SmartPrepared {
  final Map<String, Object?> block;
  final List<String> keys;

  /// Files API dosya adı (`files/…`); satır içiyse null.
  final String? remote;

  /// Ek bloklar (sunumda ilk slaytın görüntüsü — yazıya ek).
  final List<Map<String, Object?>> extra;

  const SmartPrepared(this.block, this.keys,
      {this.remote, this.extra = const []});

  /// İsteğin girdi listesi: ana blok + ekler.
  List<Map<String, Object?>> get input => [block, ...extra];

  /// Yüklenen dosyayı sunucudan siler (en iyi çaba, beklenmez).
  void release() {
    final name = remote;
    if (name != null && keys.isNotEmpty) {
      unawaited(GeminiService.deleteFile(keys.first, name));
    }
  }
}

/// **Akıllı düzen 2.0 — her dosya türü, metin kısmı** (PLAN §1.1 madde 2,
/// 2026-11-18). Görsel/PDF dışındaki belgeler Decisions isteğine `text`
/// bloğu olarak girer: yazı **izolatta** çıkarılır (ana iş parçacığı yalnız
/// sonucu alır), en çok [maxTextChars] karakter; tablo en çok [maxSheetRows]
/// satır. APK/arşivin içine bakılmaz, yalnız meta yazısı gider.
///
/// Yeni bağımlılık yok: docx/pptx [OfficeReader], xlsx [XlsxStream] (akışla,
/// hücre tavanlı), .doc/.ppt [LegacyText], .xls [XlsLegacy], CSV [CsvCodec];
/// ODF/EPUB/RTF/HTML için burada küçük, sınırlı okuyucular (zip + XML olay
/// akışı, `archive`/`xml` zaten bağımlılık).
abstract final class SmartSortInput {
  /// Yazı bloğunun en çok karakteri (~1500 girdi belirteci — baş + son korunur).
  static const maxTextChars = 6000;

  /// Tablodan gönderilen en çok satır (boş satırlar sayılmaz).
  static const maxSheetRows = 60;

  /// Tabloda en çok sütun (geniş sayfalar kesilir).
  static const maxSheetCols = 24;

  /// Görsel yeniden boyutlandırma tavanı (uzun kenar px): 1024px yazıyı net
  /// okuturken görsel belirteç ve yükleme boyutunu ~8–15× düşürür.
  static const maxImageDim = 1024;
  static const imageJpegQuality = 78;
  static const imageOptimizeThresholdBytes = 120 * 1024;

  /// Metin katmanlı PDF'lerde yerel metin çıkarımı (sayfa başına ~258 görsel
  /// belirteç yerine kompakt metin bloğu — %70–90 belirteç tasarrufu).
  static const maxPdfTextPages = 6;
  static const minPdfTextChars = 180;

  /// İçeriği okunacak en büyük kaynak dosya (zip/OLE belleğe alınır).
  static const maxExtractBytes = 40 * 1024 * 1024;

  /// Düz yazı dosyalarında okunan baş kısım (metin tavanına fazlasıyla
  /// yeter; HTML'de etiket payı).
  static const _headBytes = 512 * 1024;

  static const _textExts = {
    'docx', 'docm', 'doc', 'dot', 'odt', 'rtf', 'udf', 'txt', 'text', 'md',
    'markdown', 'html', 'htm', 'xhtml', 'epub',
  };
  static const _sheetExts = {'xlsx', 'xlsm', 'xls', 'xlt', 'csv', 'tsv', 'ods'};
  static const _slideExts = {'pptx', 'ppt', 'pot', 'pps', 'odp'};
  static const _apkExts = {'apk', 'apks', 'xapk', 'apkm'};
  static const _archiveExts = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz',
  };

  static String _ext(String path) =>
      p.extension(path).toLowerCase().replaceFirst('.', '');

  /// Uzantıya göre tür; akıllı düzenin bakmadığı tür (kod, yürütülebilir…)
  /// null.
  static SmartInputKind? kindOf(String path) {
    final type = GeminiDecisions.mediaFor(path)?.type;
    if (type == 'image' || type == 'document') return SmartInputKind.media;
    if (type == 'audio') return SmartInputKind.audio;
    if (type == 'video') return SmartInputKind.video;
    final ext = _ext(path);
    if (_textExts.contains(ext)) return SmartInputKind.text;
    if (_sheetExts.contains(ext)) return SmartInputKind.sheet;
    if (_slideExts.contains(ext)) return SmartInputKind.slides;
    if (_apkExts.contains(ext) || _archiveExts.contains(ext)) {
      return SmartInputKind.meta;
    }
    return null;
  }

  /// Files API ile yüklenecek en büyük ses (~100 dakikalık mp3).
  static const maxAudioUploadBytes = 100 * 1024 * 1024;

  /// Files API ile yüklenecek en büyük video. Model yalnız ilk 60 sn'ye
  /// bakar ama dosya bütün yüklenir (veri/kota); kırpma PLAN §1.1 m.5.
  static const maxVideoUploadBytes = 50 * 1024 * 1024;

  /// Kaynak video sınırı (m.5): daha büyüğü yalnız ilk [videoSeconds]
  /// saniyelik kesitiyle gider; kesit yapılamazsa ve dosya
  /// [maxVideoUploadBytes] üstündeyse gönderilmez.
  static const maxVideoSourceBytes = 1024 * 1024 * 1024;

  /// Videoda bakılan bölüm (sn).
  static const videoSeconds = 60;

  /// Boyut sınırı içinde mi (meta için sınır yok — içerik okunmaz)?
  static bool sizeOk(SmartInputKind kind, int bytes) {
    if (bytes <= 0) return false;
    return switch (kind) {
      SmartInputKind.media => bytes <= GeminiDecisions.maxInlineBytes,
      SmartInputKind.meta => true,
      SmartInputKind.audio => bytes <= maxAudioUploadBytes,
      SmartInputKind.video => bytes <= maxVideoSourceBytes,
      _ => bytes <= maxExtractBytes,
    };
  }

  /// Dosyanın Decisions girdi bloğu. Yazı, görsel küçültme ve PDF metin
  /// çıkarımı izolatta yapılır; okunamayan ya da boş çıkan belgede
  /// [GeminiException] (durum -1: tur durmaz, dosya "yapılamadı" sayılır).
  static Future<Map<String, Object?>> blockFor(FsEntry e) async {
    final kind = kindOf(e.path);
    switch (kind) {
      case null:
        throw GeminiException('desteklenmeyen tür', statusCode: -1);
      case SmartInputKind.media:
        final path = e.path;
        final media = GeminiDecisions.mediaFor(path);
        if (media == null) {
          throw GeminiException('desteklenmeyen tür', statusCode: -1);
        }
        return Isolate.run(() => _prepareMediaBlock(path, media.type, media.mime));
      case SmartInputKind.audio:
      case SmartInputKind.video:
        if (e.sizeBytes > GeminiDecisions.maxInlineBytes) {
          throw GeminiException('büyük ses/video yüklenmeli', statusCode: -1);
        }
        final media = GeminiDecisions.mediaFor(e.path)!;
        final src = e.path;
        // base64 (≤ 14 MB → ~19 MB yazı) izolatta; ana iş parçacığı yalnız
        // sonucu alır.
        final data = await Isolate.run(
            () => base64Encode(File(src).readAsBytesSync()));
        return avBlock(media.mime,
            video: kind == SmartInputKind.video, data: data);
      case SmartInputKind.meta:
        return GeminiDecisions.textBlock(metaText(
          name: p.basename(e.path),
          sizeBytes: e.sizeBytes,
          folder: _folderOf(e.path),
          apk: _apkExts.contains(_ext(e.path)),
        ));
      case SmartInputKind.text:
      case SmartInputKind.sheet:
      case SmartInputKind.slides:
        final path = e.path;
        final tmp = Directory.systemTemp.path;
        final body = await Isolate.run(() => extract(path, tempDir: tmp));
        if (body.trim().isEmpty) {
          throw GeminiException('yazısı okunamadı', statusCode: -1);
        }
        return GeminiDecisions.textBlock(_header(kind) + body);
    }
  }

  /// Turda kullanılan giriş: ses/video 14 MB üstüyse **Files API** ile
  /// yüklenir (anahtarlar sırayla; kota/yetki hatasında sıradaki), blokta
  /// yalnız `file_uri` gider. Öteki türler [blockFor] ile, anahtarlar aynen.
  static Future<SmartPrepared> prepare(FsEntry e, List<String> keys) async {
    final kind = kindOf(e.path);
    if (kind == SmartInputKind.video && videoCoverOnly) {
      return _coverPrepared(e, keys);
    }
    final av = kind == SmartInputKind.audio || kind == SmartInputKind.video;
    if (!av || e.sizeBytes <= GeminiDecisions.maxInlineBytes) {
      final block = await blockFor(e);
      // Sunum (m.2 kalanı): dosyanın içindeki hazır ilk slayt resmi
      // (PowerPoint/LibreOffice kaydederken yazar) yazıya ek görsel blok.
      final slide =
          kind == SmartInputKind.slides ? await slideImageBlock(e.path) : null;
      return SmartPrepared(block, keys, extra: [?slide]);
    }
    final video = kind == SmartInputKind.video;
    if (video) {
      // m.5: büyük videonun yalnız ilk dakikası (geçici kesit) gider —
      // çoğu zaman satır içine sığar, yükleme hiç olmaz.
      final clip = await _clip(e.path);
      if (clip != null) {
        try {
          final size = File(clip).lengthSync();
          if (size <= GeminiDecisions.maxInlineBytes) {
            final data = await _b64File(clip);
            return SmartPrepared(
                avBlock('video/mp4', video: true, data: data), keys);
          }
          if (size > maxVideoUploadBytes) {
            throw GeminiException('video kesiti çok büyük', statusCode: -1);
          }
          return await _upload(clip, 'video/mp4', video: true, keys: keys);
        } finally {
          _deleteQuietly(clip);
        }
      }
      if (e.sizeBytes > maxVideoUploadBytes) {
        throw GeminiException('video çok büyük', statusCode: -1);
      }
    }
    final mime = GeminiDecisions.mediaFor(e.path)!.mime;
    return _upload(e.path, mime, video: video, keys: keys);
  }

  /// **Video = yalnız kapak karesi** (2026-11-22, kullanıcı: "videoyu sadece
  /// kapak karesi olarak yapmak gerekiyor" — maliyet doğru hesaplansın).
  /// Video bloğu dakikada ~15–20 bin belirteç; tek JPEG kare bir görselle
  /// aynı (~260). Kare satır içi gider, yükleme/kesit yok; geçici kare
  /// silinir. Kare alınamazsa dosya gönderilmez ("yapılamadı").
  /// false = eski yol (ilk dakika kesiti / Files API) — testler ve ileride
  /// "ayrıntılı video" seçeneği için duruyor.
  static bool videoCoverOnly = true;

  /// Kapak karesinin zamanı (ilk karedeki siyah geçişi atlar) ve genişliği.
  static const coverAtMs = 1500;
  static const coverWidth = 768;

  /// Videonun kapak karesini geçici JPEG olarak çıkarır; olmazsa null.
  static Future<String?> Function(String path) coverFrame = _defaultCover;

  static Future<String?> _defaultCover(String path) async {
    final dir = p.join(Directory.systemTemp.path, 'smart_cover');
    Directory(dir).createSync(recursive: true);
    return await VideoTranscoder.frameAt(path,
            dir: dir, ms: coverAtMs, width: coverWidth) ??
        await VideoTranscoder.frameAt(path,
            dir: dir, ms: 0, width: coverWidth);
  }

  static Future<SmartPrepared> _coverPrepared(
      FsEntry e, List<String> keys) async {
    String? frame;
    try {
      frame = await coverFrame(e.path);
    } catch (_) {
      frame = null;
    }
    if (frame == null) {
      throw GeminiException('video karesi alınamadı', statusCode: -1);
    }
    try {
      final data = await _b64File(frame);
      return SmartPrepared(
          {'type': 'image', 'mime_type': 'image/jpeg', 'data': data}, keys);
    } finally {
      _deleteQuietly(frame);
    }
  }

  /// Files API yüklemesi: anahtarlar sırayla; kota/yetki hatasında
  /// sıradaki, blok yalnız yükleyen anahtarla.
  static Future<SmartPrepared> _upload(String path, String mime,
      {required bool video, required List<String> keys}) async {
    GeminiException? last;
    for (final raw in keys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      try {
        final f = await GeminiService.uploadFile(key, path, mime);
        return SmartPrepared(
            avBlock(mime, video: video, fileUri: f.uri), [key],
            remote: f.name);
      } on GeminiException catch (err) {
        last = err;
        if (!const {401, 403, 429}.contains(err.statusCode)) rethrow;
      }
    }
    throw last ?? GeminiException('API anahtarı yok', statusCode: 401);
  }

  static Future<String> _b64File(String path) =>
      Isolate.run(() => base64Encode(File(path).readAsBytesSync()));

  static void _deleteQuietly(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {
      // Bilinçli: geçici kesit zaten yoksa sonuç değişmez.
    }
  }

  /// Kesitler sırayla (kanal tek iş yürütür; paralel işçi beklesin).
  static Future<void> _clipQueue = Future<void>.value();

  static Future<String?> _clip(String path) {
    final next = _clipQueue.then((_) async {
      try {
        return await clipVideo(path);
      } catch (_) {
        return null;
      }
    });
    _clipQueue = next.then((_) {});
    return next;
  }

  /// Videonun ilk [videoSeconds] saniyesini geçici klasöre keser; kesit
  /// gereksizse (kısa video), kanal meşgulse ya da yapılamazsa null
  /// (testte sahte).
  @visibleForTesting
  static Future<String?> Function(String path) clipVideo = _defaultClip;

  static Future<String?> _defaultClip(String path) async {
    if (VideoTranscoder.busy) return null;
    final probe = await VideoTranscoder.probe(path);
    if (probe == null || probe.durationMs <= (videoSeconds + 5) * 1000) {
      return null;
    }
    final target = p.join(Directory.systemTemp.path,
        'smart_clip_${DateTime.now().microsecondsSinceEpoch}.mp4');
    return VideoTranscoder.clipTo(
        path, target, const TrimRange(0, videoSeconds * 1000));
  }

  /// İlk slayt görüntüsünün en büyük boyutu (gömülü önizleme çoğu zaman
  /// 20–200 KB; üstü belirteç yemesin diye gönderilmez).
  static const maxSlideImageBytes = 1024 * 1024;

  /// Sunumun gömülü ilk slayt resmi → görsel blok (izolatta: zip okuma +
  /// base64). Yoksa, desteklenmiyorsa ya da büyükse null.
  static Future<Map<String, Object?>?> slideImageBlock(String path) =>
      Isolate.run(() => slideImage(path));

  /// [slideImageBlock]'un eşzamanlı çekirdeği (izolat içinde çalışır).
  static Map<String, Object?>? slideImage(String path) {
    if (!OfficeThumbnail.supports(_ext(path))) return null;
    final bytes = OfficeThumbnail.readEmbedded(path);
    if (bytes == null ||
        bytes.length < 4 ||
        bytes.length > maxSlideImageBytes) {
      return null;
    }
    final mime = bytes[0] == 0x89 && bytes[1] == 0x50
        ? 'image/png'
        : (bytes[0] == 0xFF && bytes[1] == 0xD8 ? 'image/jpeg' : null);
    if (mime == null) return null;
    return {'type': 'image', 'mime_type': mime, 'data': base64Encode(bytes)};
  }

  /// Saf: ses/video bloğu. Satır içi [data] (base64) ya da Files API
  /// [fileUri]; videoda düşük çözünürlük + yalnız ilk [videoSeconds] sn.
  static Map<String, Object?> avBlock(String mime,
      {required bool video, String? data, String? fileUri}) {
    assert((data == null) != (fileUri == null));
    return {
      'type': video ? 'video' : 'audio',
      'mime_type': mime,
      'data': ?data,
      if (fileUri != null) 'file_data': {'file_uri': fileUri, 'mime_type': mime},
      if (video) ...{
        'media_resolution': 'low',
        'video_metadata': {
          'start_offset': '0s',
          'end_offset': '${videoSeconds}s',
        },
      },
    };
  }

  static String _header(SmartInputKind? kind) => switch (kind) {
        SmartInputKind.sheet =>
          'First rows of the first sheet of a spreadsheet, as CSV '
              '(may be truncated):\n',
        SmartInputKind.slides =>
          'Text of the slides of a presentation (may be truncated):\n',
        _ => 'Text extracted from a document (may be truncated):\n',
      };

  /// Kaynak klasör: depolama köküne göre göreli (kişisel tam yol gitmez).
  static String _folderOf(String path) {
    final dir = p.dirname(path);
    final root = FmEnv.primaryRoot;
    if (root.isNotEmpty && dir == root) return '';
    if (root.isNotEmpty && p.isWithin(root, dir)) {
      return p.relative(dir, from: root);
    }
    return p.basename(dir);
  }

  // ── Saf yardımcılar (test edilir) ──────────────────────────────────────

  /// Görsel/PDF bloğunu izolatta hazırlar:
  /// * PDF'de yeterli gömülü metin (>= [minPdfTextChars]) varsa ham PDF yerine
  ///   kompakt metin bloğu gönderilir (çok sayfalı PDF'lerde %70–90 tasarruf).
  /// * Görsel büyükse uzun kenar <= [maxImageDim] px JPEG olarak sıkıştırılır.
  static Map<String, Object?> _prepareMediaBlock(
      String path, String type, String mime) {
    final raw = File(path).readAsBytesSync();
    if (raw.isEmpty) {
      throw GeminiException('Dosya boş.', statusCode: -1);
    }
    if (type == 'document' && mime == 'application/pdf') {
      final text = extractPdfText(raw);
      if (text.isNotEmpty) {
        return GeminiDecisions.textBlock(_header(SmartInputKind.text) + text);
      }
      return {
        'type': 'document',
        'mime_type': mime,
        'data': base64Encode(raw),
      };
    }
    if (type == 'image') {
      final opt = optimizeImageBytes(raw, mime: mime);
      return {
        'type': 'image',
        'mime_type': opt.mime,
        'data': base64Encode(opt.bytes),
      };
    }
    return {
      'type': type,
      'mime_type': mime,
      'data': base64Encode(raw),
    };
  }

  /// Görseli model için optimize eder: uzun kenarı [maxDim] px üstündeyse ya da
  /// [imageOptimizeThresholdBytes] üstündeyse yeniden boyutlandırıp JPEG
  /// ([quality]) kodlar. Küçük ve zaten sınırı aşmayan görsellerde sıfır CPU
  /// için ham bayt döner; çözülemezse ham bayta düşer.
  static ({Uint8List bytes, String mime}) optimizeImageBytes(
    Uint8List raw, {
    required String mime,
    int maxDim = maxImageDim,
    int quality = imageJpegQuality,
  }) {
    try {
      final decoder = imglib.findDecoderForData(raw);
      if (decoder == null) return (bytes: raw, mime: mime);
      final info = decoder.startDecode(raw);
      if (info == null || info.width <= 0 || info.height <= 0) {
        return (bytes: raw, mime: mime);
      }
      final needsResize = info.width > maxDim || info.height > maxDim;
      if (!needsResize && raw.length <= imageOptimizeThresholdBytes) {
        return (bytes: raw, mime: mime);
      }
      final decoded = decoder.decode(raw);
      if (decoded == null) return (bytes: raw, mime: mime);
      final target = needsResize
          ? (decoded.width >= decoded.height
              ? imglib.copyResize(decoded,
                  width: maxDim, interpolation: imglib.Interpolation.linear)
              : imglib.copyResize(decoded,
                  height: maxDim, interpolation: imglib.Interpolation.linear))
          : decoded;
      final jpg = Uint8List.fromList(imglib.encodeJpg(target, quality: quality));
      if (needsResize || jpg.length < raw.length) {
        return (bytes: jpg, mime: 'image/jpeg');
      }
      return (bytes: raw, mime: mime);
    } catch (_) {
      return (bytes: raw, mime: mime);
    }
  }

  /// Metin katmanlı PDF'ten ilk [maxPages] sayfa (+ varsa son sayfa: toplam
  /// tutar, imza, son ödeme tarihi için) metnini çıkarır. Yeterli harf/rakam
  /// ([minPdfTextChars]) yoksa boş döner → çağıran taranmış PDF olarak ham
  /// `document` bloğuna düşer.
  static String extractPdfText(
    Uint8List bytes, {
    int maxPages = maxPdfTextPages,
  }) {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
      final total = doc.pages.count;
      if (total <= 0) return '';
      final extractor = PdfTextExtractor(doc);
      final buf = StringBuffer();
      final headCount = total < maxPages ? total : maxPages;
      for (var i = 0; i < headCount; i++) {
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
        if (pageText.isNotEmpty) {
          if (buf.isNotEmpty) buf.write('\n\n');
          buf.write(pageText);
        }
        if (buf.length > maxTextChars * 2) break;
      }
      if (total > headCount) {
        final lastText = extractor
            .extractText(startPageIndex: total - 1, endPageIndex: total - 1)
            .trim();
        if (lastText.isNotEmpty) {
          if (buf.isNotEmpty) buf.write('\n\n');
          buf.write(lastText);
        }
      }
      final cleaned = clip(buf.toString());
      if (_alnumCount(cleaned) < minPdfTextChars) return '';
      return cleaned;
    } catch (_) {
      return '';
    } finally {
      doc?.dispose();
    }
  }

  static int _alnumCount(String text) {
    var count = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      final isAscii = (c >= 0x30 && c <= 0x39) ||
          (c >= 0x41 && c <= 0x5A) ||
          (c >= 0x61 && c <= 0x7A);
      if (isAscii || c >= 0x00C0) count++;
    }
    return count;
  }

  static final RegExp _reTrailWsNl = RegExp(r'[ \t]+\n');
  static final RegExp _reLeadNlWs = RegExp(r'\n[ \t]+');
  static final RegExp _reManyNl = RegExp(r'\n{3,}');
  static final RegExp _reMultiWs = RegExp(r'[ \t]{2,}');

  /// Yazıyı sadeleştirip (satır sonu, fazla boş satır/boşluk) en çok [max]
  /// karaktere keser; vekil çifti ortadan bölünmez. Uzun belgelerde ([max] >=
  /// 400) baş (%78) + son (%22) korunur: fatura toplamı, son ödeme tarihi ve
  /// imza alt kısımda olsa da kaybolmaz.
  static String clip(String text, [int max = maxTextChars]) {
    var s = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(_reTrailWsNl, '\n')
        .replaceAll(_reLeadNlWs, '\n')
        .replaceAll(_reManyNl, '\n\n')
        .replaceAll(_reMultiWs, ' ')
        .trim();
    if (s.length <= max) return s;
    if (max >= 400) {
      const sep = '\n…\n';
      final avail = max - sep.length;
      var headEnd = (avail * 0.78).floor();
      var tailLen = avail - headEnd;
      if (headEnd > 0) {
        final last = s.codeUnitAt(headEnd - 1);
        if (last >= 0xD800 && last <= 0xDBFF) headEnd--;
      }
      var tailStart = s.length - tailLen;
      if (tailStart < s.length) {
        final first = s.codeUnitAt(tailStart);
        if (first >= 0xDC00 && first <= 0xDFFF) tailStart++;
      }
      final head = s.substring(0, headEnd).trimRight();
      final tail = s.substring(tailStart).trimLeft();
      return '$head$sep$tail';
    }
    var end = max;
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    s = s.substring(0, end);
    return s.trimRight();
  }

  /// Satırları CSV'ye çevirir: tamamen boş satırlar atlanır, sondaki boş
  /// hücreler kırpılır, en çok [maxRows] satır × [maxSheetCols] sütun;
  /// sonuç da [maxTextChars] ile sınırlı.
  static String rowsToCsv(Iterable<List<String>> rows,
      {int maxRows = maxSheetRows}) {
    final out = <List<String>>[];
    for (final row in rows) {
      if (out.length >= maxRows) break;
      var cells = [for (final c in row.take(maxSheetCols)) c.trim()];
      var n = cells.length;
      while (n > 0 && cells[n - 1].isEmpty) {
        n--;
      }
      if (n == 0) continue;
      if (n < cells.length) cells = cells.sublist(0, n);
      out.add(cells);
    }
    return clip(CsvCodec.encode(out).replaceAll('\r\n', '\n'));
  }

  /// APK/arşiv için yazı (içerik okunmaz): ad, tür, boyut, kaynak klasör.
  static String metaText({
    required String name,
    required int sizeBytes,
    required String folder,
    required bool apk,
  }) {
    final kind = apk
        ? 'Android app installer package (APK)'
        : 'compressed archive (${_ext(name).isEmpty ? 'unknown' : _ext(name)})';
    return 'Only the metadata of this file is available; its content was not '
        'read. Judge by its name, type and folder.\n'
        'File name: $name\n'
        'Type: $kind\n'
        'Size: ${sizeText(sizeBytes)}\n'
        'Folder: ${folder.isEmpty ? '(root)' : folder}';
  }

  /// İnsan okunur boyut (İngilizce, model için).
  static String sizeText(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var v = bytes / 1024;
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${units[i]}';
  }

  // ── Çıkarma (izolatta koşar) ───────────────────────────────────────────

  /// Dosyadan model yazısı (başlıksız, kesilmiş). Okunamazsa boş.
  static Future<String> extract(String path, {required String tempDir}) async {
    final ext = _ext(path);
    try {
      switch (ext) {
        case 'xlsx' || 'xlsm':
          final r = await XlsxStream.read(path,
              tempDir: tempDir,
              maxCells: maxSheetRows * maxSheetCols,
              maxSharedChars: 4 << 20);
          if (r.sheets.isEmpty) return '';
          final s = r.sheets.first;
          final keys = s.cells.keys.toList()..sort();
          final cols = (s.maxCol + 1).clamp(0, maxSheetCols);
          return rowsToCsv(keys.map((k) {
            final row = s.cells[k]!;
            return [for (var c = 0; c < cols; c++) row[c] ?? ''];
          }));
        case 'txt' || 'text' || 'md' || 'markdown':
          return clip(TextDecode.decode(_head(path)));
        case 'html' || 'htm' || 'xhtml':
          return htmlText(TextDecode.decode(_head(path)));
        case 'rtf':
          return rtfText(latin1.decode(_head(path)));
        case 'csv' || 'tsv':
          final head = _head(path, 1024 * 1024);
          final whole = head.length >= File(path).lengthSync();
          final rows = CsvCodec.parse(TextDecode.decode(head),
              delimiter: ext == 'tsv' ? '\t' : null);
          // Yarıda kesilen son satır atılır.
          return rowsToCsv(
              whole ? rows : rows.take(rows.isEmpty ? 0 : rows.length - 1));
      }
      return fromBytes(File(path).readAsBytesSync(), ext);
    } catch (_) {
      return '';
    }
  }

  /// Bellekteki dosya baytlarından yazı (zip/OLE biçimleri).
  static String fromBytes(Uint8List bytes, String ext) {
    try {
      return switch (ext) {
        'docx' || 'docm' => clip(OfficeReader.extractDocxText(bytes)),
        'pptx' => clip(OfficeReader.extractPptxText(bytes)),
        'doc' || 'dot' => clip(LegacyText.fromDoc(bytes) ?? ''),
        'ppt' || 'pot' || 'pps' => clip(LegacyText.fromPpt(bytes) ?? ''),
        'xls' || 'xlt' => () {
            final x = XlsLegacy.tryParse(bytes);
            if (x == null || x.sheets.isEmpty) return '';
            return rowsToCsv(x.sheets.first.rows);
          }(),
        'odt' => odfText(bytes),
        'udf' => clip(UdfReader.plainText(bytes)),
        'odp' => odfText(bytes, slides: true),
        'ods' => odsCsv(bytes),
        'epub' => epubText(bytes),
        'txt' || 'md' || 'markdown' || 'text' =>
          clip(TextDecode.decode(_cutText(bytes, _headBytes))),
        'html' || 'htm' || 'xhtml' =>
          htmlText(TextDecode.decode(_cutText(bytes, _headBytes))),
        'rtf' => rtfText(latin1.decode(bytes.length > _headBytes
            ? bytes.sublist(0, _headBytes)
            : bytes)),
        'csv' => rowsToCsv(CsvCodec.parse(TextDecode.decode(bytes))),
        'tsv' =>
          rowsToCsv(CsvCodec.parse(TextDecode.decode(bytes), delimiter: '\t')),
        _ => '',
      };
    } catch (_) {
      return '';
    }
  }

  /// Dosyanın ilk [max] baytı (UTF-8/UTF-16 karakteri ortadan bölünmez).
  static Uint8List _head(String path, [int max = _headBytes]) {
    final raf = File(path).openSync();
    try {
      final more = raf.lengthSync() > max;
      return _cutText(raf.readSync(max), max, truncated: more);
    } finally {
      raf.closeSync();
    }
  }

  /// [bytes]'ı en çok [max] bayta keser; UTF-16 (BOM'lu) çift uzunlukta,
  /// UTF-8'de çok baytlı karakterin başında bırakılır (yoksa katı UTF-8
  /// çözümü düşer ve Türkçe metin cp1254 diye bozulurdu).
  static Uint8List _cutText(Uint8List bytes, int max,
      {bool truncated = false}) {
    final b = bytes.length > max ? Uint8List.sublistView(bytes, 0, max) : bytes;
    final utf16 = b.length >= 2 &&
        ((b[0] == 0xFF && b[1] == 0xFE) || (b[0] == 0xFE && b[1] == 0xFF));
    if (utf16) {
      return b.length.isOdd ? Uint8List.sublistView(b, 0, b.length - 1) : b;
    }
    if (!truncated && bytes.length <= max) return b;
    var end = b.length;
    var back = 0;
    while (end > 0 && back < 4 && (b[end - 1] & 0xC0) == 0x80) {
      end--;
      back++;
    }
    if (end > 0 && b[end - 1] >= 0xC0) end--; // yarım kalan baş bayt
    return Uint8List.sublistView(b, 0, end);
  }

  // ── HTML / RTF ─────────────────────────────────────────────────────────

  static final _reDrop = RegExp(
      r'<(script|style|head|svg|noscript)\b[^>]*>.*?</\1\s*>|<!--.*?-->',
      caseSensitive: false,
      dotAll: true);
  static final _reBreak = RegExp(
      r'<(br|/p|/div|/li|/tr|/h[1-6]|/title|/blockquote|/section|/article)\b[^>]*>',
      caseSensitive: false);
  static final _reTag = RegExp(r'<[^>]*>', dotAll: true);
  static final _reEntity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');
  static const _entities = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
    'ndash': '–', 'mdash': '—', 'hellip': '…', 'laquo': '«', 'raquo': '»',
    'rsquo': '’', 'lsquo': '‘', 'rdquo': '”', 'ldquo': '“', 'euro': '€',
  };

  /// HTML → düz yazı (betik/stil atılır, blok sonları satır olur).
  static String htmlText(String html, [int max = maxTextChars]) {
    final s = html
        .replaceAll(_reDrop, ' ')
        .replaceAll(_reBreak, '\n')
        .replaceAll(_reTag, ' ')
        .replaceAllMapped(_reEntity, (m) {
      final v = m[1]!;
      if (v.startsWith('#')) {
        final code = v[1] == 'x' || v[1] == 'X'
            ? int.tryParse(v.substring(2), radix: 16)
            : int.tryParse(v.substring(1));
        if (code == null || code <= 0 || code > 0x10FFFF) return ' ';
        return String.fromCharCode(code);
      }
      return _entities[v.toLowerCase()] ?? m[0]!;
    });
    return clip(s, max);
  }

  /// Atlanan RTF hedef grupları (yazı değil, tablo/üst veri).
  static const _rtfSkip = {
    'fonttbl', 'colortbl', 'stylesheet', 'info', 'pict', 'object',
    'themedata', 'colorschememapping', 'datastore', 'latentstyles',
    'listtable', 'listoverridetable', 'rsidtbl', 'generator', 'xmlnstbl',
    'mmathPr', 'header', 'footer', 'headerl', 'headerr', 'footerl',
    'footerr', 'fldinst', 'filetbl', 'revtbl', 'userprops',
  };

  /// RTF → düz yazı (en iyi çaba): `\par`/`\line` satır, `\'hh` cp1254,
  /// `\uN` Unicode; yazı taşımayan hedef grupları atlanır.
  static String rtfText(String rtf, [int max = maxTextChars]) {
    final out = StringBuffer();
    final pending = <int>[]; // \'hh baytları (cp1254'e toplu çözülür)
    void flush() {
      if (pending.isEmpty) return;
      out.write(TextDecode.decodeCp1254(pending));
      pending.clear();
    }

    // Grup yığını: o grup atlanıyor mu.
    final skip = <bool>[false];
    var uc = 1; // \uN sonrası atlanacak yedek karakter sayısı
    var skipChars = 0;
    var i = 0;
    final n = rtf.length;
    while (i < n && out.length < max * 2) {
      final ch = rtf[i];
      final skipping = skip.last;
      if (ch == '{') {
        flush();
        skip.add(skipping);
        i++;
        if (i + 1 < n && rtf[i] == '\\' && rtf[i + 1] == '*') skip.last = true;
        continue;
      }
      if (ch == '}') {
        flush();
        if (skip.length > 1) skip.removeLast();
        i++;
        continue;
      }
      if (ch == '\\') {
        if (i + 1 >= n) break;
        final next = rtf[i + 1];
        if (next == "'") {
          final hex = i + 4 <= n ? rtf.substring(i + 2, i + 4) : '';
          final b = int.tryParse(hex, radix: 16);
          i += 4;
          if (skipChars > 0) {
            skipChars--;
          } else if (!skipping && b != null) {
            pending.add(b);
          }
          continue;
        }
        if (next == '\\' || next == '{' || next == '}') {
          flush();
          if (!skipping) out.write(next);
          i += 2;
          continue;
        }
        if (next == '~') {
          flush();
          if (!skipping) out.write(' ');
          i += 2;
          continue;
        }
        // Denetim sözcüğü: \harfler[-]sayı? boşluk?
        var j = i + 1;
        while (j < n && _isAsciiLetter(rtf.codeUnitAt(j))) {
          j++;
        }
        final word = rtf.substring(i + 1, j);
        var k = j;
        if (k < n && rtf[k] == '-') k++;
        while (k < n && _isDigit(rtf.codeUnitAt(k))) {
          k++;
        }
        final arg = int.tryParse(rtf.substring(j, k));
        if (k < n && rtf[k] == ' ') k++;
        i = word.isEmpty ? i + 2 : k;
        flush();
        if (_rtfSkip.contains(word)) {
          skip.last = true;
          continue;
        }
        if (skipping) continue;
        switch (word) {
          case 'par' || 'line' || 'sect' || 'page' || 'row':
            out.write('\n');
          case 'tab' || 'cell':
            out.write('\t');
          case 'uc':
            uc = arg ?? 1;
          case 'u':
            if (arg != null) {
              out.writeCharCode(arg < 0 ? arg + 65536 : arg);
              skipChars = uc;
            }
        }
        continue;
      }
      if (ch == '\r' || ch == '\n') {
        i++;
        continue;
      }
      flush();
      if (skipChars > 0) {
        skipChars--;
      } else if (!skipping) {
        out.write(ch);
      }
      i++;
    }
    flush();
    return clip(out.toString(), max);
  }

  static bool _isAsciiLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  // ── ODF (odt/odp/ods) ──────────────────────────────────────────────────

  /// `content.xml`'den okunan en çok bayt (büyük belge belleği şişirmesin;
  /// olay akışı yarım kalan XML'de durur, toplanan yazı korunur).
  static const _odfXmlBytes = 8 * 1024 * 1024;

  static String? _zipText(Archive zip, String name, [int max = _odfXmlBytes]) {
    final f = zip.findFile(name);
    if (f == null) return null;
    final raw = f.content as List<int>;
    return utf8.decode(raw.length > max ? raw.sublist(0, max) : raw,
        allowMalformed: true);
  }

  static String _local(String name) {
    final i = name.indexOf(':');
    return i < 0 ? name : name.substring(i + 1);
  }

  static String? _attr(XmlStartElementEvent e, String local) {
    for (final a in e.attributes) {
      if (_local(a.name) == local) return a.value;
    }
    return null;
  }

  /// ODT/ODP yazısı: paragraf ve başlıklar; [slides]'ta her `draw:page`
  /// "— Slayt n —" başlığıyla (pptx okuyucusuyla aynı biçim).
  static String odfText(Uint8List bytes,
      {bool slides = false, int max = maxTextChars}) {
    final xml = _zipText(OfficeZipGuard.decode(bytes), 'content.xml');
    if (xml == null) return '';
    final out = StringBuffer();
    StringBuffer? para;
    var depth = 0;
    var page = 0;
    try {
      for (final e in parseEvents(xml)) {
        if (out.length > max) break;
        if (e is XmlStartElementEvent) {
          final n = e.name;
          if (n == 'text:p' || n == 'text:h') {
            if (!e.isSelfClosing) {
              if (depth == 0) para = StringBuffer();
              depth++;
            } else if (depth == 0) {
              out.writeln();
            }
          } else if (slides && n == 'draw:page') {
            page++;
            if (out.isNotEmpty) out.writeln();
            out.writeln('— Slayt $page —');
          } else if (para != null) {
            _inline(e, para);
          }
        } else if (e is XmlEndElementEvent) {
          final n = e.name;
          if ((n == 'text:p' || n == 'text:h') && depth > 0) {
            depth--;
            if (depth == 0 && para != null) {
              out.writeln(para.toString());
              para = null;
            }
          }
        } else if (e is XmlTextEvent) {
          para?.write(e.value);
        } else if (e is XmlCDATAEvent) {
          para?.write(e.value);
        }
      }
    } catch (_) {
      // Bilinçli: kesilmiş/bozuk XML'de o ana dek toplanan yazı yeter.
    }
    if (para != null) out.writeln(para.toString());
    return clip(out.toString(), max);
  }

  /// Satır içi ODF öğeleri: boşluk, sekme, satır sonu.
  static void _inline(XmlStartElementEvent e, StringBuffer sb) {
    switch (e.name) {
      case 'text:s':
        final c = int.tryParse(_attr(e, 'c') ?? '') ?? 1;
        sb.write(' ' * c.clamp(1, 8));
      case 'text:tab':
        sb.write('\t');
      case 'text:line-break':
        sb.write('\n');
    }
  }

  /// ODS ilk sayfası → CSV (en çok [maxSheetRows] dolu satır). Tekrar
  /// öznitelikleri (`number-*-repeated`) tavanlı açılır.
  static String odsCsv(Uint8List bytes, {int maxRows = maxSheetRows}) {
    final xml = _zipText(OfficeZipGuard.decode(bytes), 'content.xml');
    if (xml == null) return '';
    final rows = <List<String>>[];
    List<String>? row;
    var rowRep = 1;
    StringBuffer? cell;
    var cellRep = 1;
    var inTable = false;
    var paras = 0;
    try {
      for (final e in parseEvents(xml)) {
        if (rows.length >= maxRows) break;
        if (e is XmlStartElementEvent) {
          switch (e.name) {
            case 'table:table':
              if (inTable) break;
              inTable = true;
            case 'table:table-row':
              if (!inTable) break;
              rowRep = (int.tryParse(_attr(e, 'number-rows-repeated') ?? '') ??
                      1)
                  .clamp(1, maxRows);
              row = e.isSelfClosing ? null : <String>[];
            case 'table:table-cell' || 'table:covered-table-cell':
              if (row == null) break;
              cellRep =
                  (int.tryParse(_attr(e, 'number-columns-repeated') ?? '') ?? 1)
                      .clamp(1, maxSheetCols);
              if (e.isSelfClosing) {
                _addCells(row, '', cellRep);
              } else {
                cell = StringBuffer();
                paras = 0;
              }
            case 'text:p' || 'text:h':
              if (cell != null && paras++ > 0) cell.write('\n');
            default:
              if (cell != null) _inline(e, cell);
          }
        } else if (e is XmlEndElementEvent) {
          switch (e.name) {
            case 'table:table':
              inTable = false;
              // Yalnız ilk (dolu) sayfa.
              if (rows.isNotEmpty) return rowsToCsv(rows, maxRows: maxRows);
            case 'table:table-cell' || 'table:covered-table-cell':
              if (row != null && cell != null) {
                _addCells(row, cell.toString(), cellRep);
              }
              cell = null;
            case 'table:table-row':
              final r = row;
              row = null;
              if (r == null || r.every((c) => c.trim().isEmpty)) break;
              for (var k = 0; k < rowRep && rows.length < maxRows; k++) {
                rows.add(r);
              }
          }
        } else if (e is XmlTextEvent) {
          cell?.write(e.value);
        }
      }
    } catch (_) {
      // Bilinçli: kesilmiş XML'de toplanan satırlar yeter.
    }
    return rowsToCsv(rows, maxRows: maxRows);
  }

  static void _addCells(List<String> row, String v, int rep) {
    for (var k = 0; k < rep && row.length < maxSheetCols; k++) {
      row.add(v);
    }
  }

  // ── EPUB ───────────────────────────────────────────────────────────────

  /// EPUB → okuma sırasıyla (OPF `spine`) bölüm yazıları; OPF yoksa
  /// (x)html dosyaları ada göre.
  static String epubText(Uint8List bytes, [int max = maxTextChars]) {
    final zip = OfficeZipGuard.decode(bytes);
    final order = <String>[];
    final opfPath = RegExp(r'full-path="([^"]+)"')
        .firstMatch(_zipText(zip, 'META-INF/container.xml') ?? '')
        ?.group(1);
    if (opfPath != null) {
      final opf = _zipText(zip, opfPath) ?? '';
      String? attr(String tag, String name) =>
          RegExp('\\b$name="([^"]*)"').firstMatch(tag)?.group(1);
      final hrefs = <String, String>{};
      for (final m in RegExp(r'<(?:\w+:)?item\b[^>]*>').allMatches(opf)) {
        final id = attr(m[0]!, 'id');
        final href = attr(m[0]!, 'href');
        if (id != null && href != null) hrefs[id] = href;
      }
      final base = p.posix.dirname(opfPath);
      for (final m in RegExp(r'<(?:\w+:)?itemref\b[^>]*>').allMatches(opf)) {
        final href = hrefs[attr(m[0]!, 'idref') ?? ''];
        if (href == null) continue;
        order.add(p.posix.normalize(base == '.'
            ? Uri.decodeFull(href)
            : p.posix.join(base, Uri.decodeFull(href))));
      }
    }
    if (order.isEmpty) {
      order.addAll([
        for (final f in zip.files)
          if (f.isFile && RegExp(r'\.x?html?$').hasMatch(f.name.toLowerCase()))
            f.name
      ]..sort());
    }
    final out = StringBuffer();
    for (final name in order) {
      if (out.length >= max) break;
      final html = _zipText(zip, name, 2 * 1024 * 1024);
      if (html == null) continue;
      final t = htmlText(html, max);
      if (t.isEmpty) continue;
      out
        ..writeln(t)
        ..writeln();
    }
    return clip(out.toString(), max);
  }
}
