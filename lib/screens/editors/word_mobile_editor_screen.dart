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

  Widget _accessory(DocxEditController c) => KeyboardAccessoryBar(
        onHideKeyboard: () {
          c.detach();
          FocusScope.of(context).unfocus();
          setState(() {});
        },
        items: [
          AccessoryItem(
              key: const ValueKey('word-acc-undo'),
              icon: OfficeIcons.undo,
              tooltip: context.t('word.undo'),
              onPressed: c.canUndo ? c.undo : null),
          AccessoryItem(
              icon: OfficeIcons.redo,
              tooltip: context.t('word.redo'),
              onPressed: c.canRedo ? c.redo : null),
          AccessoryItem(
              key: const ValueKey('word-acc-bold'),
              icon: OfficeIcons.bold,
              tooltip: context.t('common.bold'),
              selected: c.isBold,
              onPressed: c.toggleBold),
          AccessoryItem(
              icon: OfficeIcons.italic,
              tooltip: context.t('common.italic'),
              selected: c.isItalic,
              onPressed: c.toggleItalic),
          AccessoryItem(
              icon: OfficeIcons.underline,
              tooltip: context.t('common.underline'),
              selected: c.isUnderline,
              onPressed: c.toggleUnderline),
          AccessoryItem(
              icon: OfficeIcons.paste,
              tooltip: context.t('word.paste'),
              onPressed: c.paste),
        ],
      );

  Widget _ribbon(DocxEditController c) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: OfficeRibbon(
            tabs: [
              RibbonTab('', [
                RibbonButton(OfficeIcons.undo, context.t('word.undo'),
                    onTap: c.canUndo ? c.undo : null),
                RibbonButton(OfficeIcons.redo, context.t('word.redo'),
                    onTap: c.canRedo ? c.redo : null),
                const RibbonSep(),
                RibbonButton(OfficeIcons.bold, context.t('common.bold'),
                    active: c.isBold, onTap: c.toggleBold),
                RibbonButton(OfficeIcons.italic, context.t('common.italic'),
                    active: c.isItalic, onTap: c.toggleItalic),
                RibbonButton(OfficeIcons.underline, context.t('common.underline'),
                    active: c.isUnderline, onTap: c.toggleUnderline),
                const RibbonSep(),
                RibbonButton(AppIcons.translate, context.t('common.translate'),
                    onTap: () => _translate(c.selectedText())),
              ]),
            ],
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(
                key: const ValueKey('word-page-layout'),
                onPressed: _pageLayout,
                child: Text(context.t('word.page_layout')),
              ),
            ),
          ),
        ),
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
          actions: [
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
                    : EditorChrome(
                        editing: true,
                        accessory: _accessory(c),
                        ribbon: _ribbon(c),
                        panel: _panel,
                        body: DocxEditorView(
                          controller: c,
                          spellcheck: EditPrefs.wordSpellcheck,
                          actions: DocxEditorActions(
                              translate: _translate, aiFix: _aiFix),
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
