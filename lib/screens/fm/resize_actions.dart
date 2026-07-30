import '../../core/l10n/app_strings.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/path_side_index.dart';
import '../../services/fm/video_transcode.dart';
import '../../widgets/fm/media_resize_sheet.dart';

/// Seçili fotoğraf/videoları **boyut düşürme kuyruğuna** koyar.
///
/// Ayarlar sorulur, sonra iş [JobQueue]'ya verilir: kullanıcı ekranı
/// kapatabilir, başka sekmeye geçebilir; ilerleme alt şeritte ve sistem
/// bildiriminde görünür.
///
/// Dönüş: kuyruğa iş konduysa true (arayüz "başladı" diyebilir).
Future<bool> startResizeJob(
  BuildContext context,
  List<FsEntry> entries,
) async {
  final media = [
    for (final e in entries)
      if (!e.isDir &&
          (e.category == FmCategory.image || e.category == FmCategory.video))
        e,
  ];
  final messenger = ScaffoldMessenger.of(context);
  // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
  final str = AppStrings.of(context);
  if (media.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(str.t('ra.media_only'))));
    return false;
  }

  final hasImages = media.any((e) => e.category == FmCategory.image);
  final hasVideos = media.any((e) => e.category == FmCategory.video);
  final options = await showMediaResizeSheet(
    context,
    hasImages: hasImages,
    hasVideos: hasVideos,
    fileCount: media.length,
  );
  if (options == null) return false;

  // Kimlik **tüm yollara + tüm ayarlara** bağlı: iki farklı seçim (ya da aynı
  // seçimin iki farklı ayarı) aynı anda kuyrukta durabilir, ama birebir aynı iş
  // iki kez başlatılamaz. Eskiden yalnız `dosya sayısı + ilk yol` bakılıyordu:
  // "3 fotoğrafı 720p yap" sürerken aynı üçünü 480p için başlatmak sessizce
  // yutuluyordu (2026-07-29 sadakat denetimi).
  final id = 'resize_${media.length}_'
      '${Object.hashAll([for (final e in media) e.path])}_'
      '${options.signature.hashCode}';
  final before = JobQueue.instance.find(id);
  final alreadyRunning = before != null && before.status.isActive;
  final job = JobQueue.instance.enqueue(
    id: id,
    title: media.length == 1
        ? str.t('ra.job_one', {'name': media.first.name})
        : str.t('ra.job_many', {'n': media.length}),
    total: media.length,
    run: (handle) => _run(media, options, handle),
  );
  // Metin durumu OKUR. Sabit "arka planda başladı" yazıyordu; oysa aynı iş zaten
  // sürüyorsa yenisi hiç açılmıyor ve kuyrukta başka bir iş varsa bu iş
  // BEKLİYOR — ikisinde de "başladı" demek yanlıştı (2026-07-29 denetimi).
  // Nereden takip edileceği YAZILIR: kullanıcı hatası 2026-07-30 — "nerede ne
  // oluyor göremiyorum". Şerit + ana ekrandaki İşlemler kutusu, ikisi de.
  messenger.showSnackBar(SnackBar(
      content: Text(str.t(alreadyRunning
          ? 'ra.already_running'
          : job.status == JobStatus.queued && JobQueue.instance.hasActive
              ? 'ra.queued'
              : 'ra.started'))));
  return true;
}

Future<void> _run(
  List<FsEntry> media,
  MediaResizeOptions options,
  JobHandle handle,
) async {
  var done = 0;
  var savedBytes = 0;
  var failed = 0;

  /// Kaç dosyada "özgünü çöpe at" isteği **bilerek uygulanmadı** (hareketli
  /// GIF / çok sayfalı TIFF / katmanlı PSD — tek kareye inen çıktı aslın yerini
  /// tutmaz). Özette yazılır: sessizce farklı davranmak kullanıcıyı dosyalarının
  /// silindiğini sanır durumda bırakırdı.
  var keptFrameLosing = 0;

  /// "Özgünü çöpe at" seçiliyse: (özgün yol → küçültülmüş çıktı) çiftleri.
  /// Etiket/açılma geçmişi çıktıya taşınsın diye yol da tutuluyor: kullanıcının
  /// dosyası bundan sonra çıktı olduğu için "Ayşe" etiketi onda olmalı, çöpe
  /// giden özgünde değil.
  final replaced = <({String original, String output})>[];

  // `finally`: iptal (JobCancelled) burada geçip gitmemeli. Kullanıcı 10
  // dosyanın 4'ü bittikten sonra "Durdur"a bastığında o 4 dosya diskte DURUYOR;
  // eskiden iptal `FsEvents.changed()`e ve özgünleri çöpe atma adımına
  // uğramadan dışarı fırlıyordu → yeni dosyalar hiçbir listede görünmüyor,
  // "Özgün dosyayı çöp kutusuna at" açıkken kullanıcının elinde hem özgün hem
  // küçültülmüş kopya kalıyordu (2026-07-29 sadakat denetimi).
  try {
    for (final entry in media) {
      handle.throwIfCancelled();
      handle.report(
        done: done,
        detail: '${done + 1}/${media.length} · ${entry.name}',
      );
      try {
        final result = entry.category == FmCategory.video
            ? await VideoTranscoder.run(
                entry.path,
                options,
                handle: handle,
                // Toplu işte hangi dosyada olduğumuz ilerleme satırında da
                // görünsün (dosya adı BAŞLIKTA zaten var, tek dosyada
                // tekrarlamak satırı boşuna uzatırdı).
                progressPrefix:
                    media.length > 1 ? '${done + 1}/${media.length}' : null,
              )
            : await ImageResizer.run(entry.path, options);
      // Çıktı KABUL EDİLEBİLİR mi? İki koşul birlikte aranır:
      //  (a) gerçekten küçüldü mü,
      //  (b) ortada gerçek bir dosya var mı (`afterBytes > 0`).
      //
      // (b) hayat kurtarır: `ResizeResult` çıktı yoksa `afterBytes`ı bilerek 0
      // yazıyor, oysa eski koşul yalnız `afterBytes >= beforeBytes` idi →
      // **0 >= 200 MB yanlış** olduğu için BOŞ/BOZUK çıktı en büyük başarı
      // sayılıyordu: "200 MB kazanıldı" yazıp, "Özgün dosyayı çöp kutusuna at"
      // açıkken 200 MB'lık aslı çöpe atıyordu. Kaydı yarıda kesilmiş (moov
      // bozuk) bir videoda ffmpeg 0 dönüş koduyla 3 saniyelik dosya bırakabilir
      // — bu senaryo cihazda çok sık (2026-07-29 sadakat denetimi, 2. tur).
      //
      // Küçültme işe yaramadıysa (çıktı daha büyük) çıktıyı BIRAKMA: kullanıcı
      // "boyut düşür" dedi, elinde iki büyük dosya kalmasın.
      //
      // Çöpe DEĞİL, doğrudan siliniyor: bu dosyayı saniyeler önce biz ürettik,
      // kullanıcı hiç görmedi ve işe yaramadığını ölçtük. Çöpe atmak kullanıcının
      // hiç bilmediği dosyalarla çöp kutusunu doldurmak olurdu (özgün dosyaya
      // ise dokunulmuyor — o hep yerinde).
        if (result.afterBytes <= 0 ||
            result.afterBytes >= result.beforeBytes) {
          try {
            final useless = File(result.outputPath);
            if (useless.existsSync()) useless.deleteSync();
          } catch (_) {}
          failed++;
        } else {
          savedBytes += result.savedBytes;
          // Çıktı KAYDEDİLDİ → kullanıcı onu bulabilsin. İşlemler ekranı bu
          // listeyi gösterir, dosya oradan tek dokunuşla açılır (kullanıcı
          // hatası 2026-07-30: "nereye gitti, nereden açacağım bilinmiyor").
          handle.addOutput(result.outputPath);
          if (options.replaceOriginal) {
            // Hareketli/çok sayfalı kaynakta özgün ASLA çöpe atılmaz: çıktı tek
            // kare, yani aslın yerini tutmuyor (bkz. `ImageResizer.mayLoseFrames`).
            if (ImageResizer.mayLoseFrames(entry.path)) {
              keptFrameLosing++;
            } else {
              replaced.add((original: entry.path, output: result.outputPath));
            }
          }
        }
      } on JobCancelled {
        rethrow;
      } catch (_) {
        failed++;
      }
      done++;
      // Toplam ilerleme dosya sayısına göre; tek video içinde yüzde bilgisi
      // ayrıntı satırında geliyor.
      handle.report(done: done, total: media.length);
    }
  } finally {
    if (replaced.isNotEmpty) {
      // SIRA ÖNEMLİ: etiket/geçmiş ÖNCE çıktıya taşınır, SONRA özgün çöpe gider.
      // Tersi olursa çöpe atma kaydı özgünle birlikte çöp klasörüne taşır ve
      // kullanıcının etiketi "silinmiş" bir dosyada kalır.
      for (final pair in replaced) {
        await PathSideIndex.moved(pair.original, pair.output);
      }
      try {
        await FmEnv.trash.moveToTrash([for (final r in replaced) r.original]);
      } catch (_) {}
    }
    FsEvents.changed();

    // Çıktıların bulunduğu klasör(ler) — özette YAZILIR. "Kazanıldı" demek
    // ama dosyanın nereye kaydedildiğini söylememek kullanıcıyı dosyasını
    // arar durumda bırakıyordu (kullanıcı hatası 2026-07-30). Çıktı her zaman
    // özgün dosyanın yanına gider; tek klasörse adı yazılır.
    final outputDirs = {for (final o in handle.outputs) p.dirname(o)};
    // İş kuyrukta, `context` yok → uygulama genelindeki dil okunur.
    final str = AppStrings.current;
    final parts = <String>[
      if (savedBytes > 0)
        str.t('ra.saved_bytes', {'size': FsPaths.humanSize(savedBytes)})
      else
        str.t('ra.no_gain'),
      if (outputDirs.length == 1)
        str.t('ra.saved_into', {'name': p.basename(outputDirs.first)})
      else if (outputDirs.length > 1)
        str.t('ra.saved_to', {'n': outputDirs.length}),
      if (failed > 0) str.t('ra.failed_count', {'n': failed}),
      // Kaç özgün dosya GERÇEKTEN çöpe gitti: kullanıcı bunu bilmeli, hele
      // iptalde (10 dosyanın 4'ü işlendiyse 4 özgün çöpte, 6'sı yerinde).
      if (replaced.isNotEmpty)
        str.t('ra.originals_trashed', {'n': replaced.length}),
      if (keptFrameLosing > 0)
        str.t('ra.frame_losing_kept', {'n': keptFrameLosing}),
      // İptalde sayılar yarımdır; "kaç dosyada kaldı" bilgisi olmadan
      // kullanıcı kalanların işlenip işlenmediğini bilemez.
      if (handle.cancelled)
        str.t('ra.stopped_at', {'n': done, 'total': media.length}),
    ];
    handle.report(detail: parts.join(' · '));
  }
}
