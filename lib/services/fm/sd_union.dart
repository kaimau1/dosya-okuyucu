import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import 'chat_media_guard.dart';
import 'fm_env.dart';
import 'fs_scan.dart' show FsPaths;
import 'tracked_task.dart';
import 'storage_stats.dart';

/// Birleşik depolamanın kipi.
enum SdUnionMode {
  /// Dosya SD karta taşınır, ana bellekte yer açılır (asıl "birleşik" kip).
  move,

  /// Dosya SD karta kopyalanır, ana bellekte de kalır (yedek).
  copy,
}

/// **SD kartla birleşik depolama — yalnız şarj olurken** (kullanıcı isteği
/// 2026-10-17: *"sadece şarj olurken çalışan SD kartı ile birlik olarak kullan
/// özelliği"*).
///
/// Seçilen klasörlerin (Kamera, Resimler, Videolar…) belli bir günden eski
/// dosyaları SD kartta AYNI klasör yoluna taşınır (`DCIM/Camera/a.jpg` →
/// `<kart>/DCIM/Camera/a.jpg`). Uygulamanın listeleri ve galeri uygulamaları
/// iki birimi zaten birlikte gösterdiği için kullanıcı tek bir depolama
/// görür; ana bellek boşalır. Android'in "kartı dahili depolama olarak
/// biçimlendir" seçeneği kartı siler ve çoğu telefondan kaldırıldı — bu,
/// dosya düzeyindeki karşılığı.
///
/// **İşi Android yapar** (`ci/SdUnion.kt`): telefon şarja takıldığında
/// uygulama genelde kapalıdır, Dart izolatı yoktur. `JobScheduler` şarj
/// şartıyla yarım saatte bir işi uyandırır, şarj kesilince durdurur; her
/// dosya bölünmez taşınır (geçici dosya → boy doğrulama → ad değiştir →
/// kaynağı sil). Bu sınıf ayarı tutar, Android'e iletir ve durum okur.
///
/// Kurallar Kotlin'dekiyle AYNIDIR ve burada yalnız **önizleme** ("şu an
/// 1.240 dosya · 8,3 GB taşınır") için kopyalanmıştır: gizli adlar, sohbet
/// medyası (WhatsApp/Telegram dosyayı yoluyla tutar — taşınırsa sohbette
/// "dosya yok" olur), `Android/` ağacı, son 10 dakikada değişen dosya ve gün
/// sınırı. Bir kural değişirse ikisi birlikte değişmeli (testler:
/// `sd_union_test.dart` + `tool/kotlin_tests/SdUnionHarness.kt`).
class SdUnionSettings {
  final bool enabled;
  final SdUnionMode mode;

  /// Hedef kartın kök yolu (`/storage/1A2B-3C4D`); boşsa seçilmemiş.
  final String sdPath;

  /// Ana bellek köküne göre klasörler (`DCIM`, `Pictures`…).
  final List<String> folders;

  /// Bu günden eski dosyalar taşınır (0 = yaşına bakmadan — yine de son
  /// 10 dakikada değişene dokunulmaz).
  final int minAgeDays;

  /// İş bitince "N dosya SD karta taşındı" bildirimi.
  final bool notify;

  const SdUnionSettings({
    this.enabled = false,
    this.mode = SdUnionMode.move,
    this.sdPath = '',
    this.folders = defaultFolders,
    this.minAgeDays = 30,
    this.notify = true,
  });

  /// İlk açılışta seçili gelenler: ana belleği asıl dolduran üç klasör.
  static const defaultFolders = ['DCIM', 'Pictures', 'Movies'];

  /// Ekranda sunulan klasörler (Android'in standart ortak klasörleri).
  static const candidateFolders = [
    'DCIM',
    'Pictures',
    'Movies',
    'Music',
    'Download',
    'Documents',
    'Recordings',
    'Podcasts',
    'Audiobooks',
  ];

  static const ageChoices = [0, 7, 30, 90, 365];

  /// Kartta her zaman boş bırakılan pay (MB) — kartı ağzına kadar doldurmak
  /// kameranın SD'ye yazdığı telefonlarda çekimi durdururdu.
  static const keepFreeMb = 1024;

  SdUnionSettings copyWith({
    bool? enabled,
    SdUnionMode? mode,
    String? sdPath,
    List<String>? folders,
    int? minAgeDays,
    bool? notify,
  }) =>
      SdUnionSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        sdPath: sdPath ?? this.sdPath,
        folders: folders ?? this.folders,
        minAgeDays: minAgeDays ?? this.minAgeDays,
        notify: notify ?? this.notify,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'mode': mode.name,
        'sdPath': sdPath,
        'folders': folders,
        'minAgeDays': minAgeDays,
        'notify': notify,
      };

  factory SdUnionSettings.fromJson(Map<String, Object?> json) {
    final folders = json['folders'];
    return SdUnionSettings(
      enabled: json['enabled'] == true,
      mode: json['mode'] == 'copy' ? SdUnionMode.copy : SdUnionMode.move,
      sdPath: json['sdPath'] is String ? json['sdPath'] as String : '',
      folders: folders is List
          ? [
              for (final f in folders)
                if (f is String && f.isNotEmpty) f
            ]
          : defaultFolders,
      minAgeDays: json['minAgeDays'] is int ? json['minAgeDays'] as int : 30,
      notify: json['notify'] != false,
    );
  }

  /// Android'e giden ayar: ana bellek kökü ve bildirim metinleri (çeviri
  /// tablosu Dart'ta) eklenir.
  String toNativeJson({required String primary, required AppStrings strings}) =>
      jsonEncode({
        ...toJson(),
        'primary': primary,
        'keepFreeMb': keepFreeMb,
        'doneTitle': strings.t(mode == SdUnionMode.move
            ? 'sdu.notify_title_move'
            : 'sdu.notify_title_copy'),
        'doneBody': strings.t('sdu.notify_body'),
        'channelName': strings.t('sdu.title'),
      });
}

/// Android'in yazdığı durum.
class SdUnionStatus {
  final DateTime? lastRun;

  /// `charging` (şarjda kendiliğinden) ya da `manual` ("Şimdi taşı").
  final String reason;
  final int lastMoved;
  final int lastBytes;
  final int lastFailed;

  /// null = sorunsuz; `sd_missing` · `sd_readonly` · `sd_full` · `stopped`.
  final String? lastError;
  final int totalMoved;
  final int totalBytes;
  final bool running;
  final bool scheduled;
  final bool charging;

  const SdUnionStatus({
    this.lastRun,
    this.reason = '',
    this.lastMoved = 0,
    this.lastBytes = 0,
    this.lastFailed = 0,
    this.lastError,
    this.totalMoved = 0,
    this.totalBytes = 0,
    this.running = false,
    this.scheduled = false,
    this.charging = false,
  });

  factory SdUnionStatus.fromMap(Map<Object?, Object?> map) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final last = asInt(map['lastRun']);
    final error = map['lastError'];
    return SdUnionStatus(
      lastRun: last > 0 ? DateTime.fromMillisecondsSinceEpoch(last) : null,
      reason: map['reason'] is String ? map['reason'] as String : '',
      lastMoved: asInt(map['lastMoved']),
      lastBytes: asInt(map['lastBytes']),
      lastFailed: asInt(map['lastFailed']),
      lastError: error is String && error.isNotEmpty ? error : null,
      totalMoved: asInt(map['totalMoved']),
      totalBytes: asInt(map['totalBytes']),
      running: map['running'] == true,
      scheduled: map['scheduled'] == true,
      charging: map['charging'] == true,
    );
  }
}

/// Önizleme sonucu.
class SdUnionPreview {
  final int files;
  final int bytes;
  const SdUnionPreview(this.files, this.bytes);
}

abstract final class SdUnion {
  static const _channel = MethodChannel('dosya_okuyucu/sd_union');
  static const _prefKey = 'sd_union_settings';

  /// Testte ekranın Android gövdesini çizdirmek için (kanal yine çağrılmaz).
  @visibleForTesting
  static bool debugSupported = false;

  /// Bu platformda çalışır mı? (İş `JobScheduler` ile — yalnız Android.)
  static bool get supported => Platform.isAndroid || debugSupported;

  /// Yazılmakta olabilecek dosyaya dokunulmaz (Kotlin: `SETTLE_MS`).
  static const settle = Duration(minutes: 10);

  static Future<SdUnionSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return const SdUnionSettings();
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) return SdUnionSettings.fromJson(json);
    } catch (_) {}
    return const SdUnionSettings();
  }

  /// Ayarı saklar ve Android'e iletir (açıksa şarj işi kurulur, kapalıysa
  /// kaldırılır). Android dışında yalnız saklar.
  static Future<bool> save(SdUnionSettings settings,
      {AppStrings? strings}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(settings.toJson()));
    } catch (_) {}
    return _configure(settings, strings ?? AppStrings.current);
  }

  static Future<bool> _configure(
      SdUnionSettings settings, AppStrings strings) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('configure', {
        'config':
            settings.toNativeJson(primary: FmEnv.primaryRoot, strings: strings),
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Açılışta bir kez: kayıtlı ayar Android'e yeniden iletilir. Böylece iş
  /// güncellemeden sonra da kurulu kalır ve bildirim metni uygulamanın
  /// GEÇERLİ dilindedir. Ayar hiç açılmadıysa hiçbir şey yapılmaz.
  static Future<void> syncOnLaunch() async {
    if (!Platform.isAndroid) return;
    final settings = await load();
    if (!settings.enabled) return;
    await _configure(settings, AppStrings.current);
  }

  static Future<SdUnionStatus> status() async {
    if (!Platform.isAndroid) return const SdUnionStatus();
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      return map == null ? const SdUnionStatus() : SdUnionStatus.fromMap(map);
    } catch (_) {
      return const SdUnionStatus();
    }
  }

  /// Şarj şartı olmadan bir kez çalıştırır (kullanıcının açık isteği).
  ///
  /// [settings] verilirse iş **iş sistemine** de bağlanır ([_watchRun]): ana
  /// ekran şeridinde ve bildirimde "SD karta taşınıyor · 1 dk 10 sn" görünür,
  /// bitince sonucu söyler. Eskiden iş yalnız SD kart ekranı açıkken
  /// izlenebiliyordu (kullanıcı 2026-10-18: *"ne oluyor şu anda … soru işareti
  /// kalmamalı"*).
  static Future<bool> runNow({SdUnionSettings? settings}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('runNow') ?? false;
      if (ok && settings != null) _watchRun(settings);
      return ok;
    } catch (_) {
      return false;
    }
  }

  static TrackedTask? _task;
  static Timer? _watch;

  /// Yerel işi ekrandan BAĞIMSIZ izler (SD kart ekranı kapansa da şerit
  /// takılı kalmasın): 2 sn'de bir durum sorulur; iş bitince sonuç yazılır.
  /// Şeritten/bildirimden "Durdur" yerel işi durdurur.
  static void _watchRun(SdUnionSettings settings) {
    if (_task != null) return;
    final str = AppStrings.current;
    final copy = settings.mode == SdUnionMode.copy;
    final task = TrackedTask(
      title: str.t(copy ? 'sdu.job_title_copy' : 'sdu.job_title'),
      name: str.t('sdu.job_name'),
      threshold: Duration.zero,
    );
    _task = task;
    final startedAt = DateTime.now();
    var stopSent = false;
    _watch = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (task.cancelRequested && !stopSent) {
        stopSent = true;
        await stop();
      }
      final st = await status();
      if (st.running) return;
      // İş sistem kuyruğundan birkaç yüz ms sonra başlar: ilk yoklamalarda
      // "çalışmıyor" görmek "bitti" demek değildir. Son çalışma bu
      // başlatmadan SONRAYSA ya da yarım dakika geçtiyse bitmiş sayılır.
      final finishedAfterStart =
          st.lastRun != null && st.lastRun!.isAfter(startedAt);
      if (!finishedAfterStart &&
          DateTime.now().difference(startedAt) < const Duration(seconds: 30)) {
        return;
      }
      _watch?.cancel();
      _watch = null;
      _task = null;
      final detail = str.t('sdu.notify_body', {
        'n': st.lastMoved,
        'size': FsPaths.humanSize(st.lastBytes),
      });
      // Yerel iş bir şey taşıdıysa kendi "bitti" bildirimini zaten gösterir;
      // ikinci bir sonuç bildirimi gürültü olur (şerit yine sonucu söyler).
      final nativeNotified = settings.notify && st.lastMoved > 0;
      if (st.lastError == 'stopped' || task.cancelRequested) {
        await task.stopped(detail: detail);
      } else if (st.lastError != null) {
        await task.fail(str.t(switch (st.lastError) {
          'sd_missing' => 'sdu.err_sd_missing',
          'sd_full' => 'sdu.err_sd_full',
          'sd_readonly' => 'sdu.err_readonly',
          _ => 'job.error_generic',
        }));
      } else {
        await task.complete(detail: detail, quiet: nativeNotified);
      }
    });
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  /// Takılı SD kartlar (USB bellekler hedef OLMAZ: çıkarılıp takılan bir
  /// diske kamera arşivini taşımak, bellek çekilince "fotoğraflarım gitti"
  /// demek olurdu).
  static List<StorageVolume> sdCards([List<StorageVolume>? volumes]) => [
        for (final v in volumes ?? FmEnv.volumes)
          if (v.kind == StorageKind.sdCard) v,
      ];

  // ── kurallar (Kotlin `SdUnionRules` ile AYNI) ───────────────────────────

  static bool isEligibleDir(String name, String relPath) {
    if (name.startsWith('.') || ChatMediaGuard.isChatPath(relPath)) {
      return false;
    }
    final lower = relPath.toLowerCase();
    return lower != 'android' && !lower.startsWith('android/');
  }

  static bool isEligibleFile({
    required String name,
    required String relPath,
    required int length,
    required DateTime modified,
    required DateTime now,
    required int minAgeDays,
  }) {
    if (length <= 0) return false;
    if (name.startsWith('.') || ChatMediaGuard.isChatPath(relPath)) {
      return false;
    }
    final age = now.difference(modified);
    if (age < settle) return false;
    return age >= Duration(days: minAgeDays);
  }

  /// Şu an taşınabilecek dosyaların sayısı ve boyutu (izolatta, diske yazmaz).
  static Future<SdUnionPreview> preview(SdUnionSettings settings,
      {String? primary}) {
    final root = primary ?? FmEnv.primaryRoot;
    final folders = List.of(settings.folders);
    final minAge = settings.minAgeDays;
    return Isolate.run(
        () => previewSync(root, folders, minAge, DateTime.now()));
  }

  static SdUnionPreview previewSync(
      String primary, List<String> folders, int minAgeDays, DateTime now) {
    var files = 0;
    var bytes = 0;
    for (final folder in folders) {
      final start = Directory(p.join(primary, folder));
      if (!isEligibleDir(p.basename(folder), folder)) continue;
      final stack = <(Directory, String)>[(start, folder)];
      while (stack.isNotEmpty) {
        final (dir, rel) = stack.removeLast();
        List<FileSystemEntity> children;
        try {
          children = dir.listSync(followLinks: false);
        } catch (_) {
          continue;
        }
        for (final child in children) {
          final name = p.basename(child.path);
          final childRel = '$rel/$name';
          if (child is Directory) {
            if (isEligibleDir(name, childRel)) stack.add((child, childRel));
            continue;
          }
          if (child is! File) continue;
          try {
            final stat = child.statSync();
            if (isEligibleFile(
              name: name,
              relPath: childRel,
              length: stat.size,
              modified: stat.modified,
              now: now,
              minAgeDays: minAgeDays,
            )) {
              files++;
              bytes += stat.size;
            }
          } catch (_) {}
        }
      }
    }
    return SdUnionPreview(files, bytes);
  }
}
