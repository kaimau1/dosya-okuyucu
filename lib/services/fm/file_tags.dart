import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';
import 'path_side_index.dart';

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
///   dosyayla gitmez. Uygulama içinden taşıma/yeniden adlandırma ve çöpten
///   geri alma yolu güncelliyor ([movePath]) — bu, `PathSideIndex` kancasıyla
///   `FileOps` ve `TrashService`e bağlıdır (bkz. `path_side_index.dart`).
///   **Kanca bağlı olmadan bu satır YANLIŞTIR;** 2026-07-29 sadakat
///   denetiminde tam olarak bu durum bulundu ve bağlandı.
/// - Silinen dosyaların etiketleri yüklemede temizlenir; ölü kayıt birikmez.
abstract final class FileTags {
  static const _fileName = 'file_tags.json';

  static final Map<String, Set<String>> _byPath = {};

  /// Yükleme **Future'ı** paylaşılır (bool bayrak DEĞİL).
  ///
  /// Eskiden `_loaded = true` diskten okuma BAŞLAMADAN önce işaretleniyordu:
  /// o aralıkta gelen ikinci bir çağıran "yüklendi" sanıp boş harita üzerinde
  /// çalışıyor, yaptığı ilk `add`/`setTags` tüm etiket dosyasının üstüne
  /// yazıyordu (2026-07-29 sadakat denetimi). Ayrıca `appSupportDir` henüz
  /// hazır değilken **kilitlenmez**: `FmEnv.ensureInit()` panonun açılışında
  /// koşuyor, paylaşımla soğuk başlayan bir açılışta ondan önce buraya
  /// gelinebiliyor ve bir kez boş kilitlenmek tüm etiketleri kaybettirirdi.
  static Future<void>? _loadFuture;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Diskten okur (bir kez) ve **artık var olmayan** dosyaların kayıtlarını
  /// bellekten atar (diske yazmadan — bkz. [_shouldKeep]).
  static Future<void> ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(_path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      for (final entry in raw.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is! List) continue;
        if (!_shouldKeep(key)) continue;
        final tags = {
          for (final t in value)
            if ('$t'.trim().isNotEmpty) '$t'.trim(),
        };
        if (tags.isNotEmpty) _byPath[key] = tags;
      }
      // Ölü kayıtlar burada diske YAZILMAZ: temizlik bir sonraki gerçek
      // değişiklikte (add/remove/setTags) kendiliğinden diske iner.
    } catch (_) {
      // Bozuk dosya sessizce yok sayılır: etiketler süs, uygulamayı kilitlemez.
    }
  }

  /// Bu kayıt korunmalı mı?
  ///
  /// Depolama izni verilmemişken, izin Android tarafından geri alınmışken ya da
  /// SD kart çıkarılmışken `existsSync()` HER yol için `false` döner. "Dosya
  /// silinmiş" ile "şu an göremiyorum"u karıştırmak, Fotoğraflar ekranını bir
  /// kez açmakla kullanıcının bütün etiketlerini kalıcı olarak silmek demekti.
  /// Bu yüzden kayıt yalnız **klasörü okunabildiği hâlde** dosya yoksa atılır.
  static bool _shouldKeep(String path) {
    if (File(path).existsSync() || Directory(path).existsSync()) return true;
    return !Directory(p.dirname(path)).existsSync();
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

  /// Dosya **ya da klasör** uygulama içinden taşındı/adlandırıldı → etiketleri
  /// yeni yola taşı.
  ///
  /// Klasör taşımasında **altındaki tüm kayıtlar** da taşınır ([movedPathFor]):
  /// yalnız tam anahtara bakmak, `DCIM/Tatil` klasörünün adını değiştiren
  /// kullanıcının içindeki 40 fotoğrafın etiketini kaybettirmek demekti
  /// (2026-07-29 sadakat denetimi, 2. tur).
  static Future<void> movePath(String from, String to) async {
    await ensureLoaded();
    final moves = <String, String>{};
    for (final key in _byPath.keys) {
      final next = movedPathFor(path: key, from: from, to: to);
      if (next != null && next != key) moves[key] = next;
    }
    if (moves.isEmpty) return;
    for (final entry in moves.entries) {
      final tags = _byPath.remove(entry.key);
      if (tags != null) _byPath[entry.value] = tags;
    }
    await _save();
  }

  /// Yalnız testler için: bellek durumunu sıfırlar.
  static void resetForTest() {
    _byPath.clear();
    _loadFuture = null;
  }
}
