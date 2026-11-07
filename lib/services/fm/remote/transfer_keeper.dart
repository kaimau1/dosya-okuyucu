import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/l10n/app_strings.dart';
import '../notification_hub.dart';

/// [TransferKeeper]'ın koruyabildiği sunucu (QR/web sunucusu, alıcı).
abstract interface class KeepableServer {
  /// Şu an süren aktarım sayısı.
  int get activeTransfers;

  /// Son istek zamanı (hiç istek yoksa `null`).
  DateTime? get lastActivity;

  Future<void> stop();
}

/// **Süren aktarım ekrandan bağımsızdır** (kullanıcı 2026-11-01: *"gönderici
/// gönderim ekranından çıkarsa gönderim yarıda kalıyor"*).
///
/// Kök neden: Yakındakiler ekranı `dispose`ta sunucuyu `close(force: true)`
/// ile kapatıyordu; ana ekrana çıkınca da süreç donabiliyordu. Artık:
/// * Aktarım sürerken ön plan servisi + uyanıklık kilidi tutulur (ekran
///   açıkken de: ana ekrana çıkmak ya da ekranı kilitlemek aktarımı kesmez).
/// * Ekran kapanırken son [idle] içinde isteği olan sunucu devralınır; iş
///   bitince [idle] kadar bekler (sıradaki dosya, tarayıcının yeniden denemesi)
///   ve kapanır. Hiç istek almamış sunucu eskisi gibi ANINDA kapanır: arka
///   planda kimsenin bilmediği açık kapı bırakılmaz.
class TransferKeeper {
  TransferKeeper({this.idle = const Duration(seconds: 60)});

  static final TransferKeeper instance = TransferKeeper();

  static const owner = 'transfer_keeper';
  static const actionStop = 'transfer.stop';
  static const _notificationId = 90412;
  static const _channel = MethodChannel('dosya/qr');

  final Duration idle;

  final _live = <KeepableServer>{};
  final _adopted = <KeepableServer, Future<void> Function()?>{};
  Timer? _idleTimer;
  bool _holding = false;

  /// Devralınmış sunucu sayısı (test ve durum için).
  int get adoptedCount => _adopted.length;

  /// Sunucunun aktarım sayısı değişince çağrılır.
  void onActivity(KeepableServer server) {
    _live.add(server);
    if (server.activeTransfers == 0 && !_adopted.containsKey(server)) {
      _live.remove(server);
    }
    _sync();
  }

  /// Ekran sunucuyu bırakıyor. [onClosed], sunucu gerçekten kapandığında
  /// çalışır (geçici ağı kapatmak gibi).
  Future<void> handOff(
    KeepableServer server, {
    Future<void> Function()? onClosed,
  }) async {
    if (!_isBusy(server)) {
      _live.remove(server);
      await server.stop();
      await onClosed?.call();
      _sync();
      return;
    }
    _adopted[server] = onClosed;
    _live.add(server);
    _sync();
  }

  /// Yeni ekran geçici ağı kendisi kuracak: devralınan oturum onu kapatmasın.
  void detachClosers() => _adopted.updateAll((_, _) => null);

  /// Bildirimdeki "Durdur": devralınan her şey hemen kapanır.
  Future<void> stopAdopted() async {
    for (final server in _adopted.keys.toList()) {
      await _close(server);
    }
    _sync();
  }

  bool _isBusy(KeepableServer server) {
    if (server.activeTransfers > 0) return true;
    final last = server.lastActivity;
    return last != null && DateTime.now().difference(last) < idle;
  }

  Future<void> _close(KeepableServer server) async {
    final onClosed = _adopted.remove(server);
    _live.remove(server);
    await server.stop();
    await onClosed?.call();
  }

  void _sync() {
    final active = _live.any((s) => s.activeTransfers > 0);
    unawaited(_hold(active || _adopted.isNotEmpty));
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_adopted.isEmpty) return;
    _idleTimer = Timer(idle ~/ 4, () {
      final expired = [
        for (final server in _adopted.keys)
          if (!_isBusy(server)) server,
      ];
      unawaited(() async {
        for (final server in expired) {
          await _close(server);
        }
        _sync();
      }());
    });
  }

  Future<void> _hold(bool on) async {
    if (on == _holding) return;
    _holding = on;
    try {
      await _channel.invokeMethod('keepAwake', {'on': on});
    } catch (_) {
      // Bilinçli: kilit alınamasa da aktarım ekran açıkken sürer.
    }
    final hub = NotificationHub.instance;
    if (!on) {
      await hub.releaseService(owner);
      return;
    }
    final str = AppStrings.current;
    await hub.acquireService(
      owner,
      FgNotice(
        id: _notificationId,
        title: str.t('near.keep_title'),
        body: str.t('near.keep_body'),
        details: AndroidNotificationDetails(
          'fm_transfer',
          str.t('peer.channel_name'),
          channelDescription: str.t('peer.channel_desc'),
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          actions: [
            AndroidNotificationAction(
              actionStop,
              str.t('common.stop'),
              cancelNotification: false,
            ),
          ],
        ),
        payload: owner,
      ),
    );
  }
}
