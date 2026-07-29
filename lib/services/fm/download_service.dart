import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../models/download_task.dart';
import 'file_ops.dart';
import 'fm_env.dart';
import 'fs_events.dart';

/// **İndirme yöneticisi** — bağlantıdan dosya indirir, ilerlemeyi bildirir,
/// duraklatma/sürdürme yapar ve kuyruğu diskte saklar.
///
/// ## Niye uygulama içi indirme
/// Kullanıcı isteği (2026-07-29): *"bir linkten bir şey indireceğim (GitHub
/// release, tarayıcı) — bizim programımızdan indirmek istiyorum, daha
/// organize, hızlı ve etkili olabiliriz"*. Tarayıcının indirdiği dosya
/// `Download` klasörüne düşer ve orada kaybolur; burada dosya **istenen
/// klasöre** (örn. Önemli Dosyalar/Faturalar) doğrudan iner, bittiğinde
/// açılabilir, yarım kalan indirme sürdürülebilir.
///
/// ## Tasarım kararları
/// - **Akış hâlinde yazılır** (`StreamedResponse` → dosyaya parça parça):
///   500 MB'lık bir APK'yı belleğe almak uygulamayı öldürürdü.
/// - **Sürdürme `Range` ile.** Sunucu 206 dönmezse aralık yok sayılmış
///   demektir → dosya baştan yazılır (yarım dosyanın üstüne yazmak sessiz
///   bozulma olurdu, bkz. `serverHonorsRange`).
/// - Dosya `.indiriliyor` uzantısıyla yazılır, bitince asıl adına taşınır:
///   yarım dosya galeriye/listeye düşmez.
/// - **Arka planda devam ETMEZ.** Android'de bunun için ön plan servisi
///   gerekir; uygulama kapanınca indirme duraklatılır ve kullanıcıya böyle
///   gösterilir (yalancı "devam ediyor" göstermek yerine).
/// - Aynı anda en çok [maxConcurrent] indirme: mobil bağlantıda daha fazlası
///   hepsini yavaşlatır.
class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  static const maxConcurrent = 2;
  static const _queueFile = 'downloads.json';

  final List<DownloadTask> _tasks = [];
  final Map<String, _ActiveDownload> _active = {};
  bool _loaded = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.state.isActive).toList();
  bool get hasActive => activeTasks.isNotEmpty;

  String get _queuePath => p.join(FmEnv.appSupportDir, _queueFile);

  /// Kuyruğu diskten okur (uygulama açılışında bir kez).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await FmEnv.ensureInit();
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_queuePath);
      if (!file.existsSync()) return;
      _tasks
        ..clear()
        ..addAll(decodeQueue(await file.readAsString()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      await File(_queuePath).writeAsString(encodeQueue(_tasks));
    } catch (_) {}
  }

  /// Yeni indirme ekler ve (yer varsa) hemen başlatır.
  ///
  /// [destDir] verilmezse İndirilenler klasörüne iner. [fileName] verilmezse
  /// sunucunun/URL'nin verdiği ad kullanılır (bkz. `resolveFileName`).
  Future<DownloadTask> enqueue(
    String url, {
    String? destDir,
    String? fileName,
  }) async {
    await ensureLoaded();
    final dir = destDir ?? _defaultDir();
    final name = fileName ?? resolveFileName(url: url);
    final task = DownloadTask(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      destPath: p.join(dir, FileOps.sanitizeName(name)),
      fileName: name,
      startedMs: DateTime.now().millisecondsSinceEpoch,
    );
    _tasks.insert(0, task);
    notifyListeners();
    await _persist();
    _pump();
    return task;
  }

  String _defaultDir() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    return Directory(download).existsSync() ? download : FmEnv.primaryRoot;
  }

  /// Sıradaki görevleri eşzamanlılık sınırına kadar başlatır.
  void _pump() {
    if (_active.length >= maxConcurrent) return;
    for (final task in _tasks) {
      if (_active.length >= maxConcurrent) break;
      if (task.state != DownloadState.queued) continue;
      if (_active.containsKey(task.id)) continue;
      unawaited(_start(task.id));
    }
  }

  void pause(String id) {
    _active[id]?.cancel();
    _update(id, (t) => t.copyWith(
          state: DownloadState.paused,
          bytesPerSecond: 0,
        ));
    _pump();
  }

  void resume(String id) {
    _update(id, (t) => t.copyWith(state: DownloadState.queued, clearError: true));
    _pump();
  }

  /// İndirmeyi iptal eder ve yarım dosyayı siler.
  Future<void> cancel(String id) async {
    _active[id]?.cancel();
    final task = _find(id);
    if (task != null) {
      try {
        final partial = File(_partPath(task));
        if (partial.existsSync()) await partial.delete();
      } catch (_) {}
    }
    _update(id, (t) => t.copyWith(
          state: DownloadState.canceled,
          bytesPerSecond: 0,
        ));
    _pump();
  }

  /// Kaydı listeden düşürür (dosyaya dokunmaz).
  Future<void> remove(String id) async {
    _active[id]?.cancel();
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }

  /// Biten/iptal edilen tüm kayıtları temizler.
  Future<void> clearFinished() async {
    _tasks.removeWhere((t) => !t.state.isActive && t.state != DownloadState.paused);
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

  /// Yarım dosyanın yolu — bitene kadar bu adla yazılır.
  String _partPath(DownloadTask task) => '${task.destPath}.indiriliyor';

  Future<void> _start(String id) async {
    final task = _find(id);
    if (task == null) return;
    final active = _ActiveDownload();
    _active[id] = active;
    _update(id, (t) => t.copyWith(state: DownloadState.running));

    final partFile = File(_partPath(task));
    var received = 0;
    IOSink? sink;
    try {
      await partFile.parent.create(recursive: true);
      // Sürdürme: elde ne kadar varsa oradan iste.
      final existing = partFile.existsSync() ? partFile.lengthSync() : 0;
      final request = http.Request('GET', Uri.parse(task.url));
      if (existing > 0) request.headers['range'] = 'bytes=$existing-';
      // Bazı sunucular (GitHub dahil) User-Agent istemeyen isteği reddeder.
      request.headers['user-agent'] = 'DosyaOkuyucu/1.0';

      final response = await active.client.send(request);
      if (response.statusCode >= 400) {
        throw HttpException('Sunucu ${response.statusCode} döndü');
      }

      final resumed = existing > 0 && serverHonorsRange(response.statusCode);
      received = resumed ? existing : 0;
      // Sunucu aralığı yok saydıysa dosya BAŞTAN yazılır; yoksa yarım dosyanın
      // üstüne baştan veri gelir ve dosya sessizce bozulur.
      sink = partFile.openWrite(
          mode: resumed ? FileMode.append : FileMode.write);

      final contentLength = response.contentLength ?? -1;
      final total = contentLength < 0 ? -1 : received + contentLength;
      final serverName = resolveFileName(
        url: task.url,
        contentDisposition: response.headers['content-disposition'],
        contentType: response.headers['content-type'],
      );
      _update(id, (t) => t.copyWith(
            received: received,
            total: total,
            // Ad yalnız URL'den tahminse sunucununkini benimse.
            fileName: t.fileName == resolveFileName(url: t.url)
                ? serverName
                : t.fileName,
            destPath: t.fileName == resolveFileName(url: t.url)
                ? p.join(p.dirname(t.destPath), FileOps.sanitizeName(serverName))
                : t.destPath,
          ));

      var lastTick = DateTime.now().millisecondsSinceEpoch;
      var lastBytes = received;

      await for (final chunk in response.stream) {
        if (active.canceled) break;
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Saniyede bir bildir: her parçada setState çağırmak listeyi kastırır.
        if (now - lastTick >= 700) {
          final speed =
              ((received - lastBytes) * 1000 / (now - lastTick)).round();
          lastTick = now;
          lastBytes = received;
          _update(id, (t) => t.copyWith(
                received: received,
                bytesPerSecond: speed,
              ));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (active.canceled) {
        // Duraklatma/iptal: yarım dosya DURUR (sürdürülebilsin diye).
        return;
      }

      final current = _find(id);
      final finalPath = FileOps.uniquePath(current?.destPath ?? task.destPath);
      await partFile.rename(finalPath);
      FsEvents.changed();
      _update(id, (t) => t.copyWith(
            state: DownloadState.completed,
            received: received,
            total: t.hasTotal ? t.total : received,
            bytesPerSecond: 0,
            destPath: finalPath,
            fileName: p.basename(finalPath),
            clearError: true,
          ));
    } catch (e) {
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      // Yarım dosya SİLİNMEZ: sürdürme buna dayanıyor.
      _update(id, (t) => t.copyWith(
            state: DownloadState.failed,
            received: received,
            bytesPerSecond: 0,
            error: _message(e),
          ));
    } finally {
      _active.remove(id);
      active.close();
      _pump();
    }
  }

  static String _message(Object error) {
    if (error is SocketException) return 'İnternet bağlantısı yok';
    if (error is HttpException) return error.message;
    if (error is FileSystemException) {
      return 'Dosya yazılamadı: ${error.osError?.message ?? error.message}';
    }
    return error.toString();
  }
}

/// Süren bir indirmenin iptal edilebilir tutamağı.
class _ActiveDownload {
  final http.Client client = http.Client();
  bool canceled = false;

  void cancel() {
    canceled = true;
    // İstemciyi kapatmak akışı da keser (bekleyen `await for` biter).
    try {
      client.close();
    } catch (_) {}
  }

  void close() {
    try {
      client.close();
    } catch (_) {}
  }
}
