import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/list_prefix.dart';
import '../../models/document.dart';
import '../../services/docx_editor.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/docx_view.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/translate_flow.dart';
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

  /// Mobil akış görünümü açık mı? (Sayfa görünümü varsayılan.)
  bool _flow = false;
  bool _selB = false, _selI = false, _selU = false;

  /// İmlecin bulunduğu paragrafın yazı tipi/puntosu (araç çubuğu gösterir).
  String _selFont = '';
  double _selSize = 0;

  /// Belgenin toplam sayfa sayısı ve görünen sayfa (canlı görünümden gelir).
  int _pageCount = 0;
  int _page = 1;

  final _viewKey = GlobalKey<DocxViewState>();

  /// Biçim çubuğunda sunulan yazı tipleri. Uygulamayla **gömülü**, metrik
  /// uyumlu karşılıkları olan aileler (bkz. `assets/word/viewer.html`):
  /// listede olmayan bir ad seçtirmek, cihazda bulunmayan bir fonta yazıp
  /// belgeyi Word'de bambaşka göstermek olurdu.
  static const _fonts = <String>[
    'Calibri',
    'Times New Roman',
    'Arial',
    'Cambria',
    'Helvetica',
  ];

  static const _sizes = <double>[
    8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36, 48,
  ];

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
    // Hata metni await'ten önce çevrilir (asenkron boşluktan sonra `context`
    // kullanılamaz).
    final saveFailed = context.t('word.save_failed');
    try {
      final bytes = editor.save();
      await File(widget.path).writeAsBytes(bytes);
      _bytes = bytes;
      _dirty = false;
      // Canlı görünüm DOM'da zaten güncel — yeniden çizim yok, imleç kaybolmaz.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('common.saved_hint'))));
        setState(() {});
      }
    } catch (e) {
      _snack(saveFailed.replaceAll('{error}', '$e'));
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

  /// Mobil akış ↔ sayfa görünümü. Kalıcı değil: belge her açılışta Word'deki
  /// gibi SAYFA görünümüyle gelir (2026-07-28 kullanıcı kararı).
  void _toggleFlow() {
    final on = !_flow;
    _viewKey.currentState?.setFlow(on);
    setState(() => _flow = on);
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
    _snack(context.t(
        'word.live_edit_unsafe', {'web': webCount, 'ours': ours}));
  }

  void _onEdited(int i, List<RunSeg> segs) {
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

  void _onSelection(bool b, bool i, bool u, String font, double size) {
    if (b == _selB &&
        i == _selI &&
        u == _selU &&
        font == _selFont &&
        size == _selSize) {
      return;
    }
    setState(() {
      _selB = b;
      _selI = i;
      _selU = u;
      _selFont = font;
      _selSize = size;
    });
  }

  /// "Sayfaya git" — canlı görünümdeki sayfa rozetine dokununca.
  Future<void> _showGoToPage() async {
    final total = _pageCount;
    if (total <= 0) return;
    final ctrl = TextEditingController(text: '$_page');
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('word.goto_page')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: ctx.t('word.goto_page_hint', {'total': total})),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(ctx.t('common.go')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) {
      _viewKey.currentState?.goToPage(value.clamp(1, total));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final bytes = _bytes;
    // Geri tuşu önce DÜZENLEMEYİ kapatır (slaytlarla aynı kural, 2026-08-01):
    // yazarken yanlışlıkla ekrandan çıkmak yazılanı görünmez kılıyordu.
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _toggleEdit();
      },
      child: _buildShell(editor, bytes),
    );
  }

  Widget _buildShell(DocxEditor? editor, Uint8List? bytes) {
    return OfficeShell(
      kind: DocKind.word,
      title: widget.name,
      dirty: _dirty,
      // Üst çubukta yalnız ALTTA KARŞILIĞI OLMAYANLAR kalır (2026-07-28
      // kullanıcı isteği: "bazı işlevler hem altta hem üstte var, gerek yok").
      // İstisna: düzenleme sırasında alt çubuk gizlendiği için Kaydet burada.
      actions: [
        if (_editing)
          IconButton(
            tooltip: context.t('common.save'),
            icon: const Icon(Icons.save_outlined),
            onPressed: editor == null ? null : _save,
          ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
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
            _plainMode
                ? PopupMenuItem(
                    value: 'page', child: Text(context.t('word.page_view')))
                : PopupMenuItem(
                    value: 'plain',
                    child: Text(context.t('word.text_editor'))),
          ],
        ),
      ],
      tabBar: _editing ? _formatBar() : null,
      // Etiketli eylem çubuğu (2026-07-28 kullanıcı isteği — PDF'teki gibi).
      // Düzenleme sırasında gizli: o sırada klavye + biçim çubuğu zaten
      // ekranın yarısını alıyor.
      bottomBar: _editing
          ? null
          : DocActionBar([
              if (!_plainMode)
                DocAction(Icons.edit_outlined, context.t('common.edit'),
                    editor == null ? null : _toggleEdit),
              if (!_plainMode)
                DocAction(
                  _flow ? Icons.description_outlined : Icons.smartphone,
                  context.t(
                      _flow ? 'word.page_layout' : 'word.mobile_flow'),
                  editor == null ? null : _toggleFlow,
                ),
              DocAction(Icons.save_outlined, context.t('common.save'),
                  editor == null ? null : _save),
              DocAction(Icons.share_outlined, context.t('common.share'),
                  editor == null ? null : _export),
              DocAction(
                Icons.translate,
                context.t('common.translate'),
                () => TranslateFlow.run(context, widget.plainText,
                    title: widget.name),
              ),
            ]),
      body: _error != null
          ? Center(
              child: Text(context.t('common.open_failed', {'error': _error})))
          : editor == null || bytes == null
              ? const Center(child: CircularProgressIndicator())
              : _plainMode
                  ? _buildPage(editor)
                  : Stack(
                      children: [
                        DocxView(
                          key: _viewKey,
                          bytes: bytes,
                          rightToLeft: editor.rightToLeft,
                          onEdited: _onEdited,
                          onSelection: _onSelection,
                          onAlign: _onAlignChanged,
                          onParagraphCount: _onParagraphCount,
                          onPageCount: (n) {
                            if (n != _pageCount) setState(() => _pageCount = n);
                          },
                          onPage: (n) {
                            if (n != _page) setState(() => _page = n);
                          },
                          onStatus: (ok) {
                            if (!ok && mounted) {
                              setState(() {
                                _plainMode = true;
                                _editing = false;
                              });
                            }
                          },
                        ),
                        // Sayfa rozeti (2026-08-01 isteği: toplam sayfa sayısı
                        // her belgede görünsün) — dokununca "sayfaya git".
                        // Düzenleme sırasında gizli: klavye+çubuk zaten yer
                        // kapıyor.
                        //
                        // Alt şeridin paylaşımı: SOL = zoom düğmeleri,
                        // ORTA = sayfa rozeti, SAĞ = AI düğmesi (FAB).
                        // Üçü de köşeye yığılırsa üst üste biniyor.
                        if (_pageCount > 0 && !_editing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Center(child: _pageBadge()),
                          ),
                      ],
                    ),
      // Klavye/biçim çubuğu varken FAB araya girmesin.
      fab: _editing
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  fileContext: widget.plainText,
                  fileName: widget.name,
                ),
              )),
              tooltip: context.t('common.ai'),
              child: const Icon(Icons.smart_toy_outlined),
            ),
    );
  }

  /// "Sayfa 3 / 12" rozeti — dokununca [_showGoToPage].
  Widget _pageBadge() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _showGoToPage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            context.t('word.page_of', {'n': _page, 'total': _pageCount}),
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// M365 mobil tarzı biçim çubuğu: yazı tipi/punto + B / I / U + bitti.
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

    Widget sep() => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white38);

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // Düğmeler sığmazsa YATAY kaydırılır; "Bitti" kaydırmanın DIŞINDA
            // kalır — dar ekranda düzenlemeden çıkış düğmesi kaybolmamalı.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    _fontMenu(),
                    _sizeMenu(),
                    sep(),
                    btn('bold', Icons.format_bold, _selB,
                        context.t('common.bold')),
                    btn('italic', Icons.format_italic, _selI,
                        context.t('common.italic')),
                    btn('underline', Icons.format_underlined, _selU,
                        context.t('common.underline')),
                    sep(),
                    btn('justifyLeft', Icons.format_align_left, false,
                        context.t('common.align_left')),
                    btn('justifyCenter', Icons.format_align_center, false,
                        context.t('common.align_center')),
                    btn('justifyRight', Icons.format_align_right, false,
                        context.t('common.align_right')),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _toggleEdit,
              icon: const Icon(Icons.keyboard_hide, color: Colors.white, size: 18),
              label: Text(context.t('word.done'),
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Yazı tipi seçici. Seçim **paragrafa** uygulanır (bkz. viewer.html:
  /// seçimi span'la sarmak `<p>` eşlemesini bozabiliyor).
  Widget _fontMenu() {
    final current = _fonts.contains(_selFont) ? _selFont : null;
    return PopupMenuButton<String>(
      tooltip: context.t('word.font_family'),
      onSelected: (v) => _viewKey.currentState?.setFontFamily(v),
      itemBuilder: (_) => [
        for (final f in _fonts)
          CheckedPopupMenuItem(
            value: f,
            checked: f == current,
            child: Text(f, style: TextStyle(fontFamily: f)),
          ),
      ],
      child: _barChip(
        // Bilinmeyen (listede olmayan) bir font geldiyse adı yine gösterilir:
        // "hangi fonttayım" bilgisi seçebilmekten bağımsız olarak değerli.
        _selFont.isEmpty ? context.t('word.font_family') : _selFont,
        icon: Icons.text_fields,
      ),
    );
  }

  Widget _sizeMenu() {
    final shown = _selSize > 0 ? _selSize : null;
    return PopupMenuButton<double>(
      tooltip: context.t('word.font_size'),
      onSelected: (v) => _viewKey.currentState?.setFontSize(v),
      itemBuilder: (_) => [
        for (final s in _sizes)
          CheckedPopupMenuItem(
            value: s,
            // Dosyadan gelen punto ara bir değer olabilir (11.5); eşitlik
            // yerine yakınlık aranır, yoksa hiçbiri işaretli görünmezdi.
            checked: shown != null && (shown - s).abs() < 0.25,
            child: Text('${s.round()}'),
          ),
      ],
      child: _barChip(
        shown == null ? '—' : '${shown.round()}',
        icon: Icons.format_size,
      ),
    );
  }

  Widget _barChip(String label, {required IconData icon}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(maxWidth: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      );

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
                        label: Text(context.t('word.add_paragraph')),
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
            toggle(Icons.format_bold, context.t('common.bold'),
                sel?.bold ?? false,
                () => toggleBool((p) => p.bold = !p.bold)),
            toggle(Icons.format_italic, context.t('common.italic'),
                sel?.italic ?? false,
                () => toggleBool((p) => p.italic = !p.italic)),
            toggle(Icons.format_underlined, context.t('common.underline'),
                sel?.underline ?? false,
                () => toggleBool((p) => p.underline = !p.underline)),
            _sep(scheme),
            toggle(Icons.format_align_left, context.t('common.align_left'),
                sel?.align == 'left', () => setAlign('left')),
            toggle(Icons.format_align_center, context.t('common.align_center'),
                sel?.align == 'center', () => setAlign('center')),
            toggle(Icons.format_align_right, context.t('common.align_right'),
                sel?.align == 'right', () => setAlign('right')),
            toggle(Icons.format_align_justify,
                context.t('common.align_justify'),
                sel?.align == 'both', () => setAlign('both')),
            _sep(scheme),
            toggle(Icons.format_list_bulleted, context.t('word.bullet_list'),
                sel != null && hasBullet(sel.text),
                () => applyList(numbered: false)),
            toggle(Icons.format_list_numbered, context.t('word.numbered_list'),
                sel != null && hasNumber(sel.text),
                () => applyList(numbered: true)),
            _sep(scheme),
            IconButton(
              tooltip: context.t('word.add_paragraph_below'),
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.playlist_add),
              onPressed: enabled ? () => _addParagraph(sel) : null,
            ),
            IconButton(
              tooltip: context.t('word.delete_paragraph'),
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

    // Paragrafın kendi yönü (`w:pPr/w:bidi`). Arapça/İbranice belgede metin
    // sağdan başlar; karışık (Arapça + Latin) satırlarda kelime sırası da
    // taban yöne göre çözülür — yön verilmezse aynı satır GÖRÜNÜR biçimde
    // yanlış sıralanır. Seçim şeridi ve iç boşluk da yönle birlikte döner
    // (`BorderDirectional`/`EdgeInsetsDirectional`).
    return Directionality(
      textDirection: para.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
      margin: EdgeInsets.only(bottom: para.heading ? 10 : 6),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: 6),
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
        textAlign: _textAlign(para),
        maxLines: null,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      ),
    );
  }

  /// Paragrafın ekrandaki hizalaması.
  ///
  /// Dosyada hizalama YAZMIYORSA (`hasExplicitAlign == false`) `TextAlign.start`
  /// kullanılır: soldan sağa paragrafta sol, sağdan solada sağ. Eskiden koşulsuz
  /// `TextAlign.left` dönüyordu — Arapça belgede her paragraf sola yapışıyordu.
  /// Dosyada AÇIKÇA yazan `left`/`right` ise mutlaktır (Word de aynalamaz).
  TextAlign _textAlign(DocxParagraph p) => switch (p.align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'both' => TextAlign.justify,
        _ => p.hasExplicitAlign ? TextAlign.left : TextAlign.start,
      };
}
