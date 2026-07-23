import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/list_prefix.dart';
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

  /// Yedek editörde biçim araç çubuğunun üzerinde çalıştığı seçili paragraf.
  DocxParagraph? _sel;

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

  /// Canlı görünümdeki hizalama düğmesinden gelir; kaydetmede `w:jc` yazılır.
  void _onAlignChanged(int i, String align) {
    final paras = _editor?.paragraphs;
    if (paras == null || i < 0 || i >= paras.length) return;
    paras[i].align = align;
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
                      onAlign: _onAlignChanged,
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
            Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.white38),
            btn('justifyLeft', Icons.format_align_left, false, 'Sola yasla'),
            btn('justifyCenter', Icons.format_align_center, false, 'Ortala'),
            btn('justifyRight', Icons.format_align_right, false, 'Sağa yasla'),
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

  /// Yedek düz metin editörü: paragraf bazlı biçim (B/I/U, hizalama) +
  /// paragraf ekle/sil — canlı düzenlemede olmayan yapısal işlemler burada.
  Widget _buildPage(DocxEditor editor) {
    return Column(
      children: [
        _plainFormatBar(),
        Expanded(
          child: SingleChildScrollView(
            // Alt sistem çubuğu + FAB için nefes payı (edge-to-edge çakışmasın).
            padding: EdgeInsets.fromLTRB(
                12, 20, 12, MediaQuery.of(context).padding.bottom + 88),
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
  /// Seçili paragraf ([_sel]) üzerinde çalışır (yedek editör modu).
  Widget _plainFormatBar() {
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

    // Madde/numara listesi: gerçek numbering.xml riskli (bkz. HAFIZA) → düz
    // metin öneki (`• ` / `N. `). Numara, üstteki ardışık numaralı paragraflara
    // göre sıralanır.
    void applyList({required bool numbered}) {
      final p = _sel;
      final ed = _editor;
      if (p == null || ed == null) return;
      setState(() {
        if (numbered) {
          if (hasNumber(p.text)) {
            p.text = stripListPrefix(p.text);
          } else {
            final idx = ed.paragraphs.indexOf(p);
            var n = 1;
            for (var i = idx - 1; i >= 0; i--) {
              if (hasNumber(ed.paragraphs[i].text)) {
                n++;
              } else {
                break;
              }
            }
            p.text = toggleNumber(p.text, n);
          }
        } else {
          p.text = toggleBullet(p.text);
        }
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
            toggle(Icons.format_list_bulleted, 'Madde işareti',
                sel != null && hasBullet(sel.text),
                () => applyList(numbered: false)),
            toggle(Icons.format_list_numbered, 'Numaralı liste',
                sel != null && hasNumber(sel.text),
                () => applyList(numbered: true)),
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
              onPressed: enabled ? () => _deleteParagraph(sel) : null,
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
