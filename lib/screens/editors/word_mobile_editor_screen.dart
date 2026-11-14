import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/doc_fonts.dart';
import '../../core/edit/edit_session.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/edit/editor_shortcuts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/once_hints.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/document.dart';
import '../../services/docx/docx_document.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/safe_write.dart';
import '../../widgets/ai_rewrite_sheet.dart';
import '../../widgets/editor_top_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/share_export_sheet.dart';
import '../../widgets/docx_editor/docx_edit_controller.dart';
import '../../widgets/docx_editor/docx_editor_view.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/app_dialog.dart';
import 'word_mobile/word_format_ui.dart';
import 'word_mobile/word_insert_ui.dart';
import '../fm/pick_file_screen.dart';
import '../../services/docx/pro/docx_package.dart';
import '../../services/docx/pro/docx_style_ops.dart';
import '../../services/docx/pro/docx_layout_ops.dart';
import '../../services/docx/pro/docx_pdf.dart';
import '../../services/docx/pro/docx_math.dart';
import '../../services/docx/pro/docx_table_ops.dart';
import '../../services/docx/pro/docx_compare.dart';
import '../../services/office_crypto.dart';
import '../../services/dictation.dart';
import '../../services/docx/pro/docx_paginator.dart';
import '../../services/docx/pro/docx_insert_pro.dart';
import '../../services/docx/pro/docx_export_formats.dart';
import 'word_mobile/word_reader.dart';
import '../../services/docx/pro/docx_fonts.dart';
import '../../services/fm/save_to_downloads.dart';
import '../../widgets/download_action.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/docx/pro/docx_ai.dart';
import '../../services/gemini_service.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:shared_preferences/shared_preferences.dart';

part 'word_mobile/word_pro.dart';
part 'word_mobile/word_pro_sheets.dart';

/// **Word Mobil görünüm editörü** (Faz 22, K18 = b-ii).
///
/// Microsoft 365 telefonda nasıl düzenletiyorsa öyle: sayfa düzeni yerine
/// ekran genişliğinde akan metin, okunur boy, tam klavye desteği (otomatik
/// düzeltme, kaydırarak yazma, sesle yazma), Enter yeni paragraf, geri silme
/// birleştirir, seçim + tutamak + bağlam menüsü, yazım denetimi. Kaydetme
/// yalnız değişen paragrafları yazar; köprü, alan, dipnot, resim, içerik
/// denetimi dokunulmaz ada olarak korunur.
///
/// Çıkışta (ya da "Sayfa düzeni") Word ekranı dosyayı yeniden açar.
class WordMobileEditorScreen extends StatefulWidget {
  final String path;
  final String name;

  /// Açılışta gösterilecek paragraf (-1/0: baş).
  final int startPara;

  /// İmlecin bulunduğu paragraf buraya yazılır: görüntüleyici dönüşte oraya
  /// odaklanır.
  final ValueNotifier<int>? caretOut;

  /// Ayrıştırmayı izolatta yap (testte kapatılır: flutter_test sahte saatinde
  /// izolat yanıtı beklenemez).
  @visibleForTesting
  static bool parseInIsolate = true;

  /// Testte dosya seçici yerine (bayt, uzantı) verir.
  @visibleForTesting
  static Future<(Uint8List, String)?> Function()? pickImageForTest;

  /// Testte dosya seçici yerine docx baytı verir (karşılaştır/birleştir).
  @visibleForTesting
  static Future<Uint8List?> Function()? pickDocxForTest;


  const WordMobileEditorScreen(
      {super.key,
      required this.path,
      required this.name,
      this.startPara = -1,
      this.caretOut});

  @override
  State<WordMobileEditorScreen> createState() => _WordMobileEditorScreenState();
}

class _WordMobileEditorScreenState extends State<WordMobileEditorScreen>
    with DraftRecoveryMixin<WordMobileEditorScreen> {
  DocxDocument? _doc;
  DocxEditController? _ctrl;
  String? _error;
  int _seenRevision = 0;
  final _panel = FormatPanelController();

  /// Faz 37: yapısal (paket düzeyi) işlemlerin geri alma yığını — her biri
  /// işlemden önceki belge baytı (en çok 5; bellek bütçesi).
  final List<Uint8List> _proUndo = [];
  bool _proBusy = false;

  /// Madde 8/11: artımlı sayfa tahmini (gezinti, küçük resim, sayaç).
  DocxPaginator _paginator = DocxPaginator();

  /// Madde 5: gözden geçirme çubuğu öğeleri (null → kapalı) ve parola.
  List<DocxReviewItem>? _review;
  int _reviewAt = 0;
  String? _filePassword;

  /// `word_pro_v1` bayrağı (anayasa k.9): kapalıysa Araçlar sekmesi yok.
  bool _proOn = true;

  late final EditSession _session = EditSession(
    sourcePath: widget.path,
    editor: 'word',
    save: _writeFile,
    snapshot: () async => _doc?.saveAsync(),
  );

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(_loadProFlag());
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onEdit);
    _ctrl?.dispose();
    _panel.dispose();
    _session.dispose();
    super.dispose();
  }

  static DocxDocument _parse(Uint8List bytes) => DocxDocument.parse(bytes);

  /// Tam ayrıştırma sürerken gösterilen ilk paragraflar (Faz 22 kalanı —
  /// "ilk 50 paragraf önce"). Büyük belgede editör modeli birkaç saniye
  /// sürebiliyor; kullanıcı o arada boş çark yerine belgenin başını görür.
  List<String>? _preview;

  static List<String> _previewParas(Uint8List bytes) =>
      docxPreviewParagraphs(bytes, limit: 50);

  Future<void> _load() async {
    try {
      var bytes = await File(widget.path).readAsBytes();
      // Faz 37 madde 5: parolalı belge (ECMA-376 Agile) önce çözülür.
      if (OfficeCrypto.isEncrypted(bytes)) {
        final plain = await _unlock(bytes);
        if (plain == null) {
          if (mounted) setState(() {});
          return;
        }
        bytes = plain;
      }
      final isolate = WordMobileEditorScreen.parseInIsolate;
      // Önizleme ve tam ayrıştırma AYNI ANDA başlar; önizleme önce biter.
      if (isolate) {
        unawaited(compute(_previewParas, bytes).then((list) {
          if (mounted && _doc == null && list.isNotEmpty) {
            setState(() => _preview = list);
          }
        }, onError: (_) {}));
      }
      final doc = isolate ? await compute(_parse, bytes) : _parse(bytes);
      _attach(doc);
    } catch (e) {
      _error = userErrorText(e);
    }
    if (mounted) setState(() {});
    if (_doc != null) {
      _openAtStart();
      unawaited(_session.captureSource());
      unawaited(lookForDraft(widget.path));
    }
  }

  /// Görüntüleyicide bakılan yerde aç; imleç de orada olsun.
  void _openAtStart() {
    final i = widget.startPara;
    final c = _ctrl;
    if (i <= 0 || c == null || i >= c.paras.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.select(DocPos(i, 0), DocPos(i, 0));
      unawaited(_viewKey.currentState?.revealParagraph(i, top: true));
    });
  }

  void _attach(DocxDocument doc) {
    _ctrl?.removeListener(_onEdit);
    _ctrl?.dispose();
    _doc = doc;
    _ctrl = DocxEditController(doc)..addListener(_onEdit);
    _seenRevision = 0;
  }

  /// İçerik değiştiyse oturuma bildir (taslak + otomatik kaydetme).
  void _onEdit() {
    final c = _ctrl;
    if (c == null) return;
    if (c.revision != _seenRevision) {
      _seenRevision = c.revision;
      _session.changed();
    }
    widget.caretOut?.value = c.extent.para;
    setState(() {});
  }

  Future<void> _writeFile() async {
    final doc = _doc;
    if (doc == null) return;
    final plain = await doc.saveAsync();
    final pw = _filePassword;
    final bytes = pw == null
        ? plain
        : await OfficeCrypto.encryptInBackground(plain, pw);
    await SafeWrite.bytes(widget.path, bytes);
    unawaited(ActivityLog.add(ActivityKind.documentEdit, widget.path));
  }

  Future<void> _restoreDraft(Uint8List bytes) async {
    setState(() => _attach(DocxDocument.parse(bytes)));
    _session.changed();
  }

  Future<void> _save() async {
    if (_doc == null) return;
    final failed = context.t('word.save_failed');
    final ok = await _session.saveNow();
    if (!mounted) return;
    if (ok) {
      // H7.3: "kalıcı yer için…" ipucu bir kez; sonra yalnız "Kaydedildi".
      final where = await OnceHints.take('save_where');
      if (!mounted) return;
      showSnack(context, context.t(where ? 'common.saved_hint' : 'common.saved'));
    } else {
      showSnack(
          context,
          failed.replaceAll('{error}',
              userErrorText(_session.coordinator.lastError ?? '')));
    }
  }

  /// "Sayfa düzeni": kaydedip Word ekranına (sayfa görünümü) döner.
  Future<void> _pageLayout() async {
    if (_session.isDirty) {
      final ok = await _session.saveNow();
      if (!ok || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _aiFix(String text) async {
    final c = _ctrl;
    if (c == null || text.trim().isEmpty) return;
    final result = await showAiRewriteSheet(context, text);
    if (result == null || !mounted) return;
    c.replaceSelection(result);
  }

  void _translate(String text) {
    if (text.trim().isEmpty) return;
    QuickTranslateSheet.show(context, text, title: widget.name);
  }

  /// Mobil görünümün punto → dp çarpanı (Görünüm > Yakınlaştır).
  double _scale = 1.35;
  static const _scales = [1.0, 1.15, 1.35, 1.6, 1.9, 2.2];

  void _zoom(int dir) {
    final i = _scales.indexOf(_scale) + dir;
    if (i < 0 || i >= _scales.length) return;
    setState(() => _scale = _scales[i]);
  }

  final _viewKey = GlobalKey<DocxEditorViewState>();

  WordFormatUi _ui(DocxEditController c) => WordFormatUi(
        context: context,
        c: c,
        onPageLayout: _pageLayout,
        onNavigate: _navigate,
        onWordCount: _proOn ? _stats : _wordCount,
        onZoomIn: _scale < _scales.last ? () => _zoom(1) : null,
        onZoomOut: _scale > _scales.first ? () => _zoom(-1) : null,
        onTranslate: _translate,
        onInsertTable: _insertTable,
        onInsertLink: _insertLink,
        onSymbol: _insertSymbol,
        onFind: () => setState(() => _findOpen = !_findOpen),
        onHeaderFooter: _headerFooter,
        onResolveTracked: _resolveTracked,
        onInsertImage: () => _pickImage(replace: false),
        onReplaceImage: () => _pickImage(replace: true),
        onImageAlt: _imageAlt,
        onComments: () => _comments(),
        onNewComment: _newComment,
        onFootnote: _insertFootnote,
        onDate: _insertDate,
        onPro: _proOn ? _onPro : null,
      );

  Future<void> _pickImage({required bool replace}) async {
    final c = _ctrl;
    if (c == null) return;
    (Uint8List, String)? got;
    final hook = WordMobileEditorScreen.pickImageForTest;
    if (hook != null) {
      got = await hook();
    } else {
      final picked = await AppFilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'bmp'],
        withData: true,
      );
      final f = picked?.files.single;
      if (f?.bytes != null) {
        got = (f!.bytes!, (f.extension ?? 'png').toLowerCase());
      }
    }
    if (got == null || !mounted) return;
    var size = (0, 0);
    try {
      final codec = await ui.instantiateImageCodec(got.$1);
      final frame = await codec.getNextFrame();
      size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      size = (0, 0);
    }
    if (!mounted) return;
    if (size.$1 <= 0 || size.$2 <= 0) {
      showSnack(context, context.t('word.img_failed'));
      return;
    }
    if (replace) {
      c.replaceImage(got.$1, got.$2, pixelWidth: size.$1, pixelHeight: size.$2);
    } else {
      c.insertImage(got.$1, got.$2, pixelWidth: size.$1, pixelHeight: size.$2);
    }
  }

  Future<void> _imageAlt() async {
    final c = _ctrl;
    if (c == null || c.selectedImage == null) return;
    final t = await showWordTextSheet(context,
        title: context.t('word.img_alt'),
        label: context.t('word.img_alt_hint'),
        action: context.t('common.apply'),
        initial: c.imageAlt,
        fieldKey: const ValueKey('word-img-alt-field'));
    if (t != null && mounted) c.setImageAlt(t);
  }

  Future<void> _comments({String? focus}) async {
    final c = _ctrl;
    if (c == null) return;
    await showWordCommentsSheet(context, c,
        focusId: focus,
        reveal: (i) => _viewKey.currentState?.revealParagraph(i));
  }

  Future<void> _newComment() async {
    final c = _ctrl;
    if (c == null) return;
    final author = await wordCommentAuthor(context);
    if (author == null || !mounted) return;
    final text = await showWordTextSheet(context,
        title: context.t('word.comment_new'),
        label: context.t('word.comment_text'),
        action: context.t('word.comment_post'),
        fieldKey: const ValueKey('word-comment-text'));
    if (text != null && mounted) c.addComment(text, author);
  }

  Future<void> _insertFootnote() async {
    final c = _ctrl;
    if (c == null) return;
    final t = await showWordTextSheet(context,
        title: context.t('word.insert_footnote'),
        label: context.t('word.footnote_text'),
        action: context.t('common.insert'),
        fieldKey: const ValueKey('word-footnote-field'));
    if (t != null && t.trim().isNotEmpty && mounted) c.insertFootnote(t.trim());
  }

  Future<void> _openFootnote(String id) async {
    final c = _ctrl;
    if (c == null) return;
    final cur = c.footnoteText(id);
    if (cur == null) return;
    final t = await showWordTextSheet(context,
        title: context.t('word.footnote_edit', {'n': id}),
        label: context.t('word.footnote_text'),
        action: context.t('common.apply'),
        initial: cur,
        fieldKey: const ValueKey('word-footnote-field'));
    if (t == null || !mounted || t.trim() == cur) return;
    if (!c.setFootnoteText(id, t.trim())) {
      showSnack(context, context.t('word.footnote_rich'));
    }
  }

  Future<void> _insertDate() async {
    final c = _ctrl;
    if (c == null) return;
    final t = await showWordDateSheet(context);
    if (t != null && mounted) c.insertText(t);
  }

  bool _findOpen = false;

  Future<void> _insertTable() async {
    final c = _ctrl;
    if (c == null) return;
    final size = await showWordTableSheet(context);
    if (size == null || !mounted) return;
    if (!c.insertTable(size.$1, size.$2)) {
      showSnack(context, context.t('word.table_failed'));
      return;
    }
    await _viewKey.currentState?.revealParagraph(c.extent.para);
  }

  Future<void> _insertLink() async {
    final c = _ctrl;
    if (c == null) return;
    final r = await showWordLinkSheet(context, text: c.selectedText());
    if (r == null || !mounted) return;
    c.insertLink(r.$1, r.$2);
  }

  /// Bağlantıya dokunuş: metni / adresi düzenle, aç ya da kaldır.
  Future<void> _editLink(int para, int offset) async {
    final c = _ctrl;
    final link = c?.linkAt(para, offset);
    if (c == null || link == null) return;
    final r = await showWordLinkSheet(context, text: link.$1, url: link.$2);
    if (r == null || !mounted) return;
    if (r == link) return;
    c.editLinkAt(para, offset, r.$1, r.$2);
  }

  Future<void> _headerFooter() async {
    final c = _ctrl;
    if (c == null) return;
    await showWordHeaderFooterSheet(context, c);
  }

  Future<void> _resolveTracked(bool accept) async {
    final c = _ctrl;
    if (c == null) return;
    final n = c.trackedChanges;
    if (n == 0) {
      showSnack(context, context.t('word.track_none'));
      return;
    }
    final ok = await showAppConfirm(
      context,
      message: context.t(
          accept ? 'word.track_confirm_accept' : 'word.track_confirm_reject',
          {'n': n}),
      confirmLabel:
          context.t(accept ? 'word.track_accept' : 'word.track_reject'),
    );
    if (!ok || !mounted) return;
    c.resolveTracked(accept: accept);
  }

  Future<void> _insertSymbol() async {
    final c = _ctrl;
    if (c == null) return;
    final sym = await showWordSymbolSheet(context);
    if (sym != null) c.insertText(sym);
  }

  /// Görünüm > Gezinti: başlık listesi → dokun = o başlığa atla.
  Future<void> _navigate() async {
    final c = _ctrl;
    if (c == null) return;
    final hs = c.headings();
    final i = await showAppSheet<int>(
      context,
      title: context.t('word.navigation'),
      builder: (ctx) => hs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(ctx.t('word.no_headings')),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, level, text) in hs)
                  ListTile(
                    key: ValueKey('word-nav-$i'),
                    contentPadding: EdgeInsetsDirectional.only(
                        start: 16.0 + (level - 1).clamp(0, 4) * 20, end: 16),
                    title: Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: level == 1
                            ? const TextStyle(fontWeight: FontWeight.w600)
                            : null),
                    onTap: () => Navigator.pop(ctx, i),
                  ),
              ],
            ),
    );
    if (i == null || !mounted) return;
    c.goToParagraph(i);
    await _viewKey.currentState?.revealParagraph(i);
  }

  /// Gözden Geçir > Sözcük sayısı.
  Future<void> _wordCount() async {
    final c = _ctrl;
    if (c == null) return;
    final n = c.counts();
    await showAppSheet<void>(
      context,
      title: context.t('word.word_count'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (k, v) in [
            ('word.count_words', n.words),
            ('word.count_chars', n.chars),
            ('word.count_chars_ns', n.charsNoSpace),
            ('word.count_paras', n.paragraphs),
          ])
            ListTile(
              title: Text(ctx.t(k)),
              trailing: Text('$v', style: Theme.of(ctx).textTheme.titleMedium),
            ),
        ],
      ),
    );
  }

  Widget _accessory(DocxEditController c, WordFormatUi ui) =>
      KeyboardAccessoryBar(
        onFormat: _panel.open,
        onHideKeyboard: () {
          c.detach();
          FocusScope.of(context).unfocus();
          setState(() {});
        },
        items: ui.accessory(),
      );

  Widget _ribbon(WordFormatUi ui) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: OfficeRibbon(tabs: ui.ribbonTabs()),
        ),
      ),
    );
  }

  /// Biçim boyacısı etkinken belgenin üstünde ince şerit (kilitliyse ✕).
  Widget _painterBanner(DocxEditController c) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('word-painter-banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Row(children: [
          Icon(OfficeIcons.formatPainter,
              size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t(c.painterLocked
                  ? 'word.format_painter_locked'
                  : 'word.format_painter_hint'),
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
          IconButton(
            tooltip: context.t('common.close'),
            icon: const Icon(AppIcons.close),
            onPressed: c.cancelPainter,
          ),
        ]),
      ),
    );
  }

  Widget _chrome(DocxEditController c) {
    final ui = _ui(c);
    return EditorChrome(
      editing: true,
      accessory: _accessory(c, ui),
      ribbon: _ribbon(ui),
      panel: _panel,
      panelTabs: ui.panelTabs(),
      body: Column(
        children: [
          if (c.painterActive) _painterBanner(c),
          if (_review != null) _reviewBar(),
          if (_findOpen)
            WordFindBar(
              controller: c,
              reveal: (i) async => _viewKey.currentState?.revealParagraph(i),
              onClose: () => setState(() => _findOpen = false),
            ),
          Expanded(
            child: DocxEditorView(
              key: _viewKey,
              controller: c,
              scale: _scale,
              spellcheck: EditPrefs.wordSpellcheck,
              actions: DocxEditorActions(
                  translate: _translate,
                  aiFix: _aiFix,
                  openNote: _openFootnote,
                  openComment: (id) => _comments(focus: id),
                  openLink: _editLink),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return EditExitGuard(
      session: _session,
      hasOpenLayer: false,
      closeLayer: () {},
      child: EditorShortcuts(
        save: c == null ? null : _save,
        undo: c?.undo,
        redo: c?.redo,
        bold: c?.toggleBold,
        italic: c?.toggleItalic,
        underline: c?.toggleUnderline,
        copy: c == null ? null : () => c.copy(),
        cut: c == null ? null : () => c.cut(),
        paste: c == null ? null : () => c.paste(),
        selectAll: c?.selectAll,
        child: OfficeShell(
          kind: DocKind.word,
          title: widget.name,
          session: _session,
          subtitle: context.t('word.mobile_view'),
          // ↶ ↷ hep üst çubukta (§5 madde 5); Sayfa düzeni M365'teki gibi
          // tepede — şerit yazı işlerine kalır.
          // Faz 40 / 1: ortak üst çubuk sırası (kaydet · ↶ · ↷ · düzen · ⋮).
          actions: EditorTopBar.actions(
            context,
            onSave: c == null ? null : _save,
            undoKey: const ValueKey('word-undo'),
            undo: () => c != null && c.canUndo
                ? c.undo
                : (_proUndo.isNotEmpty && !_proBusy ? _proUndoLast : null),
            redo: () => c != null && c.canRedo ? c.redo : null,
            extras: [
              IconButton(
                key: const ValueKey('word-page-layout'),
                tooltip: context.t('word.page_layout'),
                icon: const Icon(AppIcons.newWord),
                onPressed: c == null ? null : _pageLayout,
              ),
            ],
            menu: [
              EditorMenuItem(
                id: 'export',
                icon: AppIcons.share,
                label: context.t('ux.share_export'),
                onTap: c == null ? null : _shareExport,
              ),
            ],
          ),
          body: withDraftBanner(
            restore: _restoreDraft,
            _error != null
                ? AppErrorView(
                        message: context.t('ux.error_body'),
                        details: context.t('common.open_failed', {'error': _error}))
                : c == null
                    ? (_preview == null
                        ? const AppSkeleton()
                        : DocxLoadingPreview(paragraphs: _preview!))
                    : _chrome(c),
          ),
        ),
      ),
    );
  }
}

/// Belge açılırken ilk paragraflar — salt okunur, sayfa zemininde; üstte
/// ince ilerleme çubuğu ve "açılıyor" notu.
class DocxLoadingPreview extends StatelessWidget {
  final List<String> paragraphs;
  const DocxLoadingPreview({super.key, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('word-loading-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(context.t('word.opening_preview'),
              style: context.type.small.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Expanded(
          child: ColoredBox(
            color: Paper.docSurface(context),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: paragraphs.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(paragraphs[i],
                    style: context.type.large.copyWith(height: 1.4)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
