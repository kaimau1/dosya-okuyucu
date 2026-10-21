import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../core/busy_dialog.dart';
import '../core/l10n/app_strings.dart';
import '../services/conversion_service.dart';
import '../services/document_scanner.dart';
import '../services/ocr_service.dart';
import '../services/pdf_tools.dart';
import '../services/scan_prepare.dart';
import '../widgets/pdf_save_dialog.dart';
import '../core/snack.dart';
import '../services/fm/tracked_task.dart';
import '../core/user_error.dart';

part 'pdf_tools/actions.dart';
part 'pdf_tools/views.dart';

/// **PDF Araçları** — sayfa ızgarası üzerinden birleştir / çıkar / sil / sırala /
/// döndür, ayrıca parola ve sıkıştırma.
///
/// Çalışma biçimi: dosya belleğe alınır, işlemler bellekteki baytlara uygulanır
/// (anında önizleme), kullanıcı **Kaydet** deyince diske yazılır. Böylece geri
/// alma ucuz ve yanlış dokunuş dosyayı bozmaz.
class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key, required this.path});

  final String path;

  /// Ekranı açar; [path] yoksa kullanıcıya PDF seçtirir. Dosya kaydedildiyse
  /// `true` döner (çağıran görüntüleyiciyi tazeleyebilir).
  static Future<bool?> open(BuildContext context, {String? path}) async {
    var target = path;
    if (target == null) {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      target = res?.files.single.path;
      if (target == null) return null;
    }
    if (!context.mounted) return null;
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PdfToolsScreen(path: target!)),
    );
  }

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  /// Mesajlar uzun asenkron işlerin **içinden** üretiliyor (`_apply` ve
  /// `catch` dalları); orada `context` kullanmak `use_build_context_synchronously`
  /// demektir. Doğrudan çizilen parçalarda `context.t` kullanılır.
  AppStrings get _str => AppStrings.current;

  final _conversion = ConversionService();

  Uint8List? _bytes;
  String? _password;
  String? _error;

  /// Seçili sayfalar (0-tabanlı).
  ///
  /// **Neden `ValueNotifier` ve `setState` değil** (2026-07-26 kullanıcı bulgusu
  /// "her sayfa seçtiğinde baştan render oluyor ve başa atıyor"): ekran
  /// `setState` ettiğinde `PdfDocumentViewBuilder` YENİ bir widget örneği olarak
  /// yeniden kurulur; pdfrx'in `didUpdateWidget`'i eski belgenin dinleyicisini
  /// kaldırır → pdfrx'in statik önbelleğinde başka dinleyici kalmadığı için
  /// belge **dispose edilir**, sonra sıfırdan yüklenir. Bu arada `document`
  /// null döner, ızgara ağaçtan düşer → kaydırma başa gider ve tüm küçük
  /// resimler yeniden çizilir. Çözüm iki parçalı: (1) seçim `setState`
  /// etmiyor, yalnız bu notifier'ı dinleyen karolar güncelleniyor;
  /// (2) ızgara widget'ı önbelleğe alınıp AYNI ÖRNEK döndürülüyor (`_gridCache`)
  /// — Flutter aynı örneği görünce alt ağacı hiç güncellemiyor.
  final ValueNotifier<Set<int>> _selection = ValueNotifier(<int>{});

  Set<int> get _selected => _selection.value;

  /// Geri alma yığını. Sayfa silme geri alınamazsa korkutucu; 5 adım yeter.
  final _undo = <Uint8List>[];

  bool _dirty = false;

  /// Süren işin etiketi (boşsa iş yok). Kullanıcı ne olduğunu görsün diye
  /// yazıyla gösteriliyor — eskiden yalnız ince bir çubuk vardı.
  String _busyLabel = '';

  bool get _busy => _busyLabel.isNotEmpty;

  /// pdfrx `PdfDocumentRefData`'yı YALNIZ `sourceName` ile eşit sayar; bayt
  /// değişince aynı ad verilirse önizleme tazelenmez → her işlemde artar.
  int _rev = 0;

  /// Önbelleklenmiş ızgara widget'ı ve hangi revizyona ait olduğu.
  Widget? _gridCache;
  int _gridCacheRev = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  // ── İşlemler ──────────────────────────────────────────────────────────────

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.path),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            // Tümünü seç / seçimi ters çevir: 200 sayfalık bir belgede tek
            // tek dokunmak (eski tek yol) kullanılabilir bir şey değildi.
            ValueListenableBuilder<Set<int>>(
              valueListenable: _selection,
              builder: (context, selection, _) => IconButton(
                tooltip: context.t(selection.isEmpty
                    ? 'pt.select_all'
                    : 'pt.invert_selection'),
                icon: Icon(selection.isEmpty
                    ? Icons.select_all
                    : Icons.flip_to_back),
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        selection.isEmpty ? _selectAll() : _invertSelection()),
              ),
            ),
            IconButton(
              tooltip: context.t('common.undo'),
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty ? null : _undoLast,
            ),
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: _dirty ? _save : null,
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'scan' => _scanAndAppend(),
                'merge' => _mergeOther(),
                'move_to' => _moveTo(),
                'duplicate' => _duplicateSelected(),
                'insert_blank' => _insertBlank(),
                'reverse' => _reverse(),
                'split' => _splitEvery(),
                'compress' => _compress(),
                'numbers' => _addPageNumbers(),
                'watermark' => _addWatermark(),
                'images' => _exportImages(),
                'lock' => _setPassword(),
                'unlock' => _removePassword(),
                'share' => _share(),
                _ => null,
              },
              itemBuilder: (_) => [
                // **Sayfa düzeni işlemleri en üstte** (kullanıcı isteği
                // 2026-09-03): en sık istenen şey sayfaları düzeltmek.
                PopupMenuItem(
                  value: 'move_to',
                  enabled: _selection.value.length == 1,
                  child: Text(context.t('pt.move_to')),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  enabled: _selection.value.isNotEmpty,
                  child: Text(context.t('pt.op_duplicate')),
                ),
                PopupMenuItem(
                    value: 'insert_blank',
                    child: Text(context.t('pt.op_insert_blank'))),
                PopupMenuItem(
                    value: 'reverse', child: Text(context.t('pt.op_reverse'))),
                PopupMenuItem(
                    value: 'split', child: Text(context.t('pt.split_every'))),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'scan', child: Text(context.t('pt.scan_append'))),
                PopupMenuItem(
                    value: 'merge', child: Text(context.t('pt.merge_other'))),
                PopupMenuItem(
                    value: 'compress',
                    child: Text(context.t('pt.compress_menu'))),
                PopupMenuItem(
                    value: 'numbers',
                    child: Text(context.t('pt.page_numbers'))),
                PopupMenuItem(
                    value: 'watermark',
                    child: Text(context.t('pt.watermark'))),
                PopupMenuItem(
                    value: 'images',
                    child: Text(context.t('pt.export_images'))),
                if (_password == null)
                  PopupMenuItem(
                      value: 'lock', child: Text(context.t('pt.set_password')))
                else
                  PopupMenuItem(
                      value: 'unlock',
                      child: Text(context.t('pt.remove_password'))),
                PopupMenuItem(
                    value: 'share', child: Text(context.t('common.share'))),
              ],
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('pt.open_failed', {'error': _error})),
              ))
            : bytes == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // 0. çocuk DAİMA ızgara: `_busy` değişince çocuk listesi
                      // uzunluğu değişse bile ızgaranın elemanı yerinde kalır.
                      _pageGrid(bytes),
                      if (_busy) _busyOverlay(),
                    ],
                  ),
        bottomNavigationBar: bytes == null ? null : _actionBar(),
      ),
    );
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
