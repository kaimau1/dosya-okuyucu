import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../services/conversion_service.dart';
import '../services/document_scanner.dart';
import '../services/ocr_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/pdf_save_dialog.dart';
import 'scan_review_screen.dart';

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

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Şifreli belge: sayfa sayısı okunamıyorsa parola sor.
      try {
        await PdfTools.pageCount(bytes);
      } catch (_) {
        final pw = await _askPassword(
            _str.t('pt.locked_title'), _str.t('pt.enter_password'));
        if (pw == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        await PdfTools.pageCount(bytes, password: pw);
        _password = pw;
      }
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Tüm işlemlerin tek kapısı: yeni baytı üretir, geri almayı besler, önizlemeyi
  /// tazeler. Hata olursa belge dokunulmadan kalır.
  ///
  /// [op] artık **arka plan isolate'inde** koşan `…InBackground` sürümlerini
  /// çağırır; ana izlek boş kalır, ekran donmaz ve [_busyLabel] süreci gösterir.
  Future<void> _apply(
    String label,
    Future<List<int>> Function(Uint8List bytes) op,
  ) async {
    final current = _bytes;
    if (current == null || _busy) return;
    setState(() => _busyLabel = '$label…');
    try {
      final out = Uint8List.fromList(await op(current));
      if (!mounted) return;
      setState(() {
        _undo.add(current);
        if (_undo.length > 5) _undo.removeAt(0);
        _bytes = out;
        _dirty = true;
        _rev++;
      });
      _selection.value = <int>{};
    } catch (e) {
      if (mounted) {
        _snack(_str.t('pt.op_failed', {'label': label, 'error': e}));
      }
    } finally {
      if (mounted) setState(() => _busyLabel = '');
    }
  }

  Future<int> _pageCount() =>
      PdfTools.pageCount(_bytes!, password: _password);

  // ── İşlemler ──────────────────────────────────────────────────────────────

  Future<void> _rotate() async {
    final pages = _selected.isEmpty
        ? List.generate(await _pageCount(), (i) => i)
        : _selected.toList();
    final pw = _password;
    await _apply(
      _str.t('pt.op_rotate'),
      (b) => PdfTools.rotatePagesInBackground(b,
          pageIndexes: pages, quarterTurns: 1, password: pw),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.length >= await _pageCount()) {
      _snack(_str.t('pt.cannot_delete_all'));
      return;
    }
    final pages = _selected.toList();
    final pw = _password;
    await _apply(_str.t('pt.op_delete'),
        (b) => PdfTools.deletePagesInBackground(b, pages, password: pw));
  }

  /// **Sayfa numarası ekle** (2026-08-28).
  ///
  /// Seçenekler tek bir kısa sayfada: kapağı atla, "n / toplam" yaz, sağa
  /// hizala. Varsayılanlar en sık istenen hâl (ortada, 1'den, sade sayı) —
  /// kullanıcı hiçbir şeye dokunmadan "Ekle" diyebilmeli.
  Future<void> _addPageNumbers() async {
    final options = await showModalBottomSheet<_NumberOptions>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PageNumberSheet(),
    );
    if (options == null) return;
    final pw = _password;
    await _apply(
      _str.t('pt.op_page_numbers'),
      (b) => PdfTools.addPageNumbersInBackground(
        b,
        password: pw,
        skipFirstPage: options.skipFirst,
        startAt: options.skipFirst ? 2 : 1,
        withTotal: options.withTotal,
        position: options.right
            ? PdfTools.numberBottomRight
            : PdfTools.numberBottomCenter,
      ),
    );
  }

  /// **Filigran (damga) ekle** (2026-08-28).
  ///
  /// Yazı tipi baytları ASSET'ten geçiliyor: gömülü standart PDF fontları
  /// WinAnsi kodlamasında ve `ş/ğ/ı/İ` orada YOK — "BAŞLIK" bozuk çıkardı.
  /// Font okunamazsa işlem iptal edilmez, standart fonta düşülür.
  Future<void> _addWatermark() async {
    final text = await _askText(
        _str.t('pt.watermark'), _str.t('pt.watermark_hint'));
    if (text == null || text.trim().isEmpty) return;
    List<int>? fontBytes;
    try {
      final data = await rootBundle.load('assets/fonts/Carlito-Bold.ttf');
      fontBytes = data.buffer.asUint8List();
    } catch (_) {
      fontBytes = null;
    }
    final pw = _password;
    await _apply(
      _str.t('pt.op_watermark'),
      (b) => PdfTools.addWatermarkInBackground(b,
          text: text, password: pw, fontBytes: fontBytes),
    );
  }

  /// **Sayfaları görsel (PNG) olarak dışa aktar** (2026-08-28).
  ///
  /// "PDF'i JPG yap" bir PDF aracından en çok istenen dönüşümlerden biri
  /// (sunum/sosyal medya/mesajla gönderme). Belge zaten pdfrx ile açık
  /// olduğundan yeni bir bağımlılık gerekmedi; render `OcrService`in
  /// kullandığı yolun aynısı (1600 px genişliğe ölçekli).
  ///
  /// Seçili sayfa varsa yalnız onlar, yoksa tüm belge. **Sınır 30 sayfa:**
  /// her sayfa tam boyutlu bir bitmap; 300 sayfalık bir kitabı tek seferde
  /// açmak belleği şişirir ve paylaşım penceresi zaten o kadar dosyayı
  /// taşıyamaz. Aşarsa kullanıcıya sayfa seçmesi söylenir.
  Future<void> _exportImages() async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;
    final total = await _pageCount();
    final pages = _selected.isEmpty
        ? List.generate(total, (i) => i)
        : (_selected.toList()..sort());
    if (pages.length > 30) {
      _snack(_str.t('pt.export_images_limit', {'n': 30}));
      return;
    }
    setState(() => _busyLabel = '${_str.t('pt.op_export_images')}…');
    final password = _password;
    try {
      final document = await PdfDocument.openData(
        bytes,
        passwordProvider: password == null ? null : () async => password,
      );
      final files = <XFile>[];
      try {
        for (final index in pages) {
          final rendered = await OcrService.renderPageToPng(
              document.pages[index],
              tag: 'export');
          if (rendered == null) continue;
          // Paylaşım penceresinde dosya adı görünüyor: "belge-3.png" gibi
          // anlamlı olsun, "ocr_page_export_3.png" değil.
          final name =
              '${p.basenameWithoutExtension(widget.path)}-${index + 1}.png';
          final target = File(p.join(
              Directory.systemTemp.path, name));
          await File(rendered.path).rename(target.path);
          files.add(XFile(target.path));
        }
      } finally {
        await document.dispose();
      }
      if (files.isEmpty) {
        if (mounted) _snack(_str.t('pt.export_images_failed'));
        return;
      }
      await Share.shareXFiles(files,
          text: _str.t('pt.export_images_count', {'n': files.length}));
    } catch (e) {
      if (mounted) {
        _snack(_str.t('pt.op_failed',
            {'label': _str.t('pt.op_export_images'), 'error': e}));
      }
    } finally {
      if (mounted) setState(() => _busyLabel = '');
    }
  }

  /// Sayfa kopyalayan işlemler vurguları taşıyamaz — kullanıcı bilmeden
  /// kaybetmesin diye yalnız belgede vurgu VARSA sorulur.
  Future<bool> _confirmAnnotationLoss(String action) async {
    final count = await PdfTools.annotationCount(_bytes!, password: _password);
    if (count == 0 || !mounted) return count == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.annot_title')),
        content:
            Text(ctx.t('pt.annot_body', {'n': count, 'action': action})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.continue'))),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Seçili sayfaları **yeni bir PDF** olarak paylaşır (böl / sayfa çıkar).
  Future<void> _extractSelected() async {
    if (_selected.isEmpty || _bytes == null) return;
    final pages = _selected.toList()..sort();
    final str = _str;
    setState(() => _busyLabel = str.t('pt.extracting'));
    try {
      final out = await PdfTools.selectPagesInBackground(_bytes!, pages,
          password: _password);
      final name = '${p.basenameWithoutExtension(widget.path)}'
          '_sayfa${pages.length == 1 ? pages.first + 1 : '${pages.length}'}.pdf';
      final path =
          await _conversion.writeToTemp(name, Uint8List.fromList(out));
      await Share.shareXFiles([XFile(path)],
          text: str.t('pt.extracted'));
    } catch (e) {
      if (mounted) _snack(str.t('pt.extract_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _busyLabel = '');
    }
  }

  /// Tek seçili sayfayı bir sıra öne/arkaya taşır.
  ///
  /// ponytail: sürükle-bırak yerine ok düğmeleri — çok daha az kod, aynı iş.
  /// Uzun belgede sıkıcı olursa `ReorderableGridView` benzeri bir çözüme geç.
  Future<void> _move(int delta) async {
    if (_selected.length != 1) return;
    final from = _selected.first;
    final total = await _pageCount();
    final to = from + delta;
    if (to < 0 || to >= total) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_move_page'))) return;
    final order = movePageOrder(total, from, to);
    final pw = _password;
    await _apply(_str.t('pt.op_move'),
        (b) => PdfTools.selectPagesInBackground(b, order, password: pw));
    if (mounted) _selection.value = {to};
  }

  Future<void> _mergeOther() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    final paths = res?.files.map((f) => f.path).whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_merge'))) return;
    final others = [
      for (final path in paths) await File(path).readAsBytes(),
    ];
    await _apply(_str.t('pt.op_merge'),
        (b) => PdfTools.mergeInBackground([b, ...others]));
    if (mounted) _snack(_str.t('pt.merged', {'n': paths.length}));
  }

  /// Kameradan yeni sayfa(lar) tarayıp belgenin sonuna ekler — kâğıt eki olan
  /// sözleşme/rapor için asıl işe yarayan birleşim.
  Future<void> _scanAndAppend() async {
    final scanned = await DocumentScanner.scanPages();
    if (scanned == null || !mounted) return;
    // Ana tarama akışıyla aynı önizleme: yamuk sayfa belgeye girmeden düzeltilir.
    final pages = await ScanReviewScreen.open(context, scanned);
    if (pages == null || pages.isEmpty || !mounted) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_scan_append'))) return;
    // Hata/ilerleme yönetimi _apply'da; taranan sayfalar ızgarada zaten görünür.
    await _apply(_str.t('pt.op_scan_append'), (b) async {
      final doc = await _conversion.imagesToPdf(pages,
          uniformPage: PdfPageFormat.a4);
      return PdfTools.mergeInBackground([b, doc]);
    });
  }

  /// Sıkıştırma: **önce onay, sonra arka planda**.
  ///
  /// 2026-07-26 kullanıcı bulgusu: "sıkıştır denince donma". Kök neden
  /// Syncfusion'ın belgeyi ana izlekte baştan yazmasıydı (bkz.
  /// [PdfTools.compressInBackground]). Ayrıca ne olacağı önceden söylenmiyordu:
  /// taranmış belgede kazanç küçüktür, kullanıcı bunu beklemeden bilmeli.
  Future<void> _compress() async {
    final before = _bytes!.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.compress_title')),
        content: Text(ctx.t('pt.compress_body', {'size': _kb(before)})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.compress'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pw = _password;
    await _apply(_str.t('pt.op_compress'),
        (b) => PdfTools.compressInBackground(b, password: pw));
    if (!mounted) return;
    final after = _bytes!.length;
    _snack(after < before
        ? _str.t('pt.size_change',
            {'before': _kb(before), 'after': _kb(after)})
        : _str.t('pt.already_compact', {'size': _kb(before)}));
  }

  Future<void> _setPassword() async {
    final pw = await _askPassword(
        _str.t('pt.set_password'), _str.t('pt.new_password'));
    if (pw == null || pw.isEmpty) return;
    final current = _password;
    await _apply(
      _str.t('pt.op_set_password'),
      (b) => PdfTools.setPasswordInBackground(b,
          password: pw, currentPassword: current),
    );
    if (mounted) setState(() => _password = pw);
  }

  Future<void> _removePassword() async {
    final pw = _password;
    if (pw == null) return;
    await _apply(_str.t('pt.op_remove_password'),
        (b) => PdfTools.removePasswordInBackground(b, currentPassword: pw));
    if (mounted) setState(() => _password = null);
  }

  /// Kaydet — **üzerine yaz** ya da **kopyasını kaydet**.
  ///
  /// Kopya kaydedilirse ekran o dosyayı düzenlemeye devam etmez: özgün belge
  /// açık kalır (çağıran görüntüleyici hâlâ onu gösteriyor), kullanıcıya yeni
  /// dosyanın adı söylenir.
  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || !_dirty) return;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.path,
      bytes: bytes,
    );
    if (outcome == null || !mounted) return;
    // Kopya kaydedildiyse ekrandaki belge hâlâ özgün dosya: "kaydedilmemiş
    // değişiklik" durumu sürüyor demektir.
    setState(() => _dirty = !outcome.overwritten);
  }

  Future<void> _share() async {
    if (_bytes == null) return;
    final path = await _conversion.writeToTemp(
        p.basename(widget.path), _bytes!);
    await Share.shareXFiles([XFile(path)], text: 'PDF');
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _bytes = _undo.removeLast();
      _dirty = true;
      _rev++;
    });
    _selection.value = <int>{};
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  Future<String?> _askPassword(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: hint),
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
  }

  /// [_askPassword]'ün görünür metin karşılığı (filigran yazısı gibi).
  Future<String?> _askText(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: hint),
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
  }

  String _kb(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).round()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.unsaved_title')),
        content: Text(ctx.t('pt.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('pt.stay'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.leave'))),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Kaydedilmemiş değişiklikle geri tuşu: onay al, sonra kapat.
  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final leave = await _confirmLeave();
    if (!mounted || !leave) return;
    Navigator.of(context).pop(false);
  }

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

  /// Süren iş perdesi: ne olduğunu yazar ve dokunuşları yutar (işlem sürerken
  /// ikinci bir işlem başlatmak belgeyi tutarsız bırakırdı).
  Widget _busyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 16),
                  Text(_busyLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sayfa ızgarası. **Aynı revizyonda AYNI widget örneği** döner — bkz.
  /// [_selection] açıklaması (yeniden render + başa atma hatasının çözümü).
  Widget _pageGrid(Uint8List bytes) {
    if (_gridCache == null || _gridCacheRev != _rev) {
      _gridCacheRev = _rev;
      final password = _password;
      _gridCache = PdfDocumentViewBuilder(
        // sourceName revizyonu taşır: düzenleme sonrası önizleme tazelensin.
        documentRef: PdfDocumentRefData(
          bytes,
          sourceName: '${widget.path}#$_rev',
          passwordProvider: password == null ? null : () async => password,
        ),
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final count = document.pages.length;
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: count,
            itemBuilder: (context, i) => _pageTile(document, i),
          );
        },
      );
    }
    return _gridCache!;
  }

  Widget _pageTile(PdfDocument document, int index) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: _selection,
      builder: (context, selection, child) {
        final scheme = Theme.of(context).colorScheme;
        final selected = selection.contains(index);
        return InkWell(
          onTap: () {
            final next = Set<int>.from(_selection.value);
            if (!next.remove(index)) next.add(index);
            _selection.value = next;
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // child: seçim değişince YENİDEN KURULMAZ — küçük resmin
                      // pdfium render'ı seçim dokunuşunda tekrarlanmasın.
                      child!,
                      if (selected)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.check_circle,
                                color: scheme.primary, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        );
      },
      child: PdfPageView(
        document: document,
        pageNumber: index + 1,
        // Küçük resim: 300 DPI gereksiz bellek yer.
        maximumDpi: 96,
        decoration: const BoxDecoration(color: Colors.white),
      ),
    );
  }

  Widget _actionBar() {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: _selection,
      builder: (context, selection, _) {
        final has = selection.isNotEmpty;
        final single = selection.length == 1;
        return BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _barButton(
                  Icons.rotate_right,
                  context.t(has ? 'vw.rotate' : 'pt.rotate_all'),
                  _busy ? null : _rotate),
              _barButton(Icons.delete_outline, context.t('common.delete'),
                  has && !_busy ? _deleteSelected : null),
              _barButton(Icons.call_split, context.t('pt.extract'),
                  has && !_busy ? _extractSelected : null),
              _barButton(Icons.arrow_upward, context.t('pt.forward'),
                  single && !_busy ? () => _move(-1) : null),
              _barButton(Icons.arrow_downward, context.t('pt.backward'),
                  single && !_busy ? () => _move(1) : null),
            ],
          ),
        );
      },
    );
  }

  Widget _barButton(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: onTap == null ? Theme.of(context)
                  .disabledColor : null),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: onTap == null ? Theme.of(context).disabledColor : null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// [_PageNumberSheet]'in döndürdüğü seçenekler.
class _NumberOptions {
  final bool skipFirst;
  final bool withTotal;
  final bool right;
  const _NumberOptions(this.skipFirst, this.withTotal, this.right);
}

/// Sayfa numarası seçenekleri — üç anahtar, hepsi kapalı gelir.
///
/// Varsayılan (ortada, 1'den başlayan sade sayı) en sık istenen hâl olduğu
/// için kullanıcı hiçbir şeye dokunmadan "Ekle" diyebilir.
class _PageNumberSheet extends StatefulWidget {
  const _PageNumberSheet();

  @override
  State<_PageNumberSheet> createState() => _PageNumberSheetState();
}

class _PageNumberSheetState extends State<_PageNumberSheet> {
  bool _skipFirst = false;
  bool _withTotal = false;
  bool _right = false;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.t('pt.page_numbers'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            SwitchListTile(
              value: _skipFirst,
              onChanged: (v) => setState(() => _skipFirst = v),
              title: Text(context.t('pt.pn_skip_first')),
              subtitle: Text(context.t('pt.pn_skip_first_sub')),
            ),
            SwitchListTile(
              value: _withTotal,
              onChanged: (v) => setState(() => _withTotal = v),
              title: Text(context.t('pt.pn_with_total')),
            ),
            SwitchListTile(
              value: _right,
              onChanged: (v) => setState(() => _right = v),
              title: Text(context.t('pt.pn_right')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.t('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                        context, _NumberOptions(_skipFirst, _withTotal, _right)),
                    child: Text(context.t('common.add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
