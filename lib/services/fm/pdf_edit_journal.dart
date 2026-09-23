import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

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

  /// Günlükteki yedek yolları — geçici dosya süpürücüsü bunlara dokunmaz.
  static Set<String> backups() => _read().values.toSet();

  /// Yarıda kalmış oturumların özgün dosyalarını geri yükler; geri yüklenen
  /// dosya sayısını döner.
  ///
  /// Özgün dosya yedekten ESKİYSE geri yazılmaz: bizim yazdığımız dosya
  /// yedekten sonra değişmiş olmalı; daha eskiyse yedeğin alındığı andan
  /// sonra başka biri (kullanıcı başka bir uygulamayla) üstüne yazmış
  /// olabilir ve onun işini ezmek istemeyiz.
  static int recover() {
    final entries = _read();
    if (entries.isEmpty) return 0;
    var restored = 0;
    final keep = <String, String>{};
    for (final e in entries.entries) {
      if (_live.contains(e.key)) {
        keep[e.key] = e.value;
        continue;
      }
      final original = File(e.key);
      final backup = File(e.value);
      try {
        if (!backup.existsSync()) continue; // yapacak bir şey yok
        if (original.existsSync() &&
            original.lastModifiedSync().isBefore(backup.lastModifiedSync())) {
          _deleteBackup(backup);
          continue;
        }
        backup.copySync(original.path);
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
