import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'peer_share.dart';

/// Bluetooth ile görülen yakındaki Dosya Okuyucu.
class BlePeer {
  final String id;
  final String name;
  final String address;
  final int rssi;

  const BlePeer({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
  });
}

/// Bluetooth'tan gelen "dosya gönderiyorum" daveti. Veri Wi-Fi'den akar:
/// * [url] doluysa alıcı çeker — QR'daki metnin aynısı (gerekirse hotspot bilgisiyle).
/// * [push] ise gönderen (ör. Windows "Dosya Aktar", `tool/pc_aktar`) alıcı Yakındakiler'i
///   açınca onu Wi-Fi'de bulup kendisi gönderir; alıcı yalnız onaylar.
class BleInvite {
  final String from;
  final String fromId;
  final String url;
  final bool push;
  final int count;
  final int totalBytes;
  final List<String> names;

  const BleInvite({
    required this.from,
    required this.fromId,
    required this.url,
    this.push = false,
    required this.count,
    required this.totalBytes,
    required this.names,
  });

  String encode() => jsonEncode({
        'v': 1,
        'f': from,
        'i': fromId,
        'u': url,
        if (push) 'p': 1,
        'n': count,
        's': totalBytes,
        // BLE yazması kısa olmalı: ilk birkaç ad, kısaltılmış.
        'a': [
          for (final n in names.take(4))
            n.length > 40 ? '${n.substring(0, 37)}…' : n,
        ],
      });

  static BleInvite? decode(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final push = m['p'] == 1;
      final url = m['u'] is String ? m['u'] as String : '';
      if (!push && url.isEmpty) return null;
      return BleInvite(
        from: '${m['f'] ?? '?'}',
        fromId: '${m['i'] ?? ''}',
        url: url,
        push: push,
        count: (m['n'] as num?)?.toInt() ?? 0,
        totalBytes: (m['s'] as num?)?.toInt() ?? 0,
        names: [
          if (m['a'] is List)
            for (final n in m['a'] as List) '$n',
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// [BleNearby.start] sonucu.
enum BleStart { ok, off, denied, unsupported, failed }

/// `ci/NearbyBle.kt`in Dart yüzü (kanal `dosya/ble`).
///
/// Yakındakiler ekranı açıkken telefon Bluetooth LE ile **görünür** ve
/// **tarar**: aynı Wi-Fi'de olmasalar da iki telefon birbirini otomatik görür
/// (2026-10-29 kullanıcı isteği). Bluetooth yalnız bulma + davet içindir;
/// dosya Wi-Fi'den (ortak ağ ya da gönderenin geçici hotspot'u) akar.
abstract final class BleNearby {
  static const _ch = MethodChannel('dosya/ble');

  static final _found = StreamController<BlePeer>.broadcast();
  static final _invites = StreamController<BleInvite>.broadcast();

  static Stream<BlePeer> get found => _found.stream;
  static Stream<BleInvite> get invites => _invites.stream;

  static bool _wired = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _ch.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (args is! Map) return null;
      switch (call.method) {
        case 'found':
          _found.add(BlePeer(
            id: '${args['id'] ?? ''}',
            name: '${args['name'] ?? ''}',
            address: '${args['address'] ?? ''}',
            rssi: (args['rssi'] as num?)?.toInt() ?? -100,
          ));
        case 'invite':
          final invite = BleInvite.decode('${args['payload'] ?? ''}');
          if (invite != null) _invites.add(invite);
      }
      return null;
    });
  }

  /// Görünmeyi ve taramayı başlatır. İzin eksikse bir kez ister.
  static Future<BleStart> start({required String id, required String name}) async {
    _wire();
    Future<void> call() =>
        _ch.invokeMethod<bool>('start', {'id': id, 'name': name});
    try {
      await call();
      return BleStart.ok;
    } on PlatformException catch (e) {
      if (e.code == 'perm') {
        final statuses = await _request();
        if (!statuses) return BleStart.denied;
        try {
          await call();
          return BleStart.ok;
        } on PlatformException catch (e2) {
          return _map(e2.code);
        }
      }
      return _map(e.code);
    } on MissingPluginException {
      return BleStart.unsupported;
    } catch (_) {
      return BleStart.failed;
    }
  }

  static BleStart _map(String code) => switch (code) {
        'off' => BleStart.off,
        'perm' => BleStart.denied,
        'unsupported' => BleStart.unsupported,
        _ => BleStart.failed,
      };

  static Future<bool> _request() async {
    try {
      final perms = [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final res = await perms.request();
      // Android 12+: üç Bluetooth izni; öncesi: konum (Bluetooth izinleri
      // orada her zaman "verildi" döner).
      final bt = res[Permission.bluetoothScan]?.isGranted == true &&
          res[Permission.bluetoothConnect]?.isGranted == true;
      return bt || res[Permission.locationWhenInUse]?.isGranted == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  /// **Arka planda görünürlük** (yalnız kişisel derleme, `ci/kisisel/NearbyBgService.kt`):
  /// genel derlemede `available` false döner ve anahtar hiç gösterilmez.
  static Future<({bool available, bool on})> bgState() async {
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('bgState');
      return (available: r?['available'] == true, on: r?['on'] == true);
    } catch (_) {
      return (available: false, on: false);
    }
  }

  /// Servisi açar (ya da adı/metinleri tazeler). [texts]: bildirim metinleri (dil tablosundan).
  static Future<bool> bgEnable(
      {required String id, required String name, required Map<String, String> texts}) async {
    _wire();
    Future<bool?> call() =>
        _ch.invokeMethod<bool>('bgEnable', {'id': id, 'name': name, ...texts});
    try {
      // Android 13+: bildirim izni yoksa istek görünmez — önce sorulur (reddedilse de açılır).
      await Permission.notification.request();
      return await call() ?? false;
    } on PlatformException catch (e) {
      if (e.code != 'perm' || !await _request()) return false;
      try {
        return await call() ?? false;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> bgDisable() async {
    try {
      await _ch.invokeMethod('bgDisable');
    } catch (_) {}
  }

  /// Bildirimden gelinen isteğin bildirimi kalksın.
  static Future<void> bgClearAsk() async {
    try {
      await _ch.invokeMethod('bgClearAsk');
    } catch (_) {}
  }

  /// [address]'teki cihaza daveti yazar; ulaştıysa true.
  static Future<bool> invite(String address, BleInvite invite) async {
    try {
      return await _ch.invokeMethod<bool>(
              'invite', {'address': address, 'payload': invite.encode()}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Bu kurulumun kalıcı kimliği — kendi yayınımızı ayıklamak ve Wi-Fi ile
/// Bluetooth'tan gelen aynı cihazı birleştirmek için.
abstract final class NearbyIdentity {
  static const _key = 'nearby_device_id';
  static String? _cached;

  static Future<String> id() async {
    final c = _cached;
    if (c != null) return c;
    try {
      final prefs = await SharedPreferences.getInstance();
      var v = prefs.getString(_key);
      if (v == null || v.length != 8) {
        v = PeerShare.newDeviceId();
        await prefs.setString(_key, v);
      }
      return _cached = v;
    } catch (_) {
      return _cached = PeerShare.newDeviceId();
    }
  }
}
