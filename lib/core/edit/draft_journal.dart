/// Kaydedilmemiş değişikliklerin **taslak günlüğü** — çökme / pil bitmesi /
/// sistemin uygulamayı öldürmesine karşı (Faz 20 / ED2, K21).
///
/// Taslak, uygulamanın kendi veri klasöründe (`<destek>/drafts/`) durur:
/// `<anahtar>.bin` belgenin o anki baytları, `<anahtar>.json` meta (kaynak yol,
/// boy, değiştirilme zamanı, editör türü, saat). Açılışta kaynak dosya o
/// zamandan beri DEĞİŞMEDİYSE ve taslak daha yeniyse ekranda "Kaydedilmemiş
/// değişiklikler bulundu — Geri yükle · Sil" şeridi çıkar.
///
/// KVKK: yalnız cihazda, uygulama verisinde; ayar yedeğine ve paylaşıma
/// girmez. Kayıt ya da vazgeçmeden sonra silinir; 7 günden eskiler temizlenir.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Bulunan bir taslağın bilgisi.
class DraftInfo {
  final String sourcePath;
  final String editor;
  final DateTime savedAt;
  final String _binPath;

  const DraftInfo(this.sourcePath, this.editor, this.savedAt, this._binPath);

  /// Taslağın baytları. Eşzamanlı okunur: yalnız kullanıcı "Geri yükle"ye
  /// bastığında, tek sefer (ayrıştırma bundan çok daha pahalı).
  Future<Uint8List> read() async => File(_binPath).readAsBytesSync();
}

class DraftJournal {
  final Directory root;

  DraftJournal(this.root);

  static DraftJournal? _instance;

  /// Testler geçici bir klasör verir.
  static set instance(DraftJournal? value) => _instance = value;

  static Future<DraftJournal> shared() async {
    final existing = _instance;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    return _instance = DraftJournal(Directory('${base.path}/drafts'));
  }

  /// Kaynak yolun kararlı anahtarı (FNV-1a 64 — yol dosya adına sızmasın).
  static String keyFor(String sourcePath) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(sourcePath)) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  File _bin(String key) => File('${root.path}/$key.bin');
  File _meta(String key) => File('${root.path}/$key.json');

  /// Taslağı yazar (önce geçici dosyaya, sonra yeniden adlandırma — yarım
  /// yazılmış taslak hiç "bulunmaz").
  Future<void> write(String sourcePath, List<int> bytes,
      {required String editor, DateTime? now}) async {
    await root.create(recursive: true);
    final key = keyFor(sourcePath);
    final stat = await _stat(sourcePath);
    final tmp = File('${root.path}/$key.bin.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(_bin(key).path);
    await _meta(key).writeAsString(jsonEncode({
      'source': sourcePath,
      'editor': editor,
      'size': stat?.$1,
      'mtime': stat?.$2,
      'saved': (now ?? DateTime.now()).millisecondsSinceEpoch,
    }));
  }

  /// Bu kaynak için geçerli taslak (kaynak sonradan değiştiyse null — eski
  /// taslağı yeni dosyanın üstüne geri yüklemek veriyi bozardı).
  ///
  /// Eşzamanlı disk okuması bilinçli: meta birkaç yüz bayt, açılışta bir kez
  /// okunur (ve `flutter_test`in sahte saatinde de biter).
  Future<DraftInfo?> find(String sourcePath) async => findSync(sourcePath);

  DraftInfo? findSync(String sourcePath) {
    final key = keyFor(sourcePath);
    final meta = _meta(key);
    final bin = _bin(key);
    if (!meta.existsSync() || !bin.existsSync()) return null;
    try {
      final m = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      if (m['source'] != sourcePath) return null;
      final stat = _statSync(sourcePath);
      if (stat != null && (stat.$1 != m['size'] || stat.$2 != m['mtime'])) {
        return null;
      }
      final saved = DateTime.fromMillisecondsSinceEpoch(m['saved'] as int);
      if (stat != null && stat.$2 > saved.millisecondsSinceEpoch) return null;
      return DraftInfo(sourcePath, m['editor'] as String? ?? '', saved, bin.path);
    } catch (_) {
      return null;
    }
  }

  Future<void> discard(String sourcePath) async {
    final key = keyFor(sourcePath);
    for (final f in [_bin(key), _meta(key)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// [maxAge]'den eski taslakları siler.
  Future<int> prune(
      {Duration maxAge = const Duration(days: 7), DateTime? now}) async {
    if (!await root.exists()) return 0;
    final limit = (now ?? DateTime.now()).subtract(maxAge);
    var n = 0;
    await for (final e in root.list()) {
      if (e is! File) continue;
      try {
        if ((await e.lastModified()).isBefore(limit)) {
          await e.delete();
          n++;
        }
      } catch (_) {}
    }
    return n;
  }

  static (int, int)? _statSync(String path) {
    try {
      final st = File(path).statSync();
      if (st.type == FileSystemEntityType.notFound) return null;
      return (st.size, st.modified.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }

  static Future<(int, int)?> _stat(String path) async {
    try {
      final st = await File(path).stat();
      if (st.type == FileSystemEntityType.notFound) return null;
      return (st.size, st.modified.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }
}
