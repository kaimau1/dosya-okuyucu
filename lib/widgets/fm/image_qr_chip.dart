import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/remote/qr_transfer.dart';
import '../app_dialog.dart';

/// **Görseldeki QR'ı kendiliğinden tanıyan düğme** (2026-11-18, kullanıcı:
/// *"QR'lı görseli otomatik tanıma ve QR butonu ile otomatik linke gitme"*).
///
/// Görsel ekranda [_settle] kadar durunca (kaydırırken değil) Kotlin tarafı
/// ([QrNative.decodeImage]) dosyayı ARKA İŞ PARÇACIĞINDA küçültüp ML Kit'e
/// verir; QR yoksa hiçbir şey çizilmez. Sonuç yol başına bellekte tutulur
/// (galeride geri dönünce yeniden çözülmez). Bağlantıysa tek dokunuş tarayıcıda
/// açar; yazı/Wi-Fi vb. ise levhada gösterilir, kopyalanır.
class ImageQrChip extends StatefulWidget {
  final String path;

  const ImageQrChip({super.key, required this.path});

  /// Yol → QR değerleri (son [_cap] görsel).
  static final Map<String, List<String>> _cache = {};
  static const _cap = 64;

  @visibleForTesting
  static void debugSeed(String path, List<String> codes) =>
      _cache[path] = codes;

  /// Değer web bağlantısı mı (http/https ya da şemasız `www.`)?
  static Uri? linkOf(String raw) {
    final t = raw.trim();
    final withScheme = t.toLowerCase().startsWith('www.') ? 'https://$t' : t;
    final u = Uri.tryParse(withScheme);
    if (u == null || !u.hasAuthority) return null;
    return const {'http', 'https'}.contains(u.scheme.toLowerCase()) ? u : null;
  }

  @override
  State<ImageQrChip> createState() => _ImageQrChipState();
}

class _ImageQrChipState extends State<ImageQrChip> {
  static const _settle = Duration(milliseconds: 600);
  Timer? _timer;
  List<String> _codes = const [];

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ImageQrChip old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    final cached = ImageQrChip._cache[widget.path];
    _codes = cached ?? const [];
    if (cached != null) return;
    final path = widget.path;
    _timer = Timer(_settle, () async {
      final codes = await QrNative.decodeImage(path);
      final cache = ImageQrChip._cache;
      cache[path] = codes;
      if (cache.length > ImageQrChip._cap) cache.remove(cache.keys.first);
      if (mounted && widget.path == path && codes.isNotEmpty) {
        setState(() => _codes = codes);
      }
    });
  }

  Future<void> _open(String raw) async {
    final link = ImageQrChip.linkOf(raw);
    if (link != null) {
      final ok = await launchUrl(link, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showSnack(context, context.t('qrimg.open_failed'));
      return;
    }
    if (!mounted) return;
    await _sheet();
  }

  Future<void> _sheet() => showAppSheet<void>(
        context,
        title: context.t('qrimg.title'),
        builder: (ctx) => Padding(
          padding:
              const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final raw in _codes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(ImageQrChip.linkOf(raw) != null
                      ? AppIcons.link
                      : AppIcons.qrScan),
                  title: SelectableText(raw, maxLines: 4),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (ImageQrChip.linkOf(raw) != null)
                      IconButton(
                        tooltip: context.t('qrimg.open'),
                        icon: const Icon(AppIcons.open),
                        onPressed: () {
                          Navigator.pop(ctx);
                          unawaited(_open(raw));
                        },
                      ),
                    IconButton(
                      tooltip: context.t('common.copy'),
                      icon: const Icon(AppIcons.copyPlain),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: raw));
                        Navigator.pop(ctx);
                        showSnack(context, context.t('near.copied'));
                      },
                    ),
                  ]),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final codes = _codes;
    if (codes.isEmpty) return const SizedBox.shrink();
    final link = codes.length == 1 ? ImageQrChip.linkOf(codes.first) : null;
    final label = link != null
        ? (link.host.startsWith('www.') ? link.host.substring(4) : link.host)
        : context.t('qrimg.chip', {'n': codes.length});
    return FilledButton.tonalIcon(
      key: const ValueKey('img-qr-chip'),
      onPressed: () =>
          codes.length == 1 ? unawaited(_open(codes.first)) : unawaited(_sheet()),
      onLongPress: () => unawaited(_sheet()),
      icon: Icon(link != null ? AppIcons.open : AppIcons.qrScan, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
