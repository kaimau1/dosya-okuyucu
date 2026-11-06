import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_version.dart';
import '../core/device_profile.dart';
import 'crash_log.dart';

/// **Kare ölçümü (A8 / Faz 42 / 3·7)** — yavaş karelerin (`KARE` günlüğü)
/// cihazda biriken, anonim **dağılımı**.
///
/// - Yalnız kullanıcı açtıysa çalışır (varsayılan KAPALI; [prefKey]).
/// - Kare ÜRETMEZ: `addTimingsCallback` yalnız çizilen karelerin zamanını
///   alır; boşta 0 kare korunur (anayasa k.6). Zamanlayıcı yok — diske yazım
///   kare geldiğinde, en çok dakikada bir.
/// - Kare başına iş: bir kova sayacı. Tek tek kare/ekran adı SAKLANMAZ.
class FrameStats {
  FrameStats._();
  static final FrameStats instance = FrameStats._();

  static const prefKey = 'diag_frame_stats';
  static const _file = 'frame_stats.json';

  /// Kova üst sınırları (ms); son kova ">100".
  static const bucketsMs = <int>[8, 16, 24, 33, 50, 100];

  /// Kova sayaçları (bucketsMs.length + 1).
  final List<int> counts = List<int>.filled(bucketsMs.length + 1, 0);
  bool _running = false;
  bool _loaded = false;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  @visibleForTesting
  static String? dirOverride;

  bool get running => _running;

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(prefKey) ?? false;

  static Future<void> setEnabled(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(prefKey, on);
    if (on) {
      await instance.start();
    } else {
      instance.stop();
    }
  }

  /// Açılış kuyruğundan (ilk 2 sn sonra) — açıksa başlatır.
  static Future<void> startIfEnabled() async {
    if (await enabled()) await instance.start();
  }

  Future<void> start() async {
    if (_running) return;
    await _load();
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    unawaited(flush());
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      addSample(t.totalSpan.inMicroseconds / 1000);
    }
    if (DateTime.now().difference(_lastFlush) > const Duration(minutes: 1)) {
      unawaited(flush());
    }
  }

  @visibleForTesting
  void addSample(double ms) {
    var i = 0;
    while (i < bucketsMs.length && ms > bucketsMs[i]) {
      i++;
    }
    counts[i]++;
  }

  int get total => counts.fold(0, (a, b) => a + b);

  /// Eşikten yavaş karelerin oranı (%). 24 ms ≈ 60 Hz'de iki vsync kaçırma.
  double slowPercent([int overMs = 24]) {
    final n = total;
    if (n == 0) return 0;
    var slow = 0;
    for (var i = 0; i < counts.length; i++) {
      final lower = i == 0 ? 0 : bucketsMs[i - 1];
      if (lower >= overMs) slow += counts[i];
    }
    return slow * 100 / n;
  }

  /// Yüzdelik (kova üst sınırı, ms); ">100" kovası 101 döner.
  int percentile(double q) {
    final n = total;
    if (n == 0) return 0;
    final want = (n * q).ceil();
    var seen = 0;
    for (var i = 0; i < counts.length; i++) {
      seen += counts[i];
      if (seen >= want) return i < bucketsMs.length ? bucketsMs[i] : 101;
    }
    return 101;
  }

  void reset() {
    counts.fillRange(0, counts.length, 0);
    unawaited(flush());
  }

  Future<File?> _fileRef() async {
    try {
      final dir = dirOverride ?? (await getApplicationSupportDirectory()).path;
      return File(p.join(dir, _file));
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _fileRef();
      if (f == null || !f.existsSync()) return;
      final list = (jsonDecode(await f.readAsString()) as List).cast<num>();
      for (var i = 0; i < counts.length && i < list.length; i++) {
        counts[i] += list[i].toInt();
      }
    } catch (_) {}
  }

  Future<void> flush() async {
    _lastFlush = DateTime.now();
    try {
      final f = await _fileRef();
      await f?.writeAsString(jsonEncode(counts));
    } catch (_) {}
  }
}

/// **Anonim tanılama özeti** (Faz 42 / 3·7, A8): çökme / ANR / bellek
/// öldürmesi sayıları + ilk satırları ve kare dağılımı — kullanıcı ÖNCE
/// metnin tamamını görür, onaylarsa kendisi paylaşır (ağ isteği yok).
///
/// KVKK: dosya adı/yol, URI, e-posta, 6+ haneli sayı (TC no, telefon,
/// hesap no) ve bağlantılar [scrub] ile maskelenir; belge içeriği hiç girmez.
abstract final class DiagReport {
  static final _rules = <(RegExp, String)>[
    // Tırnak içindeki yol (FileSystemException biçimi; boşluklu adlar dahil).
    (RegExp(r"'[^'\n]*[/\\][^'\n]*'"), "'<yol>'"),
    (RegExp(r'"[^"\n]*[/\\][^"\n]*"'), '"<yol>"'),
    (RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<eposta>'),
    (RegExp(r'(content|file|https?|ftp|smb|sftp|webdav)://\S+'), '<uri>'),
    (RegExp(r'(?<![\w.])(/[^\s/:,;()\[\]"' "'" r']+){2,}/?'), '<yol>'),
    (
      RegExp(
          r'[^\s/\\:"' "'" r'()\[\]]+\.(pdf|docx?|xlsx?|xlsm|csv|pptx?|odt|ods|odp|rtf|txt|md|epub|jpe?g|png|webp|heic|gif|mp[34]|mkv|zip|rar|7z|apk)\b',
          caseSensitive: false),
      '<dosya>'
    ),
    (RegExp(r'\d{6,}'), '<n>'),
  ];

  /// Kişisel olabilecek parçaları maskeler.
  static String scrub(String s) {
    var out = s;
    for (final (re, rep) in _rules) {
      out = out.replaceAll(re, rep);
    }
    return out;
  }

  /// Saf kurucu (test edilir): kayıtlar + kare sayaçları → düz metin.
  static String build({
    required List<CrashRecord> records,
    required FrameStats frames,
    required String tier,
    required String perfMode,
    String platform = '',
    int maxErrors = 5,
  }) {
    final b = StringBuffer()
      ..writeln('Dosya Okuyucu — anonim tanılama özeti')
      ..writeln('sürüm: $appVersionFull · profil: $tier ($perfMode)'
          '${platform.isEmpty ? '' : ' · $platform'}');
    final byKind = <String, int>{};
    var anr = 0, lowMem = 0, nativeCrash = 0;
    for (final r in records) {
      byKind[r.kind] = (byKind[r.kind] ?? 0) + r.count;
      if (r.kind == 'exit') {
        final e = r.error.toUpperCase();
        if (e.contains('ANR')) anr += r.count;
        if (e.contains('LOW_MEMORY') || e.contains('LOW MEMORY')) {
          lowMem += r.count;
        }
        if (e.contains('CRASH_NATIVE') || e.contains('NATIVE')) {
          nativeCrash += r.count;
        }
      }
    }
    b.writeln('kayıt: ${records.length} '
        '(${byKind.entries.map((e) => '${e.key}=${e.value}').join(', ')})');
    b.writeln('ANR: $anr · bellek öldürmesi: $lowMem · yerel çökme: $nativeCrash');
    if (frames.total > 0) {
      b.writeln('kare: n=${frames.total} p90≤${frames.percentile(.9)} ms '
          'p99≤${frames.percentile(.99)} ms · >24 ms '
          '%${frames.slowPercent().toStringAsFixed(1)} · >50 ms '
          '%${frames.slowPercent(50).toStringAsFixed(1)}');
      b.writeln('kare kovaları (ms ≤${FrameStats.bucketsMs.join('/')}/>100): '
          '${frames.counts.join('/')}');
    } else {
      b.writeln('kare: ölçüm kapalı ya da veri yok');
    }
    final seen = <String>{};
    var n = 0;
    for (final r in records) {
      final head = scrub(r.error.split('\n').first.trim());
      if (!seen.add(head)) continue;
      if (++n > maxErrors) break;
      b
        ..writeln()
        ..writeln('[$n] ${r.kind} ×${r.count} · ${r.version ?? '?'}')
        ..writeln(head);
      if (r.context != null) b.writeln('bağlam: ${scrub(r.context!)}');
      final frames = r.stack
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(6)
          .map(scrub);
      for (final f in frames) {
        b.writeln('  $f');
      }
    }
    return b.toString().trimRight();
  }

  /// Cihazdaki verilerden özet.
  static Future<String> collect() async {
    final records = await CrashLog.load();
    final frames = FrameStats.instance;
    if (!frames.running) await frames._load();
    return build(
      records: records,
      frames: frames,
      tier: DeviceProfile.tier.value.name,
      perfMode: DeviceProfile.mode.name,
      platform: Platform.isAndroid ? 'Android' : Platform.operatingSystem,
    );
  }
}
