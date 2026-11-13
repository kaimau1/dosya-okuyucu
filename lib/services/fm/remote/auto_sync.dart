import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_nearby.dart' show NearbyIdentity;
import 'peer_crypto.dart';
import 'peer_share.dart';
import 'transfer_history.dart';

/// Bir güvenilen cihazla eşitleme kuralı.
class SyncRule {
  /// Karşı cihazın kalıcı anahtar parmak izi (G5) — kural YALNIZ bu anahtarı
  /// kanıtlayan eşe uygulanır.
  final String fp;
  final String name;
  final bool on;
  final List<String> folders;

  /// Bu andan (ms) sonra değişen dosyalar gönderilir: açıldığı an, sonra her
  /// başarılı turda gönderilen en yeni dosyanın zamanı.
  final int mark;

  const SyncRule(this.fp, this.name, this.on, this.folders, this.mark);

  SyncRule copyWith({bool? on, List<String>? folders, int? mark, String? name}) =>
      SyncRule(fp, name ?? this.name, on ?? this.on, folders ?? this.folders,
          mark ?? this.mark);

  Map<String, Object> toJson() =>
      {'fp': fp, 'n': name, 'on': on, 'd': folders, 'm': mark};

  static SyncRule? fromJson(Object? raw) {
    if (raw is! Map || raw['fp'] is! String) return null;
    return SyncRule(
      raw['fp'] as String,
      '${raw['n'] ?? ''}',
      raw['on'] == true,
      [for (final d in (raw['d'] as List? ?? const [])) '$d'],
      (raw['m'] as num?)?.toInt() ?? 0,
    );
  }
}

/// **Otomatik klasör eşitleme** (2026-11-13 kullanıcı isteği: ör. Kamera →
/// bilgisayar).
///
/// * Varsayılan KAPALI; cihaz başına açılır. Yalnız açıldığı andan SONRA
///   değişen dosyalar gider (eski arşiv bir anda yollanmaz).
/// * Yalnız güvenilen, anahtar parmak izi eşleşen eşe ve yalnız şifreli
///   protokolle ([PeerSender.send] `requireFingerprint`): ad/IP taklidi ya da
///   eski sürüm eş → hiçbir şey gönderilmez.
/// * Pil: arka planda tarama YOK. Tur yalnız (a) uygulama açılış kuyruğunda,
///   (b) öne gelişte (en çok 5 dk'da bir) ve (c) Aktar ekranı açıkken o eş
///   görününce koşar. Kural yoksa ağa hiç çıkılmaz.
class AutoSync extends ChangeNotifier {
  AutoSync._();
  static final instance = AutoSync._();

  static const _key = 'aktar_esitle_v1';
  static const batch = 20;
  static const cooldown = Duration(minutes: 5);

  final Map<String, SyncRule> _rules = {};
  Future<void>? _loading;
  bool _running = false;
  DateTime? _lastSweep;

  /// Ekranda "eşitleniyor" göstermek için (parmak izi → durum metni yok; yalnız bayrak).
  final ValueNotifier<String?> active = ValueNotifier(null);

  Future<void> ensureLoaded() => _loading ??= () async {
        try {
          final raw = (await SharedPreferences.getInstance()).getString(_key);
          if (raw == null) return;
          for (final r in (jsonDecode(raw) as List).map(SyncRule.fromJson)) {
            if (r != null) _rules[r.fp] = r;
          }
          notifyListeners();
        } catch (_) {
          // Bozuk kayıt: kural yok sayılır (güvenli yön — hiçbir şey gönderilmez).
        }
      }();

  SyncRule? rule(String fp) => _rules[fp];

  bool get anyOn => _rules.values.any((r) => r.on && r.folders.isNotEmpty);

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, jsonEncode([for (final r in _rules.values) r.toJson()]));
    } catch (_) {
      // Bilinçli: yazılamazsa bellekteki kural bu oturumda geçerli kalır.
    }
  }

  /// Kuralı açar/kapatır, klasörleri değiştirir. Kapalıdan açığa geçişte
  /// işaret "şimdi" olur (önceki dosyalar gönderilmez).
  Future<void> set(String fp, String name,
      {bool? on, List<String>? folders, DateTime? now}) async {
    await ensureLoaded();
    final old = _rules[fp] ?? SyncRule(fp, name, false, const [], 0);
    final turningOn = (on ?? old.on) && !old.on;
    _rules[fp] = old.copyWith(
      name: name,
      on: on,
      folders: folders,
      mark: turningOn ? (now ?? DateTime.now()).millisecondsSinceEpoch : null,
    );
    notifyListeners();
    await _save();
  }

  /// Gönderilecekler: kuralın klasörlerinde (3 kat derinliğe kadar, gizliler
  /// hariç) işaretten sonra değişen dosyalar, eskiden yeniye.
  static Future<List<File>> pending(SyncRule r, {int limit = 500}) async {
    final out = <(File, int)>[];
    Future<void> walk(Directory d, int depth) async {
      try {
        await for (final e in d.list(followLinks: false)) {
          if (p.basename(e.path).startsWith('.')) continue;
          if (e is File) {
            final t = (await e.stat()).modified.millisecondsSinceEpoch;
            if (t > r.mark) out.add((e, t));
          } else if (e is Directory && depth < 3) {
            await walk(e, depth + 1);
          }
        }
      } catch (_) {
        // Bilinçli: okunamayan klasör atlanır; tur geri kalanla sürer.
      }
    }

    for (final f in r.folders) {
      await walk(Directory(f), 0);
    }
    out.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final e in out.take(limit)) e.$1];
  }

  /// [peer] için kural açıksa yeni dosyaları gönderir; giden dosya sayısı.
  /// Gönderim parti parti; bir parti tam gitmezse işaret ilerlemez (sonraki
  /// turda kaldığı yerden — yarım dosya alıcıda tid ile sürer).
  Future<int> runFor(Peer peer,
      {required PeerIdentity me,
      required String name,
      required String id,
      Duration retryFor = const Duration(seconds: 30)}) async {
    await ensureLoaded();
    final r = _rules[peer.fingerprint];
    if (r == null || !r.on || r.folders.isEmpty || !peer.secure) return 0;
    if (_running) return 0;
    _running = true;
    active.value = r.name;
    var sent = 0;
    try {
      final files = await pending(r);
      for (var i = 0; i < files.length; i += batch) {
        final part = files.sublist(i, i + batch > files.length ? files.length : i + batch);
        final started = DateTime.now();
        final res = await PeerSender.send(peer, [for (final f in part) f.path],
            senderName: name,
            senderId: id,
            identity: me,
            requireFingerprint: r.fp,
            retryFor: retryFor);
        final ok = res.sent == part.length && !res.hasError && !res.identityMismatch &&
            !res.declined && !res.wrongCode && !res.cancelled;
        await TransferHistory.instance.add([
          for (final f in part)
            TransferRecord(
              incoming: false,
              path: f.path,
              name: p.basename(f.path),
              size: await f.length(),
              peer: r.name,
              at: DateTime.now(),
              ok: ok,
              percent: ok ? 100 : 0,
              duration: DateTime.now().difference(started),
            ),
        ]);
        if (!ok) break;
        sent += part.length;
        final newest = (await part.last.stat()).modified.millisecondsSinceEpoch;
        _rules[r.fp] = (_rules[r.fp] ?? r).copyWith(mark: newest);
        await _save();
      }
    } catch (_) {
      // Bilinçli: tur bir güvence; hata olursa işaret ilerlemez, sonraki turda yeniden denenir.
    } finally {
      _running = false;
      active.value = null;
      notifyListeners();
    }
    return sent;
  }

  /// Açılışta / öne gelişte: kural varsa 4 sn Wi-Fi'de arar, kuralı olan eş
  /// görünürse eşitler. [force] bekleme süresini atlar.
  Future<void> sweep({bool force = false}) async {
    await ensureLoaded();
    if (!anyOn || _running) return;
    final now = DateTime.now();
    final last = _lastSweep;
    if (!force && last != null && now.difference(last) < cooldown) return;
    _lastSweep = now;
    final PeerIdentity me;
    final String id;
    final String name;
    try {
      me = await PeerIdentity.load();
      id = await NearbyIdentity.id();
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getString('peer_device_name') ?? '';
      name = n.trim().isEmpty ? 'Android' : n.trim();
    } catch (_) {
      return;
    }
    final found = <Peer>[];
    try {
      await for (final peer in PeerSender.discover()) {
        if (peer.secure && (_rules[peer.fingerprint]?.on ?? false)) found.add(peer);
      }
    } catch (_) {
      // Bilinçli: ağ yok/yayın engelli — tur yapılmaz.
    }
    for (final peer in found) {
      await runFor(peer, me: me, name: name, id: id);
    }
  }

  @visibleForTesting
  void debugReset() {
    _rules.clear();
    _loading = null;
    _running = false;
    _lastSweep = null;
  }
}
