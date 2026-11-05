import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';

/// **Sayfaları sürükleyerek sırala** (Faz 39 madde 8) — PDF Araçları'ndaki
/// ok düğmeleriyle tek tek taşımanın uzun belgedeki karşılığı.
///
/// Perf: sabit satır yüksekliği (`itemExtent`), küçük resim 72 DPI ve
/// `RepaintBoundary`; yalnız görünen satırların sayfası çizilir (liste
/// tembel). Belge bir kez açılır.
class PdfReorderScreen extends StatefulWidget {
  const PdfReorderScreen({super.key, required this.bytes, this.password});

  final Uint8List bytes;
  final String? password;

  /// Yeni sıra (0-tabanlı özgün indeksler) ya da vazgeçilirse `null`.
  static Future<List<int>?> open(BuildContext context,
          {required Uint8List bytes, String? password}) =>
      Navigator.of(context).push<List<int>>(MaterialPageRoute(
          builder: (_) => PdfReorderScreen(bytes: bytes, password: password)));

  @override
  State<PdfReorderScreen> createState() => _PdfReorderScreenState();
}

class _PdfReorderScreenState extends State<PdfReorderScreen> {
  PdfDocument? _doc;
  List<int> _order = const [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final password = widget.password;
    final doc = await PdfDocument.openData(
      widget.bytes,
      passwordProvider: password == null ? null : () async => password,
    );
    if (!mounted) {
      await doc.dispose();
      return;
    }
    setState(() {
      _doc = doc;
      _order = List<int>.generate(doc.pages.length, (i) => i);
    });
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('pp.reorder')),
        actions: [
          TextButton(
            onPressed: _changed ? () => Navigator.pop(context, _order) : null,
            child: Text(context.t('common.ok')),
          ),
        ],
      ),
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              itemCount: _order.length,
              itemExtent: 112,
              onReorderItem: (from, to) => setState(() {
                final item = _order.removeAt(from);
                _order.insert(to, item);
                _changed = true;
              }),
              itemBuilder: (context, i) {
                final page = _order[i];
                return ListTile(
                  key: ValueKey(page),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.xs),
                  leading: SizedBox(
                    width: 72,
                    height: 100,
                    child: RepaintBoundary(
                      child: PdfPageView(
                        document: doc,
                        pageNumber: page + 1,
                        maximumDpi: 72,
                        decoration: const BoxDecoration(color: AppColors.page),
                      ),
                    ),
                  ),
                  title: Text(context.t('pp.compare_page', {'n': i + 1})),
                  subtitle: page == i
                      ? null
                      : Text(context.t('pp.reorder_was', {'n': page + 1})),
                  trailing: const Icon(AppIcons.dragHandle),
                );
              },
            ),
    );
  }
}
