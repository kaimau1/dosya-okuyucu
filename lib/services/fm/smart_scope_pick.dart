import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../gemini_decisions.dart';
import 'ai_scope.dart';
import 'fs_scan.dart';
import 'smart_sort.dart';
import 'smart_sort_input.dart';

/// Akıllı düzenin dosya **türü** grupları ("Neyi düzenleyelim?" ekranı).
enum SmartGroup { docs, screenshots, images, audio, videos, packages }

/// Dosyanın geldiği **yer** (klasör kaynağı). Ekran görüntüsü tür olarak
/// ayrıca seçildiği için yer listesinde "Diğer"e düşer.
enum SmartSource { camera, whatsapp, telegram, download, other }

/// Bir grup × yer hücresinin sayıları.
class SmartScopeCell {
  final int total;
  final int remaining;
  const SmartScopeCell(this.total, this.remaining);
}

/// Kapsam sayımı: (tür, yer) → toplam / kalan. Sayım yalnız cihazda.
class SmartScopeCounts {
  final Map<(SmartGroup, SmartSource), SmartScopeCell> cells;
  const SmartScopeCounts(this.cells);

  static const empty = SmartScopeCounts({});

  ({int total, int remaining}) sum(
      {bool Function(SmartGroup g, SmartSource s)? where}) {
    var t = 0, r = 0;
    cells.forEach((k, v) {
      if (where == null || where(k.$1, k.$2)) {
        t += v.total;
        r += v.remaining;
      }
    });
    return (total: t, remaining: r);
  }

  int groupTotal(SmartGroup g) => sum(where: (x, _) => x == g).total;
  int sourceTotal(SmartSource s) => sum(where: (_, y) => y == s).total;
}

/// **"Neyi düzenleyelim?"** — Akıllı düzen kapsamı (2026-11-22, kullanıcı:
/// "fotoğraflar dahil edilsin mi, belgeler dahil edilsin mi, şu klasörler…
/// kişi istediği yeri dahil eder"). Aşama 1: sunucusuz; seçim + sayım +
/// tahmin. Kamera yeri mevcut [SmartSort.includeCamera] ayarıdır (kök
/// klasörü de o açar); öteki seçimler burada saklanır.
abstract final class SmartScopePick {
  static const prefSkipGroups = 'smart_scope_skip_groups';
  static const prefSkipSources = 'smart_scope_skip_sources';

  static final Set<SmartGroup> _skipGroups = {};
  static final Set<SmartSource> _skipSources = {};
  static bool _read = false;

  /// Seçim değişince artar (ekran dinler).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Önce değerli dosyalar: ücretsiz/paket hakkı belgeye ve ekran
  /// görüntüsüne harcansın, video en sonda.
  static const priority = [
    SmartGroup.docs,
    SmartGroup.screenshots,
    SmartGroup.images,
    SmartGroup.audio,
    SmartGroup.videos,
    SmartGroup.packages,
  ];

  static SmartGroup? groupOf(String path) {
    final kind = SmartSortInput.kindOf(path);
    return switch (kind) {
      null => null,
      SmartInputKind.media =>
        GeminiDecisions.mediaFor(path)?.type == 'image'
            ? (bucketForPath(path) == MediaBucket.screenshot
                ? SmartGroup.screenshots
                : SmartGroup.images)
            : SmartGroup.docs,
      SmartInputKind.audio => SmartGroup.audio,
      SmartInputKind.video => SmartGroup.videos,
      SmartInputKind.meta => SmartGroup.packages,
      _ => SmartGroup.docs,
    };
  }

  static SmartSource sourceOf(String path) => switch (bucketForPath(path)) {
        MediaBucket.camera => SmartSource.camera,
        MediaBucket.whatsapp => SmartSource.whatsapp,
        MediaBucket.telegram => SmartSource.telegram,
        MediaBucket.download => SmartSource.download,
        _ => SmartSource.other,
      };

  static Future<void> read() async {
    if (_read) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _skipGroups
        ..clear()
        ..addAll([
          for (final n in prefs.getStringList(prefSkipGroups) ?? const [])
            for (final g in SmartGroup.values)
              if (g.name == n) g,
        ]);
      _skipSources
        ..clear()
        ..addAll([
          for (final n in prefs.getStringList(prefSkipSources) ?? const [])
            for (final s in SmartSource.values)
              if (s.name == n) s,
        ]);
    } catch (_) {
      // Bilinçli: okunamazsa her şey dahil (eski davranış).
    }
    _read = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _skipGroups.clear();
    _skipSources.clear();
    _read = false;
  }

  /// Kamera dışındaki yer seçimi + tür seçimi. Kamera [SmartSort] ayarında.
  static bool groupOn(SmartGroup g) => !_skipGroups.contains(g);
  static bool sourceOn(SmartSource s) => s == SmartSource.camera
      ? SmartSort.includeCamera
      : !_skipSources.contains(s);

  static Future<void> setGroup(SmartGroup g, bool on) async {
    await read();
    on ? _skipGroups.remove(g) : _skipGroups.add(g);
    await _save();
  }

  static Future<void> setSource(SmartSource s, bool on) async {
    await read();
    if (s == SmartSource.camera) {
      await SmartSort.setSettings(camera: on);
    } else {
      on ? _skipSources.remove(s) : _skipSources.add(s);
    }
    await _save();
  }

  static Future<void> _save() async {
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          prefSkipGroups, [for (final g in _skipGroups) g.name]);
      await prefs.setStringList(
          prefSkipSources, [for (final s in _skipSources) s.name]);
    } catch (_) {
      // Bilinçli: yazılamazsa seçim yalnız bu oturumda geçerli.
    }
  }

  /// Tur bu dosyayı sorabilir mi (tür ve yer seçili mi)?
  static bool allows(String path) {
    final g = groupOf(path);
    if (g == null || !groupOn(g)) return false;
    return sourceOn(sourceOf(path));
  }

  /// Turdaki sıra: [priority] grubuna göre, grup içinde gelen sıra (en yeni).
  static List<FsEntry> ordered(List<FsEntry> files) {
    final rank = {for (var i = 0; i < priority.length; i++) priority[i]: i};
    final indexed = [for (var i = 0; i < files.length; i++) (i, files[i])];
    indexed.sort((a, b) {
      final ra = rank[groupOf(a.$2.path)] ?? priority.length;
      final rb = rank[groupOf(b.$2.path)] ?? priority.length;
      return ra != rb ? ra.compareTo(rb) : a.$1.compareTo(b.$1);
    });
    return [for (final x in indexed) x.$2];
  }

  /// Tüm adayları (kamera dahil — kapalıyken de sayısı görünsün) sayar.
  static Future<SmartScopeCounts> count(AiScope scope) async {
    await read();
    await SmartSort.ensureLoaded();
    final roots = SmartSort.scopeRoots(camera: true);
    if (roots.isEmpty) return SmartScopeCounts.empty;
    final files = await FsScan.freshFiles(roots, limit: SmartSort.scanAll);
    return tally(files, scope.allowsFile, SmartSort.supports, SmartSort.needs);
  }

  /// Saf sayım (test edilir).
  static SmartScopeCounts tally(
    Iterable<FsEntry> files,
    bool Function(FsEntry) allowedByAiScope,
    bool Function(FsEntry) supports,
    bool Function(FsEntry) needs,
  ) {
    final total = <(SmartGroup, SmartSource), int>{};
    final rem = <(SmartGroup, SmartSource), int>{};
    for (final e in files) {
      if (!supports(e) || !allowedByAiScope(e)) continue;
      final g = groupOf(e.path);
      if (g == null) continue;
      final k = (g, sourceOf(e.path));
      total[k] = (total[k] ?? 0) + 1;
      if (needs(e)) rem[k] = (rem[k] ?? 0) + 1;
    }
    return SmartScopeCounts({
      for (final k in total.keys) k: SmartScopeCell(total[k]!, rem[k] ?? 0),
    });
  }
}

/// **Akıllı düzen kredisi — TASLAK** (PLAN §3 K15a; satın alma yok, yalnız
/// tahmin göstergesi). Fiyatlar kullanıcı önerisi, karar verilmedi.
abstract final class SmartCreditDraft {
  static const freeFiles = 500;
  static const packs = [(1000, 25), (5000, 100), (10000, 200)];

  /// Ücretsiz haktan sonra kalan dosyaya yeten en küçük paket; gerekmezse
  /// null; en büyük de yetmezse en büyük.
  static (int files, int lira)? packFor(int remaining) {
    final need = remaining - freeFiles;
    if (need <= 0) return null;
    for (final pk in packs) {
      if (pk.$1 >= need) return pk;
    }
    return packs.last;
  }
}
