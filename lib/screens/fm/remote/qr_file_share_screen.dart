import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/motion.dart';
import '../../../core/safe_insets.dart';
import '../../../core/theme.dart';
import '../../../core/user_error.dart';
import '../../../services/fm/archive_ops.dart';
import '../../../services/fm/remote/qr_transfer.dart';
import '../../../widgets/qr_code.dart';
import '../../qr_share_screen.dart';

/// **QR ile paylaş** — gönderen ekranı. Protokol ve güvenlik:
/// `services/fm/remote/qr_transfer.dart`.
///
/// Ekran açıkken sunucu (ve kurulduysa hotspot) yaşar; kapanınca ikisi de
/// kapanır, geçici ZIP'ler silinir.
class QrFileShareScreen extends StatefulWidget {
  final List<String> paths;

  const QrFileShareScreen({super.key, required this.paths});

  @override
  State<QrFileShareScreen> createState() => _QrFileShareScreenState();
}

class _QrFileShareScreenState extends State<QrFileShareScreen> {
  QrShareServer? _server;
  Directory? _tempDir;
  String? _wifiHost;

  /// Hotspot kurulduysa: ağ bilgisi + o arayüzdeki adres.
  ({String ssid, String pass, String sec})? _hotspot;
  String? _hotspotHost;
  bool _hotspotBusy = false;

  /// Hotspot kipinde hangi QR görünüyor: 0 = Wi-Fi'ye bağlan, 1 = dosya.
  int _step = 0;
  int _served = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_server?.stop());
    if (_hotspot != null) unawaited(QrNative.stopHotspot());
    final t = _tempDir;
    // Bilinçli: geçici ZIP temizliği; kalırsa açılıştaki TempSweep süpürür.
    if (t != null) unawaited(t.delete(recursive: true).catchError((_) => t));
    super.dispose();
  }

  Future<void> _start() async {
    try {
      // Klasörler ZIP olarak gider (Yakındaki cihaz'daki gibi).
      final files = <String>[];
      for (final path in widget.paths) {
        if (Directory(path).existsSync()) {
          _tempDir ??= await Directory.systemTemp.createTemp('qr-zip');
          files.add(await ArchiveOps.zip([path], _tempDir!.path,
              archiveName: p.basename(path)));
        } else {
          files.add(path);
        }
      }
      final server = QrShareServer(files, onServed: (_) {
        if (mounted) setState(() => _served++);
      });
      await server.start();
      final host = await _wifiAddress();
      if (!mounted) {
        await server.stop();
        return;
      }
      setState(() {
        _server = server;
        _wifiHost = host;
      });
      // Ortak Wi-Fi yoksa hotspot'a geçmek tek yol — kullanıcıya sormadan.
      if (host == null) await _startHotspot();
    } catch (e) {
      if (mounted) setState(() => _error = userErrorText(e));
    }
  }

  /// Wi-Fi arayüzünün (`wlan0`) adresi; mobil veri (`rmnet`, `ccmni`) değil.
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

  Future<void> _startHotspot() async {
    if (_hotspotBusy || _hotspot != null) return;
    setState(() => _hotspotBusy = true);
    final before = <String>{if (_wifiHost != null) _wifiHost!};
    try {
      final h = await QrNative.startHotspot();
      // Hotspot arayüzünün adresi birkaç yüz ms sonra görünür.
      String? host;
      for (var i = 0; i < 20 && host == null; i++) {
        await Future<void>.delayed(Motion.medium); // yoklama aralığı
        host = await _wifiAddress(except: before);
      }
      if (!mounted) return;
      setState(() {
        _hotspot = h;
        _hotspotHost = host;
        _step = 0;
      });
      if (host == null) setState(() => _error = context.t('qrf.no_address'));
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _error = context.t(switch (e.code) {
              'perm' => 'qrf.err_perm',
              'location_off' => 'qrf.err_location',
              'unsupported' => 'qrf.err_unsupported',
              _ => 'qrf.err_hotspot',
            }));
      }
    } finally {
      if (mounted) setState(() => _hotspotBusy = false);
    }
  }

  bool get _textOnly {
    if (widget.paths.length != 1) return false;
    final f = File(widget.paths.single);
    if (!f.existsSync()) return false;
    final len = f.lengthSync();
    return const {'.txt', '.md', '.markdown'}
            .contains(p.extension(f.path).toLowerCase()) &&
        len > 0 &&
        len <= 30 * 1024;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size =
        (MediaQuery.sizeOf(context).shortestSide - 96).clamp(180.0, 380.0);
    final server = _server;
    final hs = _hotspot;
    String? qr;
    String hint;
    if (server == null) {
      hint = context.t('qrf.preparing');
    } else if (hs != null && _hotspotHost != null) {
      qr = _step == 0
          ? QrPayload.wifi(hs.ssid, hs.pass, sec: hs.sec)
          : QrPayload.encode(server.urlFor(_hotspotHost!),
              ssid: hs.ssid, pass: hs.pass, sec: hs.sec);
      hint = context.t(_step == 0 ? 'qrf.hint_wifi' : 'qrf.hint_file');
    } else if (_wifiHost != null) {
      qr = server.urlFor(_wifiHost!).toString();
      hint = context.t('qrf.hint_same');
    } else {
      hint = context.t('qrf.preparing');
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('qrf.title'))),
      body: ListView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
        children: [
          Text(
            widget.paths.length == 1
                ? p.basename(widget.paths.single)
                : context.t('qrf.n_files', {'n': widget.paths.length}),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.sm),
          if (hs != null && _hotspotHost != null)
            Center(
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(context.t('qrf.step_wifi'))),
                  ButtonSegment(value: 1, label: Text(context.t('qrf.step_file'))),
                ],
                selected: {_step},
                onSelectionChanged: (s) => setState(() => _step = s.first),
              ),
            ),
          const SizedBox(height: Gap.md),
          Center(
            child: qr == null
                ? SizedBox.square(
                    dimension: size,
                    child: Center(
                      child: _hotspotBusy || server == null
                          ? const CircularProgressIndicator()
                          : const Icon(AppIcons.qr, size: 64),
                    ),
                  )
                : QrCode(key: ValueKey(qr), data: qr, size: size),
          ),
          const SizedBox(height: Gap.md),
          Text(hint, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          if (hs != null && _step == 0) ...[
            const SizedBox(height: Gap.xs),
            SelectableText('${hs.ssid} · ${hs.pass}',
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
          if (hs != null && _step == 0 && _hotspotHost != null)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _step = 1),
                child: Text(context.t('qrf.connected_next')),
              ),
            ),
          const SizedBox(height: Gap.sm),
          Text(context.t('qrf.app_hint'),
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          if (_served > 0) ...[
            const SizedBox(height: Gap.sm),
            Text(context.t('qrf.served', {'n': _served}),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
          const Divider(height: Gap.xl),
          if (hs == null && server != null)
            ListTile(
              leading: const Icon(AppIcons.hotspot),
              title: Text(context.t('qrf.no_common_wifi')),
              subtitle: Text(context.t('qrf.no_common_wifi_sub')),
              trailing: _hotspotBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _hotspotBusy ? null : _startHotspot,
            ),
          if (_textOnly)
            ListTile(
              leading: const Icon(AppIcons.textSnippet),
              title: Text(context.t('qrf.text_in_qr')),
              subtitle: Text(context.t('qrf.text_in_qr_sub')),
              onTap: () async {
                final path = widget.paths.single;
                final text = await File(path).readAsString();
                if (!context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        QrShareScreen(title: p.basename(path), text: text)));
              },
            ),
          const SizedBox(height: Gap.sm),
          Text(context.t('qrf.privacy'),
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
