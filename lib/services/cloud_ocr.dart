import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n/app_strings.dart';
import '../core/private_zone.dart';
import 'ai_pool.dart';
import 'gemini_decisions.dart';
import 'gemini_service.dart';
import 'ocr_service.dart';
import 'offline_mode.dart';

/// Metin tanıma alfabesi ayarı (Ayarlar → Belgeler → "Metin tanıma dili").
enum OcrScript {
  /// Cihazda Latin; sonuç zayıfsa ve görselde Latin dışı yazı varsa AI.
  auto,

  /// Yalnız cihazda (çevrimdışı, Latin alfabesi).
  latin,

  /// Arapça ve öteki alfabeler: AI ile (internet + anahtar gerekir).
  arabic,
}

/// **AI ile metin tanıma** (2026-11-18, kullanıcı: *"metin tanımada arapça
/// desteği yok"*).
///
/// KÖK: cihaz içi tanıma Google ML Kit ve ML Kit'in Arapça modeli YOK (yalnız
/// Latin, Çince, Devanagari, Japonca, Korece). Tesseract gibi cihaz içi bir
/// motor APK'ya yerel kitaplık + dil verisi ekler (APK bütçesi yalnız düşer,
/// bkz. PLAN §0). Bu yüzden Arapça (ve Farsça, Urduca, Kiril, Yunanca…) Gemini
/// görsel modeliyle tanınır: satır satır metin + 0–1000 kutusu döner, kutular
/// resim pikseline çevrilir → aranabilir PDF ve taranmış sayfada seçim aynı
/// yoldan çalışır.
///
/// **Ne zaman buluta gidilir** ([OcrService]): kullanıcının başlattığı
/// tanımada (`allowCloud`) ve ayar `arabic` ise her zaman; `auto` ise yalnız
/// cihazdaki sonuç zayıfken VE Decisions API (`gemini-decision-1`, ~200 ms,
/// çıktı ücretsiz) "görselde Latin dışı yazı var" deyince. Arka plan içerik
/// dizini hiç buluta gitmez.
abstract final class CloudOcr {
  static const prefKey = 'ocr_script';

  /// Satır içi gönderilebilecek en büyük görsel.
  static const maxBytes = 14 * 1024 * 1024;

  /// Kimlikler (main.dart bağlar; testte boş).
  static AiCredentials Function()? credentials;

  static OcrScript? _cached;

  static Future<OcrScript> script() async {
    final c = _cached;
    if (c != null) return c;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(prefKey);
      return _cached = OcrScript.values.asNameMap()[raw] ?? OcrScript.auto;
    } catch (_) {
      return OcrScript.auto;
    }
  }

  static Future<void> setScript(OcrScript v) async {
    _cached = v;
    try {
      await (await SharedPreferences.getInstance()).setString(prefKey, v.name);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
  }

  static List<String> get _keys =>
      credentials?.call().normalized.keys ?? const [];

  /// Anahtar var, çevrimdışı kip ve gizli kasa kapalı.
  static bool get available =>
      _keys.isNotEmpty && !OfflineMode.enabled && !PrivateZone.active;

  /// Cihazdaki sonuç "zayıf" mı: Arapça bir sayfada Latin modeli ya hiçbir
  /// şey ya da birkaç anlamsız harf döndürür. Saf → birim testli.
  static bool looksWeak(String latinText) {
    final letters = RegExp(r'[A-Za-zÀ-ɏ]').allMatches(latinText).length;
    return letters < 24;
  }

  /// Decisions API: görselde Latin dışı alfabeyle yazı var mı?
  static Future<bool> hasNonLatinScript(String path) async {
    if (PrivateZone.active || PrivateZone.isPrivatePath(path)) return false;
    try {
      final block = await GeminiDecisions.fileBlock(path);
      final r = await GeminiDecisions.ask(
        keys: _keys,
        input: [block],
        questions: const [
          DecisionQuestion.yesNo(
            'non_latin',
            'non_latin',
            'Does this image contain written text in a non-Latin script, such '
                'as Arabic, Persian, Urdu, Hebrew, Cyrillic or Greek?',
          ),
        ],
      );
      return r.answers.isNotEmpty && r.answers.first.isYes;
    } catch (_) {
      return false; // Bilinçli: karar alınamazsa cihazdaki sonuç kalır.
    }
  }

  static String _mime(String path) {
    final m = GeminiDecisions.mediaFor(path);
    return m != null && m.type == 'image' ? m.mime : 'image/png';
  }

  static const _schema = <String, Object?>{
    'type': 'OBJECT',
    'properties': {
      'lines': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'text': {'type': 'STRING'},
            'box': {
              'type': 'ARRAY',
              'items': {'type': 'INTEGER'},
            },
          },
          'required': ['text', 'box'],
        },
      },
    },
    'required': ['lines'],
  };

  static const _prompt =
      'Transcribe ALL text in this image exactly as written, in its original '
      'language and script (Arabic, Persian, Latin, etc.). Do not translate, '
      'summarise or correct anything. Return one entry per visual text line in '
      'reading order. For each line give box = [ymin, xmin, ymax, xmax] '
      'normalised to 0-1000 relative to the image.';

  /// Görseldeki satırlar, resim pikseli koordinatında.
  static Future<List<OcrLine>> lines(String path) async {
    if (PrivateZone.active || PrivateZone.isPrivatePath(path)) {
      throw GeminiException('Gizli kasa dosyaları yapay zekâya gönderilemez.',
          statusCode: -1);
    }
    if (_keys.isEmpty) {
      throw GeminiException(AppStrings.current.t('ocr.cloud_need_key'),
          statusCode: -1);
    }
    final bytes = await File(path).readAsBytes();
    if (bytes.length > maxBytes) {
      throw GeminiException(AppStrings.current.t('qc.too_large'),
          statusCode: -1);
    }
    final size = await _imageSize(bytes);
    final raw = await PooledGemini(credentials!.call()).generateJsonFromImage(
      prompt: _prompt,
      schema: _schema,
      image: bytes,
      mimeType: _mime(path),
    );
    return parse(raw, size.width, size.height);
  }

  static Future<({double width, double height})> _imageSize(
      List<int> bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? desc;
    try {
      buffer =
          await ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(bytes));
      desc = await ui.ImageDescriptor.encoded(buffer);
      return (width: desc.width.toDouble(), height: desc.height.toDouble());
    } catch (_) {
      return (width: 1000.0, height: 1000.0);
    } finally {
      desc?.dispose();
      buffer?.dispose();
    }
  }

  /// Model yanıtı → satırlar (kutu 0–1000 → piksel). Saf → birim testli.
  static List<OcrLine> parse(String raw, double width, double height) {
    final Object? data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    final list = data is Map ? data['lines'] : null;
    if (list is! List) return const [];
    final out = <OcrLine>[];
    for (final item in list) {
      if (item is! Map) continue;
      final text = '${item['text'] ?? ''}'.trim();
      if (text.isEmpty) continue;
      final box = item['box'];
      var rect = ui.Rect.zero;
      if (box is List && box.length == 4 && box.every((v) => v is num)) {
        double v(int i) => ((box[i] as num).toDouble().clamp(0, 1000)) / 1000;
        rect = ui.Rect.fromLTRB(
            v(1) * width, v(0) * height, v(3) * width, v(2) * height);
      }
      out.add(OcrLine(text, rect));
    }
    return out;
  }

  /// Satırı sözcüklere böler; kutu harf sayısıyla orantılı paylaştırılır
  /// (sağdan sola yazıda sağdan başlanır). Yaklaşık — seçim için yeter.
  static List<({String text, ui.Rect box})> words(OcrLine line) {
    final parts = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return const [];
    final total = list.fold<int>(0, (n, w) => n + w.length) + list.length - 1;
    final rtl = RegExp(r'[֐-ࣿ]').hasMatch(line.text);
    final b = line.box;
    final unit = total == 0 ? 0.0 : b.width / total;
    var cursor = 0.0;
    final out = <({String text, ui.Rect box})>[];
    for (final w in list) {
      final start = cursor * unit;
      final end = (cursor + w.length) * unit;
      out.add((
        text: w,
        box: rtl
            ? ui.Rect.fromLTRB(b.right - end, b.top, b.right - start, b.bottom)
            : ui.Rect.fromLTRB(b.left + start, b.top, b.left + end, b.bottom),
      ));
      cursor += w.length + 1;
    }
    return out;
  }
}
