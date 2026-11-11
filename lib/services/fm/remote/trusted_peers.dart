import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenilen gönderen: ad + (biliniyorsa) kurulum kimliği.
class TrustedPeer {
  final String name;
  final String id;
  const TrustedPeer(this.name, [this.id = '']);

  Map<String, String> toJson() => {'name': name, 'id': id};
}

/// **Güvenilen cihazlar** — teklifi sorulmadan kabul edilir (kullanıcı isteği
/// 2026-11-03: *"dosya aktarımında güvenilir cihaz ekleme, onay sormaz, PC'de
/// de"*). Telefon (Wi-Fi `/sor`) ve bilgisayar ("Dosya Aktar" push daveti)
/// aynı listeye düşer.
///
/// Eşleşme: iki tarafta da kimlik varsa KİMLİK, yoksa ad (bilgisayar
/// uygulaması `/sor`'da kimlik göndermiyor).
/// ponytail: ad/kimlik ağda taklit edilebilir — aynı Wi-Fi'deki biri aynı adı
/// alırsa dosyası sorulmadan GELİR (yalnız kayıt klasörüne yazılır, açılmaz).
/// Gerekirse çifte özel jeton (`/sor` cevabında verilip saklanan) eklenir.
class TrustedPeers extends ChangeNotifier {
  TrustedPeers._();
  static final instance = TrustedPeers._();

  static const _key = 'near_trusted_v1';

  final List<TrustedPeer> _items = [];
  Future<void>? _loading;

  List<TrustedPeer> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      for (final e in jsonDecode(raw) as List) {
        if (e is Map && e['name'] is String) {
          _items.add(TrustedPeer(e['name'] as String, '${e['id'] ?? ''}'));
        }
      }
      notifyListeners();
    } catch (_) {
      // Bozuk kayıt: liste boş başlar (her teklif yine sorulur — güvenli yön).
    }
  }

  bool isTrusted(String name, [String id = '']) => _items.any((t) =>
      id.isNotEmpty && t.id.isNotEmpty ? t.id == id : t.name == name);

  Future<void> add(String name, [String id = '']) async {
    await ensureLoaded();
    if (name.trim().isEmpty || isTrusted(name, id)) return;
    _items.add(TrustedPeer(name, id));
    notifyListeners();
    await _save();
  }

  Future<void> remove(TrustedPeer peer) async {
    _items.remove(peer);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, jsonEncode([for (final t in _items) t.toJson()]));
    } catch (_) {
      // Bilinçli: kalıcı kayıt yazılamadı (disk dolu/izin) — bellekteki durum geçerli kalır, sonraki kayıtta yeniden denenir.
    }
  }

  @visibleForTesting
  void debugReset() {
    _items.clear();
    _loading = null;
  }
}
