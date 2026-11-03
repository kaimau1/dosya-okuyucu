import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/user_error.dart';
import '../image_enhance.dart';
import 'fs_events.dart';
import 'job_queue.dart';

/// Biten bir iyileştirme: özgün → yeni kopya.
class EnhanceResult {
  final String source;
  final String output;
  const EnhanceResult(this.source, this.output);
}

/// **Arka planda görsel iyileştirme** (kullanıcı isteği 2026-11-03: *"yeni
/// yapay zekâlı iyileştirme arka planda yapılabilsin, üretilende yenisi ile
/// eskisi beraber görülmeli; şu an üretiliyor ve kayboluyor"*).
///
/// Eskiden iş galerinin modal "İyileştiriliyor…" penceresine bağlıydı: ekran
/// kapanınca sonuç yalnız galerinin o anki listesine eklenmiş olarak
/// kalıyordu, başka hiçbir yerde iz yoktu. Şimdi:
/// * iş [JobQueue.track] ile izlenir → alt şerit, İşlemler ekranı ve sistem
///   bildirimi (ön plan servisi uygulamadan çıkınca da korur), "Durdur";
/// * çıktı özgünüyle çift olarak kaydedilir (`outputSources`) → bildirime /
///   karta dokunmak "önce / sonra" karşılaştırmasını açar
///   ([FmJobTargetKind.enhance]);
/// * dosya galeriye bildirilir ([FsEvents]) ve açık ekranlar
///   [results] akışından haber alır.
abstract final class EnhanceJobs {
  static final _results = StreamController<EnhanceResult>.broadcast();

  /// Biten işler (açık galeri yeni kopyayı listesine ekler).
  static Stream<EnhanceResult> get results => _results.stream;

  /// Test kancası: gerçek iyileştirme yerine çağrılır.
  static Future<String> Function(String path, EnhanceKind kind,
      {void Function(double ratio)? onProgress,
      Future<void>? cancelSignal})? debugRun;

  static String _kindLabel(EnhanceKind k) => AppStrings.current.t(switch (k) {
        EnhanceKind.auto => 'gal.enh_auto',
        EnhanceKind.sharpen => 'gal.enh_sharpen',
        EnhanceKind.denoise => 'gal.enh_denoise',
        EnhanceKind.upscale => 'gal.enh_ai',
      });

  /// İşi başlatır ve hemen döner. Aynı görsel aynı yöntemle zaten
  /// iyileştiriliyorsa ikinci iş açılmaz (null döner).
  static TrackedJob? start(String path, EnhanceKind kind) {
    final id = 'enhance:${kind.name}:$path';
    final queue = JobQueue.instance;
    if (queue.find(id)?.status.isActive ?? false) return null;
    final str = AppStrings.current;
    final job = queue.track(
      id: id,
      title: str.t('gal.enh_job'),
      name: p.basename(path),
      detail: _kindLabel(kind),
      total: 100,
      target: FmJobTarget(FmJobTargetKind.enhance, paths: [path]),
    );
    unawaited(_run(job, path, kind));
    return job;
  }

  static Future<void> _run(TrackedJob job, String path, EnhanceKind kind) async {
    final run = debugRun ?? ImageEnhance.enhanceFile;
    // "Durdur" kuyruğu değiştirir (notifyListeners) → sinyal hemen tetiklenir.
    final stop = Completer<void>();
    void watch() {
      if (job.cancelRequested && !stop.isCompleted) stop.complete();
    }

    JobQueue.instance.addListener(watch);
    try {
      final out = await run(
        path,
        kind,
        onProgress: (r) => job.report(done: (r * 100).floor()),
        cancelSignal: stop.future,
      );
      if (job.cancelRequested) {
        try {
          File(out).deleteSync();
        } catch (_) {}
        await job.stopped();
        return;
      }
      FsEvents.changed([out]); // galeriye de bildirir (MediaScan)
      job.addOutput(out, source: path);
      await job.complete(
          detail: AppStrings.current
              .t('gal.enh_saved', {'name': p.basename(out)}));
      _results.add(EnhanceResult(path, out));
    } on EnhanceCancelled {
      await job.stopped();
    } catch (e) {
      await job.fail(userErrorText(e));
    } finally {
      JobQueue.instance.removeListener(watch);
    }
  }
}
