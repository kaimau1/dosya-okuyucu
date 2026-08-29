import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'fm_env.dart';

/// Panodaki **Araçlar** ızgarasının sırası: çok kullanılan araç öne gelir.
///
/// Kullanıcı isteği (2026-08-29): *"araçlar alanı kullanıma göre sıralanmalı"*.
/// 11 araç dört sütuna üç satır hâlinde diziliyordu ve sıra ELLE yazılmıştı:
/// birinin günde beş kez açtığı "Yer aç" üçüncü satırda, hiç dokunmadığı
/// "Ağ depolama" ilk satırda duruyordu. Sıra artık kullanıcının kendi
/// davranışından geliyor.
///
/// **Kalıcılık [OpenHistory] deseniyle aynı:** `appSupportDir` altında küçük
/// bir JSON. `SharedPreferences` değil — bu sayaçlar ayar değil, kullanım
/// kaydı; ayar tablosunu şişirmeleri için bir sebep yok.
abstract final class ToolUsage {
  static const _fileName = 'tool_usage.json';

  /// Araç kimliği → kaç kez açıldı.
  static final Map<String, int> _counts = {};

  /// Yükleme Future'ı paylaşılır: bayrak kullanılsaydı, disk okuması hâlâ
  /// sürerken gelen bir [record] boş belleğin üstüne yazıp var olan tüm
  /// sayaçları silerdi (bkz. `OpenHistory` aynı tuzak).
  static Future<void>? _loadFuture;

  /// Sayaçlar değiştikçe artar — pano ızgarayı bununla tazeler.
  static int revision = 0;

  static String get _path => p.join(FmEnv.appSupportDir, _fileName);

  /// Salt okunur görünüm (sıralama ve test için).
  static Map<String, int> get counts => Map.unmodifiable(_counts);

  /// Dizin henüz hazır değilse **kilitlemez**: boş bir haritayla bir kez
  /// kilitlenirse sayaçlar o oturum boyunca sıfır kalırdı.
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
        final n = (entry.value as num?)?.toInt();
        if (n == null || n <= 0) continue;
        _counts['${entry.key}'] = n;
      }
    } catch (_) {
      // Bozuk dosya sessizce yok sayılır: bu bir kolaylık kaydı, sıralama
      // bozulur ama uygulama çalışmaya devam eder.
    } finally {
      revision++;
    }
  }

  /// "[id] aracı açıldı" — sayacı bir artırır.
  ///
  /// Çağıran `await` etmez (araç ekranı bu yazmayı beklememeli); önce var olan
  /// kayıt yüklenir, sonra artırılır.
  static Future<void> record(String id) async {
    if (id.isEmpty) return;
    await ensureLoaded();
    _counts[id] = (_counts[id] ?? 0) + 1;
    await _save();
  }

  static Future<void> _save() async {
    revision++;
    if (FmEnv.appSupportDir.isEmpty) return;
    try {
      final tmp = File('$_path.tmp');
      await tmp.writeAsString(jsonEncode(_counts), flush: true);
      await tmp.rename(_path);
    } catch (_) {}
  }

  /// Yalnız test için: bellekteki sayaçları sıfırlar.
  static void resetForTest() {
    _counts.clear();
    _loadFuture = null;
    revision++;
  }
}

/// **Saf sıralama** — kimlik listesi + sayaçlar → yeni sıra (indeksler).
///
/// Kurallar:
/// - Çok kullanılan önce gelir.
/// - Eşitlikte **yazılış sırası** korunur (kararlı sıralama). Böylece hiç
///   kullanılmamış araçlar birbirine göre yer değiştirmez; kullanıcı ızgarayı
///   her açtığında aynı yerde bulur.
/// - Hiç kayıt yoksa liste **hiç değişmez** — ilk kurulumda ızgara elle
///   düşünülmüş sırasında kalır.
///
/// Saf ve senkron: `flutter_test` içinde diske dokunmadan doğrulanabilir.
List<int> rankByUsage(List<String> ids, Map<String, int> counts) {
  final order = [for (var i = 0; i < ids.length; i++) i];
  order.sort((a, b) {
    final ca = counts[ids[a]] ?? 0;
    final cb = counts[ids[b]] ?? 0;
    if (ca != cb) return cb.compareTo(ca);
    return a.compareTo(b);
  });
  return order;
}
