import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';
import '../models/document.dart';
import '../services/conversion_service.dart';
import '../services/file_service.dart';
import 'chat_screen.dart';

class ViewerScreen extends StatefulWidget {
  final LoadedDoc doc;
  const ViewerScreen({super.key, required this.doc});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _fileService = FileService();
  final _conversion = ConversionService();

  PdfControllerPinch? _pdfController;
  TextEditingController? _textController;
  bool _dirty = false;

  // Görüntüleme durumu (okuma konforu).
  int _pdfPage = 1;
  int _pdfCount = 0;
  int _imgQuarterTurns = 0;
  double _fontSize = 15;
  final TransformationController _imgTx = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf) {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(doc.path),
      );
    }
    if (doc.plainText.isNotEmpty ||
        doc.kind == DocKind.text ||
        doc.kind == DocKind.word ||
        doc.kind == DocKind.slides) {
      _textController = TextEditingController(text: doc.plainText);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _textController?.dispose();
    _imgTx.dispose();
    super.dispose();
  }

  void _handleImgDoubleTap() {
    if (_imgTx.value != Matrix4.identity()) {
      _imgTx.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      _imgTx.value = Matrix4.identity()
        ..translate(-pos.dx * 2, -pos.dy * 2)
        ..scale(3.0);
    }
  }

  void _changeFont(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(10.0, 32.0));
  }

  Future<void> _save() async {
    final doc = widget.doc;
    final text = _textController?.text ?? '';
    try {
      if (doc.kind == DocKind.text) {
        await _fileService.saveText(doc.path, text);
        _dirty = false;
        _snack('Kaydedildi');
      } else {
        // Word/Slayt: özgün formata güvenli yazım yerine dışa aktarma öner.
        await _exportPdf();
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _exportPdf() async {
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: 'PDF olarak dışa aktarıldı');
  }

  Future<void> _exportSlides() async {
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToSlidesPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}-slayt.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: 'Slayt destesi (PDF)');
  }

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.doc.path)]);
  }

  Future<void> _print() async {
    if (widget.doc.kind == DocKind.pdf) {
      final bytes = await _fileService.readBytes(widget.doc.path);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final bytes = await _conversion.textToPdf(
        widget.doc.name,
        _textController?.text ?? widget.doc.plainText,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        fileContext: widget.doc.plainText,
        fileName: widget.doc.name,
      ),
    ));
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? name : name.substring(0, dot);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final hasApiKey = context.watch<AppState>().hasApiKey;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (doc.kind == DocKind.image)
            IconButton(
              tooltip: 'Döndür',
              icon: const Icon(Icons.rotate_right),
              onPressed: () =>
                  setState(() => _imgQuarterTurns = (_imgQuarterTurns + 1) % 4),
            ),
          if (_textController != null) ...[
            IconButton(
              tooltip: 'Yazıyı küçült',
              icon: const Icon(Icons.text_decrease),
              onPressed: () => _changeFont(-2),
            ),
            IconButton(
              tooltip: 'Yazıyı büyüt',
              icon: const Icon(Icons.text_increase),
              onPressed: () => _changeFont(2),
            ),
          ],
          if (doc.isEditableText)
            IconButton(
              tooltip: 'Kaydet / Dışa aktar',
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'pdf':
                  _exportPdf();
                  break;
                case 'slides':
                  _exportSlides();
                  break;
                case 'share':
                  _share();
                  break;
                case 'print':
                  _print();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('PDF’e dönüştür')),
              PopupMenuItem(value: 'slides', child: Text('Slayta dönüştür')),
              PopupMenuItem(value: 'share', child: Text('Paylaş')),
              PopupMenuItem(value: 'print', child: Text('Yazdır')),
            ],
          ),
        ],
      ),
      body: _buildBody(doc),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChat,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text(hasApiKey ? 'AI ile çalış' : 'AI (anahtar gerekli)'),
      ),
    );
  }

  /// PDF sayfa numarası rozeti (yarı saydam koyu pill).
  Widget _pageBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildBody(LoadedDoc doc) {
    switch (doc.kind) {
      case DocKind.pdf:
        return Stack(
          children: [
            Positioned.fill(
              child: PdfViewPinch(
                controller: _pdfController!,
                onDocumentLoaded: (d) {
                  if (mounted) setState(() => _pdfCount = d.pagesCount);
                },
                onPageChanged: (p) {
                  if (mounted) setState(() => _pdfPage = p);
                },
              ),
            ),
            if (_pdfCount > 0)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(child: _pageBadge('$_pdfPage / $_pdfCount')),
              ),
          ],
        );

      case DocKind.image:
        return Container(
          color: Colors.black,
          child: GestureDetector(
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _handleImgDoubleTap,
            child: InteractiveViewer(
              transformationController: _imgTx,
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _imgQuarterTurns,
                  child: Image.file(
                    File(doc.path),
                    errorBuilder: (_, __, ___) => const Text(
                      'Görsel görüntülenemedi.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case DocKind.spreadsheet:
        return _SpreadsheetView(table: doc.table ?? const []);

      case DocKind.text:
      case DocKind.word:
      case DocKind.slides:
        return _TextEditor(
          controller: _textController!,
          editable: doc.isEditableText,
          fontSize: _fontSize,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
        );

      case DocKind.unknown:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu dosya türü için görüntüleyici henüz yok. '
              'Yine de paylaşabilir veya AI’a içeriğini sorabilirsiniz.',
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }
}

class _TextEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool editable;
  final double fontSize;
  final VoidCallback onChanged;
  const _TextEditor({
    required this.controller,
    required this.editable,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: !editable,
        onChanged: (_) => onChanged(),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: editable ? 'Belge içeriği…' : null,
          filled: false,
        ),
        style: TextStyle(fontSize: fontSize, height: 1.5),
      ),
    );
  }
}

class _SpreadsheetView extends StatelessWidget {
  final List<List<String>> table;
  const _SpreadsheetView({required this.table});

  @override
  Widget build(BuildContext context) {
    if (table.isEmpty) {
      return const Center(child: Text('Tablo boş veya okunamadı.'));
    }
    final maxCols =
        table.fold<int>(0, (m, row) => row.length > m ? row.length : m);
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: List.generate(
            maxCols == 0 ? 1 : maxCols,
            (i) => DataColumn(label: Text('${i + 1}')),
          ),
          rows: table.take(500).map((row) {
            return DataRow(
              cells: List.generate(maxCols, (i) {
                final v = i < row.length ? row[i] : '';
                return DataCell(Text(v));
              }),
            );
          }).toList(),
        ),
      ),
    );
  }
}
