import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/snack.dart';
import '../../../core/theme.dart';
import '../../../services/fm/file_ops.dart';
import '../../../services/fm/archive_ops.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/notification_hub.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/peer_share.dart';
import '../../../widgets/fm/fm_progress_dialog.dart';
import '../folder_picker_screen.dart';

/// **Yakındaki cihaz** — iki Dosya Okuyucu arasında doğrudan dosya aktarımı.
///
/// Kullanıcı isteği (2026-09-06): *"paylaş dendiğinde iki dosya okuyucusu
/// arasında hızlı dosya paylaşımı özelliği yapalım."*
///
/// ## Ekranın şekli — tek ekran, iki yön
/// Gönderme ve alma AYRI ekranlar değil, aynı ekranın iki sekmesi. Gerekçe
/// deneyimsel: bu özellik ancak **iki taraf da doğru yerdeyse** çalışıyor ve
/// en sık yapılan hata karşı tarafın "Al" ekranını açmamış olması. Aynı
/// ekranda iki sekme görmek, gönderen kişiye karşı tarafta ne yapılması
/// gerektiğini de gösteriyor; "cihaz bulunamadı" metni de bunu tekrar ediyor.
///
/// Dosya seçiliyken açılırsa **Gönder** sekmesinde, boş açılırsa **Al**
/// sekmesinde başlar: kullanıcı zaten ne yapmak istediğini seçerek geldi.
///
/// Protokol, güvenlik sınırları ve niye yeni bir paket eklenmediği:
/// `services/fm/remote/peer_share.dart`.
class PeerShareScreen extends StatefulWidget {
  /// Gönderilecek dosyalar. Boşsa ekran "Al" kipinde açılır.
  final List<String> sendPaths;

  const PeerShareScreen({super.key, this.sendPaths = const []});

  @override
  State<PeerShareScreen> createState() => _PeerShareScreenState();
}

/// Gelen dosya bildiriminin kimliği. 0 OLAMAZ (eklenti reddediyor) ve
/// uygulamadaki öteki kimliklerden (iş kuyruğu 90301, ağ paylaşımı 90411)
/// farklı olmalı: aynı anda görünebiliyorlar.
const _receiveNotificationId = 90521;

class _PeerShareScreenState extends State<PeerShareScreen> {
  late bool _sending = widget.sendPaths.isNotEmpty;

  /// Gönderilecek düz dosyalar.
  late final List<String> _files = [
    for (final path in widget.sendPaths)
      if (!Directory(path).existsSync()) path,
  ];

  /// Gönderilecek KLASÖRLER. Gönderim anında ZIP'lenip tek dosya olarak
  /// gidiyorlar (2026-09-06): eskiden sessizce atlanıyorlardı ve kullanıcı
  /// "klasörü seçtim ama gitmedi" diyordu.
  late final List<String> _folders = [
    for (final path in widget.sendPaths)
      if (Directory(path).existsSync()) path,
  ];

  // ── Gönderme durumu ────────────────────────────────────────────────────
  final _peers = <Peer>[];
  StreamSubscription<Peer>? _scan;
  bool _scanning = false;
  final _addressController = TextEditingController();

  // ── Alma durumu ────────────────────────────────────────────────────────
  PeerReceiver? _receiver;
  String _saveDir = '';

  /// Alıcıda kod istensin mi ve o kodun kendisi.
  bool _requireCode = false;
  String _code = '';
  final _received = <(String path, String from)>[];
  String? _incoming;

  @override
  void initState() {
    super.initState();
    _saveDir = _defaultSaveDir();
    if (_sending) {
      _startScan();
    } else {
      unawaited(_startReceiving());
    }
  }

  @override
  void dispose() {
    _scan?.cancel();
    _addressController.dispose();
    // Sunucu ekranla birlikte ÖLÜR: arka planda dinleyen bir kapı bırakmak
    // kullanıcının bilmediği bir risk olurdu (bkz. peer_share.dart güvenlik).
    unawaited(_receiver?.stop());
    super.dispose();
  }

  static String _defaultSaveDir() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    return Directory(download).existsSync() ? download : FmEnv.primaryRoot;
  }

  /// Karşı tarafta görünecek ad. Kullanıcı ad vermediyse okunur bir
  /// varsayılan: "Android telefon" bir listede "localhost"tan iyidir.
  String get _deviceName {
    final chosen = context.read<AppState>().peerName;
    if (chosen.isNotEmpty) return chosen;
    return Platform.isAndroid ? 'Android' : Platform.operatingSystem;
  }

  // ── Gönderme ───────────────────────────────────────────────────────────

  void _startScan() {
    _scan?.cancel();
    setState(() {
      _scanning = true;
      _peers.clear();
    });
    _scan = PeerSender.discover().listen(
      (peer) {
        if (!mounted) return;
        setState(() {
          if (!_peers.contains(peer)) _peers.add(peer);
        });
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _connectManually() async {
    final host = _addressController.text.trim();
    if (host.isEmpty) return;
    final notFound = context.t('peer.not_found_at');
    final peer = await PeerSender.probe(host);
    if (!mounted) return;
    if (peer == null) {
      showSnack(context, notFound);
      return;
    }
    setState(() {
      if (!_peers.contains(peer)) _peers.add(peer);
    });
    await _sendTo(peer);
  }

  Future<void> _sendTo(Peer peer) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final senderName = _deviceName;

    // **Klasörler tek dosya hâline getiriliyor.** HTTP aktarımı tek dosya
    // taşıyor; klasörü göndermenin makul yolu onu ZIP'lemek. Geçici dizine
    // yazılıyor, gönderim bitince siliniyor.
    final payload = [..._files];
    Directory? tempDir;
    if (_folders.isNotEmpty) {
      showSnackOn(messenger, strings.t('peer.folder_zipping'));
      try {
        tempDir = await Directory.systemTemp.createTemp('peer-zip');
        for (final folder in _folders) {
          payload.add(await ArchiveOps.zip([folder], tempDir.path,
              archiveName: p.basename(folder)));
        }
      } catch (e) {
        showSnackOn(messenger, '$e');
      }
    }
    if (payload.isEmpty) return;

    // Alıcı kod istiyorsa kodu SORUYORUZ — gönderim başlamadan önce.
    var code = '';
    if (peer.needsCode) {
      if (!mounted) return;
      code = await _askCode() ?? '';
      if (code.isEmpty) return;
    }
    if (!mounted) return;
    final startedAt = DateTime.now();
    // Ortak ilerleme penceresi: "Arka plana al", "Durdur" ve kalıcı şerit
    // burada da olsun — 2 GB'lık bir video gönderirken kullanıcı ekranda
    // tutsak kalmasın (kopyalama/sıkıştırma ile aynı dil).
    final result = await showFmProgress<PeerSendResult>(
      context,
      title: strings.t('peer.sending'),
      task: (report, isCancelled) => PeerSender.send(
        peer,
        payload,
        senderName: senderName,
        pairingCode: code,
        isCancelled: isCancelled,
        onProgress: (name, sent, total) =>
            report(FmProgress(sent, total, name)),
      ),
      // Sayaç BAYT sayıyor; "12345678 / 29000000" kimseye bir şey anlatmaz.
      // **Hız da yazıyor** (2026-09-06): "ne kadar sürecek" sorusunun tek
      // cevabı bu — 2 GB'lık bir video Wi-Fi'de 2 dakika da sürebilir,
      // 20 dakika da (ev ağı mı, hotspot mı).
      describe: (value) {
        if (value.total <= 0) return '';
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        final speed = elapsed > 300
            ? FsPaths.humanSize((value.done * 1000 / elapsed).round())
            : '';
        final head = '${FsPaths.humanSize(value.done)} / '
            '${FsPaths.humanSize(value.total)}';
        return speed.isEmpty
            ? head
            : strings.t('peer.speed', {
                'done': FsPaths.humanSize(value.done),
                'total': FsPaths.humanSize(value.total),
                'speed': speed,
              });
      },
    );
    // Geçici ZIP'ler her hâlükârda siliniyor (iptal edilse de).
    if (tempDir != null) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
    if (!mounted) return;
    // Başarılı gönderimden sonra cihaz hatırlanıyor: aynı iki telefon
    // arasında gönderim tekrarlanan bir iş ve yayın her ağda çalışmıyor.
    if (result.sent > 0) {
      await context.read<AppState>().rememberPeer(peer.name, peer.host, peer.port);
      if (!mounted) return;
    }
    showSnackBarReplacing(
      messenger,
      SnackBar(
        content: Text(
          result.wrongCode
              ? strings.t('peer.code_wrong')
              : result.hasError
                  ? strings.t('peer.send_failed', {'error': result.errors.first})
                  : result.cancelled
                      ? strings.t('peer.send_stopped', {'n': result.sent})
                      : strings
                          .t('peer.sent', {'n': result.sent, 'name': peer.name}),
        ),
      ),
    );
  }

  /// Eşleştirme kodunu sorar (alıcı ekranında yazan dört hane).
  Future<String?> _askCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('peer.code_label')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(hintText: ctx.t('peer.code_ask')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    );
    controller.dispose();
    return code?.trim();
  }

  // ── Alma ───────────────────────────────────────────────────────────────

  Future<void> _startReceiving() async {
    await _receiver?.stop();
    if (_requireCode && _code.isEmpty) _code = PeerReceiver.newCode();
    final receiver = PeerReceiver(
      deviceName: _deviceName,
      saveDir: _saveDir,
      pairingCode: _requireCode ? _code : '',
      onProgress: (name, received, total) {
        if (!mounted) return;
        final label = total > 0
            ? '$name · ${FsPaths.humanSize(received)} / '
                '${FsPaths.humanSize(total)}'
            : name;
        // `setState` her yığında değil, metin değiştikçe: saniyede yüzlerce
        // yeniden çizim yapmanın aktarımı yavaşlatmaktan başka etkisi yok.
        if (_incoming != label) setState(() => _incoming = label);
      },
      onReceived: (path, from) {
        // **Sistem bildirimi** (2026-09-06): kullanıcı bekleme ekranına
        // bakmak zorunda kalmasın. Dosya gelirken telefonu cebinde ya da
        // başka bir uygulamada olabilir; alma ekranı açık kaldığı sürece
        // aktarım sürüyor ama ekranda bir şey OLDUĞUNU görmüyordu.
        unawaited(NotificationHub.instance.show(
          _receiveNotificationId,
          AppStrings.current.t('peer.notify_title'),
          '${p.basename(path)} · $from',
          const AndroidNotificationDetails(
            'fm_peer',
            'Yakındaki cihaz',
            channelDescription: 'Yakındaki bir cihazdan dosya alındığında.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ));
        if (!mounted) return;
        setState(() {
          _incoming = null;
          _received.insert(0, (path, from));
        });
      },
    );
    try {
      await receiver.start();
    } catch (_) {
      // Port alınamadıysa ekran "kapalı" görünür; kullanıcı geri çıkıp
      // yeniden girerek deneyebilir.
    }
    if (!mounted) {
      await receiver.stop();
      return;
    }
    setState(() => _receiver = receiver);
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
    await _startReceiving(); // sunucu yeni klasörle yeniden kurulur
  }

  Future<void> _editDeviceName() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController(text: appState.peerName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('peer.device_name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.t('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    await appState.setPeerName(name);
    if (!mounted) return;
    // Ad yayın cevabının içinde gidiyor → sunucu yeni adla yeniden kurulur.
    if (!_sending) await _startReceiving();
  }

  // ── Çizim ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('peer.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(context.t('peer.tab_send')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(context.t('peer.tab_receive')),
                ),
              ],
              selected: {_sending},
              onSelectionChanged: (value) {
                final sending = value.first;
                setState(() => _sending = sending);
                if (sending) {
                  unawaited(_receiver?.stop());
                  setState(() => _receiver = null);
                  _startScan();
                } else {
                  _scan?.cancel();
                  setState(() => _scanning = false);
                  unawaited(_startReceiving());
                }
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _sending ? _sendBody() : _receiveBody()),
        ],
      ),
    );
  }

  Widget _sendBody() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(
          context.t('peer.files_to_send', {'n': _files.length}),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_folders.isNotEmpty) ...[
          const SizedBox(height: Gap.xs),
          Text(
            context.t('peer.folders_zipped', {'n': _folders.length}),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Gap.md),
        Row(
          children: [
            if (_scanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_scanning) const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                _scanning ? context.t('peer.searching') : '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: Text(context.t('peer.search_again')),
            ),
          ],
        ),
        for (final peer in _peers)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.xs),
            child: ListTile(
              leading: const Icon(Icons.smartphone),
              title: Text(peer.name),
              subtitle: Text('${peer.host}:${peer.port}'),
              trailing: Icon(peer.needsCode ? Icons.password : Icons.send),
              onTap: (_files.isEmpty && _folders.isEmpty)
                  ? null
                  : () => _sendTo(peer),
            ),
          ),
        // **Son cihazlar**: yayın (UDP) her ağda çalışmıyor; daha önce
        // gönderilen bir cihaza dönmek tek dokunuş olmalı.
        for (final entry in context.watch<AppState>().peerRecent)
          if (_recentPeer(entry) case final peer?)
            if (!_peers.contains(peer))
              Card(
                margin: const EdgeInsets.only(bottom: Gap.xs),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(peer.name),
                  subtitle: Text('${peer.host}:${peer.port}'),
                  trailing: const Icon(Icons.send),
                  onTap: (_files.isEmpty && _folders.isEmpty)
                      ? null
                      : () => _sendToRecent(peer),
                ),
              ),
        if (_peers.isEmpty && !_scanning)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            child: Text(
              context.t('peer.none_found'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: Gap.lg),
        const Divider(),
        const SizedBox(height: Gap.sm),
        Text(
          context.t('peer.address_hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: context.t('peer.address'),
                ),
                onSubmitted: (_) => _connectManually(),
              ),
            ),
            const SizedBox(width: Gap.sm),
            FilledButton(
              onPressed: _connectManually,
              child: Text(context.t('peer.connect')),
            ),
          ],
        ),
      ],
    );
  }

  /// `ad|adres|port` kaydını [Peer]'a çevirir; bozuksa null.
  Peer? _recentPeer(String entry) {
    final parts = entry.split('|');
    if (parts.length != 3) return null;
    final port = int.tryParse(parts[2]);
    if (port == null) return null;
    return Peer(name: parts[0], host: parts[1], port: port);
  }

  /// Kayıtlı bir cihaza gönderim: önce **hâlâ orada mı** diye bakılıyor.
  /// Kapalı bir telefona gönderim başlatmak, ilerleme penceresini açıp
  /// zaman aşımını beklemek olurdu.
  Future<void> _sendToRecent(Peer saved) async {
    final notFound = context.t('peer.not_found_at');
    final messenger = ScaffoldMessenger.of(context);
    final live = await PeerSender.probe(saved.host, port: saved.port);
    if (!mounted) return;
    if (live == null) {
      showSnackOn(messenger, notFound);
      return;
    }
    await _sendTo(live);
  }

  Widget _receiveBody() {
    final scheme = Theme.of(context).colorScheme;
    final running = _receiver?.running ?? false;
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Row(
          children: [
            Icon(
              running ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              color: running ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                running
                    ? context.t('peer.receiving_on')
                    : context.t('peer.receiving_off'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(context.t('peer.receive_explain'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Gap.xs),
        Text(
          context.t('peer.receive_warning'),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.error),
        ),
        const SizedBox(height: Gap.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text(context.t('peer.this_device', {'name': _deviceName})),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _editDeviceName,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: Text(context.t('peer.save_to', {'path': _saveDir})),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickSaveDir,
        ),
        // **Eşleştirme kodu**: ekran açıkken aynı ağdaki herkesin dosya
        // gönderebilmesi ev ağında sorun değil ama yurtta/ofiste değil.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.password),
          title: Text(context.t('peer.code_on')),
          value: _requireCode,
          onChanged: (value) async {
            setState(() {
              _requireCode = value;
              if (value && _code.isEmpty) _code = PeerReceiver.newCode();
            });
            await _startReceiving();
          },
        ),
        if (_requireCode)
          Center(
            child: Text(
              _code,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    letterSpacing: 8,
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        const Divider(),
        if (_incoming != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(_incoming!, maxLines: 2)),
              ],
            ),
          ),
        for (final (path, from) in _received)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(p.basename(path)),
            subtitle: Text(context.t(
              'peer.received_from',
              {'name': FsPaths.humanSize(_sizeOf(path)), 'from': from},
            )),
            // Gelen dosyaya dokununca AÇILIYOR (2026-09-06): kullanıcı
            // "geldi" yazısını görüp dosyayı bulmak için ekranı kapatıp
            // İndirilenler'e gitmek zorunda kalmasın.
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => EntryOpener.open(context, path),
          ),
        if (_received.isEmpty && _incoming == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            child: Text(context.t('peer.nothing_received'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }

  int _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

/// "Paylaş" dendiğinde çıkan seçim: **yakındaki cihaz** mı, sistemin paylaşım
/// sayfası mı?
///
/// Kullanıcı isteği (2026-09-06): *"paylaş dendiğinde iki dosya okuyucusu
/// arasında hızlı dosya paylaşımı özelliği yapalım."* Sistem paylaşımı
/// kaldırılmadı — WhatsApp'a bir fotoğraf yollamak hâlâ en sık yapılan şey.
/// İki yol yan yana duruyor ve hızlı olan **üstte**.
Future<bool> showShareChoice(BuildContext context, List<String> paths) async {
  final wantsPeer = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: Text(ctx.t('peer.send_action')),
            subtitle: Text(ctx.t('peer.send_hint')),
            onTap: () => Navigator.pop(ctx, true),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(ctx.t('common.share')),
            subtitle: Text(ctx.t('peer.other_apps')),
            onTap: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    ),
  );
  if (wantsPeer == null || !context.mounted) return false;
  if (!wantsPeer) return false;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PeerShareScreen(sendPaths: paths),
  ));
  return true;
}
