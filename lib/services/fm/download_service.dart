import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/download_task.dart';
import 'file_ops.dart';
import 'fm_env.dart';
import 'fs_events.dart';

/// **İndirme yöneticisi** — bağlantıdan dosya indirir, **uygulama kapalıyken
/// bile devam eder**, ilerlemeyi bildirir, duraklatma/sürdürme yapar.
///
/// ## Niye kendi HTTP döngümüz DEĞİL (2026-07-29, 2. karar)
/// İlk sürüm `http` paketiyle kendi akışımızı yazıyordu; uygulama arka plana
/// atılınca ya da kapanınca indirme duruyordu. Kullanıcı: *"arka planda
/// mutlaka devam etmeli, sorunsuz bir şekilde."* Android'de bunun tek doğru
/// yolu **ön plan servisi** (foreground service) + bildirim; bu, Dart'tan
/// yazılamaz, yerel kod ister. Üstelik CI her derlemede `android/` klasörünü
/// `flutter create` ile yeniden ürettiği için elle yazılmış Kotlin servisi
/// her seferinde silinirdi.
/// Bu yüzden iş `background_downloader` paketine devredildi: indirme native
/// tarafta (Android'de WorkManager + ön plan servisi) koşar, uygulama
/// öldürülse bile sürer, sistem bildiriminde ilerleme görünür.
///
/// ## Bu sınıfın rolü
/// Paket kendi görev modelini kullanır; bizim arayüzümüz [DownloadTask]
/// üzerine kurulu. Burası **iki modeli birbirine bağlayan ince katman**:
/// paketin durum/ilerleme akışını dinler, kendi listemizi günceller ve
/// diske yazar (uygulama yeniden açıldığında liste yerinde durur).
class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  /// Aynı anda koşacak indirme sayısı. Mobil bağlantıda daha fazlası
  /// hepsini yavaşlatır ve pil yakar.
  static const maxConcurrent = 2;

  static const _queueFile = 'downloads.json';
  static const _group = 'dosya-okuyucu';

  final List<DownloadTask> _tasks = [];
  StreamSubscription<bg.TaskUpdate>? _sub;
  bool _loaded = false;
  bool _ready = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.state.isActive).toList();
  bool get hasActive => activeTasks.isNotEmpty;

  String get _queuePath => p.join(FmEnv.appSupportDir, _queueFile);

  /// Kuyruğu diskten okur ve arka plan motorunu hazırlar.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await FmEnv.ensureInit();
    if (FmEnv.appSupportDir.isNotEmpty) {
      try {
        final file = File(_queuePath);
        if (file.existsSync()) {
          _tasks
            ..clear()
            ..addAll(decodeQueue(await file.readAsString()));
        }
      } catch (_) {}
    }
    await _initEngine();
    await _reconcileWithEngine();
    notifyListeners();
  }

  /// Kaydettiğimiz durumla **motorun gerçeği** arasındaki farkı kapatır.
  ///
  /// Uygulama kapalıyken indirme sürmüş, bitmiş ya da başarısız olmuş
  /// olabilir. Motorda hâlâ duran görevler "sırada/indiriliyor", motorda
  /// olmayıp diskte dosyası oluşmuşlar "tamamlandı" sayılır.
  Future<void> _reconcileWithEngine() async {
    Set<String> live = {};
    try {
      final running = await bg.FileDownloader().allTasks(group: _group);
      live = {for (final task in running) task.taskId};
    } catch (_) {
      return; // motor sorgulanamadı: elimizdeki kayıtla devam
    }
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (live.contains(task.id)) {
        if (!task.state.isActive) {
          _tasks[i] = task.copyWith(state: DownloadState.queued);
        }
        continue;
      }
      if (!task.state.isActive) continue;
      // Motorda yok: bitmiş ya da düşmüş. Diskte dosya varsa tamamlanmıştır.
      try {
        final file = File(task.destPath);
        _tasks[i] = file.existsSync()
            ? task.copyWith(
                state: DownloadState.completed,
                received: file.lengthSync(),
              )
            : task.copyWith(state: DownloadState.paused);
      } catch (_) {
        _tasks[i] = task.copyWith(state: DownloadState.paused);
      }
    }
    await _persist();
  }

  Future<void> _initEngine() async {
    if (_ready) return;
    _ready = true;
    try {
      final downloader = bg.FileDownloader();
      // Sistem bildirimi: kullanıcı uygulamadan çıksa da ilerlemeyi görür ve
      // bildirimden duraklatıp sürdürebilir. Android 13+ bildirim izni
      // istenmezse indirme yine çalışır, yalnız bildirim görünmez.
      downloader.configureNotification(
        running: const bg.TaskNotification('{filename}', 'İndiriliyor…'),
        complete: const bg.TaskNotification('{filename}', 'İndirildi'),
        paused: const bg.TaskNotification('{filename}', 'Duraklatıldı'),
        error: const bg.TaskNotification('{filename}', 'İndirilemedi'),
        progressBar: true,
        tapOpensFile: true,
      );
      await downloader.configure(globalConfig: [
        (bg.Config.holdingQueue, (maxConcurrent, null, null)),
        // Yeniden deneme: kopan mobil bağlantıda indirme çöpe gitmesin.
        (bg.Config.requestTimeout, const Duration(seconds: 60)),
      ]);
      _sub = downloader.updates.listen(_onUpdate, onError: (_) {});
      // Uygulama kapalıyken biten/ilerleyen görevlerin sonucu buradan gelir.
      await downloader.start();
      unawaited(downloader.resumeFromBackground());
    } catch (_) {
      // Motor kurulamazsa (masaüstü/test ortamı) liste yine görünür; indirme
      // denendiğinde hata kullanıcıya yazılır.
    }
  }

  Future<void> _persist() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      await File(_queuePath).writeAsString(encodeQueue(_tasks));
    } catch (_) {}
  }

  // ── paket → bizim model ────────────────────────────────────────────────────

  void _onUpdate(bg.TaskUpdate update) {
    final id = update.task.taskId;
    switch (update) {
      case bg.TaskStatusUpdate(:final status, :final exception):
        _applyStatus(id, status, exception?.description);
      case bg.TaskProgressUpdate(
          :final progress,
          :final expectedFileSize,
          :final networkSpeed,
        ):
        _update(id, (t) {
          final total = expectedFileSize > 0 ? expectedFileSize : t.total;
          return t.copyWith(
            state: DownloadState.running,
            total: total,
            received: total > 0 && progress >= 0
                ? (total * progress).round()
                : t.received,
            // Paket MB/s verir; biz bayt/sn tutuyoruz (-1 = bilinmiyor).
            bytesPerSecond:
                networkSpeed > 0 ? (networkSpeed * 1024 * 1024).round() : 0,
          );
        });
    }
  }

  void _applyStatus(String id, bg.TaskStatus status, String? error) {
    final state = stateForNativeStatus(status);
    _update(id, (t) => t.copyWith(
          state: state,
          error: state == DownloadState.failed ? (error ?? 'İndirilemedi') : null,
          clearError: state != DownloadState.failed,
          bytesPerSecond: state == DownloadState.running ? t.bytesPerSecond : 0,
          received: state == DownloadState.completed && t.hasTotal
              ? t.total
              : t.received,
        ));
    if (state == DownloadState.completed) {
      FsEvents.changed();
      // Dosya adı sunucudan gelen adla değişmiş olabilir; diskten doğrula.
      unawaited(_confirmFile(id));
    }
  }

  Future<void> _confirmFile(String id) async {
    final task = _find(id);
    if (task == null) return;
    try {
      final file = File(task.destPath);
      if (file.existsSync()) {
        _update(id, (t) => t.copyWith(received: file.lengthSync()));
      }
    } catch (_) {}
  }

  // ── genel API ─────────────────────────────────────────────────────────────

  /// Yeni indirme ekler. [destDir] verilmezse İndirilenler klasörüne iner.
  Future<DownloadTask> enqueue(
    String url, {
    String? destDir,
    String? fileName,
  }) async {
    await ensureLoaded();
    final dir = destDir ?? _defaultDir();
    final name = FileOps.sanitizeName(fileName ?? resolveFileName(url: url));
    // Aynı adlı dosya varsa üzerine yazma: "rapor (1).pdf".
    final destPath = FileOps.uniquePath(p.join(dir, name));
    final id = '${DateTime.now().microsecondsSinceEpoch}';

    final task = DownloadTask(
      id: id,
      url: url,
      destPath: destPath,
      fileName: p.basename(destPath),
      state: DownloadState.queued,
      startedMs: DateTime.now().millisecondsSinceEpoch,
    );
    _tasks.insert(0, task);
    notifyListeners();
    await _persist();

    try {
      final native = await _nativeTaskFor(task);
      final ok = await bg.FileDownloader().enqueue(native);
      if (!ok) {
        _update(id, (t) => t.copyWith(
              state: DownloadState.failed,
              error: 'İndirme başlatılamadı',
            ));
      }
    } catch (e) {
      _update(id, (t) => t.copyWith(
            state: DownloadState.failed,
            error: e.toString(),
          ));
    }
    return task;
  }

  /// Bizim kaydımızdan paketin görev nesnesini kurar.
  ///
  /// `Task.split` mutlak yolu paketin beklediği (temel dizin, alt dizin, ad)
  /// üçlüsüne çevirir — elle `BaseDirectory.root` kurmaya çalışmak platforma
  /// göre farklı kök ön eklerinde (Android/Windows) kırılırdı.
  Future<bg.DownloadTask> _nativeTaskFor(DownloadTask task) async {
    final (baseDirectory, directory, filename) =
        await bg.Task.split(filePath: task.destPath);
    return bg.DownloadTask(
      taskId: task.id,
      url: task.url,
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      group: _group,
      updates: bg.Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
      displayName: task.fileName,
      // Sunucuların bir kısmı User-Agent'sız isteği reddediyor (GitHub dahil).
      headers: const {'user-agent': 'DosyaOkuyucu/1.0'},
    );
  }

  String _defaultDir() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    return Directory(download).existsSync() ? download : FmEnv.primaryRoot;
  }

  Future<void> pause(String id) async {
    final task = _find(id);
    if (task == null) return;
    try {
      // `pause` yalnız taskId kullanır; görevi yeniden kurmak yeterli.
      await bg.FileDownloader().pause(await _nativeTaskFor(task));
    } catch (_) {}
    _update(id, (t) => t.copyWith(
          state: DownloadState.paused,
          bytesPerSecond: 0,
        ));
  }

  Future<void> resume(String id) async {
    final task = _find(id);
    if (task == null) return;
    _update(id, (t) =>
        t.copyWith(state: DownloadState.queued, clearError: true));
    try {
      final native = await _nativeTaskFor(task);
      // Sürdürme verisi yoksa (uygulama silinmiş/temizlenmiş) baştan başlat:
      // "devam et" düğmesinin hiçbir şey yapmaması en kötü sonuç olurdu.
      final resumed = await bg.FileDownloader().resume(native);
      if (!resumed) await bg.FileDownloader().enqueue(native);
    } catch (e) {
      _update(id, (t) => t.copyWith(
            state: DownloadState.failed,
            error: e.toString(),
          ));
    }
  }

  /// İndirmeyi iptal eder (yarım dosyayı paket kendisi siler).
  Future<void> cancel(String id) async {
    try {
      await bg.FileDownloader().cancelTaskWithId(id);
    } catch (_) {}
    _update(id, (t) => t.copyWith(
          state: DownloadState.canceled,
          bytesPerSecond: 0,
        ));
  }

  /// Kaydı listeden düşürür (dosyaya dokunmaz).
  Future<void> remove(String id) async {
    if (_find(id)?.state.isActive ?? false) await cancel(id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearFinished() async {
    _tasks.removeWhere(
        (t) => !t.state.isActive && t.state != DownloadState.paused);
    notifyListeners();
    await _persist();
  }

  DownloadTask? _find(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _update(String id, DownloadTask Function(DownloadTask) change) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = change(_tasks[index]).copyWith(
      updatedMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    unawaited(_persist());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Paketin durum değerlerini bizim durumlarımıza çevirir (saf → testli).
///
/// `waitingToRetry` bilinçli olarak "sırada" sayılır: kullanıcı açısından
/// indirme sürüyor, kendiliğinden yeniden denenecek — "başarısız" demek
/// gereksiz telaş yaratırdı.
DownloadState stateForNativeStatus(bg.TaskStatus status) => switch (status) {
      bg.TaskStatus.enqueued => DownloadState.queued,
      bg.TaskStatus.running => DownloadState.running,
      bg.TaskStatus.complete => DownloadState.completed,
      bg.TaskStatus.paused => DownloadState.paused,
      bg.TaskStatus.canceled => DownloadState.canceled,
      bg.TaskStatus.waitingToRetry => DownloadState.queued,
      bg.TaskStatus.notFound || bg.TaskStatus.failed => DownloadState.failed,
    };
