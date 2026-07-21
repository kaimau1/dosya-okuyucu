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

  /// Biçim araç çubuğunun üzerinde çalıştığı, o an seçili paragraf.
  DocxParagraph? _sel;

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
          title: Text('${widget.name}${_dirty ? ' •' : ''}',
              overflow: TextOverflow.ellipsis),
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
    return Column(
      children: [
        _formatBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Center(
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addParagraph(null),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Paragraf ekle'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Kalın/italik/altı çizili + hizalama + paragraf ekle/sil araç çubuğu.
  /// Seçili paragraf ([_sel]) üzerinde çalışır.
  Widget _formatBar() {
    final scheme = Theme.of(context).colorScheme;
    final sel = _sel;
    final enabled = sel != null;

    Widget toggle(IconData icon, String tip, bool active, VoidCallback onTap) =>
        IconButton(
          tooltip: tip,
          isSelected: active,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          style: active
              ? IconButton.styleFrom(backgroundColor: scheme.primaryContainer)
              : null,
          icon: Icon(icon),
          onPressed: enabled ? onTap : null,
        );

    void setAlign(String a) {
      final p = _sel;
      if (p == null) return;
      setState(() {
        p.align = a;
        _dirty = true;
      });
    }

    void toggleBool(void Function(DocxParagraph p) apply) {
      final p = _sel;
      if (p == null) return;
      setState(() {
        apply(p);
        _dirty = true;
      });
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            toggle(Icons.format_bold, 'Kalın', sel?.bold ?? false,
                () => toggleBool((p) => p.bold = !p.bold)),
            toggle(Icons.format_italic, 'İtalik', sel?.italic ?? false,
                () => toggleBool((p) => p.italic = !p.italic)),
            toggle(Icons.format_underlined, 'Altı çizili',
                sel?.underline ?? false,
                () => toggleBool((p) => p.underline = !p.underline)),
            _sep(scheme),
            toggle(Icons.format_align_left, 'Sola yasla',
                sel?.align == 'left', () => setAlign('left')),
            toggle(Icons.format_align_center, 'Ortala',
                sel?.align == 'center', () => setAlign('center')),
            toggle(Icons.format_align_right, 'Sağa yasla',
                sel?.align == 'right', () => setAlign('right')),
            toggle(Icons.format_align_justify, 'İki yana yasla',
                sel?.align == 'both', () => setAlign('both')),
            _sep(scheme),
            IconButton(
              tooltip: 'Altına paragraf ekle',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.playlist_add),
              onPressed: enabled ? () => _addParagraph(sel) : null,
            ),
            IconButton(
              tooltip: 'Paragrafı sil',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled ? () => _deleteParagraph(sel!) : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Araç çubuğu bölümleri arası dikey ayraç (sabit boyut → layout güvenli).
  Widget _sep(ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(width: 1, height: 22, color: scheme.outlineVariant),
      );

  void _addParagraph(DocxParagraph? after) {
    final editor = _editor;
    if (editor == null) return;
    final para = editor.addParagraphAfter(after);
    setState(() {
      _sel = para;
      _dirty = true;
    });
  }

  void _deleteParagraph(DocxParagraph para) {
    final editor = _editor;
    if (editor == null) return;
    editor.deleteParagraph(para);
    setState(() {
      if (identical(_sel, para)) _sel = null;
      _dirty = true;
    });
  }

  Widget _paragraphField(DocxParagraph para) {
    final theme = Theme.of(context);
    final selected = identical(_sel, para);
    double baseSize;
    FontWeight baseWeight;
    if (para.heading) {
      baseSize = para.level == 0
          ? 26.0
          : para.level == 1
              ? 22.0
              : 18.0;
      baseWeight = FontWeight.bold;
    } else {
      baseSize = 15;
      baseWeight = FontWeight.normal;
    }
    final style = TextStyle(
      fontSize: baseSize,
      fontWeight: para.bold ? FontWeight.bold : baseWeight,
      fontStyle: para.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          para.underline ? TextDecoration.underline : TextDecoration.none,
      color: theme.colorScheme.onSurface,
      height: para.heading ? 1.3 : 1.5,
    );

    return Container(
      margin: EdgeInsets.only(bottom: para.heading ? 10 : 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 6),
      child: TextFormField(
        key: ObjectKey(para),
        initialValue: para.text,
        onTap: () {
          if (!identical(_sel, para)) setState(() => _sel = para);
        },
        onChanged: (v) {
          para.text = v;
          if (!_dirty) setState(() => _dirty = true);
        },
        style: style,
        textAlign: _textAlign(para.align),
        maxLines: null,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  TextAlign _textAlign(String a) => switch (a) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'both' => TextAlign.justify,
        _ => TextAlign.left,
      };
}
