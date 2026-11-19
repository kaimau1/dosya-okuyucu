import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// **Akıllı klasörlerin düzeni** (2026-11-18, kullanıcı: *"akıllı klasörde
/// klasörlerin adını değiştirme, yerini değiştirme, düzen ayarlama olmalı;
/// 2, 3, 4 kolonlu seçenekler olmalı, parmakla zoom in/out ile
/// yapılabilir"*).
///
/// Kategori KİMLİĞİ değişmez (kayıtlar, süzgeç, arama kimlikle çalışır);
/// yalnız görünen ad ([nameOf]), sıra ([order]) ve sütun sayısı ([columns])
/// kullanıcının. Ad boş bırakılırsa çeviri tablosundaki ada dönülür.
abstract final class SmartFolderPrefs {
  static const _kNames = 'sm_folder_names';
  static const _kOrder = 'sm_folder_order';
  static const _kCols = 'sm_folder_cols';
  static const _kRules = 'sm_move_rules';

  static const minColumns = 2;
  static const maxColumns = 4;

  static final Map<String, String> _names = {};
  static final Map<String, String> _rules = {};
  static List<String> _order = const [];
  static int _cols = minColumns;
  static bool _loaded = false;
  static Future<void>? _loading;

  /// Değişince artar (ekranlar dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static int get columns => _cols;
  static List<String> get order => List.unmodifiable(_order);
  static bool get hasCustomNames => _names.isNotEmpty;

  /// Kullanıcının verdiği ad (yoksa null).
  static String? nameOf(String cat) => _names[cat];

  /// **Taşıma kuralı** (B2 dilim 2, PLAN §1.2): kategori → hedef klasör.
  /// Varsayılan YOK (karar 1: dosyalar yerinde); kullanıcı klasör menüsünden
  /// açar, ilk uygulamada onay, her taşıma "Geri al"lı.
  static String? ruleOf(String cat) => _rules[cat];
  static Map<String, String> get rules => Map.unmodifiable(_rules);

  static Future<void> setRule(String cat, String? dir) async {
    if (dir == null || dir.isEmpty) {
      _rules.remove(cat);
    } else {
      _rules[cat] = dir;
    }
    revision.value++;
    await _write((p) => p.setString(_kRules, jsonEncode(_rules)));
  }

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _readMap(p.getString(_kNames), _names);
      _readMap(p.getString(_kRules), _rules);
      _order = p.getStringList(_kOrder) ?? const [];
      _cols = (p.getInt(_kCols) ?? minColumns).clamp(minColumns, maxColumns);
    } catch (_) {
      // Bilinçli: okunamazsa varsayılan düzen (çeviri adları, 2 sütun).
    }
    _loaded = true;
    revision.value++;
  }

  static void _readMap(String? raw, Map<String, String> into) {
    if (raw == null) return;
    final m = jsonDecode(raw);
    if (m is! Map) return;
    for (final e in m.entries) {
      if (e.key is String && e.value is String) {
        into[e.key as String] = e.value as String;
      }
    }
  }

  /// [cats]'ı kullanıcının sırasına dizer; sırada olmayanlar (yeni çıkan
  /// kategoriler) verilen sırayla sona.
  static List<String> arrange(List<String> cats) {
    final set = cats.toSet();
    return [
      for (final c in _order)
        if (set.contains(c)) c,
      for (final c in cats)
        if (!_order.contains(c)) c,
    ];
  }

  static Future<void> setName(String cat, String? name) async {
    final v = name?.trim() ?? '';
    if (v.isEmpty) {
      _names.remove(cat);
    } else {
      _names[cat] = v;
    }
    revision.value++;
    await _write((p) => p.setString(_kNames, jsonEncode(_names)));
  }

  /// Görünen sıra (ekrandaki klasörler). Ekranda olmayan eski kimlikler
  /// sıranın sonunda korunur — klasör boşalıp yeniden dolunca yerini bilir.
  static Future<void> setOrder(List<String> visible) async {
    _order = [
      ...visible,
      for (final c in _order)
        if (!visible.contains(c)) c,
    ];
    revision.value++;
    await _write((p) => p.setStringList(_kOrder, _order));
  }

  static Future<void> setColumns(int n) async {
    final v = n.clamp(minColumns, maxColumns);
    if (v == _cols) return;
    _cols = v;
    revision.value++;
    await _write((p) => p.setInt(_kCols, v));
  }

  /// Adlar ve sıra varsayılana (sütun sayısı kalır).
  static Future<void> reset() async {
    _names.clear();
    _order = const [];
    revision.value++;
    await _write((p) async {
      await p.remove(_kNames);
      await p.remove(_kOrder);
      return true;
    });
  }

  static Future<void> _write(
      Future<bool> Function(SharedPreferences p) f) async {
    try {
      await f(await SharedPreferences.getInstance());
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
  }

  @visibleForTesting
  static void debugReset() {
    _names.clear();
    _rules.clear();
    _order = const [];
    _cols = minColumns;
    _loaded = false;
    _loading = null;
  }
}
