import 'dart:async';
import '../../core/l10n/app_strings.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/ffmpeg_video.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/path_side_index.dart';
import '../../services/fm/video_transcode.dart';
import '../../widgets/fm/media_resize_sheet.dart';
import '../../core/snack.dart';

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
    showSnackOn(messenger, str.t('ra.media_only'));
    return false;
  }

  final hasImages = media.any((e) => e.category == FmCategory.image);
  final hasVideos = media.any((e) => e.category == FmCategory.video);
  // Kaynak özellikleri ÖLÇÜLÜR (çözünürlük/kare sayısı/süre) — ayar sayfası
  // "şu an ne var, sonra ne olacak" diyebilsin (kullanıcı isteği 2026-08-07).
  final sources = await _describeSources(media);
  if (!context.mounted) return false;
  final options = await showMediaResizeSheet(
    context,
    hasImages: hasImages,
    hasVideos: hasVideos,
    fileCount: media.length,
    sources: sources,
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
    // Tarif KAYDEDİLİR: uygulama iş sürerken kapanırsa kullanıcı İşlemler
    // ekranından "Devam et" diyebilsin (2026-08-07 bulgusu).
    recipe: JobRecipe(resizeJobKind, {
      'paths': [for (final e in media) e.path],
      'options': options.toJson(),
    }),
    run: (handle) => _run(media, options, handle),
  );
  // Metin durumu OKUR. Sabit "arka planda başladı" yazıyordu; oysa aynı iş zaten
  // sürüyorsa yenisi hiç açılmıyor ve kuyrukta başka bir iş varsa bu iş
  // BEKLİYOR — ikisinde de "başladı" demek yanlıştı (2026-07-29 denetimi).
  // Nereden takip edileceği YAZILIR: kullanıcı hatası 2026-07-30 — "nerede ne
  // oluyor göremiyorum". Şerit + ana ekrandaki İşlemler kutusu, ikisi de.
  showSnackOn(messenger, str.t(alreadyRunning
          ? 'ra.already_running'
          : job.status == JobStatus.queued && JobQueue.instance.hasActive
              ? 'ra.queued'
              : 'ra.started'));
  return true;
}

/// Seçilen dosyaların özelliklerini ölçer.
///
/// Video için ffprobe (çözünürlük/kare sayısı/süre), görüntü için yalnız
/// dosya boyutu. **En çok [_probeLimit] dosya** ölçülür: 200 fotoğraflık bir
/// seçimde her dosyayı ölçmek ayar sayfasını saniyelerce geciktirirdi ve
/// sayfada zaten yalnız ilki gösteriliyor. Ölçüm başarısızsa liste boş döner
/// ve sayfa eskisi gibi çalışır — kart çizilmez, iş engellenmez.
const int _probeLimit = 5;

Future<List<MediaSourceInfo>> _describeSources(List<FsEntry> media) async {
  final out = <MediaSourceInfo>[];
  // Video ÖNCE: kart ilk öğeyi gösteriyor ve asıl merak edilen video
  // (fotoğrafta çözünürlük/kare sayısı sorusu yok).
  final ordered = [
    ...media.where((e) => e.category == FmCategory.video),
    ...media.where((e) => e.category != FmCategory.video),
  ];
  for (final entry in ordered.take(_probeLimit)) {
    final isVideo = entry.category == FmCategory.video;
    VideoProbe? probe;
    ({int width, int height})? photo;
    if (isVideo) {
      try {
        probe = await FfmpegVideo.probe(entry.path);
      } catch (_) {
        // ffprobe yoksa/düşerse ölçüsüz devam: boyut yine gösterilir.
      }
    } else {
      // Fotoğrafın ölçüsü de okunur (yalnız başlık): tahmini boyut ancak
      // piksel sayısı bilinerek hesaplanabiliyor.
      photo = await ImageResizer.probeSize(entry.path);
    }
    out.add(MediaSourceInfo(
      name: entry.name,
      sizeBytes: entry.sizeBytes,
      isVideo: isVideo,
      width: probe?.width ?? photo?.width ?? 0,
      height: probe?.height ?? photo?.height ?? 0,
      fps: probe?.fps,
      durationMs: probe?.durationMs ?? 0,
    ));
  }
  // Toplam boyut kartta yazılıyor: ölçülmeyen dosyalar da sayılsın.
  for (final entry in ordered.skip(_probeLimit)) {
    out.add(MediaSourceInfo(
      name: entry.name,
      sizeBytes: entry.sizeBytes,
      isVideo: entry.category == FmCategory.video,
    ));
  }
  return out;
}

/// Boyut düşürme işinin tarif türü (bkz. [JobRecipe]).
const String resizeJobKind = 'resize';

/// Yarıda kalan boyut düşürme işini yeniden kurabilmek için kaydı yapar.
/// Uygulama açılışında bir kez çağrılır (`main.dart`).
void registerResizeJobRunner() {
  JobRecipes.register(resizeJobKind, (handle, params) async {
    final paths = [
      for (final path in (params['paths'] as List? ?? const [])) '$path',
    ];
    final options = MediaResizeOptions.fromJson(params['options']);
    // Biten dosyalar atlanır: on videonun dördü kodlanmışsa beşinciden devam
    // edilir, dördü baştan kodlanmaz.
    final skip = ((params['skip'] as num?)?.toInt() ?? 0).clamp(0, paths.length);
    final media = <FsEntry>[];
    for (final path in paths.skip(skip)) {
      final entry = FsEntry.ofPath(path);
      // Aradan silinmiş/taşınmış dosya sessizce atlanır: iş "bulunamadı"
      // diye tamamen düşmemeli, kalanlar yine küçültülmeli.
      if (entry != null) media.add(entry);
    }
    if (media.isEmpty) {
      // Kalan dosya kalmadıysa iş BİTMİŞTİR; sessiz çıkmak kartı "0/0" ile
      // bırakırdı. Sayaç tamamlanmış olarak yazılır.
      handle.report(done: paths.length, total: paths.length);
      return;
    }
    // İlerleme **mutlak** bildirilir: dördü bitmiş on dosyalık iş 4/10'dan
    // devam eder. Eskiden `_run` her zaman 0'dan sayıyor ve `total`ı kalan
    // dosya sayısına düşürüyordu → kullanıcı "devam et 0'dan başlıyor" diyordu
    // (2026-08-07). Dahası bir sonraki "Devam et" `job.done`u okuduğu için
    // yanlış yerden (baştan) devam ederdi.
    await _run(media, options, handle, offset: skip, totalFiles: paths.length);
  });
}

/// [offset] daha önceki bir koşuda BİTMİŞ dosya sayısı ("Devam et"), [totalFiles]
/// işin başındaki toplam. İkisi de ilerlemenin mutlak bildirilmesi için:
/// kullanıcı 10 dosyalık işi 4'te bıraktıysa çubuk 4/10'dan sürmelidir.
Future<void> _run(
  List<FsEntry> media,
  MediaResizeOptions options,
  JobHandle handle, {
  int offset = 0,
  int totalFiles = 0,
}) async {
  final total = totalFiles > 0 ? totalFiles : offset + media.length;
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
        done: offset + done,
        total: total,
        detail: '${offset + done + 1}/$total · ${entry.name}',
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
                    total > 1 ? '${offset + done + 1}/$total' : null,
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
          // "Yaptıklarım" defteri: küçültülen dosya, kazanılan yerle birlikte
          // (istek 2026-08-07 — "video boyutu düşürdük, düşen video orada").
          unawaited(ActivityLog.add(
            entry.category == FmCategory.video
                ? ActivityKind.videoResize
                : ActivityKind.imageResize,
            result.outputPath,
            detail: '${FsPaths.humanSize(result.beforeBytes)} → '
                '${FsPaths.humanSize(result.afterBytes)}',
          ));
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
      handle.report(done: offset + done, total: total);
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
        str.t('ra.stopped_at', {'n': offset + done, 'total': total}),
    ];
    handle.report(detail: parts.join(' · '));
  }
}
