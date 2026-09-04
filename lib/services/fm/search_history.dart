import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **Arama geçmişi** — en son yazılan sorgular.
///
/// Niye (2026-09-04 denetimi): arama ekranı her açıldığında boştu ve
/// kullanıcı aynı sorguyu ("bordro 2026", "fatura") her seferinde baştan
/// yazıyordu. Dosya adları uzun ve karışıkken bu, aramanın en yorucu kısmı.
///
/// **Ne kaydedilir:** yalnız kullanıcının "bitirdiği" sorgular — arama
/// düğmesine bastığı ya da sonuçlardan bir dosya açtığı sorgular. Her tuş
/// vuruşunu kaydetmek geçmişi "f", "fa", "fat" gibi ön eklerle doldururdu.
///
/// Kayıt uygulamanın kendi dizininde JSON; dosyaların içine hiçbir şey
/// yazılmaz (etiketlerle aynı desen: `file_tags.dart`).
abstract final class SearchHistory {
  static const _fileName = 'search_history.json';

  /// En çok kaç sorgu saklansın.
  static const maxEntries = 20;

  static final List<String> _queries = [];
  static Future<void>? _loadFuture;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// En yeniden eskiye sorgular.
  static List<String> get queries => List.unmodifiable(_queries);

  /// Diskten okur. `appSupportDir` hazır değilse kilitlemez (bkz.
  /// `OpenHistory.ensureLoaded`).
  static Future<void> ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return;
      _queries
        ..clear()
        ..addAll([
          for (final q in raw)
            if (q is String && q.trim().isNotEmpty) q.trim(),
        ].take(maxEntries));
    } catch (_) {
      // Bozuk dosya: kolaylık kaydı, aramayı engellemesin.
    }
  }

  /// Sorguyu geçmişin başına ekler.
  ///
  /// Aynı sorgu (büyük/küçük harf ayrımı olmadan) zaten varsa yukarı taşınır;
  /// iki kere listelenmez. İki karakterden kısa sorgular alınmaz — arama da
  /// onlarla çalışmıyor.
  static Future<void> record(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return;
    final lower = clean.toLowerCase();
    _queries.removeWhere((q) => q.toLowerCase() == lower);
    _queries.insert(0, clean);
    if (_queries.length > maxEntries) {
      _queries.removeRange(maxEntries, _queries.length);
    }
    await _save();
  }

  /// Tek bir sorguyu siler (çipin çarpısı).
  static Future<void> remove(String query) async {
    final lower = query.trim().toLowerCase();
    final before = _queries.length;
    _queries.removeWhere((q) => q.toLowerCase() == lower);
    if (_queries.length != before) await _save();
  }

  /// Geçmişin tamamını siler.
  static Future<void> clear() async {
    if (_queries.isEmpty) return;
    _queries.clear();
    await _save();
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      await File(_path).writeAsString(jsonEncode(_queries), flush: true);
    } catch (_) {
      // Yazılamadı: geçmiş bu oturumda yine çalışır.
    }
  }

  /// Yalnız test.
  static void debugReset() {
    _queries.clear();
    _loadFuture = null;
  }
}
