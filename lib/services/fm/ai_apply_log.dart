/// **AI önerilerinden yapılanların kaydı** — "ne yapıldı, ne yapılmadı".
///
/// Kullanıcı (2026-11-07): *"eski yapılanlar hâlâ yapılabilir gibi
/// görünüyor, anlaşılmıyor ne yapıldı ne yapılmadı"*. Uygulanan öneri
/// listeden sessizce kayboluyordu; kullanıcı hangi dosyanın adının
/// değiştiğini, nereye taşındığını göremiyordu. Bu kayıt Öneriler
/// sekmesinin "Yapılanlar" bölümünü besler (son [_limit] işlem, diskte).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// Tek bir yapılan değişiklik.
class AiApplyEntry {
  final String from;
  final String to;
  final int atMs;

  const AiApplyEntry({required this.from, required this.to, required this.atMs});

  /// Ad değişti mi (klasör aynı kalıp)?
  bool get renamed => p.basename(from) != p.basename(to);

  /// Klasör değişti mi?
  bool get moved => p.dirname(from) != p.dirname(to);

  Map<String, Object?> toJson() => {'f': from, 't': to, 'a': atMs};

  static AiApplyEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final f = raw['f'], t = raw['t'];
    if (f is! String || t is! String) return null;
    return AiApplyEntry(from: f, to: t, atMs: (raw['a'] as num?)?.toInt() ?? 0);
  }
}

abstract final class AiApplyLog {
  static const _fileName = 'ai_apply_log.json';
  static const _limit = 300;

  /// En yeni başta.
  static final ValueNotifier<List<AiApplyEntry>> entries =
      ValueNotifier<List<AiApplyEntry>>(const []);

  static bool _loaded = false;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await FmEnv.ensureInit();
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return;
      final out = <AiApplyEntry>[];
      for (final item in raw) {
        final entry = AiApplyEntry.fromJson(item);
        if (entry != null) out.add(entry);
      }
      entries.value = out;
    } catch (_) {
      // Okunamayan kayıt boş kayıttır.
    }
  }

  static Future<void> add(String from, String to) async {
    await ensureLoaded();
    final next = [
      AiApplyEntry(
          from: from, to: to, atMs: DateTime.now().millisecondsSinceEpoch),
      ...entries.value,
    ];
    entries.value =
        next.length > _limit ? next.sublist(0, _limit) : List.unmodifiable(next);
    await _save();
  }

  static Future<void> clear() async {
    entries.value = const [];
    await _save();
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      await File(_path).writeAsString(
          jsonEncode([for (final e in entries.value) e.toJson()]));
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTest() {
    _loaded = true;
    entries.value = const [];
  }
}
