import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/document.dart';
import '../../services/docx_editor.dart';
import '../../widgets/docx_view.dart';
import '../../widgets/office_shell.dart';
import '../chat_screen.dart';

/// Word ekranı: belge **gerçek sayfa düzeniyle** açılır (docx-preview) ve
/// kalem moduna geçince **sayfanın üzerinde** düzenlenir — popup/sekme yok.
/// Değişen paragraflar JS köprüsünden gelir, `w:t`/`w:r` düğümlerine yazılır;
/// B/I/U seçime uygulanır. Sayfa görünümü açılamazsa yedek metin editörü devreye girer.
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

  /// true → yedek düz metin editörü (sayfa görünümü açılamadı veya kullanıcı seçti).
  bool _plainMode = false;
  bool _editing = false;
  bool _selB = false, _selI = false, _selU = false;
  final _viewKey = GlobalKey<DocxViewState>();

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
      _dirty = false;
      // Canlı görünüm DOM'da zaten güncel — yeniden çizim yok, imleç kaybolmaz.
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

  void _toggleEdit() {
    final on = !_editing;
    _viewKey.currentState?.setEditing(on);
    setState(() => _editing = on);
  }

  /// Eşleme sigortası: WebView'daki paragraf sayısı bizimkiyle uyuşmuyorsa
  /// canlı düzenleme yanlış paragrafa yazabilir → kapat, yedek editöre yönlendir.
  void _onParagraphCount(int webCount) {
    final ours = _editor?.paragraphs.length ?? -1;
    if (webCount == ours) return;
    _viewKey.currentState?.setEditing(false);
    setState(() => _editing = false);
    _snack('Bu belgede canlı düzenleme güvenli değil '
        '(paragraf eşleşmedi: $webCount/$ours). ⋮ > Metin düzenleyici kullanın.');
  }

  void _onEdited(int i, List<(String, bool, bool, bool)> segs) {
    _editor?.setRuns(i, segs);
    if (!_dirty) setState(() => _dirty = true);
  }

  void _onSelection(bool b, bool i, bool u) {
    if (b == _selB && i == _selI && u == _selU) return;
    setState(() {
      _selB = b;
      _selI = i;
      _selU = u;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final bytes = _bytes;
    return OfficeShell(
      kind: DocKind.word,
      title: widget.name,
      dirty: _dirty,
      actions: [
        if (!_plainMode)
          IconButton(
            tooltip: _editing ? 'Düzenlemeyi bitir' : 'Sayfada düzenle',
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
            onPressed: editor == null ? null : _toggleEdit,
          ),
        IconButton(
          tooltip: 'Kaydet',
          icon: const Icon(Icons.save_outlined),
          onPressed: editor == null ? null : _save,
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'export':
                _export();
                break;
              case 'plain':
                setState(() {
                  _plainMode = true;
                  _editing = false;
                });
                break;
              case 'page':
                if (_dirty) await _save();
                setState(() => _plainMode = false);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'export', child: Text('Paylaş / Dışa aktar')),
            _plainMode
                ? const PopupMenuItem(
                    value: 'page', child: Text('Sayfa görünümü'))
                : const PopupMenuItem(
                    value: 'plain', child: Text('Metin düzenleyici')),
          ],
        ),
      ],
      tabBar: _editing ? _formatBar() : null,
      body: _error != null
          ? Center(child: Text('Açılamadı: $_error'))
          : editor == null || bytes == null
              ? const Center(child: CircularProgressIndicator())
              : _plainMode
                  ? _buildPage(editor)
                  : DocxView(
                      key: _viewKey,
                      bytes: bytes,
                      onEdited: _onEdited,
                      onSelection: _onSelection,
                      onParagraphCount: _onParagraphCount,
                      onStatus: (ok) {
                        if (!ok && mounted) {
                          setState(() {
                            _plainMode = true;
                            _editing = false;
                          });
                        }
                      },
                    ),
      // Klavye/biçim çubuğu varken FAB araya girmesin.
      fab: _editing
          ? null
          : FloatingActionButton.extended(
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

  /// M365 mobil tarzı biçim çubuğu: B / I / U + bitti.
  PreferredSizeWidget _formatBar() {
    Widget btn(String cmd, IconData icon, bool active, String tip) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          tooltip: tip,
          icon: Icon(icon, color: Colors.white),
          visualDensity: VisualDensity.compact,
          onPressed: () => _viewKey.currentState?.format(cmd),
        ),
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 8),
            btn('bold', Icons.format_bold, _selB, 'Kalın'),
            btn('italic', Icons.format_italic, _selI, 'İtalik'),
            btn('underline', Icons.format_underlined, _selU, 'Altı çizili'),
            const Spacer(),
            TextButton.icon(
              onPressed: _toggleEdit,
              icon: const Icon(Icons.keyboard_hide, color: Colors.white, size: 18),
              label: const Text('Bitti', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Yedek düz metin editörü (sayfa görünümü açılamadığında).
  Widget _buildPage(DocxEditor editor) {
    return Center(
      child: SingleChildScrollView(
        // Alt sistem çubuğu + FAB için nefes payı (edge-to-edge çakışmasın).
        padding: EdgeInsets.fromLTRB(
            12, 20, 12, MediaQuery.of(context).padding.bottom + 88),
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
