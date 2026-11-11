/// **Düzenleme oturumunun çökme kurtarması** (PDF Pro Faz 54 / 4, PK3).
///
/// Kaydedilmemiş değişiklik bellektedir; süreç ölürse (düşük bellek, çökme)
/// kaybolmasın diye iki şey uygulamanın özel alanına yazılır:
/// * **komut günlüğü** — son kayıttan sonraki işlemler (her değişiklikte);
///   açılışta belgenin üstüne yeniden oynatılır, adımlar yine geri alınabilir;
/// * **geçici artımlı kayıt** — 30 sn'de bir belgenin tam hâli; günlük
///   oynatılamazsa (belge dışarıda değişmiş) kopya olarak kurtarılır.
///
/// Oturum düzgün kapanınca (kaydet / vazgeç) ikisi de silinir; açılışta kalan
/// kayıt yarıda kalmış bir oturumdur.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../fm/fm_env.dart';
import '../../fm/safe_write.dart';
import 'pdf_edit_bridge.dart';
import 'pdf_edit_session.dart';

/// Günlükteki bir adım: işlem + kullanıcıya gösterilen ad.
class PdfRecoveredStep {
  final PdfEditOp op;
  final String label, detail;
  const PdfRecoveredStep(this.op, this.label, this.detail);
}

class PdfEditRecoveryEntry {
  final String path;

  /// Günlük yazıldığında diskteki dosyanın boyu ve değişme anı — işlemler
  /// bu hâlin üstüne oynatılır.
  final int baseSize, baseModifiedMs;

  /// Oynatılacak adımlar; null = günlük oynatılamaz (yalnız [snapshot]).
  final List<PdfRecoveredStep>? steps;

  /// Geçici artımlı kayıt (belgenin tam hâli); yoksa null.
  final File? snapshot;

  final DateTime savedAt;

  const PdfEditRecoveryEntry({
    required this.path,
    required this.baseSize,
    required this.baseModifiedMs,
    required this.steps,
    required this.snapshot,
    required this.savedAt,
  });

  /// Kurtarılabilecek değişiklik sayısı (bilinmiyorsa 0).
  int get count => steps?.length ?? 0;
}

abstract final class PdfEditRecovery {
  /// Geçici kayıt aralığı.
  static const snapshotEvery = Duration(seconds: 30);

  /// Test için kök klasör; null → uygulama destek dizini.
  static String? rootOverride;

  /// Bu süreçte açık oturumlar: [find] bunları "yarıda kalmış" saymaz.
  static final Set<String> _live = {};

  static String get _root =>
      rootOverride ?? p.join(FmEnv.appSupportDir, 'pdf_edit_recovery');

  static bool get _usable =>
      rootOverride != null || FmEnv.appSupportDir.isNotEmpty;

  static Directory _dirFor(String path) => Directory(p.join(
      _root, sha1.convert(utf8.encode(p.normalize(path))).toString()));

  static File _journal(String path) =>
      File(p.join(_dirFor(path).path, 'gunluk.json'));

  static File _snapshot(String path) =>
      File(p.join(_dirFor(path).path, 'gecici.pdf'));

  /// Oturum açıldı: bu süreçte canlı.
  static void begin(String path) => _live.add(p.normalize(path));

  /// Komut günlüğünü yazar. [steps] null → günlük oynatılamaz diye işaretlenir
  /// (geçici kayıt varsa o kalır). Boş liste = kaydedilmemiş değişiklik yok →
  /// kayıt silinir.
  static Future<void> writeJournal(String path, List<PdfEditStep>? steps) {
    // Sırayla: art arda iki değişiklikte eski günlük yenisinin üstüne
    // yazılmasın.
    final job = _queue.then((_) => _writeJournal(path, steps));
    _queue = job;
    return job;
  }

  static Future<void> _queue = Future.value();

  static Future<void> _writeJournal(
      String path, List<PdfEditStep>? steps) async {
    if (!_usable) return;
    try {
      if (steps != null && steps.isEmpty) {
        await _delete(path);
        return;
      }
      final stat = await File(path).stat();
      final dir = _dirFor(path);
      await dir.create(recursive: true);
      await SafeWrite.bytes(
          _journal(path).path,
          utf8.encode(jsonEncode({
            'v': 1,
            'path': path,
            'size': stat.size,
            'modified': stat.modified.millisecondsSinceEpoch,
            'at': DateTime.now().millisecondsSinceEpoch,
            'steps': steps == null
                ? null
                : [
                    for (final s in steps)
                      {
                        'label': s.label,
                        'detail': s.detail,
                        'op': s.op!.toJson(),
                      }
                  ],
          })));
    } catch (_) {
      // Bilinçli: günlük bir emniyet ağı; yazılamaması düzenlemeyi durdurmaz.
    }
  }

  /// Geçici artımlı kaydı (belgenin tam hâli) yazar.
  static Future<void> writeSnapshot(String path, Uint8List bytes) {
    final job = _queue.then((_) => _writeSnapshot(path, bytes));
    _queue = job;
    return job;
  }

  static Future<void> _writeSnapshot(String path, Uint8List bytes) async {
    if (!_usable || !PdfBytesCheck.looksValid(bytes)) return;
    // Oturum bu arada kapandıysa (kaydet / vazgeç) artık yazılmaz.
    if (!_live.contains(p.normalize(path))) return;
    try {
      await _dirFor(path).create(recursive: true);
      await SafeWrite.bytes(_snapshot(path).path, bytes);
    } catch (_) {
      // Bilinçli: yukarıdaki gibi — emniyet ağı.
    }
  }

  /// [path] için yarıda kalmış oturum; yoksa (ya da oturum bu süreçte
  /// canlıysa) null.
  static Future<PdfEditRecoveryEntry?> find(String path) async {
    if (!_usable || _live.contains(p.normalize(path))) return null;
    try {
      final file = _journal(path);
      if (!await file.exists()) return null;
      final j = jsonDecode(await file.readAsString());
      if (j is! Map<String, Object?>) return null;
      final size = j['size'], modified = j['modified'], at = j['at'];
      if (size is! int || modified is! int || at is! int) return null;
      final snap = _snapshot(path);
      final hasSnap = await snap.exists();
      var steps = _steps(j['steps']);
      // Belge günlükten sonra değiştiyse işlemler artık bu dosyaya ait değil.
      final src = File(path);
      if (!await src.exists()) return null;
      final stat = await src.stat();
      if (stat.size != size ||
          stat.modified.millisecondsSinceEpoch != modified) {
        steps = null;
      }
      if (steps == null && !hasSnap) return null;
      return PdfEditRecoveryEntry(
        path: path,
        baseSize: size,
        baseModifiedMs: modified,
        steps: steps,
        snapshot: hasSnap ? snap : null,
        savedAt: DateTime.fromMillisecondsSinceEpoch(at),
      );
    } catch (_) {
      return null;
    }
  }

  static List<PdfRecoveredStep>? _steps(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final out = <PdfRecoveredStep>[];
    for (final e in raw) {
      if (e is! Map<String, Object?>) return null;
      final opJson = e['op'];
      if (opJson is! Map<String, Object?>) return null;
      final op = PdfEditOp.fromJson(opJson);
      final label = e['label'], detail = e['detail'];
      if (op == null || label is! String) return null;
      out.add(PdfRecoveredStep(op, label, detail is String ? detail : ''));
    }
    return out;
  }

  /// Günlükteki adımları [session]'a sırayla yeniden uygular (her biri yine
  /// geri alınabilir bir komut olur). İlk reddedilen adımda durur; uygulanan
  /// adım sayısını döndürür.
  static Future<int> replay(
      PdfEditSession session, PdfEditRecoveryEntry entry) async {
    var n = 0;
    for (final s in entry.steps ?? const <PdfRecoveredStep>[]) {
      try {
        await session.apply(s.op, label: s.label, detail: s.detail);
      } on PdfEditBridgeRefused {
        break;
      }
      n++;
    }
    return n;
  }

  /// Oturum düzgün kapandı: kayıt silinir.
  static Future<void> end(String path) {
    _live.remove(p.normalize(path));
    return clear(path);
  }

  /// Oturum kaydedilmeden koptu (ekran arkadan kapandı): kayıt KALIR ve
  /// belge yeniden açılınca kurtarma olarak sunulur.
  static void abandon(String path) => _live.remove(p.normalize(path));

  /// Kurtarma kaydını siler (oturum canlı kalır).
  static Future<void> clear(String path) {
    final job = _queue.then((_) => _delete(path));
    _queue = job;
    return job;
  }

  static Future<void> _delete(String path) async {
    if (!_usable) return;
    try {
      final dir = _dirFor(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Bilinçli: silinemezse sonraki açılışta yeniden sunulur; zararsız.
    }
  }

  /// Test: canlı oturum kümesini sıfırlar ("süreç öldü").
  static void debugForgetLive() => _live.clear();
}
