import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edit/edit_session.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/edit/editor_shortcuts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../../models/document.dart';
import '../../services/docx/docx_document.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/safe_write.dart';
import '../../widgets/ai_rewrite_sheet.dart';
import '../../widgets/docx_editor/docx_edit_controller.dart';
import '../../widgets/docx_editor/docx_editor_view.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/app_dialog.dart';
import 'word_mobile/word_format_ui.dart';
import 'word_mobile/word_insert_ui.dart';

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

  /// Ayrıştırmayı izolatta yap (testte kapatılır: flutter_test sahte saatinde
  /// izolat yanıtı beklenemez).
  @visibleForTesting
  static bool parseInIsolate = true;

  const WordMobileEditorScreen(
      {super.key, required this.path, required this.name});

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

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final doc = WordMobileEditorScreen.parseInIsolate
          ? await compute(_parse, bytes)
          : _parse(bytes);
      _attach(doc);
    } catch (e) {
      _error = userErrorText(e);
    }
    if (mounted) setState(() {});
    if (_doc != null) {
      unawaited(_session.captureSource());
      unawaited(lookForDraft(widget.path));
    }
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
    setState(() {});
  }

  Future<void> _writeFile() async {
    final doc = _doc;
    if (doc == null) return;
    final bytes = await doc.saveAsync();
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
      showSnack(context, context.t('common.saved_hint'));
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
        onWordCount: _wordCount,
        onZoomIn: _scale < _scales.last ? () => _zoom(1) : null,
        onZoomOut: _scale > _scales.first ? () => _zoom(-1) : null,
        onTranslate: _translate,
        onInsertTable: _insertTable,
        onInsertLink: _insertLink,
        onSymbol: _insertSymbol,
        onFind: () => setState(() => _findOpen = !_findOpen),
      );

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
              actions:
                  DocxEditorActions(translate: _translate, aiFix: _aiFix),
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
          actions: [
            IconButton(
              key: const ValueKey('word-undo'),
              tooltip: context.t('word.undo'),
              icon: const Icon(OfficeIcons.undo),
              onPressed: c != null && c.canUndo ? c.undo : null,
            ),
            IconButton(
              tooltip: context.t('word.redo'),
              icon: const Icon(OfficeIcons.redo),
              onPressed: c != null && c.canRedo ? c.redo : null,
            ),
            IconButton(
              key: const ValueKey('word-page-layout'),
              tooltip: context.t('word.page_layout'),
              icon: const Icon(AppIcons.newWord),
              onPressed: c == null ? null : _pageLayout,
            ),
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(AppIcons.save),
              onPressed: c == null ? null : _save,
            ),
          ],
          body: withDraftBanner(
            restore: _restoreDraft,
            _error != null
                ? Center(
                    child: Text(context.t('common.open_failed', {'error': _error})))
                : c == null
                    ? const Center(child: CircularProgressIndicator())
                    : _chrome(c),
          ),
        ),
      ),
    );
  }
}
