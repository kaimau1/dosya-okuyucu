import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'fm/fm_env.dart';
import 'fm/tracked_task.dart';

/// Kaydedilmiş bir AI özeti.
class AiSummaryRecord {
  /// Özetin anahtarı: dosya yolu ya da (dosyasız metin akışında) `flow:<ad>`.
  final String key;
  final String title;
  final String summary;
  final int createdAtMs;

  /// Kaynak dosyanın özet anındaki boyu/değişme zamanı — dosya sonradan
  /// değiştiyse özet BAYAT sayılır (eski içeriğin özetini yeni dosyanınki
  /// diye göstermek yanlış olurdu). Dosyasız akışta 0.
  final int sourceSize;
  final int sourceModifiedMs;

  /// Girdi kırpıldı mı (uzun belgede yalnız başı özetlendi).
  final bool truncated;

  const AiSummaryRecord({
    required this.key,
    required this.title,
    required this.summary,
    required this.createdAtMs,
    this.sourceSize = 0,
    this.sourceModifiedMs = 0,
    this.truncated = false,
  });

  Map<String, Object?> toJson() => {
        'key': key,
        'title': title,
        'summary': summary,
        'createdAtMs': createdAtMs,
        'sourceSize': sourceSize,
        'sourceModifiedMs': sourceModifiedMs,
        'truncated': truncated,
      };

  static AiSummaryRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final summary = raw['summary'];
    if (key is! String || summary is! String || summary.isEmpty) return null;
    return AiSummaryRecord(
      key: key,
      title: raw['title'] as String? ?? '',
      summary: summary,
      createdAtMs: (raw['createdAtMs'] as num?)?.toInt() ?? 0,
      sourceSize: (raw['sourceSize'] as num?)?.toInt() ?? 0,
      sourceModifiedMs: (raw['sourceModifiedMs'] as num?)?.toInt() ?? 0,
      truncated: raw['truncated'] == true,
    );
  }
}

/// **AI özetlerinin diskteki kaydı + süren özet işleri** (2026-10-23).
///
/// Kullanıcı: *"ai özet hazırlanıyor ama açamıyorum, aynı dosyada tekrar
/// basınca yenisini yapmaya başlıyor"*. Kök neden: özet yalnız onu başlatan
/// ekranın `context`i hâlâ yaşıyorsa gösteriliyordu; kullanıcı pencereyi geri
/// tuşuyla kapatıp başka yere geçince sonuç hiçbir yerde tutulmuyordu
/// (bildirime dokunmak da hiçbir yere götürmüyordu) ve ikinci dokunuş baştan
/// yeni bir Gemini isteği açıyordu. Artık:
/// * biten özet dosyaya yazılır — aynı dosyaya tekrar basınca hazır özet
///   anında açılır (dosya değişmediyse),
/// * süren iş anahtarıyla tutulur — ikinci dokunuş YENİ iş açmaz, süreni izler,
/// * işin hedefi özetin kendisidir: bildirim/şerit dokununca özet açılır.
abstract final class AiSummaryStore {
  /// Testler kökü değiştirir.
  @visibleForTesting
  static String? rootOverride;

  static String get root =>
      rootOverride ??
      p.join(
          FmEnv.appSupportDir.isEmpty
              ? Directory.systemTemp.path
              : FmEnv.appSupportDir,
          'ai_summaries');

  static String _fileFor(String key) => p.join(root,
      '${sha1.convert(utf8.encode(key)).toString().substring(0, 20)}.json');

  /// Kaydı okur; yoksa ya da bozuksa null.
  static Future<AiSummaryRecord?> read(String key) async {
    try {
      final f = File(_fileFor(key));
      if (!await f.exists()) return null;
      final r = AiSummaryRecord.fromJson(jsonDecode(await f.readAsString()));
      return r?.key == key ? r : null;
    } catch (_) {
      return null;
    }
  }

  /// Dosyanın özeti — yalnız dosya özetten bu yana DEĞİŞMEDİYSE.
  static Future<AiSummaryRecord?> forFile(String path) async {
    final r = await read(path);
    if (r == null) return null;
    try {
      final st = await File(path).stat();
      if (st.type == FileSystemEntityType.notFound) return r;
      if (st.size != r.sourceSize ||
          st.modified.millisecondsSinceEpoch != r.sourceModifiedMs) {
        return null;
      }
    } catch (_) {}
    return r;
  }

  static Future<void> write(AiSummaryRecord record) async {
    final f = File(_fileFor(record.key));
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(record.toJson()), flush: true);
  }

  static Future<void> remove(String key) async {
    try {
      final f = File(_fileFor(key));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Dosyanın şu anki boy/zaman damgası (kayda yazılır).
  static ({int size, int modifiedMs}) stampOf(String path) {
    try {
      final st = File(path).statSync();
      return (size: st.size, modifiedMs: st.modified.millisecondsSinceEpoch);
    } catch (_) {
      return (size: 0, modifiedMs: 0);
    }
  }

  // ── Süren işler ──────────────────────────────────────────────────────────
  static final Map<String, RunningSummary> _running = {};

  /// [key] için süren özet işi (yoksa null).
  static RunningSummary? running(String key) => _running[key];

  /// [key] için işi başlatır; zaten sürüyorsa YENİSİ açılmaz, süren döner.
  static RunningSummary start(
    String key,
    Future<AiSummaryRecord> Function(RunningSummary run) body,
  ) {
    final existing = _running[key];
    if (existing != null) return existing;
    final run = RunningSummary._(key);
    _running[key] = run;
    run.result = () async {
      try {
        final record = await body(run);
        await write(record);
        return record;
      } finally {
        _running.remove(key);
      }
    }();
    // Kimse beklemese de hata "yakalanmamış" sayılmasın.
    unawaited(run.result.then((_) {}, onError: (_) {}));
    return run;
  }

  @visibleForTesting
  static void resetRunning() => _running.clear();
}

/// Süren bir özet işi: durum satırı + sonuç.
class RunningSummary {
  RunningSummary._(this.key);

  final String key;
  late final Future<AiSummaryRecord> result;

  /// İşin iş sistemi kaydı (gövde ilk satırında kurar; pencere izler).
  TrackedTask? task;

  /// Penceredeki satır ("Belge okunuyor…", "Özet hazırlanıyor…").
  final status = ValueNotifier<String>('');

  /// Sonucu ekranda bekleyen biri var mı? Bitişte bildirim sessiz mi olsun
  /// kararı buna bakar: kimse izlemiyorsa sonuç bildirimle söylenir.
  bool watched = false;
}
