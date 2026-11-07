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
///
/// 2026-11-07 (kullanıcı: *"kendi kendine önemli dosyalara taşıma yapıyor"*):
/// klasör önerileri eskiden **Önemli Dosyalar/<klasör>** altına taşınıyordu —
/// "önemli" işareti (yıldız, silme koruması) kullanıcı istemeden yüzlerce
/// dosyaya yayılıyordu. Artık hedef sıradan **Documents/<klasör>**; ad ve
/// klasör ayrı ayrı seçilir ve iş yalnız onay penceresinden başlar.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import 'ai_apply_log.dart';
import 'ai_index.dart';
import 'chat_media_guard.dart';
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

  /// Klasör önerilerinin açılacağı kök: `<bellek>/Documents`.
  static String folderRootIn(String volumeRoot) =>
      p.join(volumeRoot, 'Documents');

  /// Bu kayıt seçilen öneri türleriyle bir değişikliğe yol açar mı?
  static bool wants(AiRecord r, {required bool rename, required bool move}) =>
      r.hasSuggestion &&
      ((rename && r.hasNameSuggestion) || (move && r.hasFolderSuggestion));

  /// Önerileri **iş kuyruğunda** uygular. Aynı anda tek iş koşar.
  ///
  /// [folderRoot] klasör önerilerinin altına açılacağı kök (bkz.
  /// [folderRootIn]). [rename]/[move] kullanıcının onay penceresinde seçtiği
  /// öneri türleri; seçilmeyen tür hiç uygulanmaz.
  static void start(
    List<AiRecord> records, {
    required String folderRoot,
    bool rename = true,
    bool move = true,
  }) {
    final targets = List<AiRecord>.unmodifiable(
        records.where((r) => wants(r, rename: rename, move: move)));
    if (_running || targets.isEmpty) return;
    _running = true;
    progress.value = 0;
    lastResult.value = null;

    JobQueue.instance.enqueue(
      id: jobId,
      title: _str.t('aiap.job_title'),
      name: _str.t('aiap.job_name'),
      total: targets.length,
      target: const FmJobTarget.aiHub(),
      run: (handle) async {
        try {
          lastResult.value = await _run(targets, folderRoot, handle,
              rename: rename, move: move);
        } finally {
          _running = false;
          progress.value = null;
        }
      },
    );
  }

  static Future<AiApplyResult> _run(
    List<AiRecord> targets,
    String folderRoot,
    JobHandle handle, {
    required bool rename,
    required bool move,
  }) async {
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

        // Sohbet medyası (WhatsApp/Telegram…): ad/yer değişirse sohbet dosyayı
        // kaybeder. Eski kayıtlarda öneri durabilir → burada da durdurulur.
        if (ChatMediaGuard.isChatPath(path)) continue;

        if (rename &&
            record.hasNameSuggestion &&
            record.suggestedName != p.basename(path)) {
          final wanted = p.join(p.dirname(path), record.suggestedName);
          // Çakışma = hata DEĞİL, numaralandırma sebebi.
          final free = _exists(wanted) ? FileOps.uniquePath(wanted) : wanted;
          path = await FileOps.rename(path, p.basename(free));
          renamed++;
          // Kayıt HEMEN yeni yola: ardından taşıma başarısız olursa eski
          // yolda (artık olmayan) öneriyle hayalet satır kalıyordu.
          await AiIndex.movePath(record.path, path);
          if (!(move && record.hasFolderSuggestion)) {
            await AiApplyLog.add(record.path, path);
          }
        }

        if (move && record.hasFolderSuggestion) {
          final dest = p.join(folderRoot, _safeFolder(record.suggestedFolder));
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
          await AiApplyLog.add(record.path, landed);
          // Hedefte ad çakıştıysa `moveAll` numaralandırmış olabilir; yeni yolu
          // kesin bilemediğimiz durumda kaydı düşürüyoruz (bir sonraki analiz
          // dosyayı yeni yerinde bulur). Yanlış yola işaret eden bir kayıt
          // bırakmak, kayıt bırakmamaktan daha kötü.
          if (File(landed).existsSync()) {
            await AiIndex.movePath(path, landed);
          } else {
            await AiIndex.remove(path);
          }
          continue;
        }

        if (path == record.path) await AiIndex.movePath(record.path, path);
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

  /// Model "Faturalar/2026" ya da "../x" yazabilir: tek düzey, güvenli ad.
  static String _safeFolder(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
    return clean.isEmpty || clean == '.' || clean == '..' ? 'Diğer' : clean;
  }

  static bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();
}
