import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/drive_file.dart';
import 'drive_cache.dart';

/// Yerel kopya ile Drive sürümünün karşılaştırma sonucu.
enum DriveSyncState {
  /// İkisi de indirildiği gibi.
  inSync,

  /// Yalnız telefondaki kopya değişti → Drive'a yüklenebilir.
  localChanged,

  /// Yalnız Drive'daki değişti → yeniden indirilmeli.
  remoteChanged,

  /// İkisi de değişti → kullanıcı seçer (çakışma).
  conflict,
}

/// Çakışmada kullanıcının seçimi.
enum DriveConflictChoice { keepBoth, usePhone, useDrive }

/// **Drive çevrimdışı kopya + çakışma çözümü** (Faz 41 / madde 2).
///
/// * **Sabitleme:** "Çevrimdışı kullan" denen dosyanın kopyası önbellek
///   budamasında ([DriveCache.prune] `keep`) SİLİNMEZ.
/// * **Taban kaydı:** her indirmede `<kimlik>/.base.json` = (Drive değişme
///   zamanı, yerel değişme zamanı). Sonraki açılışta iki taraf tabanla
///   karşılaştırılır ([decide]) — kim değişti, ikisi mi?
/// Kayıtlar uygulamanın kendi klasöründe; dosya içeriği/kimlik bilgisi
/// dışarı gitmez (KVKK).
abstract final class DriveOffline {
  static const _pinsFile = 'offline_pins.json';
  static const _baseFile = '.base.json';

  /// Saf karar ([tolMs]: dosya sistemi zaman yuvarlaması payı).
  static DriveSyncState decide({
    required int localMs,
    required int baseLocalMs,
    required int remoteMs,
    required int baseRemoteMs,
    int tolMs = 2000,
  }) {
    final local = localMs - baseLocalMs > tolMs;
    final remote = remoteMs - baseRemoteMs > tolMs;
    if (local && remote) return DriveSyncState.conflict;
    if (local) return DriveSyncState.localChanged;
    if (remote) return DriveSyncState.remoteChanged;
    return DriveSyncState.inSync;
  }

  /// "İkisini de tut": telefondaki kopyanın Drive'a yükleneceği ad
  /// (`Rapor.docx` → `Rapor (telefon).docx`).
  static String keepBothName(String name, String suffix) {
    final ext = p.extension(name);
    final base = ext.isEmpty ? name : name.substring(0, name.length - ext.length);
    return '$base ($suffix)$ext';
  }

  // ── Sabitlenenler ────────────────────────────────────────────────────────
  static Set<String> pins(String root) {
    try {
      final f = File(p.join(root, _pinsFile));
      if (!f.existsSync()) return {};
      return {for (final v in jsonDecode(f.readAsStringSync()) as List) '$v'};
    } catch (_) {
      return {};
    }
  }

  static void setPinned(String root, String id, bool on) {
    final now = pins(root);
    if (on) {
      now.add(id);
    } else {
      now.remove(id);
    }
    try {
      Directory(root).createSync(recursive: true);
      File(p.join(root, _pinsFile)).writeAsStringSync(jsonEncode(now.toList()));
    } catch (_) {
      // Bilinçli: yazılamazsa sabitleme yalnız bu oturumda kaybolur.
    }
  }

  // ── Taban ────────────────────────────────────────────────────────────────
  /// İndirmeden hemen sonra çağrılır.
  static void recordBase(DriveFile file, String root) {
    final local = File(DriveCache.pathFor(file, root));
    if (!local.existsSync()) return;
    try {
      File(p.join(DriveCache.dirFor(file, root), _baseFile)).writeAsStringSync(
          jsonEncode({
        'remote': file.modifiedAtMs,
        'local': local.statSync().modified.millisecondsSinceEpoch,
      }));
    } catch (_) {}
  }

  /// Önbellekteki kopyanın durumu; kopya ya da taban yoksa null.
  static DriveSyncState? stateOf(DriveFile file, String root) {
    final local = File(DriveCache.pathFor(file, root));
    final base = File(p.join(DriveCache.dirFor(file, root), _baseFile));
    if (!local.existsSync() || !base.existsSync()) return null;
    try {
      final m = jsonDecode(base.readAsStringSync()) as Map;
      return decide(
        localMs: local.statSync().modified.millisecondsSinceEpoch,
        baseLocalMs: (m['local'] as num).toInt(),
        remoteMs: file.modifiedAtMs,
        baseRemoteMs: (m['remote'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
