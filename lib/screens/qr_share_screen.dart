import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/qr_code.dart';

/// **Notu QR kodla paylaş** (2026-10-22, kullanıcı: *"paylaşa basılır, QR
/// kod seçilince bir QR kod oluşur, karşı taraf okutunca veri gönderilir;
/// karşı tarafta Dosya Okuyucu olmasa da, aynı ağa bağlı olmasa da"*).
///
/// Metin QR'ın **kendisinde**: karşı tarafın yalnız kamerası yeter (her
/// telefonun kamerası QR'daki yazıyı gösterir ve kopyalatır). İnternet, ağ,
/// sunucu, hesap YOK — not hiçbir yere yüklenmez. Bir QR ~1.000 bayt
/// taşır; uzun not "1/3, 2/3…" diye sırayla okutulan QR'lara bölünür
/// (kelime sınırından), otomatik ilerleyebilir.
class QrShareScreen extends StatefulWidget {
  final String title;
  final String text;

  const QrShareScreen({super.key, required this.title, required this.text});

  /// Bir QR'a konan en çok bayt (UTF-8). Düşük hata düzeltmede sınır ~2.900;
  /// telefon kamerasının ekrandan rahat okuması için yoğunluk düşük tutuldu.
  static const maxBytes = 1000;

  /// Metni QR parçalarına böler; birden çoksa her parçanın başına "[i/n] ".
  static List<String> parts(String text, {int maxBytes = maxBytes}) {
    final clean = text.trim();
    if (utf8.encode(clean).length <= maxBytes) return [clean];
    final budget = maxBytes - 12; // "[12/34] " payı
    final out = <String>[];
    var rest = clean;
    while (rest.isNotEmpty) {
      if (utf8.encode(rest).length <= budget) {
        out.add(rest);
        break;
      }
      // Bayt bütçesine sığan en uzun önek (karakter sınırında), sonra kelime.
      var lo = 1, hi = rest.length;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (utf8.encode(rest.substring(0, mid)).length <= budget) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      var cut = lo;
      final space = rest.lastIndexOf(RegExp(r'\s'), cut);
      if (space > cut ~/ 2) cut = space;
      out.add(rest.substring(0, cut).trimRight());
      rest = rest.substring(cut).trimLeft();
    }
    return [
      for (var i = 0; i < out.length; i++) '[${i + 1}/${out.length}] ${out[i]}',
    ];
  }

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  late final List<String> _parts = QrShareScreen.parts(widget.text);
  final _pages = PageController();
  int _index = 0;
  Timer? _auto;

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _toggleAuto() {
    if (_auto != null) {
      setState(() {
        _auto!.cancel();
        _auto = null;
      });
      return;
    }
    setState(() {
      _auto = Timer.periodic(const Duration(seconds: 4), (_) {
        final next = (_index + 1) % _parts.length;
        Motion.toPage(context, _pages, next);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size =
        (MediaQuery.sizeOf(context).shortestSide - 64).clamp(180.0, 420.0);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('qr.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Text(
              _parts.length == 1
                  ? context.t('qr.hint_one')
                  : context.t('qr.hint_many', {'n': _parts.length}),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _parts.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Center(
                child:
                    QrCode(key: ValueKey('qr-$i'), data: _parts[i], size: size),
              ),
            ),
          ),
          if (_parts.length > 1)
            Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: context.t('qr.prev'),
                    icon: const Icon(AppIcons.back),
                    onPressed: _index == 0
                        ? null
                        : () => Motion.toPage(context, _pages, _index - 1),
                  ),
                  Text('${_index + 1} / ${_parts.length}',
                      style: theme.textTheme.titleMedium),
                  IconButton(
                    tooltip: context.t('qr.next'),
                    icon: const Icon(AppIcons.chevron),
                    onPressed: _index >= _parts.length - 1
                        ? null
                        : () => Motion.toPage(context, _pages, _index + 1),
                  ),
                  const SizedBox(width: Gap.md),
                  FilledButton.tonalIcon(
                    key: const ValueKey('qr-auto'),
                    onPressed: _toggleAuto,
                    icon: Icon(_auto == null ? AppIcons.play : AppIcons.pause),
                    label:
                        Text(context.t(_auto == null ? 'qr.auto' : 'qr.stop')),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: Text(context.t('qr.privacy'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
