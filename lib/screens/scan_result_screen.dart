import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/document_scanner.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/file_ops.dart';
import '../services/ocr_service.dart';
import '../widgets/translate_flow.dart';
import 'fm/folder_picker_screen.dart';

/// **Tarama sonucu** — taranan belge ve tanınan metin, yan yana iki sekmede.
///
/// Kullanıcı hatası/isteği 2026-07-31: *"belge okumada 'metinleri de tanı'
/// dediğimde kullanışsız saçma bir sayfa oluştu; düzgünce yazılar okunmalı,
/// bir sayfada belge bir sayfada yazılar düzgün formatta gelmeli ve çeviri
/// seçeneği olmalı, PDF dönüştür ve kaydet seçeneği olmalı, kaydedilecek
/// konum seçilebilmeli."*
///
/// Eski akışta tarama biter bitmez PDF Belgeler dizinine yazılıp
/// görüntüleyicide açılıyordu. Tanınan metin **hiçbir yerde** görünmüyordu
/// (yalnız PDF'in içine görünmez katman olarak giriyordu — ve o katman da
/// bozuk basılıyordu, bkz. `ConversionService.imagesToPdf`), kaydedilecek yer
/// sorulmuyordu, çeviri için belgeyi kapatıp yeniden açmak gerekiyordu.
///
/// ## Kaydetme: önce kaydet, sonra yerini değiştir
/// PDF ekran açılmadan **Belgeler dizinine yazılmış** olarak gelir; sonuç
/// ekranı yeri değiştirmeyi (taşımayı) önerir. Sıra tersine kurulsaydı
/// (kaydetmeden göster, kaydetme düğmesi bekle) geri tuşuna basan kullanıcı
/// taramasını kaybederdi. Tarama pahalı bir iştir; kaybolmasına izin veren bir
/// akış doğru olamaz.
class ScanResultScreen extends StatefulWidget {
  /// Kaydedilmiş PDF'in yolu.
  final String pdfPath;

  /// Sayfa görselleri (önizleme).
  final List<String> pages;

  /// Tanınan metin, sayfa sayfa. Boşsa "Metin" sekmesi OCR teklif eder.
  final List<OcrPage> textPages;

  const ScanResultScreen({
    super.key,
    required this.pdfPath,
    required this.pages,
    this.textPages = const [],
  });

  static Future<void> open(
    BuildContext context, {
    required String pdfPath,
    required List<String> pages,
    List<OcrPage> textPages = const [],
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          pdfPath: pdfPath,
          pages: pages,
          textPages: textPages,
        ),
      ));

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late String _pdfPath = widget.pdfPath;
  late List<OcrPage> _text = List.of(widget.textPages);
  bool _busy = false;

  String get _folder => p.dirname(_pdfPath);

  /// Metnin tek parça hâli (kopyala/paylaş/çeviri buradan besleniyor).
  String get _plainText => OcrService.joinPages(
      _text, (n) => context.t('tf.page_header', {'n': n}));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('scr.title')),
          bottom: TabBar(tabs: [
            Tab(icon: const Icon(Icons.picture_as_pdf_outlined),
                text: context.t('scr.tab_document')),
            Tab(icon: const Icon(Icons.subject),
                text: context.t('scr.tab_text')),
          ]),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            _savedRow(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [_documentTab(), _textTab()],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(child: _actions()),
      ),
    );
  }

  /// "Kaydedildi: <klasör>" + konumu değiştir. Kullanıcı nereye yazıldığını
  /// görmeden "kaydedildi" demek, dosyayı aratmak demektir.
  Widget _savedRow() => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 18, color: Color(0xFF2E7D32)),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                context.t('scr.saved_to', {'folder': p.basename(_folder)}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _changeLocation,
              icon: const Icon(Icons.drive_file_move_outlined, size: 18),
              label: Text(context.t('scr.change_location')),
            ),
          ],
        ),
      );

  Widget _documentTab() => PageView.builder(
        itemCount: widget.pages.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(widget.pages[i]),
              key: ValueKey(widget.pages[i]),
              errorBuilder: (_, __, ___) => Text(context.t('sr.page_failed')),
            ),
          ),
        ),
      );

  Widget _textTab() {
    if (_text.isEmpty) {
      // OCR istenmeden taranmış olabilir; kullanıcı fikir değiştirebilsin
      // (baştan taramak yerine).
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('scr.no_text_yet'),
                  textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton.icon(
                onPressed: _busy ? null : _recognize,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(context.t('vw.ocr_short')),
              ),
            ],
          ),
        ),
      );
    }
    // Sayfa sayfa kart: "düzgün formatta" isteğinin karşılığı — metin tek
    // yığın hâlinde değil, sayfa başlıklarıyla ve seçilebilir olarak duruyor.
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
      children: [
        for (final page in _text)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_text.length > 1)
                    Text(
                      context.t('tf.page_header', {'n': page.number}),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  const SizedBox(height: Gap.xs),
                  SelectableText(page.text,
                      style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => EntryOpener.open(context, _pdfPath),
              icon: const Icon(Icons.open_in_new, size: 20),
              label: Text(context.t('scr.open_pdf')),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _translate,
              icon: const Icon(Icons.translate, size: 20),
              label: Text(context.t('common.translate')),
            ),
            TextButton.icon(
              onPressed: _text.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _plainText));
                      if (mounted) _snack(context.t('vw.copied_all'));
                    },
              icon: const Icon(Icons.copy, size: 20),
              label: Text(context.t('common.copy')),
            ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => Share.shareXFiles([XFile(_pdfPath)],
                      text: p.basename(_pdfPath)),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: Text(context.t('common.share')),
            ),
          ],
        ),
      );

  /// Metin yoksa OCR'ı burada koşturur; sonuç hem sekmede görünür hem
  /// çeviriye kaynak olur. (PDF'in içindeki katman değişmez — o, kaydedilmiş
  /// belgenin bir parçası; kullanıcı isterse "Metinleri de tanı" ile yeniden
  /// tarar.)
  Future<void> _recognize() async {
    setState(() => _busy = true);
    try {
      final lines = await DocumentScanner.recognizePages(widget.pages);
      if (!mounted) return;
      setState(() => _text = DocumentScanner.textPages(lines));
      if (_text.isEmpty) _snack(context.t('vw.ocr_none'));
    } catch (e) {
      if (mounted) _snack(context.t('vw.ocr_failed', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _translate() async {
    await TranslateFlow.runDocument(
      context,
      title: p.basename(_pdfPath),
      load: (progress) async {
        if (_text.isNotEmpty) return _text;
        progress.status(AppStrings.of(context).t('vw.ocr_running'));
        final lines = await DocumentScanner.recognizePages(widget.pages);
        final pages = DocumentScanner.textPages(lines);
        if (mounted) setState(() => _text = pages);
        return pages;
      },
    );
  }

  /// PDF'i kullanıcının seçtiği klasöre **taşır**.
  Future<void> _changeLocation() async {
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: [_pdfPath],
          actionLabel: context.t('scr.save_here'),
        ),
      ),
    );
    if (target == null || !mounted || target == _folder) return;
    setState(() => _busy = true);
    final result = await FileOps.moveAll([_pdfPath], target);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.transfers.isNotEmpty) {
      setState(() => _pdfPath = result.transfers.first.dest);
      _snack(context.t('scr.moved', {'folder': p.basename(_folder)}));
    } else {
      _snack(result.errors.isEmpty
          ? context.t('scr.move_failed', {'error': '-'})
          : context.t('scr.move_failed', {'error': result.errors.first}));
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}
