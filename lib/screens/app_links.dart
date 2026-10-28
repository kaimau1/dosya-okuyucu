import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/fs_entry.dart';
import '../services/fm/media_library.dart';
import 'fm/photos_screen.dart';

import '../widgets/scan_flow.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/fm_env.dart';
import 'fm/bills_screen.dart';
import 'fm/downloads_screen.dart';
import 'fm/open_history_screen.dart';
import 'fm/cleanup_screen.dart';
import 'fm/search_screen.dart';
import '../core/l10n/app_strings.dart';

/// **Uygulama içi bağlantılar** (2026-10-18): ana ekran widget'ları ve yerel
/// iş bildirimleri uygulamayı bir bağlantıyla açar. Biçim:
/// - `app:scan` belge tara · `app:search` ara · `app:clean` yer aç ·
///   `app:bills` faturalar
/// - `app:downloads` İndirilenler · `app:recent` Son açılanlar (başlatıcı
///   kısayolları, Faz 19)
/// - `app:images` Görüntüler (foto + video) · `app:photos` Fotoğraflar ·
///   `app:videos` Videolar (ana ekran kısayolları, 2026-10-28)
/// - `file:/tam/yol` o dosyayı açar.
///
/// Tanınmayan bağlantı sessizce yok sayılır (eski bir widget sürümü).
Future<void> openAppLink(BuildContext context, String link) async {
  Future<void> push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  if (link.startsWith('file:')) {
    final path = link.substring(5);
    if (path.isNotEmpty) await EntryOpener.open(context, path);
    return;
  }
  switch (link) {
    case 'app:scan':
      await ScanFlow.run(context);
    case 'app:search':
      await push(SearchScreen(rootLabel: context.t('fm.all_files')));
    case 'app:clean':
      await push(const CleanupScreen());
    case 'app:bills':
      await push(const BillsScreen());
    // Başlatıcı kısayolları (Faz 19).
    case 'app:downloads':
      await FmEnv.ensureInit();
      if (!context.mounted) return;
      await push(DownloadsScreen(path: p.join(FmEnv.primaryRoot, 'Download')));
    case 'app:recent':
      await push(const OpenHistoryScreen());
    case 'app:images' || 'app:photos' || 'app:videos':
      await FmEnv.ensureInit();
      if (!context.mounted) return;
      final locked = context.read<AppState>().fmLockedFolders;
      final cats = switch (link) {
        'app:photos' => [FmCategory.image],
        'app:videos' => [FmCategory.video],
        _ => [FmCategory.image, FmCategory.video],
      };
      await push(PhotosScreen(
        title: context.t(switch (link) {
          'app:photos' => 'fm.photos',
          'app:videos' => 'enum.cat_video',
          _ => 'fm.media_all',
        }),
        scopeId: link == 'app:images'
            ? 'depolama-media'
            : 'depolama-${cats.first.name}',
        files: const [],
        loadAll: () async {
          final parts = await Future.wait([
            for (final c in cats)
              MediaLibrary.categoryFiles(c, lockedFolders: locked),
          ]);
          return [for (final l in parts) ...l]
            ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
        },
      ));
  }
}
