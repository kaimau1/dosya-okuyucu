import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/xlsx_editor.dart';
import '../chat_screen.dart';

/// Excel benzeri, hücre hücre düzenlenebilir tablo görünümü.
class SpreadsheetEditorScreen extends StatefulWidget {
  final String path;
  final String name;
  final String plainText;
  const SpreadsheetEditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.plainText,
  });

  @override
  State<SpreadsheetEditorScreen> createState() =>
      _SpreadsheetEditorScreenState();
}

class _SpreadsheetEditorScreenState extends State<SpreadsheetEditorScreen> {
  static const _cellW = 96.0;
  static const _cellH = 38.0;
  static const _maxRows = 300;
  static const _maxCols = 40;

  XlsxEditor? _editor;
  int _sheetIndex = 0;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _editor = XlsxEditor.parse(bytes);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final editor = _editor;
    if (editor == null) return;
    try {
      final bytes = editor.save();
      await File(widget.path).writeAsBytes(bytes);
      _dirty = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kaydedildi. Kalıcı yer için ⋮ > Paylaş/Dışa aktar.')));
        setState(() {});
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    final dir = Directory.systemTemp;
    final f = File('${dir.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  static String _colLabel(int i) {
    var n = i;
    final sb = StringBuffer();
    do {
      sb.write(String.fromCharCode(65 + (n % 26)));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(sb.toString().codeUnits.reversed);
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Kaydet',
            icon: const Icon(Icons.save_outlined),
            onPressed: editor == null ? null : _save,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _export();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Paylaş / Dışa aktar')),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Açılamadı: $_error'))
          : editor == null
              ? const Center(child: CircularProgressIndicator())
              : _buildSheet(editor),
      bottomNavigationBar: editor == null || editor.sheets.length < 2
          ? null
          : _sheetTabs(editor),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            fileContext: widget.plainText,
            fileName: widget.name,
          ),
        )),
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('AI'),
      ),
    );
  }

  Widget _sheetTabs(XlsxEditor editor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < editor.sheets.length; i++)
            Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(
                label: Text(editor.sheets[i].name),
                selected: _sheetIndex == i,
                onSelected: (_) => setState(() => _sheetIndex = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet(XlsxEditor editor) {
    final sheet = editor.sheets[_sheetIndex];
    final rowCount = sheet.rows.length.clamp(0, _maxRows);
    final colCount = sheet.maxCols.clamp(1, _maxCols);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı (sütun harfleri)
            Row(
              children: [
                _headerCell('', width: 44),
                for (var c = 0; c < colCount; c++)
                  _headerCell(_colLabel(c)),
              ],
            ),
            for (var r = 0; r < rowCount; r++)
              Row(
                children: [
                  _headerCell('${r + 1}', width: 44),
                  for (var c = 0; c < colCount; c++)
                    _cell(editor, sheet.name, r, c, scheme),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {double width = _cellW}) {
    return Container(
      width: width,
      height: _cellH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _cell(
      XlsxEditor editor, String sheetName, int r, int c, ColorScheme scheme) {
    final row = editor.sheets[_sheetIndex].rows[r];
    final value = c < row.length ? row[c] : '';
    return Container(
      width: _cellW,
      height: _cellH,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: TextFormField(
        initialValue: value,
        onChanged: (v) {
          editor.setCell(sheetName, r, c, v);
          if (!_dirty) setState(() => _dirty = true);
        },
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
