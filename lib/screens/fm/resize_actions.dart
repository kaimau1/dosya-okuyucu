import 'dart:io';

import 'package:flutter/material.dart';

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
  if (media.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Boyut düşürme yalnız fotoğraf ve videolarda '
            'yapılabilir.')));
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

  // Kimlik dosya kümesine bağlı: iki farklı seçim aynı anda kuyrukta durabilir,
  // ama aynı seçim iki kez başlatılamaz.
  final id = 'resize_${media.length}_${media.first.path.hashCode}';
  JobQueue.instance.enqueue(
    id: id,
    title: media.length == 1
        ? 'Boyut düşürülüyor: ${media.first.name}'
        : '${media.length} dosyanın boyutu düşürülüyor',
    total: media.length,
    run: (handle) => _run(media, options, handle),
  );
  messenger.showSnackBar(const SnackBar(
      content: Text('İşlem arka planda başladı. İlerlemeyi alttaki '
          'şeritten izleyebilirsin.')));
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

  /// "Özgünü çöpe at" seçiliyse: (özgün yol → küçültülmüş çıktı) çiftleri.
  /// Etiket/açılma geçmişi çıktıya taşınsın diye yol da tutuluyor: kullanıcının
  /// dosyası bundan sonra çıktı olduğu için "Ayşe" etiketi onda olmalı, çöpe
  /// giden özgünde değil.
  final replaced = <({String original, String output})>[];

  for (final entry in media) {
    handle.throwIfCancelled();
    handle.report(
      done: done,
      detail: '${done + 1}/${media.length} · ${entry.name}',
    );
    try {
      final result = entry.category == FmCategory.video
          ? await VideoTranscoder.run(entry.path, options, handle: handle)
          : await ImageResizer.run(entry.path, options);
      // Küçültme işe yaramadıysa (çıktı daha büyük) çıktıyı BIRAKMA: kullanıcı
      // "boyut düşür" dedi, elinde iki büyük dosya kalmasın.
      //
      // Çöpe DEĞİL, doğrudan siliniyor: bu dosyayı saniyeler önce biz ürettik,
      // kullanıcı hiç görmedi ve işe yaramadığını ölçtük. Çöpe atmak kullanıcının
      // hiç bilmediği dosyalarla çöp kutusunu doldurmak olurdu (özgün dosyaya
      // ise dokunulmuyor — o hep yerinde).
      if (result.afterBytes >= result.beforeBytes) {
        try {
          final useless = File(result.outputPath);
          if (useless.existsSync()) useless.deleteSync();
        } catch (_) {}
        failed++;
      } else {
        savedBytes += result.savedBytes;
        if (options.replaceOriginal) {
          replaced.add((original: entry.path, output: result.outputPath));
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

  final parts = <String>[
    if (savedBytes > 0)
      '${FsPaths.humanSize(savedBytes)} kazanıldı'
    else
      'Kazanç olmadı',
    if (failed > 0) '$failed dosya küçültülemedi',
  ];
  handle.report(detail: parts.join(' · '));
}
