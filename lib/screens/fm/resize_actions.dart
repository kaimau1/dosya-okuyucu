import 'package:flutter/material.dart';

import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/job_queue.dart';
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
  final replaced = <String>[];

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
      if (result.afterBytes >= result.beforeBytes) {
        try {
          await FmEnv.trash.moveToTrash([result.outputPath]);
        } catch (_) {}
        failed++;
      } else {
        savedBytes += result.savedBytes;
        if (options.replaceOriginal) replaced.add(entry.path);
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
    try {
      await FmEnv.trash.moveToTrash(replaced);
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
