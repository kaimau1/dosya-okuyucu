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
import 'fm/library_screen.dart';
import 'fm/remote/nearby_screen.dart';
import '../services/fm/remote/ble_nearby.dart';
import '../services/fm/hidden_vault.dart';
import '../services/fm/secure_vault.dart';

/// **Bağlantı yolu beyaz listesi (G1.2 / B4).** `file:` bağlantısı ve ana ekran
/// kısayolu yolu dışarıdan (başka uygulamanın Intent'i) gelmiş olabilir; yalnız
/// ortak depolamadaki, uygulamanın özel dizinini ve kasayı göstermeyen yollar açılır.
bool isSafeLinkPath(String path) {
  if (path.isEmpty || path.contains('\u0000')) return false;
  if (!p.isAbsolute(path)) return false;
  // Ham `..` parçası (normalize sonrası görünmez olur): doğrudan reddet.
  if (p.split(path).contains('..')) return false;
  final n = p.normalize(path);
  final parts = p.split(n);
  // Uygulamanın özel dizini ve sistem alanları (/data/data, /data/user/0, /proc, /system …).
  const blockedRoots = {'data', 'proc', 'system', 'sys', 'dev', 'vendor', 'apex', 'etc'};
  if (parts.length > 1 && blockedRoots.contains(parts[1])) return false;
  // Başka uygulamaların / bizim harici özel dizinimiz (Android/data, Android/obb).
  for (var i = 0; i + 1 < parts.length; i++) {
    if (parts[i] == 'Android' && (parts[i + 1] == 'data' || parts[i + 1] == 'obb')) {
      return false;
    }
  }
  // Kasa klasörleri (şifreli kasa + gizli kasa).
  if (parts.contains(SecureVault.folderName) ||
      parts.contains(HiddenVault.folderName)) {
    return false;
  }
  return true;
}

/// `openAppLink` kabul listesi: bilinen `app:` adları, `davet:`/`davetsor:` ve güvenli `file:`.
bool isAllowedAppLink(String link) {
  if (link.startsWith('file:')) return isSafeLinkPath(link.substring(5));
  if (link.startsWith('davet:') || link.startsWith('davetsor:')) return true;
  return _knownAppLinks.contains(link);
}

const _knownAppLinks = {
  'app:nearby', 'app:scan', 'app:search', 'app:clean', 'app:bills',
  'app:downloads', 'app:recent', 'app:images', 'app:photos', 'app:videos',
  'app:files', 'app:library',
};

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
  if (!isAllowedAppLink(link)) return;
  if (link.startsWith('file:')) {
    final path = link.substring(5);
    if (path.isNotEmpty) await EntryOpener.open(context, path);
    return;
  }
  // Arka planda görünürlük bildirimi (kişisel derleme, ci/kisisel/NearbyBgService.kt):
  // "Kabul et" → `davet:`, bildirime dokunmak → `davetsor:` (uygulamada yeniden sorar).
  if (link.startsWith('davet:') || link.startsWith('davetsor:')) {
    final accepted = link.startsWith('davet:');
    final invite = BleInvite.decode(link.substring(accepted ? 6 : 9));
    if (invite != null) await push(NearbyScreen(invite: invite, inviteAccepted: accepted));
    return;
  }
  switch (link) {
    case 'app:nearby':
      await push(const NearbyScreen());
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
    case LibraryScreen.link:
      await push(const LibraryScreen());
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
