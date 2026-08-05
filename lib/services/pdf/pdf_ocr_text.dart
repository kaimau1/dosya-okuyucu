import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../ocr_service.dart';
import 'ocr_page_text.dart';

/// Taranmış (metin katmanı olmayan) PDF sayfası için OCR'dan seçilebilir
/// metin üretir: sayfa bitmap'e çizilir → ML Kit sözcük kutuları →
/// [buildOcrPageText] ile sahte `PdfPageText`.
///
/// Seçim katmanı bunu pdfium metniyle birebir aynı arayüzden kullanır;
/// kullanıcı için yazılmış/taranmış farkı yoktur (Chrome'un yaptığı gibi).
///
/// KVKK notu: OCR tamamen cihaz içinde (ML Kit yerel model), tanınan metin
/// yalnız bellekte tutulur; diske sayfa görüntüsünden başka bir şey yazılmaz
/// ve o da iş biter bitmez silinir.
class PdfOcrText {
  PdfOcrText._();

  /// Test kancası: bütün boru hattının (çiz → ML Kit → kur) yerine geçer.
  /// Testler Linux'ta koşar; ML Kit de pdfium bitmap çizimi de orada yok.
  static Future<OcrPageText?> Function(PdfPage page)? debugOcrOverride;

  /// OCR bu platformda çalışır mı? (ML Kit modeli mobil APK ile gelir;
  /// masaüstünde taranmış sayfa seçimi — şimdilik — yok.)
  static bool get isSupported =>
      debugOcrOverride != null ||
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Sayfa başına sonuç önbelleği (null = denendi, sayfada metin yok — yeniden
  /// denemek pil yakar). Anahtar dosya yolu + sayfa numarası: `PdfReload`
  /// belgeyi aynı yoldan tazelediği için önbellek yeniden yüklemeden etkilenmez.
  static final _cache = <String, OcrPageText?>{};
  static final _inFlight = <String, Future<OcrPageText?>>{};
  static const _cacheCap = 24;

  /// Disk önbelleği (2. katman): uygulama kapanıp açılınca taranmış sayfa
  /// YENİDEN OCR'lanmaz — seçim/arama anında hazır olur, pil korunur.
  /// Anahtar belge yolu + mtime + boyut (bkz. [_docStamp]): dosya değişirse
  /// eski girdi kendiliğinden ıskalanır. En çok [_diskCap] sayfa dosyası
  /// tutulur; taşınca en eskiler silinir. Testler için [debugDiskDirOverride].
  static String? debugDiskDirOverride;
  static const _diskCap = 300;
  static Directory? _diskDir;
  static Future<void>? _diskWarmUp;

  static String _key(PdfPage page) =>
      '${page.document.sourceName}#${page.pageNumber}';

  /// Disk dizini — **beklemesiz**. Çözülmemişse arka planda ısındırır ve null
  /// döner (o çağrı diski atlar; OCR ~1 sn sürdüğü için yazma anına dek dizin
  /// hazır olur).
  ///
  /// TUZAK (2026-08-05, HAFIZA §F akrabası): `getApplicationSupportDirectory`
  /// platform kanalıdır; flutter_test'te kanal yanıtı İLERLEMEZ ve kritik
  /// yolda `await` edilirse OCR zinciri sonsuza dek askıda kalır — üç widget
  /// testi tam böyle kırıldı. Kanal bu yüzden ASLA kritik yolda beklenmez.
  static Directory? _dirSync() {
    final override = debugDiskDirOverride;
    if (override != null) {
      return Directory(override)..createSync(recursive: true);
    }
    if (_diskDir == null) {
      _diskWarmUp ??= () async {
        try {
          final base = await getApplicationSupportDirectory();
          _diskDir = Directory(p.join(base.path, 'ocr_sayfa_onbellek'))
            ..createSync(recursive: true);
        } catch (_) {
          // Disk önbelleği olmadan da her şey çalışır.
        }
      }();
    }
    return _diskDir;
  }

  /// Belgenin kimlik damgası: yol + değişme zamanı + boyut. `sourceName`
  /// gerçek bir dosya değilse (bellekten açılmış belge) yalnız ad kalır —
  /// yanlış eşleşme riski sıfır değil ama pdfrx'te belgeler yol tabanlı.
  static String _docStamp(PdfPage page) {
    final name = page.document.sourceName;
    try {
      final st = File(name).statSync();
      return '$name|${st.modified.millisecondsSinceEpoch}|${st.size}';
    } catch (_) {
      return name;
    }
  }

  static String _diskFileName(PdfPage page) =>
      '${fnv1a(_docStamp(page))}_p${page.pageNumber}.json';

  /// Disk girdisi: `hit` false ise girdi yok (OCR koşmalı); true ise sonuç
  /// [text]'tir — null da olabilir ("bu sayfada metin yok" işareti: metinsiz
  /// taranmış sayfa her açılışta yeniden OCR'lanmasın).
  static Future<({bool hit, OcrPageText? text})> _diskRead(
      PdfPage page) async {
    final dir = _dirSync();
    if (dir == null) return (hit: false, text: null);
    try {
      final f = File(p.join(dir.path, _diskFileName(page)));
      if (!f.existsSync()) return (hit: false, text: null);
      final raw = await f.readAsString();
      if (raw == 'yok') return (hit: true, text: null);
      final decoded = decodeOcrPageText(raw);
      if (decoded != null) return (hit: true, text: decoded);
      f.deleteSync(); // bozuk girdi: at, OCR yeniden koşsun
    } catch (_) {}
    return (hit: false, text: null);
  }

  static Future<void> _diskWrite(PdfPage page, OcrPageText? text) async {
    final dir = _dirSync();
    if (dir == null) return;
    try {
      final f = File(p.join(dir.path, _diskFileName(page)));
      await f.writeAsString(text == null ? 'yok' : encodeOcrPageText(text),
          flush: true);
      _pruneDisk(dir);
    } catch (_) {}
  }

  /// Taşan önbelleği buda: en eski değiştirilenler gider. Her yazımda koşar —
  /// birkaç yüz dosyalık dizin listelemek milisaniyelik iş.
  static void _pruneDisk(Directory dir) {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      if (files.length <= _diskCap) return;
      files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - _diskCap)) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Bu sayfanın sonucu önbellekte (bellek ya da disk) hazır mı? OCR arama
  /// bütçesi (bkz. `PdfOcrSearch.maxFreshOcrPages`) yalnız GERÇEKTEN OCR
  /// koşacak sayfaları saysın diye. Disk dizini henüz kurulmadıysa tutucu
  /// davranır (false) — bütçeden düşer ama yanlış "hazır" demez.
  static bool isCached(PdfPage page) {
    if (_cache.containsKey(_key(page))) return true;
    final dir = _dirSync();
    if (dir == null) return false;
    try {
      return File(p.join(dir.path, _diskFileName(page))).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// [page] için OCR metni. Aynı sayfa için eşzamanlı ikinci çağrı ilk işi
  /// bekler; sonuç (boş olsa da) önbelleğe girer.
  static Future<OcrPageText?> forPage(PdfPage page) {
    if (!isSupported) return Future.value(null);
    final key = _key(page);
    if (_cache.containsKey(key)) {
      // LRU tazele: sonda duran en taze olandır.
      final v = _cache.remove(key);
      _cache[key] = v;
      return Future.value(v);
    }
    return _inFlight[key] ??= _run(page, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<OcrPageText?> _run(PdfPage page, String key) async {
    OcrPageText? result;
    try {
      final disk = await _diskRead(page);
      if (disk.hit) {
        _cache[key] = disk.text;
        if (_cache.length > _cacheCap) _cache.remove(_cache.keys.first);
        return disk.text;
      }
      final override = debugOcrOverride;
      if (override != null) {
        result = await override(page);
      } else {
        final rendered = await OcrService.renderPageToPng(page,
            tag: 'sel${page.pageNumber}');
        if (rendered != null) {
          try {
            final lines =
                await OcrService.recognizeImageWordLines(rendered.path);
            result = buildOcrPageText(
              pageNumber: page.pageNumber,
              pageHeight: page.height,
              imageScale: rendered.scale,
              lines: lines,
            );
          } finally {
            try {
              File(rendered.path).deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // OCR başarısızlığı seçimi değil yalnız taranmış-sayfa desteğini düşürür;
      // sessizce "metin yok" say (önbelleğe de öyle yaz — tekrar deneme yok).
    }
    _cache[key] = result;
    if (_cache.length > _cacheCap) _cache.remove(_cache.keys.first);
    await _diskWrite(page, result);
    return result;
  }

  /// Testler arası sızıntı olmasın diye.
  static void debugReset() {
    _cache.clear();
    _inFlight.clear();
    debugOcrOverride = null;
    debugDiskDirOverride = null;
    _diskDir = null;
    _diskWarmUp = null;
  }
}
