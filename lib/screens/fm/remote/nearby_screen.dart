import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_haptics.dart';
import '../../../core/app_icons.dart';
import '../../../core/app_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/motion.dart';
import '../../../core/safe_insets.dart';
import '../../../core/snack.dart';
import '../../../core/theme.dart';
import '../../../core/user_error.dart';
import '../../../models/fs_entry.dart';
import '../../../services/fm/download_service.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/file_ops.dart' show FmProgress;
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/notification_hub.dart';
import '../../../services/fm/remote/ble_nearby.dart';
import '../../../services/fm/remote/ftp_service.dart';
import '../../../services/fm/remote/peer_share.dart';
import '../../../services/fm/remote/qr_transfer.dart';
import '../../../services/fm/remote/transfer_history.dart';
import '../../../services/fm/remote/transfer_thumbs.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_entry_icon.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';
import '../../../widgets/fm/transfer_offer_sheet.dart';
import '../../../widgets/qr_code.dart';
import '../../../widgets/section_header.dart';
import '../browser_screen.dart';
import '../download_manager_screen.dart';
import '../folder_picker_screen.dart';
import 'ftp_server_screen.dart';
import 'qr_receive_flow.dart';
import 'remote_connections_screen.dart';

/// Gelen dosya bildiriminin kimliği (uygulamadaki öteki kimliklerden farklı).
const _receiveNotificationId = 90521;

/// Ekranda tek bir yakındaki cihaz: Wi-Fi'den, Bluetooth'tan ya da ikisinden.
class _Near {
  final String key;
  String name;
  Peer? wifi;
  BlePeer? ble;
  DateTime wifiSeen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime bleSeen = DateTime.fromMillisecondsSinceEpoch(0);

  _Near(this.key, this.name);
}

/// **Yakındakiler** — telefonlar arası aktarımın TEK ekranı (2026-10-29).
///
/// Kullanıcı isteği: *"Gönder / Al ayrımını kaldırın (AirDrop mantığı) —
/// Yakındakiler adında tek bir aktarım ekranı; yakındaki cihazlar bu ekrana
/// girer girmez birbirini otomatik görsün"* ve *"aktarım ekranlarını tek
/// birleşik, anlaşılır, pratik bir ekrana indirgeyelim"*.
///
/// Eskiden üç ekran vardı: Aktar (merkez), Yakındaki cihaz (Gönder/Al
/// sekmeli) ve QR ile paylaş. Kullanıcı hangisini açacağını, karşı tarafın
/// hangi sekmede olması gerektiğini bilmek zorundaydı. Artık ekran açıldığı
/// anda HER İKİ yön birden çalışır:
/// * **Görünür + alır:** alıcı sunucusu açılır, Wi-Fi yayınına ve Bluetooth
///   taramasına cevap verilir; gelen her gönderim küçük resimli kabul
///   penceresiyle sorulur.
/// * **Bulur:** Wi-Fi (UDP yayını, birkaç saniyede bir) ve Bluetooth LE ile
///   yakındaki Dosya Okuyucu'lar avatar olarak belirir — aynı cihaz iki
///   yoldan görünse de tek avatardır.
/// * **Gönderir:** dosya/klasör seçiliyse avatara dokunmak yeter. Aynı
///   Wi-Fi'deyse doğrudan, yalnız Bluetooth'tan görünüyorsa gönderen geçici
///   ağ (hotspot) kurar ve adresi Bluetooth'tan davet olarak yollar; alıcı
///   uygulama ağa kendisi bağlanır.
/// * **Uygulaması olmayana:** aynı ekranda QR kodu + elle yazılabilir kısa
///   adres (geçici web sunucusu, tarayıcıdan indirme).
/// * **Geçmiş:** Son alınanlar / gönderilenler; dokununca açılır, "Konumu
///   göster" klasörde gösterir.
///
/// Bilgisayar (FTP/tarayıcı), ağ depolama ve indirmeler "Diğer yollar"da.
/// Eşleştirme kodu (PIN) kullanıcı isteğiyle bu ekranda YOK; onay penceresi
/// var.
class NearbyScreen extends StatefulWidget {
  /// Gönderilecek dosya/klasörler (boş da olabilir).
  final List<String> sendPaths;

  /// Testte ağ/Bluetooth başlatılmasın.
  @visibleForTesting
  final bool services;

  const NearbyScreen({super.key, this.sendPaths = const [], this.services = true});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const _section = EdgeInsets.fromLTRB(Gap.xs, Gap.lg, Gap.xs, Gap.sm);

  late final List<String> _selection = [...widget.sendPaths];

  String _id = '';
  String _saveDir = QrReceiveFlow.defaultSaveDir();
  bool _confirmIncoming = true;

  // ── alma ────────────────────────────────────────────────────────────────
  PeerReceiver? _receiver;
  String? _incoming;
  double? _incomingFraction;

  // ── bulma ───────────────────────────────────────────────────────────────
  final Map<String, _Near> _near = {};
  Timer? _scanTimer;
  Timer? _pruneTimer;
  StreamSubscription<Peer>? _scan;
  StreamSubscription<BlePeer>? _bleFound;
  StreamSubscription<BleInvite>? _bleInvite;
  BleStart? _ble;
  bool _hasWifi = false;

  // ── QR / web ────────────────────────────────────────────────────────────
  QrShareServer? _web;
  String? _webHost;
  ({String ssid, String pass, String sec})? _hotspot;
  String? _hotspotHost;
  bool _hotspotBusy = false;
  int _hotspotStep = 0;
  int _served = 0;
  Timer? _webDebounce;
  String? _webError;

  bool _historyIncoming = true;
  bool _historyAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(TransferHistory.instance.ensureLoaded());
    if (widget.services) unawaited(_boot());
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _pruneTimer?.cancel();
    _webDebounce?.cancel();
    _scan?.cancel();
    _bleFound?.cancel();
    _bleInvite?.cancel();
    // Sunucu, yayın ve hotspot ekranla birlikte ÖLÜR: arka planda dinleyen
    // bir kapı bırakmak kullanıcının bilmediği bir risk olurdu.
    unawaited(_receiver?.stop());
    unawaited(_web?.stop());
    if (_hotspot != null) unawaited(QrNative.stopHotspot());
    if (widget.services) unawaited(BleNearby.stop());
    super.dispose();
  }

  String get _deviceName {
    final chosen = context.read<AppState>().peerName;
    if (chosen.isNotEmpty) return chosen;
    return Platform.isAndroid ? 'Android' : Platform.operatingSystem;
  }

  Future<void> _boot() async {
    _id = await NearbyIdentity.id();
    if (!mounted) return;
    await _startReceiving();
    _hasWifi = (await _wifiAddress()) != null;
    if (!mounted) return;
    _scanWifi();
    _scanTimer = Timer.periodic(const Duration(seconds: 6), (_) => _scanWifi());
    _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) => _prune());
    _bleFound = BleNearby.found.listen(_onBle);
    _bleInvite = BleNearby.invites.listen(_onInvite);
    await _startBle();
    if (_selection.isNotEmpty) _scheduleWeb();
  }

  Future<void> _startBle() async {
    final r = await BleNearby.start(id: _id, name: _deviceName);
    if (mounted) setState(() => _ble = r);
  }

  // ── Bulma ──────────────────────────────────────────────────────────────

  void _scanWifi() {
    _scan?.cancel();
    _scan = PeerSender.discover(timeout: const Duration(seconds: 4)).listen((peer) {
      if (!mounted) return;
      // Kendi cevabımız (aynı telefonun alıcısı) listeye girmez.
      if (peer.id.isNotEmpty && peer.id == _id) return;
      setState(() {
        final key = peer.id.isNotEmpty ? peer.id : peer.key;
        final n = _near.putIfAbsent(key, () => _Near(key, peer.name));
        n
          ..name = peer.name
          ..wifi = peer
          ..wifiSeen = DateTime.now();
      });
    });
  }

  void _onBle(BlePeer peer) {
    if (!mounted || peer.id == _id) return;
    setState(() {
      final n = _near.putIfAbsent(peer.id, () => _Near(peer.id, peer.name));
      if (n.name.isEmpty || n.wifi == null) n.name = peer.name;
      n
        ..ble = peer
        ..bleSeen = DateTime.now();
    });
  }

  /// Uzun süredir görünmeyen yol düşer; iki yolu da düşen cihaz silinir.
  void _prune() {
    if (!mounted) return;
    final now = DateTime.now();
    var changed = false;
    for (final n in _near.values) {
      if (n.wifi != null && now.difference(n.wifiSeen).inSeconds > 20) {
        n.wifi = null;
        changed = true;
      }
      if (n.ble != null && now.difference(n.bleSeen).inSeconds > 15) {
        n.ble = null;
        changed = true;
      }
    }
    final before = _near.length;
    _near.removeWhere((_, n) => n.wifi == null && n.ble == null);
    if (changed || before != _near.length) setState(() {});
  }

  // ── Alma ───────────────────────────────────────────────────────────────

  Future<void> _startReceiving() async {
    await _receiver?.stop();
    final receiver = PeerReceiver(
      deviceName: _deviceName,
      deviceId: _id,
      saveDir: _saveDir,
      onAsk: _confirmIncoming ? _askIncoming : null,
      onProgress: (name, received, total) {
        if (!mounted) return;
        final fraction = total > 0 ? received / total : null;
        final label = total > 0
            ? '$name · ${FsPaths.humanSize(received)} / ${FsPaths.humanSize(total)}'
            : name;
        // `setState` her yığında değil, metin değiştikçe.
        if (_incoming != label) {
          setState(() {
            _incoming = label;
            _incomingFraction = fraction;
          });
        }
      },
      onReceived: (path, from) {
        unawaited(TransferHistory.instance.add([
          TransferRecord(
            incoming: true,
            path: path,
            name: p.basename(path),
            size: _sizeOf(path),
            peer: from,
            at: DateTime.now(),
          ),
        ]));
        // Kullanıcı ekrana bakmıyor olabilir: sistem bildirimi.
        unawaited(NotificationHub.instance.show(
          _receiveNotificationId,
          AppStrings.current.t('peer.notify_title'),
          '${p.basename(path)} · $from',
          AndroidNotificationDetails(
            'fm_peer',
            AppStrings.current.t('peer.channel_name'),
            channelDescription: AppStrings.current.t('peer.channel_desc'),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ));
        if (!mounted) return;
        setState(() {
          _incoming = null;
          _incomingFraction = null;
          _historyIncoming = true;
        });
      },
    );
    try {
      await receiver.start();
    } catch (_) {
      // Port alınamadı: ekran "görünmüyor" der.
    }
    if (!mounted) {
      await receiver.stop();
      return;
    }
    setState(() => _receiver = receiver);
  }

  Future<bool> _askIncoming(PeerOffer offer) async {
    if (!mounted) return false;
    return showTransferOffer(
      context,
      from: offer.from,
      count: offer.count,
      totalBytes: offer.totalBytes,
      saveDir: _saveDir,
      items: [
        if (offer.items.isEmpty && offer.firstName.isNotEmpty)
          OfferRow(name: offer.firstName, size: offer.totalBytes),
        for (final it in offer.items)
          OfferRow(
            name: it.name,
            size: it.size,
            folderFiles: it.folderFiles,
            thumb: it.thumb,
          ),
      ],
    );
  }

  /// Bluetooth daveti: önce ne geleceği sorulur, kabul edilirse Wi-Fi'ye
  /// (gerekirse gönderenin geçici ağına) bağlanılıp dosyalar çekilir.
  Future<void> _onInvite(BleInvite invite) async {
    if (!mounted) return;
    final ok = await showTransferOffer(
      context,
      from: invite.from,
      count: invite.count,
      totalBytes: invite.totalBytes,
      saveDir: _saveDir,
      items: [for (final n in invite.names) OfferRow(name: n, size: 0)],
    );
    if (!ok || !mounted) return;
    await QrReceiveFlow.runPayload(context, invite.url,
        saveDir: _saveDir, preAccepted: true, from: invite.from);
  }

  Future<void> _scanQr() async {
    await QrReceiveFlow.run(context, saveDir: _saveDir);
  }

  // ── Seçim ──────────────────────────────────────────────────────────────

  Future<void> _addFiles() async {
    try {
      final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
      final paths = [
        for (final f in picked?.files ?? const <PlatformFile>[])
          if (f.path != null) f.path!,
      ];
      if (paths.isEmpty || !mounted) return;
      setState(() {
        for (final path in paths) {
          if (!_selection.contains(path)) _selection.add(path);
        }
      });
      _scheduleWeb();
    } catch (e) {
      if (mounted) showSnack(context, userErrorText(e));
    }
  }

  Future<void> _addFolder() async {
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        actionLabel: AppStrings.of(context).t('near.pick_this_folder'),
        startPath: FmEnv.primaryRoot,
      ),
    ));
    if (dest == null || !mounted) return;
    setState(() {
      if (!_selection.contains(dest)) _selection.add(dest);
    });
    _scheduleWeb();
  }

  void _remove(String path) {
    setState(() => _selection.remove(path));
    _scheduleWeb();
  }

  // ── QR / web sunucusu ──────────────────────────────────────────────────

  /// Seçim değişince sunucu yeni listeyle (kısa bir beklemeden sonra) kurulur.
  void _scheduleWeb() {
    if (!widget.services) return;
    _webDebounce?.cancel();
    _webDebounce = Timer(Motion.long, () {
      unawaited(_restartWeb());
    });
  }

  Future<void> _restartWeb() async {
    final old = _web;
    _web = null;
    await old?.stop();
    if (_selection.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final server = QrShareServer([..._selection],
          senderName: _deviceName,
          thumbnail: TransferThumbs.of,
          onServed: (name) {
            unawaited(TransferHistory.instance.add([
              TransferRecord(
                incoming: false,
                path: _selection.firstWhere((s) => name.startsWith(p.basename(s)),
                    orElse: () => name),
                name: name,
                size: 0,
                peer: AppStrings.current.t('near.via_web'),
                at: DateTime.now(),
              ),
            ]));
            if (mounted) setState(() => _served++);
          });
      await server.start();
      final host = await _wifiAddress();
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _web = server;
        _webHost = host;
        _webError = null;
      });
      // Ortak Wi-Fi yoksa hotspot tek yol — sormadan kurulur.
      if (host == null && _hotspot == null) await _startHotspot();
    } catch (e) {
      if (mounted) setState(() => _webError = userErrorText(e));
    }
  }

  /// Wi-Fi arayüzünün (`wlan0`) adresi; mobil veri değil.
  static Future<String?> _wifiAddress({Set<String> except = const {}}) async {
    try {
      final list = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final i in list) {
        final n = i.name.toLowerCase();
        if (!(n.startsWith('wlan') || n.startsWith('ap') || n.startsWith('swlan'))) {
          continue;
        }
        for (final a in i.addresses) {
          if (!except.contains(a.address)) return a.address;
        }
      }
    } catch (_) {
      // Arayüz listesi okunamadı: adres yok sayılır, ekran hotspot'u önerir.
    }
    return null;
  }

  Future<bool> _startHotspot() async {
    if (_hotspot != null) return true;
    if (_hotspotBusy) return false;
    setState(() => _hotspotBusy = true);
    final before = <String>{if (_webHost != null) _webHost!};
    try {
      final h = await QrNative.startHotspot();
      String? host;
      for (var i = 0; i < 20 && host == null; i++) {
        await Future<void>.delayed(Motion.medium);
        host = await _wifiAddress(except: before);
      }
      if (!mounted) return false;
      setState(() {
        _hotspot = h;
        _hotspotHost = host;
        _hotspotStep = 0;
        if (host == null) _webError = context.t('qrf.no_address');
      });
      return host != null;
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _webError = context.t(switch (e.code) {
              'perm' => 'qrf.err_perm',
              'location_off' => 'qrf.err_location',
              'unsupported' => 'qrf.err_unsupported',
              _ => 'qrf.err_hotspot',
            }));
      }
      return false;
    } finally {
      if (mounted) setState(() => _hotspotBusy = false);
    }
  }

  // ── Gönderme ───────────────────────────────────────────────────────────

  Future<void> _tapPeer(_Near near) async {
    if (_selection.isEmpty) {
      final picked = await showAppSheet<String>(
        context,
        title: context.t('near.what_to_send', {'name': near.name}),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.addFile),
              title: Text(ctx.t('near.add_files')),
              onTap: () => Navigator.pop(ctx, 'files'),
            ),
            ListTile(
              leading: const Icon(AppIcons.addFolder),
              title: Text(ctx.t('near.add_folder')),
              onTap: () => Navigator.pop(ctx, 'folder'),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      if (picked == 'files') {
        await _addFiles();
      } else {
        await _addFolder();
      }
      if (_selection.isEmpty || !mounted) return;
    }
    AppHaptics.step();
    final wifi = near.wifi;
    if (wifi != null) {
      await _sendWifi(wifi);
    } else if (near.ble != null) {
      await _sendBle(near);
    }
  }

  Future<void> _sendWifi(Peer peer) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    final payload = [..._selection];
    final startedAt = DateTime.now();
    var waiting = false;
    final result = await showFmProgress<PeerSendResult>(
      context,
      title: strings.t('peer.sending'),
      name: strings.t('peer.sending_name'),
      task: (report, isCancelled) => PeerSender.send(
        peer,
        payload,
        senderName: _deviceName,
        senderId: _id,
        isCancelled: isCancelled,
        thumbnail: TransferThumbs.of,
        onWaiting: (w) => waiting = w,
        onProgress: (name, sent, total) => report(
            FmProgress(sent, total, waiting ? strings.t('near.waiting') : name)),
      ),
      describe: (value) {
        if (value.total <= 0) return '';
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        if (waiting) return strings.t('near.waiting');
        final speed = elapsed > 300
            ? FsPaths.humanSize((value.done * 1000 / elapsed).round())
            : '';
        return speed.isEmpty
            ? '${FsPaths.humanSize(value.done)} / ${FsPaths.humanSize(value.total)}'
            : strings.t('peer.speed', {
                'done': FsPaths.humanSize(value.done),
                'total': FsPaths.humanSize(value.total),
                'speed': speed,
              });
      },
    );
    if (result.sent > 0 && !result.hasError && !result.cancelled) {
      await TransferHistory.instance.add([
        for (final path in payload)
          TransferRecord(
            incoming: false,
            path: path,
            name: p.basename(path),
            size: _sizeOf(path),
            peer: peer.name,
            at: DateTime.now(),
          ),
      ]);
      await appState.rememberPeer(peer.name, peer.host, peer.port);
    }
    if (!mounted) return;
    if (result.sent > 0) setState(() => _historyIncoming = false);
    showSnackBarReplacing(
      messenger,
      SnackBar(
        content: Text(
          result.declined
              ? strings.t('peer.declined_by_peer')
              : result.hasError
                  ? strings.t('peer.send_failed', {'error': result.errors.first})
                  : result.cancelled
                      ? strings.t('peer.send_stopped', {'n': result.sent})
                      : strings.t('peer.sent', {'n': result.sent, 'name': peer.name}),
        ),
      ),
    );
  }

  /// Yalnız Bluetooth'tan görünen cihaz: gönderen geçici ağ kurar, adresi
  /// davet olarak yollar; alıcı onaylayınca dosyalar Wi-Fi'den çekilir.
  Future<void> _sendBle(_Near near) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_web == null) await _restartWeb();
    final web = _web;
    if (web == null || !mounted) return;
    // Aynı Wi-Fi'de olmadığımızı varsayıyoruz (öyle olsaydı Wi-Fi'den de
    // görünürdü): geçici ağ kurulur. Kurulamazsa Wi-Fi adresi denenir.
    final hotspotOk = await _startHotspot();
    if (!mounted) return;
    final hs = _hotspot;
    String? url;
    if (hotspotOk && hs != null && _hotspotHost != null) {
      url = QrPayload.encode(web.urlFor(_hotspotHost!),
          ssid: hs.ssid, pass: hs.pass, sec: hs.sec);
    } else if (_webHost != null) {
      url = web.urlFor(_webHost!).toString();
    }
    if (url == null) {
      showSnackOn(messenger, strings.t('near.no_network'));
      return;
    }
    final total = _selection.fold<int>(0, (a, s) => a + _sizeOf(s));
    showSnackOn(messenger, strings.t('near.inviting', {'name': near.name}));
    final ok = await BleNearby.invite(
      near.ble!.address,
      BleInvite(
        from: _deviceName,
        fromId: _id,
        url: url,
        count: _selection.length,
        totalBytes: total,
        names: [for (final s in _selection) p.basename(s)],
      ),
    );
    showSnackOn(
      messenger,
      ok
          ? strings.t('near.invited', {'name': near.name})
          : strings.t('near.invite_failed', {'name': near.name}),
      duration: const Duration(seconds: 6),
    );
  }

  // ── Ayarlar ────────────────────────────────────────────────────────────

  Future<void> _editDeviceName() async {
    final appState = context.read<AppState>();
    final name = await showAppPrompt(
      context,
      title: context.t('peer.device_name'),
      initial: appState.peerName,
      confirmLabel: context.t('common.save'),
    );
    if (name == null || !mounted) return;
    await appState.setPeerName(name);
    if (!mounted || !widget.services) return;
    // Ad yayın cevabının ve Bluetooth yayınının içinde gidiyor.
    await _startReceiving();
    await _startBle();
    _scheduleWeb();
  }

  Future<void> _pickSaveDir() async {
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        actionLabel: AppStrings.of(context).t('peer.change_folder'),
        startPath: _saveDir,
      ),
    ));
    if (dest == null || !mounted) return;
    setState(() => _saveDir = dest);
    if (widget.services) await _startReceiving();
  }

  static int _sizeOf(String path) {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) return File(path).lengthSync();
    } catch (_) {
      // Boyut yalnız bilgi: okunamazsa 0 yazılır, aktarım etkilenmez.
    }
    return 0;
  }

  // ── Çizim ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('near.title')),
        actions: [
          IconButton(
            key: const ValueKey('near-scan-qr'),
            tooltip: context.t('qrf.scan'),
            icon: const Icon(AppIcons.qrScan),
            onPressed: _scanQr,
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            onSelected: (v) async {
              switch (v) {
                case 'name':
                  await _editDeviceName();
                case 'dir':
                  await _pickSaveDir();
                case 'confirm':
                  setState(() => _confirmIncoming = !_confirmIncoming);
                  if (widget.services) await _startReceiving();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'name',
                child: Text(ctx.t('peer.device_name')),
              ),
              PopupMenuItem(
                value: 'dir',
                child: Text(ctx.t('peer.save_to', {'path': p.basename(_saveDir)})),
              ),
              CheckedPopupMenuItem(
                value: 'confirm',
                checked: _confirmIncoming,
                child: Text(ctx.t('peer.ask_switch')),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: withNavInset(context,
            const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md)),
        children: [
          _statusCard(context),
          const SizedBox(height: Gap.md),
          _selectionCard(context),
          SectionHeader(context.t('near.devices'),
              count: _near.isEmpty ? null : '${_near.length}', padding: _section),
          _devices(context),
          if (_incoming != null) _incomingRow(context),
          SectionHeader(context.t('near.no_app'), padding: _section),
          _webCard(context),
          SectionHeader(context.t('near.history'), padding: _section),
          _history(context),
          SectionHeader(context.t('near.other_ways'), padding: _section),
          _otherWays(context),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = _receiver?.running ?? false;
    final bleOk = _ble == BleStart.ok;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            _Radar(active: visible || bleOk),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _editDeviceName,
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                        Icon(AppIcons.edit, size: 16, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t(visible || bleOk ? 'near.visible' : 'near.starting'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: [
                      _Pill(
                        icon: AppIcons.wifi,
                        label: context.t(_hasWifi ? 'near.wifi_on' : 'near.wifi_off'),
                        ok: _hasWifi,
                      ),
                      _Pill(
                        icon: AppIcons.bluetooth,
                        label: context.t(switch (_ble) {
                          BleStart.ok => 'near.bt_on',
                          BleStart.off => 'near.bt_off',
                          BleStart.denied => 'near.bt_denied',
                          BleStart.unsupported => 'near.bt_none',
                          BleStart.failed => 'near.bt_failed',
                          null => 'near.bt_wait',
                        }),
                        ok: bleOk,
                        onTap: bleOk || _ble == BleStart.unsupported || !widget.services
                            ? null
                            : _startBle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selection.isEmpty
                  ? context.t('near.pick_title')
                  : context.t('near.selected', {'n': _selection.length}),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              context.t(_selection.isEmpty ? 'near.pick_sub' : 'near.tap_device'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (_selection.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selection.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
                  itemBuilder: (_, i) => _SelectedTile(
                    path: _selection[i],
                    onRemove: () => _remove(_selection[i]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('near-add-files'),
                    onPressed: _addFiles,
                    icon: const Icon(AppIcons.addFile, size: AppIcons.small),
                    label: Text(context.t('near.add_files')),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('near-add-folder'),
                    onPressed: _addFolder,
                    icon: const Icon(AppIcons.addFolder, size: AppIcons.small),
                    label: Text(context.t('near.add_folder')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _devices(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = _near.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Column(
          children: [
            Icon(AppIcons.nearMe, size: AppIcons.large, color: scheme.onSurfaceVariant),
            const SizedBox(height: Gap.sm),
            Text(
              context.t('near.searching'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              context.t('near.searching_sub'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.md,
      children: [
        for (final n in list)
          _PeerAvatar(
            name: n.name,
            wifi: n.wifi != null,
            ble: n.ble != null,
            onTap: () => _tapPeer(n),
          ),
      ],
    );
  }

  Widget _incomingRow(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('near.receiving'), style: theme.textTheme.titleSmall),
              const SizedBox(height: Gap.xs),
              Text(_incoming!, maxLines: 2, style: theme.textTheme.bodySmall),
              const SizedBox(height: Gap.sm),
              LinearProgressIndicator(value: _incomingFraction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final web = _web;
    final hs = _hotspot;
    if (_selection.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(AppIcons.qr),
          title: Text(context.t('near.web_idle')),
          subtitle: Text(context.t('near.web_idle_sub')),
        ),
      );
    }
    String? qr;
    String? url;
    String hint;
    if (web == null) {
      hint = context.t('qrf.preparing');
    } else if (hs != null && _hotspotHost != null) {
      final u = web.urlFor(_hotspotHost!);
      url = u.toString();
      qr = _hotspotStep == 0
          ? QrPayload.wifi(hs.ssid, hs.pass, sec: hs.sec)
          : QrPayload.encode(u, ssid: hs.ssid, pass: hs.pass, sec: hs.sec);
      hint = context.t(_hotspotStep == 0 ? 'near.web_step1' : 'near.web_step2');
    } else if (_webHost != null) {
      url = web.urlFor(_webHost!).toString();
      qr = url;
      hint = context.t('near.web_same_wifi');
    } else {
      hint = context.t('qrf.preparing');
    }
    final size =
        (MediaQuery.sizeOf(context).shortestSide - 140).clamp(160.0, 260.0);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hs != null && _hotspotHost != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(context.t('near.step_wifi'))),
                    ButtonSegment(value: 1, label: Text(context.t('near.step_page'))),
                  ],
                  selected: {_hotspotStep},
                  onSelectionChanged: (s) => setState(() => _hotspotStep = s.first),
                ),
              ),
            Center(
              child: qr == null
                  ? SizedBox.square(
                      dimension: size,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : QrCode(key: ValueKey(qr), data: qr, size: size),
            ),
            const SizedBox(height: Gap.sm),
            Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (hs != null && _hotspotStep == 0) ...[
              const SizedBox(height: Gap.xs),
              SelectableText(
                '${context.t('near.network')}: ${hs.ssid}\n${context.t('near.password')}: ${hs.pass}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _hotspotStep = 1),
                  child: Text(context.t('qrf.connected_next')),
                ),
              ),
            ],
            if (url != null && (hs == null || _hotspotStep == 1)) ...[
              const SizedBox(height: Gap.sm),
              Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.control),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: url!));
                    showSnack(context, context.t('near.copied'));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.md, vertical: Gap.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            url,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: AppTheme.fontMono,
                            ),
                          ),
                        ),
                        Icon(AppIcons.copyPlain,
                            size: AppIcons.small, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(context.t('near.type_address'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (_served > 0) ...[
              const SizedBox(height: Gap.sm),
              Text(context.t('qrf.served', {'n': _served}),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: Paper.success(context))),
            ],
            if (_webError != null) ...[
              const SizedBox(height: Gap.sm),
              Text(_webError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ],
            if (hs == null && web != null) ...[
              const SizedBox(height: Gap.xs),
              TextButton.icon(
                onPressed: _hotspotBusy ? null : _startHotspot,
                icon: _hotspotBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.hotspot, size: AppIcons.small),
                label: Text(context.t('qrf.no_common_wifi')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _history(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: TransferHistory.instance,
      builder: (context, _) {
        final h = TransferHistory.instance;
        final all = _historyIncoming ? h.received : h.sent;
        final shown = _historyAll ? all : all.take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(AppIcons.download, size: AppIcons.small),
                  label: Text(context.t('near.received_tab')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(AppIcons.uploadArrow, size: AppIcons.small),
                  label: Text(context.t('near.sent_tab')),
                ),
              ],
              selected: {_historyIncoming},
              onSelectionChanged: (s) => setState(() {
                _historyIncoming = s.first;
                _historyAll = false;
              }),
            ),
            const SizedBox(height: Gap.sm),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Text(
                  context.t(_historyIncoming ? 'near.none_received' : 'near.none_sent'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final r in shown) _historyRow(context, r),
                  ],
                ),
              ),
            if (!_historyAll && all.length > shown.length)
              TextButton(
                onPressed: () => setState(() => _historyAll = true),
                child: Text(context.t('near.show_all', {'n': all.length})),
              ),
          ],
        );
      },
    );
  }

  Widget _historyRow(BuildContext context, TransferRecord r) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exists = r.exists;
    final isDir = exists && FileSystemEntity.isDirectorySync(r.path);
    final ext = p.extension(r.name).replaceFirst('.', '').toLowerCase();
    final c = isDir ? FmCategory.folder : FsEntry.categoryForExtension(ext);
    final (glyph, color) = isDir
        ? (AppIcons.folder, FmColors.folder)
        : FmColors.forExtension(ext) ?? (FmColors.iconFor(c), FmColors.forCategory(c));
    final when = MaterialLocalizations.of(context).formatShortDate(r.at);
    final time = TimeOfDay.fromDateTime(r.at).format(context);
    return ListTile(
      leading: Icon(glyph, color: exists ? color : scheme.outline),
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          r.peer,
          '$when $time',
          if (r.size > 0) FsPaths.humanSize(r.size),
          if (!exists) context.t('near.missing'),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: !exists
          ? null
          : () {
              if (isDir) {
                Navigator.of(context)
                    .push(browserRoute(BrowserScreen(path: r.path)));
              } else {
                EntryOpener.open(context, r.path);
              }
            },
      trailing: PopupMenuButton<String>(
        icon: const Icon(AppIcons.more, size: AppIcons.small),
        onSelected: (v) {
          switch (v) {
            case 'open':
              EntryOpener.open(context, r.path);
            case 'reveal':
              Navigator.of(context).push(browserRoute(BrowserScreen(
                  path: p.dirname(r.path), focusPath: r.path)));
            case 'remove':
              unawaited(TransferHistory.instance.remove(r));
          }
        },
        itemBuilder: (ctx) => [
          if (exists && !isDir)
            PopupMenuItem(value: 'open', child: Text(ctx.t('common.open'))),
          if (exists)
            PopupMenuItem(value: 'reveal', child: Text(ctx.t('near.reveal'))),
          PopupMenuItem(value: 'remove', child: Text(ctx.t('near.remove_record'))),
        ],
      ),
    );
  }

  Widget _otherWays(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FtpService.instance, DownloadService.instance]),
      builder: (context, _) {
        final sharing = FtpService.instance.running;
        final downloading = DownloadService.instance.activeTasks.length;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _wayTile(
                context,
                icon: sharing ? AppIcons.hotspot : AppIcons.computer,
                title: context.t('xfer.computer'),
                note: sharing ? context.t('ftpd.running') : context.t('xfer.computer_note'),
                live: sharing,
                screen: const FtpServerScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.dns,
                title: context.t('fm.network_storage'),
                note: context.t('xfer.nas_note'),
                screen: const RemoteConnectionsScreen(),
              ),
              const Divider(height: 1),
              _wayTile(
                context,
                icon: AppIcons.downloadForOffline,
                title: context.t('xfer.downloads'),
                note: downloading > 0
                    ? context.t('fm.jobs_running', {'n': downloading})
                    : context.t('xfer.downloads_note'),
                live: downloading > 0,
                screen: const DownloadManagerScreen(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wayTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String note,
    required Widget screen,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(note,
          maxLines: 2,
          style: live ? TextStyle(color: Paper.success(context)) : null),
      trailing: Icon(AppIcons.chevron, color: scheme.onSurfaceVariant),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}

/// Durum kartındaki küçük "yayında" halkası.
class _Radar extends StatefulWidget {
  final bool active;

  const _Radar({required this.active});

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Radar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher
        .accessibilityFeatures.disableAnimations;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? scheme.primary : scheme.outline;
    return SizedBox.square(
      dimension: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _RadarPainter(color, widget.active ? _c.value : 0),
          child: Center(child: Icon(AppIcons.device, color: color)),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Color color;
  final double t;

  _RadarPainter(this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..color = color.withValues(alpha: 0.12));
    if (t > 0) {
      for (final k in [0.0, 0.5]) {
        final v = (t + k) % 1.0;
        canvas.drawCircle(
          c,
          r * (0.62 + 0.38 * v),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - v) * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final VoidCallback? onTap;

  const _Pill({required this.icon, required this.label, required this.ok, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = ok ? Paper.success(context) : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  final String name;
  final bool wifi;
  final bool ble;
  final VoidCallback onTap;

  const _PeerAvatar({
    required this.name,
    required this.wifi,
    required this.ble,
    required this.onTap,
  });

  static const _hues = [
    AppHues.jade, AppHues.tangerine, AppHues.purple, AppHues.green,
    AppHues.red, AppHues.olive, AppHues.cyan, AppHues.plum,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hue = _hues[name.hashCode.abs() % _hues.length];
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: 84,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: hue.withValues(alpha: 0.16),
                    foregroundColor: hue,
                    child: Text(initial,
                        style: theme.textTheme.headlineSmall?.copyWith(color: hue)),
                  ),
                  PositionedDirectional(
                    end: -4,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (wifi) Icon(AppIcons.wifi, size: 12, color: scheme.primary),
                          if (ble) Icon(AppIcons.bluetooth, size: 12, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _SelectedTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDir = FileSystemEntity.isDirectorySync(path);
    final name = p.basename(path);
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    final c = isDir ? FmCategory.folder : FsEntry.categoryForExtension(ext);
    final (glyph, color) = isDir
        ? (AppIcons.folder, FmColors.folder)
        : FmColors.forExtension(ext) ?? (FmColors.iconFor(c), FmColors.forCategory(c));
    final isImage = c == FmCategory.image;
    return SizedBox(
      width: 76,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: isImage
                        ? Image.file(File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            errorBuilder: (_, __, ___) =>
                                Center(child: Icon(glyph, color: color)))
                        : Center(child: Icon(glyph, color: color, size: 30)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall),
            ],
          ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(AppIcons.close, size: 14, color: scheme.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Paylaş" dendiğinde çıkan seçim: **Yakındakiler** mi, başka uygulama mı?
///
/// 2026-10-29: üç yol (yakındaki cihaz / QR / diğer uygulamalar) ikiye indi —
/// QR artık Yakındakiler ekranının içinde, uygulaması olmayan da oradan alır.
/// `true` = iş burada bitti (ya da vazgeçildi); `false` = çağıran sistem
/// paylaşımını açsın.
Future<bool> showShareChoice(BuildContext context, List<String> paths) async {
  final choice = await showAppSheet<String>(
    context,
    title: context.t('common.share'),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const ValueKey('share-nearby'),
          leading: const Icon(AppIcons.nearMe),
          title: Text(ctx.t('near.title')),
          subtitle: Text(ctx.t('near.share_sub')),
          onTap: () => Navigator.pop(ctx, 'near'),
        ),
        ListTile(
          leading: const Icon(AppIcons.iosShare),
          title: Text(ctx.t('peer.other_apps_title')),
          subtitle: Text(ctx.t('peer.other_apps')),
          onTap: () => Navigator.pop(ctx, 'system'),
        ),
        const SizedBox(height: Gap.sm),
      ],
    ),
  );
  if (choice == null || !context.mounted) return true;
  if (choice == 'system') return false;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => NearbyScreen(sendPaths: paths),
  ));
  return true;
}
