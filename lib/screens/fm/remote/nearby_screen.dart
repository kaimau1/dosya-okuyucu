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
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/notification_hub.dart';
import '../../../services/fm/remote/ble_nearby.dart';
import '../../../services/fm/remote/ftp_service.dart';
import '../../../services/fm/remote/peer_share.dart';
import '../../../services/fm/remote/qr_transfer.dart';
import '../../../services/fm/remote/transfer_keeper.dart';
import '../../../services/fm/remote/transfer_history.dart';
import '../../../services/fm/remote/trusted_peers.dart';
import '../../../services/fm/remote/transfer_thumbs.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_entry_icon.dart';
import '../../../widgets/fm/transfer_offer_sheet.dart';
import '../../../widgets/qr_code.dart';
import '../../../widgets/section_header.dart';
import '../browser_screen.dart';
import '../download_manager_screen.dart';
import '../folder_picker_screen.dart';
import 'ftp_server_screen.dart';
import 'qr_receive_flow.dart';
import 'remote_connections_screen.dart';
import '../pick_file_screen.dart';

part 'nearby/links.dart';
part 'nearby/sections.dart';
part 'nearby/tabs.dart';
part 'nearby/widgets.dart';

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

/// Süren bir Wi-Fi gönderimi: dosya (kalem) başına ilerleme, ekle-sırasıyla.
/// Eskiden ekranı kapatan tek çubuklu bir pencereydi; artık alınanlar gibi
/// her dosya kendi satırında, ekran kullanılabilir kalır.
class _Outgoing {
  final String to;
  final DateTime startedAt = DateTime.now();
  final Map<String, ({int sent, int size})> files = {};
  int sentBytes = 0;
  int totalBytes = 0;
  bool waiting = false;
  bool cancelled = false;

  _Outgoing(this.to);
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

  /// Gönderilecek yazı (Paylaş ile gelen düz metin; boş olabilir).
  final String? sendText;

  /// Testte ağ/Bluetooth başlatılmasın.
  @visibleForTesting
  final bool services;

  /// Bildirimden gelen davet (arka planda görünürlük, kişisel derleme).
  final BleInvite? invite;

  /// Bildirimde "Kabul et"e basıldı: yeniden sorulmaz.
  final bool inviteAccepted;

  const NearbyScreen({
    super.key,
    this.sendPaths = const [],
    this.sendText,
    this.services = true,
    this.invite,
    this.inviteAccepted = false,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  static const _section = EdgeInsets.fromLTRB(Gap.xs, Gap.lg, Gap.xs, Gap.sm);

  late final List<String> _selection = [...widget.sendPaths];

  /// Gönderilecek yazı (dosyalarla birlikte de gidebilir).
  late String? _text = widget.sendText;

  String _id = '';
  String _saveDir = QrReceiveFlow.defaultSaveDir();
  bool _confirmIncoming = true;

  /// Onaylanmış "push" daveti (ör. Windows): o göndericinin teklifi kısa süre sorulmaz.
  ({String name, DateTime until})? _preApproved;

  /// Arka planda görünürlük (yalnız kişisel derlemede [_bgAvailable]).
  bool _bgAvailable = false;
  bool _bgOn = false;

  // ── alma ────────────────────────────────────────────────────────────────
  PeerReceiver? _receiver;

  /// Süren alımlar, dosya adına göre. Eskiden TEK bir metin vardı: iki dosya
  /// aynı anda gelince adlar birbirini eziyordu (2026-11-02 kullanıcı bulgusu).
  /// Ekle-sırası korunur (LinkedHashMap) → satırlar yerinde durur.
  final Map<String, ({int received, int total})> _incoming = {};

  // ── gönderme ────────────────────────────────────────────────────────────
  /// Tek seferde tek gönderim (avatarlar bu sürede pasif).
  _Outgoing? _out;

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

  /// Kısa ömürlü bağlantı (Faz 41 / 4): süre ve tek seferlik indirme.
  Duration? _linkTtl;
  bool _linkOnce = false;
  bool _linkExpired = false;
  Timer? _webDebounce;
  String? _webError;

  bool _historyIncoming = true;
  bool _historyAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(TransferHistory.instance.ensureLoaded());
    unawaited(TrustedPeers.instance.ensureLoaded());
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
    // Boştaki sunucu, yayın ve hotspot ekranla birlikte ÖLÜR: arka planda
    // dinleyen bir kapı bırakmak kullanıcının bilmediği bir risk olurdu. Ama
    // SÜREN aktarım kesilmez: iş bitene kadar [TransferKeeper] taşır.
    final keeper = TransferKeeper.instance;
    final hadHotspot = _hotspot != null;
    final receiver = _receiver;
    if (receiver != null) {
      receiver.stopDiscovery();
      unawaited(keeper.handOff(receiver));
    }
    final web = _web;
    if (web != null) {
      unawaited(keeper.handOff(web,
          onClosed: hadHotspot ? QrNative.stopHotspot : null));
    } else if (hadHotspot) {
      unawaited(QrNative.stopHotspot());
    }
    if (widget.services) unawaited(BleNearby.stop());
    super.dispose();
  }

  String get _deviceName {
    final chosen = context.read<AppState>().peerName;
    if (chosen.isNotEmpty) return chosen;
    return Platform.isAndroid ? 'Android' : Platform.operatingSystem;
  }

  Future<void> _boot() async {
    // Bildirimde onaylanan push daveti: alıcı açılır açılmaz gönderen /sor sorabilir —
    // onay alıcıdan ÖNCE kayıtlı olsun (yoksa aynı istek bir kez daha sorulurdu).
    final accepted = widget.invite;
    if (accepted != null && accepted.push && widget.inviteAccepted) {
      _preApproved = (name: accepted.from, until: DateTime.now().add(const Duration(minutes: 3)));
    }
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
    unawaited(_loadBg());
    final invite = widget.invite;
    if (invite != null) {
      unawaited(BleNearby.bgClearAsk());
      unawaited(_takeInvite(invite, accepted: widget.inviteAccepted));
    }
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
    final previous = _receiver;
    if (previous != null) await TransferKeeper.instance.handOff(previous);
    final receiver = PeerReceiver(
      onActivity: TransferKeeper.instance.onActivity,
      deviceName: _deviceName,
      deviceId: _id,
      saveDir: _saveDir,
      onAsk: _confirmIncoming ? _askIncoming : null,
      onText: _showIncomingText,
      onProgress: (name, received, total) {
        if (!mounted) return;
        final before = _incoming[name];
        // `setState` her yığında değil, görünür yüzde (ya da yeni dosya)
        // değiştikçe.
        final shown = total > 0 ? received * 100 ~/ total : -1;
        final was = before == null
            ? -2
            : (before.total > 0 ? before.received * 100 ~/ before.total : -1);
        _incoming[name] = (received: received, total: total);
        if (shown != was) setState(() {});
      },
      onDone: (name) {
        if (mounted && _incoming.remove(name) != null) setState(() {});
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
        setState(() => _historyIncoming = true);
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
    final pre = _preApproved;
    if (pre != null && pre.name == offer.from && DateTime.now().isBefore(pre.until)) {
      return true;
    }
    if (TrustedPeers.instance.isTrusted(offer.from, offer.fromId)) return true;
    final trust = ValueNotifier(false);
    final ok = await showTransferOffer(
      context,
      trust: trust,
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
    if (ok && trust.value) await _trust(offer.from, offer.fromId);
    trust.dispose();
    return ok;
  }

  Future<void> _trust(String name, String id) async {
    await TrustedPeers.instance.add(name, id);
    if (mounted) showSnack(context, context.t('near.trusted_added', {'name': name}));
  }

  /// Gelen yazı: diske yazılmaz, kopyalanabilir olarak gösterilir.
  void _showIncomingText(String text, String from) {
    if (!mounted) return;
    AppHaptics.step();
    unawaited(showAppSheet<void>(
      context,
      title: context.t('near.text_from', {'from': from}),
      builder: (ctx) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45),
              child: SingleChildScrollView(
                child: SelectableText(
                  key: const ValueKey('near-text-in'),
                  text,
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            FilledButton.icon(
              key: const ValueKey('near-text-copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(ctx);
                showSnack(context, context.t('near.copied'));
              },
              icon: const Icon(AppIcons.copyPlain),
              label: Text(ctx.t('near.text_copy')),
            ),
          ],
        ),
      ),
    ));
  }

  /// Bluetooth daveti: önce ne geleceği sorulur, kabul edilirse Wi-Fi'ye
  /// (gerekirse gönderenin geçici ağına) bağlanılıp dosyalar çekilir.
  Future<void> _onInvite(BleInvite invite) => _takeInvite(invite, accepted: false);

  Future<void> _takeInvite(BleInvite invite, {required bool accepted}) async {
    if (!mounted) return;
    final trust = ValueNotifier(false);
    final ok = accepted ||
        TrustedPeers.instance.isTrusted(invite.from, invite.fromId) ||
        await showTransferOffer(
          context,
          trust: trust,
          from: invite.from,
          count: invite.count,
          totalBytes: invite.totalBytes,
          saveDir: _saveDir,
          items: [for (final n in invite.names) OfferRow(name: n, size: 0)],
        );
    final trusted = trust.value;
    trust.dispose();
    if (!ok || !mounted) return;
    if (trusted) await _trust(invite.from, invite.fromId);
    if (!mounted) return;
    if (invite.push) {
      // Gönderen (ör. Windows "Dosya Aktar") bu cihazı Wi-Fi'de bulup kendisi gönderir;
      // onay verildi, aynı göndericinin teklifi birkaç dakika yeniden sorulmaz.
      _preApproved = (name: invite.from, until: DateTime.now().add(const Duration(minutes: 3)));
      showSnack(context, context.t('near.bg_waiting', {'name': invite.from}));
      return;
    }
    await QrReceiveFlow.runPayload(context, invite.url,
        saveDir: _saveDir, preAccepted: true, from: invite.from);
  }

  Future<void> _scanQr() async {
    await QrReceiveFlow.run(context, saveDir: _saveDir);
  }

  // ── Seçim ──────────────────────────────────────────────────────────────

  Future<void> _addFiles() async {
    try {
      final picked = await AppFilePicker.pickFiles(allowMultiple: true);
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

  // ── Gönderme ───────────────────────────────────────────────────────────

  Future<void> _tapPeer(_Near near) async {
    if (_out != null) {
      showSnack(context, context.t('near.busy_sending'));
      return;
    }
    if (_selection.isEmpty && _text == null) {
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
            if (near.wifi != null)
              ListTile(
                leading: const Icon(AppIcons.textSnippet),
                title: Text(ctx.t('near.add_text')),
                onTap: () => Navigator.pop(ctx, 'text'),
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      if (picked == 'files') {
        await _addFiles();
      } else if (picked == 'folder') {
        await _addFolder();
      } else {
        await _editText();
      }
      if ((_selection.isEmpty && _text == null) || !mounted) return;
    }
    AppHaptics.step();
    final wifi = near.wifi;
    if (wifi != null) {
      if (_text != null && !await _sendText(wifi)) return;
      if (_selection.isNotEmpty) await _sendWifi(wifi);
    } else if (near.ble != null) {
      if (_text != null) {
        showSnack(context, context.t('near.text_wifi_only'));
        if (_selection.isEmpty) return;
      }
      await _sendBle(near);
    }
  }

  /// Yazı ekler/düzenler; panodaki metin hazır gelir.
  Future<void> _editText() async {
    var initial = _text ?? '';
    if (initial.isEmpty) {
      try {
        initial = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      } catch (_) {
        // Pano okunamadı: kutu boş açılır, kullanıcı yazar — söylenecek bir şey yok.
      }
    }
    if (!mounted) return;
    final text = await showAppPrompt(
      context,
      title: context.t('near.text_title'),
      label: context.t('near.text_hint'),
      initial: initial,
      confirmLabel: context.t('common.ok'),
      multiline: true,
    );
    if (text == null || !mounted) return;
    setState(() => _text = text);
  }

  Future<bool> _sendText(Peer peer) async {
    final strings = AppStrings.of(context);
    final ok = await PeerSender.sendText(peer, _text!, senderName: _deviceName);
    if (!mounted) return ok;
    if (ok) setState(() => _text = null);
    showSnack(context,
        ok ? strings.t('near.text_sent', {'name': peer.name}) : strings.t('near.text_failed'));
    return ok;
  }

  Future<void> _sendWifi(Peer peer) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();
    final payload = [..._selection];
    final out = _Outgoing(peer.name);
    setState(() => _out = out);
    // Görünür yüzde değişmedikçe yeniden çizilmez (yığın başına değil).
    var shown = -1;
    void tick() {
      final pct = out.totalBytes > 0 ? out.sentBytes * 100 ~/ out.totalBytes : 0;
      if (pct != shown && mounted) {
        shown = pct;
        setState(() {});
      }
    }

    PeerSendResult result;
    try {
      result = await PeerSender.send(
        peer,
        payload,
        senderName: _deviceName,
        senderId: _id,
        isCancelled: () => out.cancelled,
        thumbnail: TransferThumbs.of,
        onWaiting: (w) {
          out.waiting = w;
          if (mounted) setState(() {});
        },
        onFile: (name, sent, size) {
          final isNew = !out.files.containsKey(name);
          out.files[name] = (sent: sent, size: size);
          if (isNew || sent == size) {
            if (mounted) setState(() {});
          }
        },
        onProgress: (_, sent, total) {
          out.sentBytes = sent;
          out.totalBytes = total;
          tick();
        },
      );
    } catch (e) {
      result = PeerSendResult(errors: [userErrorText(e)]);
    } finally {
      if (mounted) setState(() => _out = null);
    }
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
    // Arka plan yayınında da ad gidiyor.
    if (_bgOn) await _enableBg();
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

  /// Bölüm dosyaları (extension) `setState`'i doğrudan çağıramaz (korumalı üye).
  void _update(VoidCallback fn) => setState(fn);

  /// Bu genişlikten sonra iki sütun: solda gönderme akışı, sağda QR, geçmiş
  /// ve diğer yollar (pano ile aynı eşik ve en geniş içerik).
  static const _wideFrom = 840.0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('xfer.title')),
          actions: [
            IconButton(
              key: const ValueKey('near-scan-qr'),
              tooltip: context.t('qrf.scan'),
              icon: const Icon(AppIcons.qrScan),
              onPressed: _scanQr,
            ),
            _menu(context),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                key: const ValueKey('near-tab-quick'),
                icon: const Icon(AppIcons.bolt, size: AppIcons.small),
                iconMargin: const EdgeInsets.only(bottom: 2),
                text: context.t('xft.tab_quick'),
              ),
              Tab(
                key: const ValueKey('near-tab-other'),
                icon: const Icon(AppIcons.computer, size: AppIcons.small),
                iconMargin: const EdgeInsets.only(bottom: 2),
                text: context.t('near.other_ways'),
              ),
              Tab(
                key: const ValueKey('near-tab-history'),
                icon: const Icon(AppIcons.history, size: AppIcons.small),
                iconMargin: const EdgeInsets.only(bottom: 2),
                text: context.t('near.history'),
              ),
            ],
          ),
        ),
        // Güvenilenler listesi değişince (ekle/kaldır) rozetler ve bölüm tazelenir.
        body: ListenableBuilder(
          listenable: TrustedPeers.instance,
          builder: (context, _) => TabBarView(
            children: [
              _quickTab(context),
              _otherTab(context),
              _historyTab(context),
            ],
          ),
        ),
      ),
    );
  }
}
