import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının kendi oluşturduğu albüm (dosyalar taşınmaz — yalnız yol listesi).
class UserAlbum {
  final String id;
  final String name;
  final List<String> paths;

  const UserAlbum(this.id, this.name, this.paths);

  /// Galeri kapsam anahtarı (klasör albümleri `dir:<yol>`).
  String get key => 'user:$id';

  Map<String, Object> toJson() => {'id': id, 'name': name, 'paths': paths};

  static UserAlbum? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final paths = raw['paths'];
    if (id is! String || name is! String || paths is! List) return null;
    return UserAlbum(id, name, [for (final x in paths) if (x is String) x]);
  }
}

/// **Albümler** (kullanıcı 2026-11-15: *"albüm oluşturma ve albümleri gizleme
/// silme ekleme gelmeli"*).
///
/// İki tür albüm var:
/// * **Klasör albümü** (`dir:<klasör>`) — eskisi gibi, klasörden türer.
///   Gizlenebilir; silmek içindeki dosyaları Çöp'e atar (ekran tarafında,
///   `deleteEntries` onayıyla).
/// * **Kullanıcı albümü** (`user:<id>`) — ad + yol listesi. Dosya taşınmaz,
///   kopyalanmaz; albümü silmek dosyalara dokunmaz.
///
/// Gizlenen albümler [hidden] kümesinde (her iki tür). Kayıt tek bir
/// SharedPreferences JSON'u: albümler küçük, okuma açılışta bir kez.
abstract final class PhotoAlbums {
  static const _key = 'ph_albums_v1';

  static final List<UserAlbum> _albums = [];
  static final Set<String> _hidden = {};
  static Future<void>? _loadFuture;

  /// Her değişiklikte artar; galeri önbelleklerini tazeler.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static List<UserAlbum> get albums => List.unmodifiable(_albums);
  static Set<String> get hidden => Set.unmodifiable(_hidden);
  static bool isHidden(String key) => _hidden.contains(key);

  static UserAlbum? byKey(String key) {
    if (!key.startsWith('user:')) return null;
    final id = key.substring(5);
    for (final a in _albums) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final list = data['albums'];
      if (list is List) {
        for (final x in list) {
          final a = UserAlbum.fromJson(x);
          if (a != null) _albums.add(a);
        }
      }
      final hid = data['hidden'];
      if (hid is List) _hidden.addAll(hid.whereType<String>());
      revision.value++;
    } catch (_) {
      // Bozuk kayıt: albümler süs, galeriyi kilitlemez.
    }
  }

  static Future<void> _save() async {
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'albums': [for (final a in _albums) a.toJson()],
        'hidden': _hidden.toList(),
      }),
    );
  }

  static Future<UserAlbum> create(String name,
      {List<String> paths = const []}) async {
    await ensureLoaded();
    final album = UserAlbum(
      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name.trim(),
      [...{...paths}],
    );
    _albums.insert(0, album);
    await _save();
    return album;
  }

  static Future<void> rename(String key, String name) async {
    final i = _indexOf(key);
    if (i < 0 || name.trim().isEmpty) return;
    final a = _albums[i];
    _albums[i] = UserAlbum(a.id, name.trim(), a.paths);
    await _save();
  }

  /// Yolları albüme ekler; kaç YENİ yol eklendiğini döner.
  static Future<int> add(String key, Iterable<String> paths) async {
    final i = _indexOf(key);
    if (i < 0) return 0;
    final a = _albums[i];
    final set = {...a.paths};
    final before = set.length;
    set.addAll(paths);
    if (set.length == before) return 0;
    _albums[i] = UserAlbum(a.id, a.name, set.toList());
    await _save();
    return set.length - before;
  }

  static Future<void> removePaths(String key, Iterable<String> paths) async {
    final i = _indexOf(key);
    if (i < 0) return;
    final a = _albums[i];
    final drop = paths.toSet();
    _albums[i] =
        UserAlbum(a.id, a.name, [for (final x in a.paths) if (!drop.contains(x)) x]);
    await _save();
  }

  /// Kullanıcı albümünü siler (dosyalar yerinde kalır).
  static Future<void> delete(String key) async {
    final i = _indexOf(key);
    if (i >= 0) _albums.removeAt(i);
    _hidden.remove(key);
    await _save();
  }

  static Future<void> setHidden(String key, bool value) async {
    await ensureLoaded();
    final changed = value ? _hidden.add(key) : _hidden.remove(key);
    if (changed) await _save();
  }

  static int _indexOf(String key) {
    if (!key.startsWith('user:')) return -1;
    final id = key.substring(5);
    return _albums.indexWhere((a) => a.id == id);
  }

  @visibleForTesting
  static void resetForTest() {
    _albums.clear();
    _hidden.clear();
    _loadFuture = null;
  }
}
