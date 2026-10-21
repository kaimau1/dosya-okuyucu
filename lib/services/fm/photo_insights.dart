import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/fs_entry.dart';
import 'exif_reader.dart';
import 'fm_env.dart';
import 'media_library.dart';
import 'native_extras.dart';

/// Bir fotoğrafın çıkarılmış bilgisi.
@immutable
class PhotoInfo {
  final int modifiedMs;

  /// EXIF çekim tarihi; yoksa null (değişme tarihi kullanılır).
  final int? takenMs;
  final double? lat;
  final double? lon;

  const PhotoInfo({
    required this.modifiedMs,
    this.takenMs,
    this.lat,
    this.lon,
  });

  int dateMs() => takenMs ?? modifiedMs;

  Map<String, Object?> toJson() =>
      {'m': modifiedMs, 't': takenMs, 'la': lat, 'lo': lon};

  static PhotoInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return PhotoInfo(
      modifiedMs: (raw['m'] as num?)?.toInt() ?? 0,
      takenMs: (raw['t'] as num?)?.toInt(),
      lat: (raw['la'] as num?)?.toDouble(),
      lon: (raw['lo'] as num?)?.toDouble(),
    );
  }
}

/// Bir yer kümesi.
class PhotoPlace {
  final String key;
  final String name;
  final List<FsEntry> photos;
  const PhotoPlace(this.key, this.name, this.photos);
}

/// **Anılar** (2026-10-18, kullanıcının onayladığı öneri: *"fotoğraflarda
/// konuma göre gruplama, 'bu tarihte bir yıl önce' anıları"*).
/// "İnsanlar" (ML Kit yüz algılama) 2026-10-21'de KALDIRILDI (K8: KVKK
/// hassasiyeti + düşük cihazda ağır tarama). Eski dizindeki `'f'` alanı
/// okunurken yok sayılır, ilk kayıtta düşer.
///
/// Her şey CİHAZDA:
/// - **Bu gün**: geçmiş yıllarda bugünün tarihinde çekilmiş fotoğraflar
///   (EXIF çekim tarihi, yoksa dosya tarihi).
/// - **Yerler**: EXIF GPS'i ~5 km'lik kümelere toplanır, kümenin adı cihazın
///   `Geocoder`ından ("Çankaya, Ankara"). Koordinat bir yere gönderilmez,
///   ekranda gösterilmez (bkz. [ExifReader.parseGps]).
///
/// Sonuçlar artımlı bir dizinde (`photo_insights.json`): dosya değişmedikçe
/// ikinci kez okunmaz.
class PhotoInsights extends ChangeNotifier {
  PhotoInsights._();

  static final instance = PhotoInsights._();

  static const _file = 'photo_insights.json';

  /// GPS/tarih için okunan baş kısım: EXIF (APP1) en çok 64 KB.
  static const _headBytes = 64 * 1024;

  /// Kümeleme çözünürlüğü: 1/20 derece ≈ 5 km.
  static const _grid = 20;

  final Map<String, PhotoInfo> _info = {};
  final Map<String, String> _placeNames = {};
  List<FsEntry> _photos = const [];
  bool _loaded = false;
  bool _busy = false;
  ({int done, int total, String step})? _progress;

  bool get busy => _busy;
  ({int done, int total, String step})? get progress => _progress;
  List<FsEntry> get photos => _photos;

  String get _path => p.join(FmEnv.appSupportDir, _file);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = File(_path);
      if (f.existsSync()) {
        final raw = jsonDecode(await f.readAsString()) as Map;
        final info = raw['info'];
        if (info is Map) {
          info.forEach((k, v) {
            final i = PhotoInfo.fromJson(v);
            if (i != null && k is String) _info[k] = i;
          });
        }
        final places = raw['places'];
        if (places is Map) {
          places.forEach((k, v) {
            if (k is String && v is String) _placeNames[k] = v;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await File(_path).writeAsString(jsonEncode({
        'info': {for (final e in _info.entries) e.key: e.value.toJson()},
        'places': _placeNames,
      }));
    } catch (_) {}
  }

  /// Fotoğraf listesini yükler ve TARİH/KONUM bilgisi eksik olanları okur
  /// (hızlı: dosya başına 64 KB).
  Future<void> refresh({bool Function()? isCancelled}) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await ensureLoaded();
      _photos = await MediaLibrary.categoryFiles(FmCategory.image);
      final todo = [
        for (final e in _photos)
          if (_info[e.path]?.modifiedMs != e.modifiedMs) e,
      ];
      for (var i = 0; i < todo.length; i++) {
        if (isCancelled?.call() ?? false) break;
        if (i % 25 == 0) {
          _progress = (done: i, total: todo.length, step: 'meta');
          notifyListeners();
        }
        final e = todo[i];
        final head = await _head(e.path);
        final exif = head == null ? ExifData.empty : ExifReader.parse(head);
        final gps = head == null ? null : ExifReader.parseGps(head);
        _info[e.path] = PhotoInfo(
          modifiedMs: e.modifiedMs,
          takenMs: exif.taken?.millisecondsSinceEpoch,
          lat: gps?.lat,
          lon: gps?.lon,
        );
        if (i % 500 == 499) await _save();
      }
      // Silinen fotoğrafların kaydı düşer.
      final alive = {for (final e in _photos) e.path};
      _info.removeWhere((k, _) => !alive.contains(k));
      await _save();
      await _namePlaces();
    } finally {
      _busy = false;
      _progress = null;
      notifyListeners();
    }
  }

  static Future<Uint8List?> _head(String path) async {
    try {
      final f = File(path);
      final len = await f.length();
      final raf = await f.open();
      try {
        return await raf.read(len < _headBytes ? len : _headBytes);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  static String clusterKey(double lat, double lon) =>
      '${(lat * _grid).round()},${(lon * _grid).round()}';

  /// Adı bilinmeyen kümelere cihazın Geocoder'ından ad sorar.
  Future<void> _namePlaces() async {
    final keys = <String, ({double lat, double lon})>{};
    for (final i in _info.values) {
      if (i.lat == null || i.lon == null) continue;
      keys.putIfAbsent(clusterKey(i.lat!, i.lon!), () => (lat: i.lat!, lon: i.lon!));
    }
    var changed = false;
    for (final e in keys.entries) {
      if (_placeNames.containsKey(e.key)) continue;
      final name = await NativeExtras.placeName(e.value.lat, e.value.lon);
      if (name != null && name.isNotEmpty) {
        _placeNames[e.key] = name;
        changed = true;
      }
    }
    if (changed) await _save();
  }

  PhotoInfo? infoOf(String path) => _info[path];

  /// Geçmiş yıllarda bugünün (ay+gün) tarihli fotoğraflar, yıla göre.
  Map<int, List<FsEntry>> onThisDay({DateTime? now}) =>
      onThisDayOf(_photos, (e) => _info[e.path]?.dateMs() ?? e.modifiedMs,
          now: now ?? DateTime.now());

  @visibleForTesting
  static Map<int, List<FsEntry>> onThisDayOf(
      List<FsEntry> photos, int Function(FsEntry) dateOf,
      {required DateTime now}) {
    final out = <int, List<FsEntry>>{};
    for (final e in photos) {
      final d = DateTime.fromMillisecondsSinceEpoch(dateOf(e));
      if (d.month == now.month && d.day == now.day && d.year < now.year) {
        out.putIfAbsent(d.year, () => []).add(e);
      }
    }
    return Map.fromEntries(
        out.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  /// Yer kümeleri, en kalabalık önce.
  List<PhotoPlace> places() {
    final groups = <String, List<FsEntry>>{};
    for (final e in _photos) {
      final i = _info[e.path];
      if (i?.lat == null || i?.lon == null) continue;
      groups.putIfAbsent(clusterKey(i!.lat!, i.lon!), () => []).add(e);
    }
    // Aynı adı alan komşu kümeler birleşir ("Çankaya, Ankara" iki hücreye
    // düşebilir).
    final byName = <String, List<FsEntry>>{};
    final keyOf = <String, String>{};
    for (final g in groups.entries) {
      final name = _placeNames[g.key] ?? '';
      final id = name.isEmpty ? g.key : name;
      byName.putIfAbsent(id, () => []).addAll(g.value);
      keyOf.putIfAbsent(id, () => g.key);
    }
    final out = [
      for (final e in byName.entries)
        PhotoPlace(keyOf[e.key]!, _placeNames[keyOf[e.key]!] ?? '', e.value
          ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs))),
    ]..sort((a, b) => b.photos.length.compareTo(a.photos.length));
    return out;
  }

  @visibleForTesting
  void debugReset() {
    _info.clear();
    _placeNames.clear();
    _photos = const [];
    _loaded = false;
    _busy = false;
  }
}
