import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../services/fm/entry_opener.dart';
import '../../services/fm/job_queue.dart';
import 'ai_hub_screen.dart';
import 'browser_screen.dart';
import 'chat_cleanup_screen.dart';
import 'cleanup_screen.dart';
import 'duplicates_screen.dart';
import 'jobs_screen.dart';
import 'similar_screen.dart';

/// İşten **ilgili yere** gezinme — tek karar noktası.
///
/// Kullanıcı isteği 2026-07-31: İşlemler listesindeki kart, alt ilerleme şeridi
/// ve sistem bildirimi; üçü de dokunulunca işin gerçekten olduğu yere
/// götürmeli. Üç çağıran da buraya gelir ki davranış ayrışmasın.
///
/// Sıra (ilk tutan kazanır):
/// 1. işin bildirdiği [FmJobTarget] (tarama sonucunu gösteren ekran),
/// 2. işin **ürettiği dosyalar** (küçültülmüş video: dosyayı aç, birden
///    çoksa klasörünü aç),
/// 3. İşlemler ekranı — ama yalnız [fallbackToJobs] açıksa: İşlemler
///    ekranındaki kart kendi ekranını yeniden açmamalı.
Future<void> openJobTarget(
  BuildContext context,
  FmJob job, {
  bool fallbackToJobs = true,
}) async {
  final target = job.target;
  if (target != null && await _openTarget(context, target)) return;
  if (!context.mounted) return;
  if (await _openOutputs(context, job)) return;
  if (!context.mounted || !fallbackToJobs) return;
  await openJobsScreen(context);
}

/// İşin hedefi var mı — kart/şeritte "dokunulabilir mi" kararı buna bakar.
/// (Hedefi de çıktısı da olmayan iş için ok simgesi göstermek yalan olurdu.)
bool jobHasDestination(FmJob job) =>
    job.target != null || job.outputs.isNotEmpty;

Future<bool> _openTarget(BuildContext context, FmJobTarget target) async {
  switch (target.kind) {
    case FmJobTargetKind.duplicates:
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuplicatesScreen(roots: target.paths),
      ));
      return true;
    case FmJobTargetKind.similar:
      await Navigator.of(context).push(MaterialPageRoute(
        // Dosya listesi verilmiyor: ekran kuyruktaki **kendi** sonucunu
        // kapsam kimliğinden buluyor, tarama baştan başlamıyor.
        builder: (_) => SimilarScreen(
          scopeId: target.scopeId ?? 'all',
          title: target.title,
        ),
      ));
      return true;
    case FmJobTargetKind.cleanup:
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const CleanupScreen(),
      ));
      return true;
    case FmJobTargetKind.chatCleanup:
      await openChatCleanupScreen(context);
      return true;
    case FmJobTargetKind.folder:
      final path = target.paths.isEmpty ? null : target.paths.first;
      if (path == null || !Directory(path).existsSync()) return false;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BrowserScreen(path: path)),
      );
      return true;
    case FmJobTargetKind.aiHub:
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const AiHubScreen(),
      ));
      return true;
    case FmJobTargetKind.file:
      return _openFiles(context, target.paths);
  }
}

/// İşin ürettiği dosyalar: tek dosyayı açar, çoksa klasörünü gösterir.
Future<bool> _openOutputs(BuildContext context, FmJob job) async {
  final outputs = job.outputs;
  if (outputs.isEmpty) return false;
  if (outputs.length == 1) return _openFiles(context, outputs);
  final dir = p.dirname(outputs.first);
  if (!Directory(dir).existsSync()) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BrowserScreen(path: dir)),
  );
  return true;
}

Future<bool> _openFiles(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  // Diskte olmayan dosyayı açmaya çalışmak yerine klasörüne düşülür: iş
  // bittikten sonra kullanıcı dosyayı taşımış ya da silmiş olabilir.
  if (!File(paths.first).existsSync()) {
    final dir = p.dirname(paths.first);
    if (!Directory(dir).existsSync()) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrowserScreen(path: dir)),
    );
    return true;
  }
  await EntryOpener.open(context, paths.first, siblings: paths);
  return true;
}
