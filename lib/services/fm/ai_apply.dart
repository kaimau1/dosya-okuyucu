/// **Önerileri uygulama** — arka planda koşan, çakışmayı çözen toplu iş.
///
/// KÖK NEDEN (2026-08-11 kullanıcı, cihaz denemesi):
/// *"0 dosya düzenlendi, 304 atlandı · FileSystemException: bu adda bir öğe
/// zaten var"* ve *"analiz sonrası öneriler arka planda yapılmaya devam
/// etmiyor."*
///
/// İki ayrı hata vardı:
/// 1. **Ad çakışması.** Model iki farklı dosyaya aynı adı önerebiliyor
///    (kullanıcının ekranında iki satır da `Derya_Soyalp_Is_Sozlesmesi.doc`
///    diyordu) ya da önerilen ad klasörde zaten olabiliyor. `FileOps.rename`
///    böyle bir durumda haklı olarak hata atıyor; toplu akış bu hatayı
///    yakalayıp **bütün listeyi** düşürüyordu. Artık çakışan ad
///    `FileOps.uniquePath` ile numaralandırılıyor ("ad (2).doc") — dosya
///    yöneticisinin kopyala/taşı akışlarında zaten kullandığı kural.
/// 2. **Ön planda koşuyordu.** Uygulama arka plana alınınca (ya da ekran
///    kapanınca) iş duruyordu. Artık `JobQueue`ya giriyor: ön plan servisi,
///    bildirimde ilerleme, bildirimden iptal.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import 'ai_index.dart';
import 'file_ops.dart';
import 'job_queue.dart';

/// Uygulama sonucu (arayüz özet satırında gösterir).
class AiApplyResult {
  final int renamed;
  final int moved;
  final int failed;
  final String lastError;

  const AiApplyResult({
    this.renamed = 0,
    this.moved = 0,
    this.failed = 0,
    this.lastError = '',
  });

  int get changed => renamed + moved;
}

abstract final class AiApply {
  static const jobId = 'ai-suggestions';

  /// Süren işin ilerlemesi (0..1) — arayüz çubuğu buna bakar; iş bittiğinde
  /// sonuç [lastResult]e yazılır.
  static final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
  static final ValueNotifier<AiApplyResult?> lastResult =
      ValueNotifier<AiApplyResult?>(null);

  static bool _running = false;
  static bool get isRunning => _running;

  static AppStrings get _str => AppStrings.current;

  /// Önerileri **iş kuyruğunda** uygular. Aynı anda tek iş koşar.
  ///
  /// [importantRoot] önerilen klasörlerin altına açılacağı kök
  /// ("Önemli Dosyalar"). Ekrandan geliyor: servis katmanı arayüz sabitlerini
  /// bilmemeli.
  static void start(
    List<AiRecord> records, {
    required String importantRoot,
  }) {
    if (_running || records.isEmpty) return;
    _running = true;
    progress.value = 0;
    lastResult.value = null;

    final targets = List<AiRecord>.unmodifiable(records);
    JobQueue.instance.enqueue(
      id: jobId,
      title: _str.t('aiap.job_title'),
      total: targets.length,
      target: const FmJobTarget.aiHub(),
      run: (handle) async {
        try {
          lastResult.value = await _run(targets, importantRoot, handle);
        } finally {
          _running = false;
          progress.value = null;
        }
      },
    );
  }

  static Future<AiApplyResult> _run(
    List<AiRecord> targets,
    String importantRoot,
    JobHandle handle,
  ) async {
    var renamed = 0;
    var moved = 0;
    var failed = 0;
    var lastError = '';

    for (var i = 0; i < targets.length; i++) {
      if (handle.cancelled) break;
      final record = targets[i];
      handle.report(done: i, total: targets.length, detail: record.name);
      progress.value = targets.isEmpty ? null : i / targets.length;

      try {
        var path = record.path;
        if (!File(path).existsSync()) {
          // Dosya bu arada silinmiş/taşınmış: sessizce atlanır ve kaydı düşer.
          await AiIndex.remove(path);
          continue;
        }

        if (record.suggestedName.isNotEmpty &&
            record.suggestedName != p.basename(path)) {
          final wanted = p.join(p.dirname(path), record.suggestedName);
          // Çakışma = hata DEĞİL, numaralandırma sebebi.
          final free = _exists(wanted) ? FileOps.uniquePath(wanted) : wanted;
          path = await FileOps.rename(path, p.basename(free));
          renamed++;
        }

        if (record.suggestedFolder.isNotEmpty) {
          final dest = p.join(importantRoot, record.suggestedFolder);
          final dir = Directory(dest);
          if (!dir.existsSync()) await dir.create(recursive: true);
          final result = await FileOps.moveAll([path], dest);
          if (result.succeeded == 0) {
            failed++;
            if (result.errors.isNotEmpty) lastError = result.errors.first;
            continue;
          }
          moved++;
          final landed = p.join(dest, p.basename(path));
          // Hedefte ad çakıştıysa `moveAll` numaralandırmış olabilir; yeni yolu
          // kesin bilemediğimiz durumda kaydı düşürüyoruz (bir sonraki analiz
          // dosyayı yeni yerinde bulur). Yanlış yola işaret eden bir kayıt
          // bırakmak, kayıt bırakmamaktan daha kötü.
          if (File(landed).existsSync()) {
            await AiIndex.movePath(record.path, landed);
          } else {
            await AiIndex.remove(record.path);
          }
          continue;
        }

        await AiIndex.movePath(record.path, path);
      } catch (e) {
        failed++;
        lastError = '$e';
      }
    }

    handle.report(done: targets.length, detail: '');
    return AiApplyResult(
      renamed: renamed,
      moved: moved,
      failed: failed,
      lastError: lastError,
    );
  }

  static bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();
}
