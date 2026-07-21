import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/docx_editor.dart';
import '../../widgets/docx_view.dart';
import '../chat_screen.dart';

/// İki sekme: **Görünüm** belgeyi Word'deki sayfa düzeniyle çizer (docx-preview),
/// **Düzenle** metni değiştirir. Kaydederken biçim korunur, sadece metin güncellenir.
class WordEditorScreen extends StatefulWidget {
  final String path;
  final String name;
  final String plainText;
  const WordEditorScreen({
    super.key,
    required this.path,
    required this.name,
    required this.plainText,
  });

  @override
  State<WordEditorScreen> createState() => _WordEditorScreenState();
}

class _WordEditorScreenState extends State<WordEditorScreen> {
  DocxEditor? _editor;
  Uint8List? _bytes;
  String? _error;
  bool _dirty = false;

  /// Kaydettikçe artar; sayfa görünümünün yeniden çizilmesini tetikler.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      _bytes = bytes;
      _editor = DocxEditor.parse(bytes);
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
      _bytes = bytes;
      _version++;
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
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final bytes = _bytes;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                PopupMenuItem(
                    value: 'export', child: Text('Paylaş / Dışa aktar')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.description_outlined), text: 'Görünüm'),
            Tab(icon: Icon(Icons.edit_outlined), text: 'Düzenle'),
          ]),
        ),
        body: _error != null
            ? Center(child: Text('Açılamadı: $_error'))
            : editor == null || bytes == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      DocxView(key: ValueKey(_version), bytes: bytes),
                      _buildPage(editor),
                    ],
                  ),
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
      ),
    );
  }

  Widget _buildPage(DocxEditor editor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(56, 64, 56, 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final para in editor.paragraphs) _paragraphField(para),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paragraphField(DocxParagraph para) {
    final theme = Theme.of(context);
    TextStyle style;
    if (para.heading) {
      final size = para.level == 0
          ? 26.0
          : para.level == 1
              ? 22.0
              : 18.0;
      style = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
        height: 1.3,
      );
    } else {
      style = const TextStyle(fontSize: 15, height: 1.5);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: para.heading ? 10 : 6),
      child: TextFormField(
        initialValue: para.text,
        onChanged: (v) {
          para.text = v;
          if (!_dirty) setState(() => _dirty = true);
        },
        style: style,
        maxLines: null,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
