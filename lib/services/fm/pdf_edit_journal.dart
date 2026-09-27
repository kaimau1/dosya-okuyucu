import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';
import 'safe_write.dart';

/// **Kaydedilmemiş PDF düzenlemelerinin günlüğü** (2026-09-23 tasarım
/// denetimi).
///
/// Görüntüleyici PDF düzenlemelerini (vurgu, yerinde metin düzeltme…)
/// ÖZGÜN dosyanın üstüne yazıyor ve özgün baytları geçici bir yedekte
/// tutuyor; kullanıcı "üzerine yaz" demeden ekrandan çıkarsa yedek geri
/// yazılıyor. Bu geri yazma yalnız `dispose`ta yapılıyordu: uygulama arada
/// **öldürülürse** (düşük bellek, çökme, sistemin arka plandaki süreci
/// kapatması) `dispose` hiç çalışmıyor ve kullanıcının dosyası KAYDETMEDİĞİ
/// düzenlemelerle kalıyordu — yedek de geçici klasörde sahipsiz.
///
/// Artık ilk yazıştan önce `özgün → yedek` çifti buraya yazılıyor; ekran
/// düzgün kapanınca siliniyor. Açılışta kalan her kayıt yarıda kalmış bir
/// oturumdur ve [recover] özgünü geri yükler — ekrandan "kaydetmeden çık"
/// ile aynı sonuç.
abstract final class PdfEditJournal {
  static const _fileName = 'pdf_edit_journal.json';

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  static bool get _usable => FmEnv.appSupportDir.isNotEmpty;

  /// Bu süreçte açılan oturumlar. [recover] bunlara DOKUNMAZ: uygulama bir
  /// PDF'le açılıp kullanıcı daha açılış işleri bitmeden düzenlemeye
  /// başladıysa o kayıt yarıda kalmış değil, CANLI bir oturumdur.
  static final Set<String> _live = {};

  static Map<String, String> _read() {
    if (!_usable) return {};
    try {
      final file = File(_path);
      if (!file.existsSync()) return {};
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  static void _write(Map<String, String> entries) {
    if (!_usable) return;
    try {
      final file = File(_path);
      if (entries.isEmpty) {
        if (file.existsSync()) file.deleteSync();
        return;
      }
      file.writeAsStringSync(jsonEncode(entries), flush: true);
    } catch (_) {
      // Günlük yazılamadı: davranış bu sınıftan önceki hâline döner.
    }
  }

  /// [original] için [backup] yedeği alındı (ilk yazıştan ÖNCE çağrılır).
  static void add(String original, String backup) {
    _live.add(original);
    final entries = _read();
    entries[original] = backup;
    _write(entries);
  }

  /// Oturum düzgün bitti (geri yazıldı ya da kullanıcı kaydetti).
  static void remove(String original) {
    _live.remove(original);
    final entries = _read();
    if (entries.remove(original) == null) return;
    _write(entries);
  }

  /// Yedeklerin durduğu klasör: uygulamanın KALICI destek klasörü.
  ///
  /// Eskiden `Directory.systemTemp` (Android'de önbellek) idi: sistem
  /// depolama sıkışınca önbelleği kendiliğinden boşaltabilir — tam da
  /// kurtarma gerektiğinde yedek yok olurdu. Destek klasörü yoksa (testte,
  /// masaüstünde erken açılışta) null döner ve çağıran geçiciye düşer.
  static String? backupRoot() =>
      _usable ? p.join(FmEnv.appSupportDir, 'pdf_edit_backups') : null;

  /// Bu dosya için yarıda kalmış (bu süreçte açılmamış) bir oturum var mı?
  /// Görüntüleyici açılırken sorar: varsa önce kurtarma yapılmalı, yoksa
  /// kullanıcı kaydetmediği düzenlemeleri özgün sanır.
  static bool hasStale(String original) =>
      !_live.contains(original) && _read().containsKey(original);

  /// Günlükteki yedek yolları — geçici dosya süpürücüsü bunlara dokunmaz.
  static Set<String> backups() => _read().values.toSet();

  /// Yarıda kalmış oturumların özgün dosyalarını geri yükler; geri yüklenen
  /// dosya sayısını döner.
  ///
  /// Özgün dosya yedekten ESKİYSE geri yazılmaz: bizim yazdığımız dosya
  /// yedekten sonra değişmiş olmalı; daha eskiyse yedeğin alındığı andan
  /// sonra başka biri (kullanıcı başka bir uygulamayla) üstüne yazmış
  /// olabilir ve onun işini ezmek istemeyiz. **İstisna (2026-09-27):**
  /// özgün dosya yoksa, 0 baytsa ya da PDF gibi görünmüyorsa (yarıda kalmış
  /// yazma) tarihe bakılmadan geri yüklenir — bozuk dosyayı korumanın
  /// anlamı yok. Geri yazma da bölünmezdir ([SafeWrite.copySync]).
  ///
  /// [only] verilirse yalnız o dosyanın kaydına bakılır (görüntüleyici
  /// açılırken).
  static int recover({String? only}) {
    final entries = _read();
    if (entries.isEmpty) return 0;
    var restored = 0;
    final keep = <String, String>{};
    for (final e in entries.entries) {
      if (_live.contains(e.key) || (only != null && e.key != only)) {
        keep[e.key] = e.value;
        continue;
      }
      final original = File(e.key);
      final backup = File(e.value);
      try {
        if (!backup.existsSync()) continue; // yapacak bir şey yok
        final broken = !original.existsSync() ||
            !PdfBytesCheck.fileLooksValidSync(original.path);
        if (!broken &&
            original.lastModifiedSync().isBefore(backup.lastModifiedSync())) {
          _deleteBackup(backup);
          continue;
        }
        SafeWrite.copySync(backup.path, original.path);
        restored++;
        _deleteBackup(backup);
      } catch (_) {
        // Özgün şu an yazılamıyor (SD kart çıkarılmış olabilir): kayıt
        // kalır, bir sonraki açılışta yeniden denenir.
        keep[e.key] = e.value;
      }
    }
    _write(keep);
    return restored;
  }

  /// Yalnız test: süreç içi durumu sıfırlar.
  static void debugReset() => _live.clear();

  static void _deleteBackup(File backup) {
    try {
      backup.deleteSync();
      final dir = backup.parent;
      if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
    } catch (_) {}
  }
}

/// Süren **geri yüklemeler** (özgün baytların dosyaya geri yazılması).
///
/// Görüntüleyici kapanırken geri yazma artık beklenmiyor (ana izleği
/// donduruyordu); kullanıcı aynı dosyayı hemen yeniden açarsa yeni
/// görüntüleyici geri yazma bitmeden dosyayı okumamalı — yoksa kaydetmediği
/// düzenlemeyi özgün sanırdı. [pendingFor] bu yüzden var.
abstract final class PdfRestoreQueue {
  static final Map<String, Future<void>> _pending = {};

  /// [path] için [job]ı sıraya koyar (aynı dosyanın işleri art arda koşar).
  static Future<void> run(String path, Future<void> Function() job) {
    final previous = _pending[path] ?? Future<void>.value();
    late final Future<void> mine;
    mine = previous.then((_) => job()).whenComplete(() {
      if (identical(_pending[path], mine)) _pending.remove(path);
    });
    _pending[path] = mine;
    return mine;
  }

  /// [path] için süren geri yükleme (yoksa null).
  static Future<void>? pendingFor(String path) => _pending[path];
}
