import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Geçmişteki tek aktarım kaydı.
class TransferRecord {
  /// `true` = alındı, `false` = gönderildi.
  final bool incoming;

  /// Alınanda diskteki yeni dosya/klasör, gönderilende kaynak yol.
  final String path;
  final String name;
  final int size;

  /// Karşı cihazın adı ("QR", "Tarayıcı" da olabilir).
  final String peer;
  final DateTime at;

  const TransferRecord({
    required this.incoming,
    required this.path,
    required this.name,
    required this.size,
    required this.peer,
    required this.at,
  });

  bool get exists =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  Map<String, Object> toJson() => {
        'i': incoming,
        'p': path,
        'n': name,
        's': size,
        'k': peer,
        't': at.millisecondsSinceEpoch,
      };

  static TransferRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['p'];
    if (path is! String) return null;
    return TransferRecord(
      incoming: raw['i'] == true,
      path: path,
      name: '${raw['n'] ?? ''}',
      size: (raw['s'] as num?)?.toInt() ?? 0,
      peer: '${raw['k'] ?? ''}',
      at: DateTime.fromMillisecondsSinceEpoch((raw['t'] as num?)?.toInt() ?? 0),
    );
  }
}

/// **Son Alınanlar / Gönderilenler** (2026-10-29 kullanıcı isteği: *"tamamlanan
/// aktarımlar için geçmiş paneli; aldığı dosyayı doğrudan buradan açabilsin
/// veya konumunu görebilsin"*).
///
/// Eskiden "alınanlar" listesi yalnız ekran açıkken bellekteydi; ekran
/// kapanınca gelen dosyanın nereye indiği unutuluyordu. Kayıt cihazda kalır
/// (SharedPreferences, en çok [limit] satır) — dosyanın İÇERİĞİ değil yalnız
/// yolu/adı.
class TransferHistory extends ChangeNotifier {
  TransferHistory._();
  static final instance = TransferHistory._();

  static const _key = 'transfer_history_v1';
  static const limit = 200;

  final List<TransferRecord> _items = [];
  Future<void>? _loading;

  List<TransferRecord> get items => List.unmodifiable(_items);
  List<TransferRecord> get received =>
      _items.where((e) => e.incoming).toList(growable: false);
  List<TransferRecord> get sent =>
      _items.where((e) => !e.incoming).toList(growable: false);

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      _items
        ..clear()
        ..addAll(list.map(TransferRecord.fromJson).whereType<TransferRecord>());
      notifyListeners();
    } catch (_) {
      // Bozuk kayıt: geçmiş boş başlar, aktarım etkilenmez.
    }
  }

  Future<void> add(List<TransferRecord> records) async {
    if (records.isEmpty) return;
    await ensureLoaded();
    _items.insertAll(0, records);
    if (_items.length > limit) _items.removeRange(limit, _items.length);
    notifyListeners();
    await _save();
  }

  Future<void> remove(TransferRecord record) async {
    _items.remove(record);
    notifyListeners();
    await _save();
  }

  Future<void> clear({required bool incoming}) async {
    _items.removeWhere((e) => e.incoming == incoming);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final e in _items) e.toJson()]));
    } catch (_) {}
  }

  @visibleForTesting
  void debugReset() {
    _items.clear();
    _loading = null;
  }
}
