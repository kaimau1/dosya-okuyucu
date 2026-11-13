import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Güvenilen gönderen: ad + (biliniyorsa) kurulum kimliği + (şifreli
/// protokolle tanındıysa) kalıcı anahtarının parmak izi.
class TrustedPeer {
  final String name;
  final String id;

  /// G5: karşı tarafın kalıcı X25519 açık anahtarının parmak izi. Doluysa
  /// eşleşme YALNIZ buna bakar (ad/kimlik taklit edilebilir, anahtar edilemez).
  final String fp;
  const TrustedPeer(this.name, [this.id = '', this.fp = '']);

  bool get keyed => fp.isNotEmpty;

  Map<String, String> toJson() =>
      {'name': name, 'id': id, if (fp.isNotEmpty) 'fp': fp};
}

/// **Güvenilen cihazlar** — teklifi sorulmadan kabul edilir (kullanıcı isteği
/// 2026-11-03: *"dosya aktarımında güvenilir cihaz ekleme, onay sormaz, PC'de
/// de"*). Telefon (Wi-Fi `/sor`) ve bilgisayar ("Dosya Aktar" push daveti)
/// aynı listeye düşer.
///
/// Eşleşme (2026-11-13, G5):
/// * **Şifreli teklif** (parmak izi var): yalnız AYNI parmak izli kayıt
///   güvenilir. Eski (anahtarsız) kayıt eşleşmez → bir kez sorulur, kabulde
///   kayıt anahtara bağlanır ([bindKey]).
/// * **Düz teklif** (eski sürüm/eski bilgisayar uygulaması): yalnız anahtarsız
///   kayıtlar — kimlik varsa KİMLİK, yoksa ad. Anahtarlı bir cihazın adını
///   taşıyan düz teklif güvenilmez (taklit olabilir).
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
      _items.clear();
      for (final e in jsonDecode(raw) as List) {
        if (e is Map && e['name'] is String) {
          _items.add(TrustedPeer(
              e['name'] as String, '${e['id'] ?? ''}', '${e['fp'] ?? ''}'));
        }
      }
      notifyListeners();
    } catch (_) {
      // Bozuk kayıt: liste boş başlar (her teklif yine sorulur — güvenli yön).
    }
  }

  bool isTrusted(String name, [String id = '', String fp = '']) {
    if (fp.isNotEmpty) return _items.any((t) => t.fp == fp);
    return _items.any((t) => !t.keyed &&
        (id.isNotEmpty && t.id.isNotEmpty ? t.id == id : t.name == name));
  }

  /// Parmak iziyle kayıt (yoksa null).
  TrustedPeer? byKey(String fp) {
    if (fp.isEmpty) return null;
    for (final t in _items) {
      if (t.fp == fp) return t;
    }
    return null;
  }

  Future<void> add(String name, [String id = '', String fp = '']) async {
    await ensureLoaded();
    if (name.trim().isEmpty || isTrusted(name, id, fp)) return;
    if (fp.isNotEmpty) {
      // Aynı cihazın eski (anahtarsız) kaydı anahtarlı kayıtla değişir.
      _items.removeWhere((t) =>
          !t.keyed && (id.isNotEmpty && t.id.isNotEmpty ? t.id == id : t.name == name));
    }
    _items.add(TrustedPeer(name, id, fp));
    notifyListeners();
    await _save();
  }

  /// Eski (anahtarsız) güvenilen kayıt şifreli teklifle eşleşti mi? — kimlik
  /// (yoksa ad) tutuyor ama parmak izi yok. Kullanıcı kabul ederse
  /// [add] anahtarla yeniler.
  bool hasLegacy(String name, [String id = '']) => _items.any((t) =>
      !t.keyed && (id.isNotEmpty && t.id.isNotEmpty ? t.id == id : t.name == name));

  /// Başka bir motorun (ör. "Dosya al" kutucuğu) yazdığını görmek için.
  Future<void> reload() async {
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {
      // Bilinçli: yeniden okunamazsa bellekteki liste geçerli kalır.
    }
    _loading = null;
    await ensureLoaded();
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
