import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device_profile.dart';
import '../../models/fs_entry.dart';
import '../ocr_service.dart';
import '../text_decode.dart';
import 'content_index.dart';
import 'content_search.dart';
import 'doc_text_search.dart';
import 'fm_env.dart';
import 'search_index.dart';

/// İçerik dizininin uygulama içi sahibi (Faz 41 / 3): dosya yeri, aday
/// listesi, metin çıkarma ve arka plan güncellemesi.
///
/// Yalnız arama ekranı "içinde ara" kipine geçince [refresh] çağrılır
/// (tembel); aynı anda tek güncelleme koşar; pil tasarrufunda durur.
abstract final class ContentIndexer {
  static const ocrPrefKey = 'content_index_ocr';

  /// OCR'lı görselin üst boyutu (büyük fotoğraf tanıma için gereksiz yavaş).
  static const ocrMaxBytes = 8 << 20;

  /// Bir güncellemede en çok kaç görsel tanınır (pil/süre tavanı).
  static const ocrPerRun = 200;

  static ContentIndex? _index;
  static Future<int>? _running;

  /// Güncelleme sürüyor mu / dizinde kaç belge var (arayüz için).
  static final ValueNotifier<bool> busy = ValueNotifier(false);

  static ContentIndex get index => _index ??= ContentIndex(
      File(p.join(FmEnv.appSupportDir, 'content_index.jsonl')));

  /// Testler için.
  static set debugIndex(ContentIndex? v) => _index = v;

  static Future<bool> ocrEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(ocrPrefKey) ??
          DeviceProfile.budget.contentIndexOcrDefault;
    } catch (_) {
      return false;
    }
  }

  /// Dizine girecek dosyalar: metin/Office/PDF ve (açıksa) görseller.
  static Future<List<FsEntry>> candidates({required bool ocr}) async {
    final docs = await SearchIndex.query('',
        matchAll: true, includeDirs: false, limit: 200000);
    final out = <FsEntry>[];
    var images = 0;
    for (final e in docs) {
      if (ContentSearch.isSearchable(e.path) &&
          e.sizeBytes <= ContentSearch.maxFileBytes) {
        out.add(e);
      } else if (DocTextSearch.supports(e)) {
        out.add(e);
      } else if (ocr &&
          e.category == FmCategory.image &&
          e.sizeBytes <= ocrMaxBytes &&
          images < ocrPerRun * 10) {
        images++;
        out.add(e);
      }
    }
    return out;
  }

  static Future<String> textOf(FsEntry e) async {
    if (ContentSearch.isSearchable(e.path)) {
      return TextDecode.decode(await File(e.path).readAsBytes());
    }
    if (DocTextSearch.supports(e)) return DocTextSearch.textOf(e);
    if (e.category == FmCategory.image) {
      return OcrService.recognizeImageFile(e.path);
    }
    return '';
  }

  /// Arka planda artımlı güncelle (zaten sürüyorsa onu bekler).
  static Future<int> refresh() => _running ??= () async {
        busy.value = true;
        try {
          final ocr = await ocrEnabled();
          final list = await candidates(ocr: ocr);
          var ocrDone = 0;
          return await index.update(
            list,
            textOf: (e) async {
              if (e.category == FmCategory.image) {
                if (ocrDone >= ocrPerRun) return null; // sonraki tura
                ocrDone++;
              }
              return textOf(e);
            },
            shouldPause: DeviceProfile.powerSave,
          );
        } catch (_) {
          return 0;
        } finally {
          busy.value = false;
          _running = null;
        }
      }();

  /// "Dizini sil" (ayar).
  static Future<void> clear() => index.clear();
}
