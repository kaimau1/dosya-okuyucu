/// Word Mobil görünüm editörünün **biçim arayüzü** (Faz 23).
///
/// M365 Word'ün telefondaki dili:
/// * **Giriş** sekmesi (klavye kapalı): Pano (Yapıştır · Kes · Kopyala ·
///   Biçim boyacısı) · Yazı tipi (ad, punto, A+ A−, K T A S, x² x₂, renk,
///   vurgu, temizle) · Paragraf (madde, numara, çok düzeyli, girinti,
///   hizalama ×4, satır aralığı, sağdan sola) · Stiller galerisi.
/// * **Görünüm** (Mobil görünüm ↔ Sayfa düzeni, yakınlaştır, gezinti) ve
///   **Gözden Geçir** (sözcük sayısı, çeviri).
/// * **Klavye üstü çubuk** (yazarken şerit gizli), bağlamsal (B9 m.7):
///   seçim yokken ↶ • 1. ⇤ ⇥ hizalama K T A; seçim varken ↶ K T A S renk
///   vurgu temizle; sağda Aa ⌄.
/// * **Aa paneli** klavyenin yerinde: Yazı · Paragraf · Stiller.
///
/// Her düğme seçimin durumunu yansıtır; karışık seçimde punto "—".
library;

import 'package:flutter/material.dart';

import '../../../core/app_icons.dart';
import '../../../core/doc_fonts.dart';
import '../../../core/edit/editor_chrome.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/app_colors.dart';
import '../../../core/theme.dart';
import '../../../services/docx/docx_document.dart';
import '../../../services/docx/docx_styles.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/docx_editor/docx_edit_controller.dart';
import '../../../widgets/office_ribbon.dart';

/// Office'in 10 standart rengi (renk menüsünün alt sırası).
const kWordStandardColors = <int>[
  0xFFC00000, 0xFFFF0000, 0xFFFFC000, 0xFFFFFF00, 0xFF92D050,
  0xFF00B050, 0xFF00B0F0, 0xFF0070C0, 0xFF002060, 0xFF7030A0,
];

/// Hücre gölgesi renkleri (açık tonlar).
const kWordShadeColors = <int>[
  0xFFD9D9D9, 0xFFFFF2CC, 0xFFE2EFDA, 0xFFDDEBF7, 0xFFFCE4D6, 0xFFEAD1F5,
  0xFFFFFF00, 0xFFBDD7EE,
];

/// Satır aralığı seçenekleri (Word'ün menüsü).
const kWordLineSpacings = <double>[1.0, 1.15, 1.5, 2.0];

/// Galeri öğesinin arayüz adı (yerleşik ad → çeviri anahtarı).
String wordStyleLabel(BuildContext context, DocxGalleryStyle g) {
  final key = switch (g.builtin) {
    'Normal' => 'word.st_normal',
    'Title' => 'word.st_title',
    'Subtitle' => 'word.st_subtitle',
    'heading 1' => 'word.st_h1',
    'heading 2' => 'word.st_h2',
    'heading 3' => 'word.st_h3',
    'Quote' => 'word.st_quote',
    'List Paragraph' => 'word.st_list',
    _ => null,
  };
  return key == null ? g.builtin : context.t(key);
}

String _num(double v) => v == v.roundToDouble()
    ? '${v.round()}'
    : v.toStringAsFixed(v * 10 == (v * 10).roundToDouble() ? 1 : 2);

/// Faz 37 Araçlar sekmesinin düğmeleri (kimlik, simge), gruplu.
const kWordProTools = <List<(String, IconData)>>[
  [
    ('page_setup', AppIcons.cropFree),
    ('print_preview', AppIcons.print),
    ('reader', AppIcons.chromeReaderMode),
  ],
  [
    ('equation', AppIcons.functions),
    ('textbox', AppIcons.textFields),
    ('shape', AppIcons.rectTool),
    ('cover', AppIcons.title),
    ('toc', AppIcons.accountTree),
    ('section_break', AppIcons.wrapText),
    ('field', AppIcons.dataObject),
    ('cross_ref', AppIcons.link),
    ('bibliography', AppIcons.menuBook),
    ('para_border', AppIcons.borderOuter),
  ],
  [
    ('outline', AppIcons.accountTree),
    ('thumbnails', AppIcons.thumbnails),
  ],
  [
    ('review_bar', AppIcons.rule),
    ('compare', AppIcons.compare),
    ('combine', AppIcons.mergeType),
    ('password', AppIcons.password),
  ],
  [
    ('dictate', AppIcons.micNone),
    ('ai_inline', AppIcons.ai),
    ('ai_proof', AppIcons.spellcheck),
  ],
];

class WordFormatUi {
  final BuildContext context;
  final DocxEditController c;

  /// Görünüm sekmesi ve Gözden Geçir eylemleri (ekran verir).
  final VoidCallback onPageLayout;
  final VoidCallback onNavigate;
  final VoidCallback onWordCount;
  final VoidCallback? onZoomIn, onZoomOut;
  final void Function(String text) onTranslate;

  /// Faz 24: Ekle ve Bul-Değiştir (ekran açar; sekme yoksa gizli).
  final VoidCallback? onInsertTable, onInsertLink, onSymbol, onFind;

  /// Faz 24b: üst/alt bilgi ve izlenen değişiklikleri çözme (ekran onaylar).
  final VoidCallback? onHeaderFooter;
  final void Function(bool accept)? onResolveTracked;

  /// B9 m.3: Değişiklikleri izle aç/kapa (ekran yazar adını sorar).
  final VoidCallback? onTrackChanges;

  /// Faz 24 kalanı: resim, yorum, dipnot, tarih (ekran açar).
  final VoidCallback? onInsertImage,
      onReplaceImage,
      onImageAlt,
      onComments,
      onNewComment,
      onFootnote,
      onEndnote,
      onDate;

  /// Faz 37: Araçlar sekmesi ([kWordProTools] kimliğiyle ekran açar; null →
  /// sekme gizli, bayrak `word_pro_v1` kapalı).
  final void Function(String id)? onPro;

  const WordFormatUi({
    this.onPro,
    this.onInsertImage,
    this.onReplaceImage,
    this.onImageAlt,
    this.onComments,
    this.onNewComment,
    this.onFootnote,
    this.onEndnote,
    this.onDate,
    this.onInsertTable,
    this.onInsertLink,
    this.onSymbol,
    this.onFind,
    this.onHeaderFooter,
    this.onResolveTracked,
    this.onTrackChanges,
    required this.context,
    required this.c,
    required this.onPageLayout,
    required this.onNavigate,
    required this.onWordCount,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onTranslate,
  });

  String _t(String k) => context.t(k);

  IconData get alignIcon => switch (c.paraLook.align) {
        'center' => OfficeIcons.alignCenter,
        'right' => OfficeIcons.alignRight,
        'both' => OfficeIcons.alignJustify,
        _ => OfficeIcons.alignLeft,
      };

  int get lastColor =>
      c.recentColors.isEmpty ? kWordStandardColors.first : c.recentColors.first;

  // ── klavye üstü çubuk ────────────────────────────────────────────────────

  /// B9 m.7: bağlamsal — seçim varken harf biçimi (K T A S, renk, vurgu,
  /// temizle), yokken paragraf (madde, numara, girinti, hizalama) + K T A
  /// (sıradaki yazının biçimi). Geri al her iki kipte başta.
  List<AccessoryItem> accessory() => c.collapsed
      ? [_undoItem(), ..._paraItems(), ..._charItems()]
      : [_undoItem(), ..._charItems(), ..._selectionItems()];

  AccessoryItem _undoItem() => AccessoryItem(
      key: const ValueKey('word-acc-undo'),
      icon: OfficeIcons.undo,
      tooltip: _t('word.undo'),
      onPressed: c.canUndo ? c.undo : null);

  List<AccessoryItem> _charItems() => [
        AccessoryItem(
            key: const ValueKey('word-acc-bold'),
            icon: OfficeIcons.bold,
            tooltip: _t('common.bold'),
            selected: c.isBold,
            onPressed: c.toggleBold),
        AccessoryItem(
            key: const ValueKey('word-acc-italic'),
            icon: OfficeIcons.italic,
            tooltip: _t('common.italic'),
            selected: c.isItalic,
            onPressed: c.toggleItalic),
        AccessoryItem(
            key: const ValueKey('word-acc-underline'),
            icon: OfficeIcons.underline,
            tooltip: _t('common.underline'),
            selected: c.isUnderline,
            onPressed: c.toggleUnderline),
      ];

  List<AccessoryItem> _selectionItems() => [
        AccessoryItem(
            key: const ValueKey('word-acc-strike'),
            icon: OfficeIcons.strike,
            tooltip: _t('common.strike'),
            selected: c.isStrike,
            onPressed: c.toggleStrike),
        AccessoryItem(
            key: const ValueKey('word-acc-color'),
            icon: OfficeIcons.textColor,
            tooltip: _t('word.text_color'),
            onPressed: () => c.setColor(lastColor)),
        AccessoryItem(
            key: const ValueKey('word-acc-highlight'),
            icon: OfficeIcons.highlight,
            tooltip: _t('word.highlight'),
            onPressed: () => c.setHighlight('yellow')),
        AccessoryItem(
            key: const ValueKey('word-acc-clear'),
            icon: OfficeIcons.clearFormat,
            tooltip: _t('word.clear_format'),
            onPressed: c.clearFormatting),
      ];

  List<AccessoryItem> _paraItems() => [
        AccessoryItem(
            key: const ValueKey('word-acc-bullets'),
            icon: OfficeIcons.bullets,
            tooltip: _t('word.bullets'),
            selected: c.listKind == 'bullet',
            onPressed: () => c.toggleList('bullet')),
        AccessoryItem(
            key: const ValueKey('word-acc-numbering'),
            icon: OfficeIcons.numbering,
            tooltip: _t('word.numbering'),
            selected: c.listKind == 'number',
            onPressed: () => c.toggleList('number')),
        AccessoryItem(
            icon: OfficeIcons.indentLess,
            tooltip: _t('sl.indent_less'),
            onPressed: () => c.indent(-1)),
        AccessoryItem(
            icon: OfficeIcons.indentMore,
            tooltip: _t('sl.indent_more'),
            onPressed: () => c.indent(1)),
        AccessoryItem(
            key: const ValueKey('word-acc-align'),
            icon: alignIcon,
            tooltip: _t('word.align_cycle'),
            onPressed: c.cycleAlign),
      ];

  // ── şerit ────────────────────────────────────────────────────────────────

  List<RibbonTab> ribbonTabs() {
    RibbonChip chip(String key, IconData icon, String labelKey,
            {String? tipKey, bool? active, VoidCallback? onTap}) =>
        RibbonChip(
          key: ValueKey(key),
          icon: icon,
          label: _t(labelKey),
          tooltip: _t(tipKey ?? labelKey),
          active: active,
          onTap: onTap,
        );
    return [
      RibbonTab(_t('word.tab_home'), home()),
      if (onInsertTable != null)
        RibbonTab(_t('word.tab_insert'), [
          chip('word-ins-table', AppIcons.tableView, 'word.insert_table',
              onTap: onInsertTable),
          if (onInsertImage != null)
            chip('word-ins-image', AppIcons.addPhoto, 'word.insert_image',
                onTap: onInsertImage),
          chip('word-ins-link', AppIcons.link, 'word.insert_link',
              onTap: onInsertLink),
          chip('word-ins-break', AppIcons.wrapText, 'word.insert_break',
              onTap: c.insertPageBreak),
          chip('word-ins-symbol', AppIcons.textFields, 'word.insert_symbol',
              onTap: onSymbol),
          if (onHeaderFooter != null)
            chip('word-ins-hf', AppIcons.newWord, 'word.insert_hf',
                onTap: onHeaderFooter),
          if (onInsertImage != null) ...[
            const RibbonSep(),
            chip('word-ins-footnote', AppIcons.footnote, 'word.insert_footnote',
                onTap: onFootnote),
            if (onEndnote != null)
              chip('word-ins-endnote', AppIcons.footnote, 'word.insert_endnote',
                  onTap: onEndnote),
            chip('word-ins-rule', AppIcons.horizontalRule, 'word.insert_rule',
                onTap: c.insertHorizontalRule),
            chip('word-ins-date', AppIcons.calendarMonth, 'word.insert_date',
                onTap: onDate),
          ],
        ]),
      if (c.selectedImage != null) RibbonTab(_t('word.tab_picture'), picture()),
      if (c.inTable) RibbonTab(_t('word.tab_table'), table()),
      if (onInsertTable != null) RibbonTab(_t('word.tab_layout'), layout()),
      RibbonTab(_t('word.tab_view'), [
        RibbonChip(
          icon: AppIcons.newWord,
          label: _t('word.page_layout'),
          tooltip: _t('word.page_layout'),
          onTap: onPageLayout,
        ),
        const RibbonSep(),
        RibbonButton(OfficeIcons.zoomOut, _t('word.zoom_out'), onTap: onZoomOut),
        RibbonButton(OfficeIcons.zoomIn, _t('word.zoom_in'), onTap: onZoomIn),
        const RibbonSep(),
        chip('word-nav', OfficeIcons.navigation, 'word.navigation',
            onTap: onNavigate),
      ]),
      RibbonTab(_t('word.tab_review'), [
        // 2026-11-22 (kullanıcı): gözden geçirirken belge gerçek sayfa
        // düzeninde görülsün — ilk yonga sayfa görünümüne geçer.
        RibbonChip(
          key: const ValueKey('word-rev-page'),
          icon: AppIcons.newWord,
          label: _t('word.review_page'),
          tooltip: _t('word.page_layout'),
          onTap: onPageLayout,
        ),
        const RibbonSep(),
        if (onFind != null)
          chip('word-find', OfficeIcons.search, 'word.search_short',
              tipKey: 'word.find', onTap: onFind),
        chip('word-count', OfficeIcons.wordCount, 'word.word_count',
            onTap: onWordCount),
        RibbonChip(
          icon: OfficeIcons.translate,
          label: _t('common.translate'),
          tooltip: _t('common.translate'),
          onTap: () => onTranslate(c.selectedText()),
        ),
        if (onComments != null) ...[
          const RibbonSep(),
          chip('word-rev-new-comment', AppIcons.addComment, 'word.comment_new',
              onTap: onNewComment),
          chip('word-rev-comments', AppIcons.comment, 'word.comments',
              onTap: onComments),
        ],
        if (onTrackChanges != null) ...[
          const RibbonSep(),
          chip('word-track-toggle', AppIcons.editNote, 'word.track_changes',
              active: c.trackChanges, onTap: onTrackChanges),
        ],
        if (onResolveTracked != null && c.trackedChanges > 0) ...[
          const RibbonSep(),
          chip('word-track-accept', AppIcons.check, 'word.track_accept',
              onTap: () => onResolveTracked!(true)),
          chip('word-track-reject', AppIcons.close, 'word.track_reject',
              onTap: () => onResolveTracked!(false)),
        ],
      ]),
      // Faz 37: en sonda — eski sekmelerin yeri değişmesin.
      if (onPro != null) RibbonTab(_t('wp.tab'), proTab()),
    ];
  }

  /// Faz 37 Araçlar sekmesi: her araç kısa adıyla görünür, gruplar ayrılır.
  List<Widget> proTab() => [
        for (final group in kWordProTools) ...[
          for (final (id, icon) in group)
            RibbonChip(
              key: ValueKey('word-pro-$id'),
              icon: icon,
              label: _t('wp.$id'),
              tooltip: _t('wp.$id'),
              onTap: () => onPro!(id),
            ),
          if (!identical(group, kWordProTools.last)) const RibbonSep(),
        ],
      ];

  /// Bağlamsal Resim sekmesi (bir resim seçiliyken): boyut, hiza, alternatif
  /// metin, değiştir, sil.
  List<Widget> picture() {
    final a = c.selectedImage;
    final align = c.paraLook.align;
    return [
      PopupMenuButton<double>(
        key: const ValueKey('word-img-size'),
        tooltip: _t('word.img_size'),
        onSelected: c.resizeImage,
        itemBuilder: (ctx) => [
          for (final (k, pt) in const [
            ('word.img_small', 144.0),
            ('word.img_medium', 288.0),
            ('word.img_large', 432.0),
          ])
            CheckedPopupMenuItem(
                value: pt,
                checked: a != null && (a.widthPt - pt).abs() < 1,
                child: Text(ctx.t(k))),
        ],
        child: RibbonChip(
          icon: AppIcons.resize,
          label: _t('word.img_size'),
          tooltip: _t('word.img_size'),
        ),
      ),
      RibbonButton(OfficeIcons.alignLeft, _t('common.align_left'),
          key: const ValueKey('word-img-left'),
          active: align == 'left',
          onTap: () => c.alignImage('left')),
      RibbonButton(OfficeIcons.alignCenter, _t('common.align_center'),
          key: const ValueKey('word-img-center'),
          active: align == 'center',
          onTap: () => c.alignImage('center')),
      RibbonButton(OfficeIcons.alignRight, _t('common.align_right'),
          key: const ValueKey('word-img-right'),
          active: align == 'right',
          onTap: () => c.alignImage('right')),
      const RibbonSep(),
      if (onPro != null)
        RibbonChip(
          key: const ValueKey('word-pro-img_wrap'),
          icon: AppIcons.wrapText,
          label: _t('wp.img_wrap'),
          tooltip: _t('wp.img_wrap'),
          onTap: () => onPro!('img_wrap'),
        ),
      RibbonChip(
        key: const ValueKey('word-img-alt'),
        icon: AppIcons.altText,
        label: _t('word.img_alt'),
        tooltip: _t('word.img_alt'),
        onTap: onImageAlt,
      ),
      RibbonChip(
        key: const ValueKey('word-img-replace'),
        icon: AppIcons.image,
        label: _t('word.img_replace'),
        tooltip: _t('word.img_replace'),
        onTap: onReplaceImage,
      ),
      RibbonChip(
        key: const ValueKey('word-img-delete'),
        icon: AppIcons.delete,
        label: _t('common.delete'),
        tooltip: _t('common.delete'),
        onTap: () => c.deleteSelection(),
      ),
    ];
  }

  /// Bağlamsal Tablo sekmesi (imleç bir hücredeyken).
  List<Widget> table() => [
        RibbonChip(
          key: const ValueKey('word-tbl-row-above'),
          icon: AppIcons.keyboardArrowUp,
          label: _t('word.tbl_row_up_short'),
          tooltip: _t('word.tbl_row_above'),
          onTap: () => c.tableRow(below: false),
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-row-below'),
          icon: AppIcons.keyboardArrowDown,
          label: _t('word.tbl_row_down_short'),
          tooltip: _t('word.tbl_row_below'),
          onTap: () => c.tableRow(below: true),
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-col-left'),
          icon: AppIcons.keyboardArrowLeft,
          label: _t('word.tbl_col_left_short'),
          tooltip: _t('word.tbl_col_left'),
          onTap: () => c.tableColumn(right: false),
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-col-right'),
          icon: AppIcons.keyboardArrowRight,
          label: _t('word.tbl_col_right_short'),
          tooltip: _t('word.tbl_col_right'),
          onTap: () => c.tableColumn(right: true),
        ),
        const RibbonSep(),
        RibbonChip(
          key: const ValueKey('word-tbl-del-row'),
          icon: AppIcons.deleteSweep,
          label: _t('word.tbl_del_row_short'),
          tooltip: _t('word.tbl_del_row'),
          onTap: c.deleteTableRow,
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-del-col'),
          icon: AppIcons.delete,
          label: _t('word.tbl_del_col_short'),
          tooltip: _t('word.tbl_del_col'),
          onTap: c.deleteTableColumn,
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-del'),
          icon: AppIcons.deleteForever,
          label: _t('word.tbl_del_short'),
          tooltip: _t('word.tbl_del'),
          onTap: c.deleteWholeTable,
        ),
        const RibbonSep(),
        RibbonChip(
          key: const ValueKey('word-tbl-header'),
          icon: AppIcons.tableView,
          label: _t('word.tbl_header_short'),
          tooltip: _t('word.tbl_header'),
          active: c.tableHeader,
          onTap: () => c.setTableHeader(!c.tableHeader),
        ),
        RibbonChip(
          key: const ValueKey('word-tbl-banded'),
          icon: AppIcons.viewColumn,
          label: _t('word.tbl_banded_short'),
          tooltip: _t('word.tbl_banded'),
          active: c.tableBanded,
          onTap: () => c.setTableBanded(!c.tableBanded),
        ),
        if (onPro != null) ...[
          const RibbonSep(),
          for (final (id, icon) in const [
            ('tbl_merge', AppIcons.join),
            ('tbl_split', AppIcons.split),
            ('tbl_borders', AppIcons.borderAll),
            ('tbl_autofit', AppIcons.fitScreen),
            ('tbl_sort', AppIcons.sort),
          ])
            RibbonChip(
              key: ValueKey('word-pro-$id'),
              icon: icon,
              label: _t('wp.$id'),
              tooltip: _t('wp.$id'),
              onTap: () => onPro!(id),
            ),
        ],
        RibbonMenu<int>(
          key: const ValueKey('word-tbl-shade'),
          icon: AppIcons.formatColorFill,
          tooltip: _t('word.tbl_shade'),
          onSelected: (v) => c.setCellShade(v < 0 ? null : v),
          itemBuilder: (_) => [
            PopupMenuItem(value: -1, child: Text(_t('word.tbl_shade_none'))),
            for (final col in kWordShadeColors)
              PopupMenuItem(
                value: col & 0xFFFFFF,
                child: Row(children: [
                  Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: Color(col),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant))),
                ]),
              ),
          ],
        ),
      ];

  /// Düzen sekmesi: kenar boşlukları, yönlendirme, boyut, sütunlar.
  List<Widget> layout() {
    final ps = c.pageSetup;
    final paperLabel = ps.paper == 'a4' || ps.paper == 'a5'
        ? ps.paper.toUpperCase()
        : ps.paper[0].toUpperCase() + ps.paper.substring(1);
    return [
      PopupMenuButton<String>(
        key: const ValueKey('word-lay-margins'),
        tooltip: _t('word.margins'),
        onSelected: c.setMargins,
        itemBuilder: (_) => [
          for (final k in const ['normal', 'narrow', 'moderate', 'wide'])
            CheckedPopupMenuItem(
                value: k,
                checked: ps.marginPreset == k,
                child: Text(_t('word.margin_$k'))),
        ],
        child: RibbonChip(
          icon: AppIcons.cropFree,
          label: _t('word.margin_${ps.marginPreset}'),
          tooltip: _t('word.margins'),
        ),
      ),
      PopupMenuButton<bool>(
        key: const ValueKey('word-lay-orient'),
        tooltip: _t('word.orientation'),
        onSelected: c.setLandscape,
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
              value: false,
              checked: !ps.landscape,
              child: Text(_t('word.portrait'))),
          CheckedPopupMenuItem(
              value: true,
              checked: ps.landscape,
              child: Text(_t('word.landscape'))),
        ],
        child: RibbonChip(
          icon: AppIcons.device,
          label: _t(ps.landscape ? 'word.landscape' : 'word.portrait'),
          tooltip: _t('word.orientation'),
        ),
      ),
      PopupMenuButton<String>(
        key: const ValueKey('word-lay-size'),
        tooltip: _t('word.paper_size'),
        onSelected: c.setPaper,
        itemBuilder: (_) => [
          for (final k in kDocxPaperSizes.keys)
            CheckedPopupMenuItem(
                value: k,
                checked: ps.paper == k,
                child: Text(k == 'a4' || k == 'a5'
                    ? k.toUpperCase()
                    : k[0].toUpperCase() + k.substring(1))),
        ],
        child: RibbonChip(
          icon: AppIcons.newWord,
          label: paperLabel,
          tooltip: _t('word.paper_size'),
        ),
      ),
      PopupMenuButton<int>(
        key: const ValueKey('word-lay-cols'),
        tooltip: _t('word.columns'),
        onSelected: c.setColumns,
        itemBuilder: (ctx) => [
          for (final n in const [1, 2, 3])
            CheckedPopupMenuItem(
                value: n,
                checked: ps.columns == n,
                child: Text(ctx.t('word.columns_n', {'n': n}))),
        ],
        child: RibbonChip(
          icon: AppIcons.viewColumn,
          label: context.t('word.columns_n', {'n': ps.columns}),
          tooltip: _t('word.columns'),
        ),
      ),
    ];
  }

  /// Giriş sekmesi.
  List<Widget> home() => [
        // Pano
        RibbonButton(OfficeIcons.paste, _t('word.paste'), onTap: c.paste),
        RibbonButton(OfficeIcons.cut, _t('word.cut'),
            onTap: c.collapsed ? null : () => c.cut()),
        RibbonButton(OfficeIcons.copy, _t('common.copy'),
            onTap: c.collapsed ? null : () => c.copy()),
        PainterButton(c: c),
        const RibbonSep(),
        // Yazı tipi
        fontMenu(),
        sizeMenu(),
        RibbonButton(OfficeIcons.fontGrow, _t('word.font_grow'),
            onTap: () => c.growFont(1, kDocFontSizes)),
        RibbonButton(OfficeIcons.fontShrink, _t('word.font_shrink'),
            onTap: () => c.growFont(-1, kDocFontSizes)),
        ..._charButtons(),
        colorMenu(),
        highlightMenu(),
        RibbonButton(OfficeIcons.clearFormat, _t('word.clear_format'),
            onTap: c.clearFormatting),
        const RibbonSep(),
        // Paragraf
        ..._listButtons(),
        RibbonButton(OfficeIcons.indentLess, _t('sl.indent_less'),
            onTap: () => c.indent(-1)),
        RibbonButton(OfficeIcons.indentMore, _t('sl.indent_more'),
            onTap: () => c.indent(1)),
        ..._alignButtons(),
        lineSpacingMenu(),
        RibbonButton(OfficeIcons.rtl, _t('word.rtl'),
            active: c.paraLook.bidi, onTap: c.toggleRtl),
        const RibbonSep(),
        // Stiller galerisi
        for (final g in c.doc.styles.gallery()) styleChip(g),
        if (onPro != null) ...[
          RibbonButton(AppIcons.style, _t('wp.style_update'),
              key: const ValueKey('word-style-update'),
              onTap: () => onPro!('style_update')),
          RibbonButton(AppIcons.palette, _t('wp.theme'),
              key: const ValueKey('word-style-theme'),
              onTap: () => onPro!('theme')),
        ],
      ];

  List<Widget> _charButtons() => [
        RibbonButton(OfficeIcons.bold, _t('common.bold'),
            key: const ValueKey('word-rb-bold'),
            active: c.isBold,
            onTap: c.toggleBold),
        RibbonButton(OfficeIcons.italic, _t('common.italic'),
            active: c.isItalic, onTap: c.toggleItalic),
        RibbonButton(OfficeIcons.underline, _t('common.underline'),
            active: c.isUnderline, onTap: c.toggleUnderline),
        RibbonButton(OfficeIcons.strike, _t('common.strike'),
            active: c.isStrike, onTap: c.toggleStrike),
        RibbonButton(OfficeIcons.superscript, _t('word.superscript'),
            active: c.isSuperscript, onTap: c.toggleSuperscript),
        RibbonButton(OfficeIcons.subscript, _t('word.subscript'),
            active: c.isSubscript, onTap: c.toggleSubscript),
      ];

  List<Widget> _listButtons() => [
        RibbonButton(OfficeIcons.bullets, _t('word.bullets'),
            active: c.listKind == 'bullet',
            onTap: () => c.toggleList('bullet')),
        RibbonButton(OfficeIcons.numbering, _t('word.numbering'),
            active: c.listKind == 'number',
            onTap: () => c.toggleList('number')),
        RibbonButton(OfficeIcons.multilevel, _t('word.multilevel'),
            active: c.listKind == 'multi', onTap: () => c.toggleList('multi')),
      ];

  List<Widget> _alignButtons() => [
        for (final (v, icon, tip) in const [
          ('left', OfficeIcons.alignLeft, 'common.align_left'),
          ('center', OfficeIcons.alignCenter, 'common.align_center'),
          ('right', OfficeIcons.alignRight, 'common.align_right'),
          ('both', OfficeIcons.alignJustify, 'common.align_justify'),
        ])
          RibbonButton(icon, _t(tip),
              active: c.paraLook.align == v, onTap: () => c.setAlign(v)),
      ];

  Widget fontMenu() {
    final cur = c.fontName;
    return PopupMenuButton<String>(
      tooltip: _t('word.font_family'),
      onSelected: c.setFont,
      itemBuilder: (_) => [
        for (final f in kDocFonts)
          CheckedPopupMenuItem(
            value: f.name,
            checked: f.name == cur,
            child: Text(f.name, style: TextStyle(fontFamily: f.render)),
          ),
      ],
      child: RibbonChip(
        key: const ValueKey('word-font'),
        icon: OfficeIcons.fontFamily,
        label: cur ?? '—',
        tooltip: _t('word.font_family'),
      ),
    );
  }

  Widget sizeMenu() {
    final cur = c.fontSize;
    return PopupMenuButton<double>(
      tooltip: _t('word.font_size'),
      onSelected: c.setFontSize,
      itemBuilder: (_) => [
        for (final v in kDocFontSizes)
          CheckedPopupMenuItem(
              value: v, checked: v == cur, child: Text(_num(v))),
      ],
      child: RibbonChip(
        key: const ValueKey('word-size'),
        icon: OfficeIcons.fontSize,
        label: cur == null ? '—' : _num(cur),
        tooltip: _t('word.font_size'),
      ),
    );
  }

  Widget colorMenu() {
    final scheme = Theme.of(context).colorScheme;
    final bar = c.recentColors.isEmpty
        ? scheme.onSurface
        : Color(c.recentColors.first | 0xFF000000);
    return RibbonButton(
      OfficeIcons.textColor,
      _t('word.text_color'),
      key: const ValueKey('word-color'),
      indicator: bar,
      onTap: _showColorSheet,
    );
  }

  Widget highlightMenu() => RibbonButton(
        OfficeIcons.highlight,
        _t('word.highlight'),
        key: const ValueKey('word-highlight'),
        indicator: Color(DocxStyles.highlightArgb('yellow')!),
        onTap: _showHighlightSheet,
      );

  Future<void> _showColorSheet() => showAppSheet<void>(
        context,
        title: _t('word.color_pick'),
        builder: (ctx) {
          void pick(int argb) {
            Navigator.of(ctx).pop();
            c.setColor(argb);
          }

          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.lg, 0, Gap.lg, Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.recentColors.isNotEmpty) ...[
                  _label(_t('word.recent_colors')),
                  _swatches(c.recentColors, pick),
                ],
                _label(_t('word.theme_colors')),
                _swatches(c.doc.styles.themeColors, pick),
                _label(_t('word.standard_colors')),
                _swatches(kWordStandardColors, pick),
                const SizedBox(height: Gap.md),
                TextButton.icon(
                  icon: const Icon(AppIcons.formatColorReset),
                  label: Text(_t('word.auto_color')),
                  onPressed: () => pick(DocxRunPatch.autoColor),
                ),
              ],
            ),
          );
        },
      );

  Future<void> _showHighlightSheet() => showAppSheet<void>(
        context,
        title: _t('word.highlight_pick'),
        builder: (ctx) {
          void pick(String name) {
            Navigator.of(ctx).pop();
            c.setHighlight(name);
          }

          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.lg, Gap.sm, Gap.lg, Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.md,
                  children: [
                    for (final name in DocxStyles.highlightNames)
                      Semantics(
                        button: true,
                        label: name,
                        child: InkWell(
                          key: ValueKey('word-hl-$name'),
                          customBorder: const CircleBorder(),
                          onTap: () => pick(name),
                          child: _dot(DocxStyles.highlightArgb(name)!,
                              size: 40),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                TextButton.icon(
                  icon: const Icon(AppIcons.formatColorReset),
                  label: Text(_t('word.no_highlight')),
                  onPressed: () => pick(''),
                ),
              ],
            ),
          );
        },
      );

  Widget lineSpacingMenu() {
    final cur = c.paraLook.lineMultiple ?? 1.0;
    final look = c.paraLook;
    return RibbonMenu<String>(
      icon: OfficeIcons.lineSpacing,
      tooltip: _t('word.line_spacing'),
      onSelected: (v) => switch (v) {
        'before' => c.toggleSpaceBefore(),
        'after' => c.toggleSpaceAfter(),
        _ => c.setLineSpacing(double.parse(v)),
      },
      itemBuilder: (_) => [
        for (final v in kWordLineSpacings)
          CheckedPopupMenuItem(
              value: '$v',
              checked: (cur - v).abs() < 0.01,
              child: Text(_num(v))),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
            value: 'before',
            checked: look.spaceBeforePt > 0,
            child: Text(_t('word.space_before'))),
        CheckedPopupMenuItem(
            value: 'after',
            checked: look.spaceAfterPt > 0,
            child: Text(_t('word.space_after'))),
      ],
    );
  }

  /// Galeri çipi: stil adı kendi biçimiyle (belge kâğıdı zemininde).
  Widget styleChip(DocxGalleryStyle g) {
    final scheme = Theme.of(context).colorScheme;
    final on = c.styleId == g.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: AppColors.page,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: on ? scheme.primary : scheme.outlineVariant,
              width: on ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('word-style-${g.builtin}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => c.applyStyle(g.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                wordStyleLabel(context, g),
                maxLines: 1,
                style: previewStyle(g, maxSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle previewStyle(DocxGalleryStyle g, {double maxSize = 20}) {
    final l = c.doc.styles.styleLook(g.id);
    return TextStyle(
      fontFamily: l.renderFamily,
      fontSize: (l.sizePt * 1.1).clamp(11, maxSize),
      fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: l.italic ? FontStyle.italic : FontStyle.normal,
      color: l.color == null ? AppColors.pageInk : Color(l.color!),
      height: 1.1,
    );
  }

  static Widget _dot(int argb, {double size = 20}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.pageInk.withValues(alpha: 0.25)),
        ),
      );

  // ── Aa paneli ────────────────────────────────────────────────────────────

  List<FormatPanelTab> panelTabs() => [
        FormatPanelTab(label: _t('edit.tab_text'), builder: _textPanel),
        FormatPanelTab(label: _t('edit.tab_paragraph'), builder: _paraPanel),
        FormatPanelTab(label: _t('edit.tab_styles'), builder: _stylesPanel),
      ];

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );

  Widget _swatches(Iterable<int> colors, void Function(int) onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final argb in colors)
            Semantics(
              button: true,
              label:
                  '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onPick(argb),
                child: _dot(argb, size: 32),
              ),
            ),
        ],
      );

  Widget _textPanel(BuildContext ctx) {
    final size = c.fontSize;
    final cur = c.fontName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in kDocFonts)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(f.name, style: TextStyle(fontFamily: f.render)),
                    selected: f.name == cur,
                    onSelected: (_) => c.setFont(f.name),
                  ),
                ),
            ],
          ),
        ),
        Row(children: [
          IconButton(
            tooltip: _t('word.font_shrink'),
            icon: const Icon(OfficeIcons.fontShrink),
            onPressed: () => c.growFont(-1, kDocFontSizes),
          ),
          Expanded(
            child: Slider(
              min: 8,
              max: 72,
              value: (size ?? 11).clamp(8, 72).toDouble(),
              label: size == null ? '—' : _num(size),
              onChanged: (v) => c.setFontSize(v.roundToDouble()),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(size == null ? '—' : _num(size),
                key: const ValueKey('word-panel-size'),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: _t('word.font_grow'),
            icon: const Icon(OfficeIcons.fontGrow),
            onPressed: () => c.growFont(1, kDocFontSizes),
          ),
        ]),
        Wrap(spacing: 4, runSpacing: 4, children: [
          ..._charButtons(),
          RibbonButton(OfficeIcons.clearFormat, _t('word.clear_format'),
              onTap: c.clearFormatting),
          PainterButton(c: c),
        ]),
        _label(_t('word.theme_colors')),
        _swatches(c.doc.styles.themeColors, c.setColor),
        _label(_t('word.standard_colors')),
        _swatches(kWordStandardColors, c.setColor),
        if (c.recentColors.isNotEmpty) ...[
          _label(_t('word.recent_colors')),
          _swatches(c.recentColors, c.setColor),
        ],
        TextButton.icon(
          icon: const Icon(AppIcons.formatColorReset),
          label: Text(_t('word.auto_color')),
          onPressed: () => c.setColor(DocxRunPatch.autoColor),
        ),
        _label(_t('word.highlight')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final name in DocxStyles.highlightNames.take(8))
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => c.setHighlight(name),
              child: _dot(DocxStyles.highlightArgb(name)!, size: 32),
            ),
          IconButton(
            tooltip: _t('word.no_highlight'),
            icon: const Icon(AppIcons.formatColorReset),
            onPressed: () => c.setHighlight(''),
          ),
        ]),
      ],
    );
  }

  Widget _paraPanel(BuildContext ctx) {
    final look = c.paraLook;
    final cur = look.lineMultiple ?? 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          ..._alignButtons(),
          RibbonButton(OfficeIcons.rtl, _t('word.rtl'),
              active: look.bidi, onTap: c.toggleRtl),
        ]),
        Wrap(spacing: 4, runSpacing: 4, children: [
          ..._listButtons(),
          RibbonButton(OfficeIcons.indentLess, _t('sl.indent_less'),
              onTap: () => c.indent(-1)),
          RibbonButton(OfficeIcons.indentMore, _t('sl.indent_more'),
              onTap: () => c.indent(1)),
        ]),
        _label(_t('word.line_spacing')),
        Wrap(spacing: 8, children: [
          for (final v in kWordLineSpacings)
            ChoiceChip(
              label: Text(_num(v)),
              selected: (cur - v).abs() < 0.01,
              onSelected: (_) => c.setLineSpacing(v),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilterChip(
            label: Text(_t('word.space_before')),
            selected: look.spaceBeforePt > 0,
            onSelected: (_) => c.toggleSpaceBefore(),
          ),
          FilterChip(
            label: Text(_t('word.space_after')),
            selected: look.spaceAfterPt > 0,
            onSelected: (_) => c.toggleSpaceAfter(),
          ),
        ]),
        // Liste kalıbı galerisi (Faz 23 kalanı): Word'ün madde işareti ve
        // numaralandırma kitaplığı.
        _label(_t('word.list_gallery')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in kDocxListPatterns.entries)
            ChoiceChip(
              key: ValueKey('word-list-${e.key}'),
              label: Text(e.value.sample),
              tooltip: _t(e.value.kind == 'bullet'
                  ? 'word.bullets'
                  : 'word.numbering'),
              selected: c.listPattern == e.key,
              onSelected: (_) => c.applyListPattern(e.key),
            ),
        ]),
      ],
    );
  }

  Widget _stylesPanel(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final cur = c.styleId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in c.doc.styles.gallery())
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: AppColors.page,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: cur == g.id ? scheme.primary : scheme.outlineVariant,
                    width: cur == g.id ? 2 : 1),
              ),
              child: InkWell(
                key: ValueKey('word-panel-style-${g.builtin}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => c.applyStyle(g.id),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(wordStyleLabel(ctx, g),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle(g, maxSize: 26)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Biçim boyacısı düğmesi: tek dokunuş bir kez, çift dokunuş kilitli
/// (Office gibi). Etkinken vurgulu.
class PainterButton extends StatelessWidget {
  final DocxEditController c;
  const PainterButton({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = c.painterActive;
    return Semantics(
      button: true,
      toggled: on,
      label: context.t('word.format_painter'),
      excludeSemantics: true,
      child: Tooltip(
        message: context.t('word.format_painter'),
        child: Material(
          color: on ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const ValueKey('word-painter'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => c.pickPainter(),
            onDoubleTap: () => c.pickPainter(lock: true),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(OfficeIcons.formatPainter,
                  size: 20,
                  color: on ? scheme.onPrimaryContainer : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
