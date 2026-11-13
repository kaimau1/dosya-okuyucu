import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_strings.dart';
import '../fm_env.dart';
import 'ble_nearby.dart' show NearbyIdentity;
import 'peer_crypto.dart';
import 'peer_share.dart';
import 'transfer_history.dart';
import 'trusted_peers.dart';

/// **"Dosya al" kutucuğunun Dart yüzü** (2026-11-13) — Kotlin
/// `ci/Aktar.kt` `AktarAlServisi` ekransız bir Flutter motorunda
/// [aktarKutucukAlici]'yı çalıştırır.
///
/// Ekran yok → onay penceresi yok: kural [accepts] — YALNIZ şifreli teklif
/// ve gönderenin anahtar parmak izi güvenilenlerde. Başka her teklif
/// reddedilir, Kotlin "Aktar'ı aç" bildirimi gösterir. 30 dk aktarım yoksa
/// servis kendini kapatır (G4.8 düzeni).
abstract final class TileReceiver {
  static const channel = MethodChannel('dosya/kutucuk');
  static const idle = Duration(minutes: 30);

  static bool accepts(PeerOffer offer, TrustedPeers trusted) =>
      offer.encrypted &&
      trusted.isTrusted(offer.from, offer.fromId, offer.fingerprint);

  static String saveDir() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    return Directory(download).existsSync() ? download : FmEnv.primaryRoot;
  }

  static Future<void> run() async {
    await FmEnv.ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final chosen = (prefs.getString('peer_device_name') ?? '').trim();
    final me = await PeerIdentity.load();
    final receiver = PeerReceiver(
      identity: me,
      deviceName: chosen.isEmpty ? 'Android' : chosen,
      deviceId: await NearbyIdentity.id(),
      saveDir: saveDir(),
      onAsk: (offer) async {
        await TrustedPeers.instance.reload();
        if (accepts(offer, TrustedPeers.instance)) return true;
        unawaited(_call('asked', {'from': offer.from}));
        return false;
      },
      onReceived: (path, from) {
        unawaited(() async {
          var size = 0;
          try {
            size = await File(path).length();
          } catch (_) {
            // Bilinçli: boyut yalnız bilgi.
          }
          await TransferHistory.instance.add([
            TransferRecord(
                incoming: true,
                path: path,
                name: p.basename(path),
                size: size,
                peer: from,
                at: DateTime.now()),
          ]);
        }());
        unawaited(_call('received', {'name': p.basename(path), 'from': from}));
      },
    );
    await receiver.start();
    final started = DateTime.now();
    Timer.periodic(const Duration(minutes: 1), (t) {
      final last = receiver.lastActivity ?? started;
      if (receiver.activeTransfers == 0 && DateTime.now().difference(last) > idle) {
        t.cancel();
        unawaited(receiver.stop().then((_) => _call('stop')));
      }
    });
  }

  static Future<void> _call(String method, [Object? args]) async {
    try {
      await channel.invokeMethod<void>(method, args);
    } catch (_) {
      // Bilinçli: kanal yoksa (test) bildirim gösterilmez; alım sürer.
    }
  }

  /// Ana uygulamadan: Aktar ekranı açılınca kutucuk alıcısı durur (aynı port
  /// ve yayın tek sahipte) ve bildirim metinleri geçerli dilde saklanır.
  static Future<void> handOver(AppStrings s) async {
    await _call('texts', {
      'channel': s.t('tile.channel'),
      'title': s.t('tile.title'),
      'body': s.t('tile.body'),
      'stop': s.t('tile.stop'),
      'got': s.t('tile.got'),
      'refused': s.t('tile.refused'),
      'open': s.t('tile.open'),
    });
    await _call('stop');
  }
}

/// Kotlin servisinin çalıştırdığı giriş noktası (adı Aktar.kt'de yazılı;
/// `vm:entry-point` ağaç sarsmada ve karartmada adı korur).
@pragma('vm:entry-point')
Future<void> aktarKutucukAlici() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TileReceiver.run();
}
