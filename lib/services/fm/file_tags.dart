import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// **Dosya etiketleri** — "Ayşe", "İş grubu", "Fatura" gibi kullanıcı etiketleri.
///
/// ## Niye var
/// WhatsApp/Telegram dosyalarında **gönderen ve grup bilgisi diskte yoktur**
/// (bkz. `models/chat_media.dart`); kişiye/gruba göre süzmenin dürüst yolu
/// kullanıcının bir kez etiketlemesi. Etiket dosyaya değil, uygulamanın kendi
/// dizinindeki bir JSON'a yazılır: dosyanın içine yazmak (EXIF/XMP) fotoğrafı
/// yeniden kodlamak demekti, klasöre taşımak da kullanıcının düzenini bozardı.
///
/// ## Sınırlar (arayüzde de yazılı)
/// - Etiket **yola** bağlıdır: dosya başka bir uygulamayla taşınırsa etiket o
///   dosyayla gitmez. Uygulama içinden taşımada yol güncellenir ([movePath]).
/// - Silinen dosyaların etiketleri yüklemede temizlenir; ölü kayıt birikmez.
abstract final class FileTags {
  static const _fileName = 'file_tags.json';

  static final Map<String, Set<String>> _byPath = {};
  static bool _loaded = false;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Diskten okur (bir kez) ve **artık var olmayan** dosyaların kayıtlarını atar.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      var dropped = false;
      for (final entry in raw.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is! List) continue;
        if (!File(key).existsSync() && !Directory(key).existsSync()) {
          dropped = true;
          continue;
        }
        final tags = {
          for (final t in value)
            if ('$t'.trim().isNotEmpty) '$t'.trim(),
        };
        if (tags.isNotEmpty) _byPath[key] = tags;
      }
      if (dropped) await _save();
    } catch (_) {
      // Bozuk dosya sessizce yok sayılır: etiketler süs, uygulamayı kilitlemez.
    }
  }

  static Future<void> _save() async {
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final data = {
        for (final e in _byPath.entries) e.key: e.value.toList()..sort(),
      };
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(_path);
    } catch (_) {}
  }

  /// [path] dosyasının etiketleri (yoksa boş küme).
  static Set<String> forPath(String path) => _byPath[path] ?? const {};

  /// Süzgeçlere verilen çözücü: `FmFilter.apply(..., tagsOf: FileTags.forPath)`.
  static Set<String> Function(String path) get resolver => forPath;

  /// Tüm etiketler ve kaç dosyada kullanıldıkları (süzgeç çipleri).
  static Map<String, int> counts() {
    final out = <String, int>{};
    for (final tags in _byPath.values) {
      for (final tag in tags) {
        out[tag] = (out[tag] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Etiketi verilen dosyalara ekler.
  static Future<void> add(Iterable<String> paths, String tag) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    await ensureLoaded();
    for (final path in paths) {
      (_byPath[path] ??= <String>{}).add(clean);
    }
    await _save();
  }

  /// Etiketi verilen dosyalardan kaldırır.
  static Future<void> remove(Iterable<String> paths, String tag) async {
    await ensureLoaded();
    for (final path in paths) {
      final tags = _byPath[path];
      if (tags == null) continue;
      tags.remove(tag);
      if (tags.isEmpty) _byPath.remove(path);
    }
    await _save();
  }

  /// Bir dosyanın etiket kümesini tümüyle yazar.
  static Future<void> setTags(String path, Set<String> tags) async {
    await ensureLoaded();
    final clean = {
      for (final t in tags)
        if (t.trim().isNotEmpty) t.trim(),
    };
    if (clean.isEmpty) {
      _byPath.remove(path);
    } else {
      _byPath[path] = clean;
    }
    await _save();
  }

  /// Etiketi her yerden siler (etiket yönetimi).
  static Future<void> deleteTag(String tag) async {
    await ensureLoaded();
    for (final path in _byPath.keys.toList()) {
      final tags = _byPath[path]!..remove(tag);
      if (tags.isEmpty) _byPath.remove(path);
    }
    await _save();
  }

  /// Etiketi yeniden adlandırır.
  static Future<void> renameTag(String from, String to) async {
    final clean = to.trim();
    if (clean.isEmpty || clean == from) return;
    await ensureLoaded();
    for (final tags in _byPath.values) {
      if (tags.remove(from)) tags.add(clean);
    }
    await _save();
  }

  /// Dosya uygulama içinden taşındı/adlandırıldı → etiketi yeni yola taşı.
  static Future<void> movePath(String from, String to) async {
    await ensureLoaded();
    final tags = _byPath.remove(from);
    if (tags == null) return;
    _byPath[to] = tags;
    await _save();
  }

  /// Yalnız testler için: bellek durumunu sıfırlar.
  static void resetForTest() {
    _byPath.clear();
    _loaded = false;
  }
}
