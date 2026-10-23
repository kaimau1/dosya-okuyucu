import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show instantiateImageCodec;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../labs/word_editor/lab_word_screen.dart';
import '../../core/doc_fonts.dart';
import '../../core/edit/edit_session.dart';
import '../../core/edit/editor_chrome.dart';
import '../../core/edit/editor_shortcuts.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/list_prefix.dart';
import '../../core/theme.dart';
import '../../core/undo_stack.dart';
import '../../models/document.dart';
import '../../services/fm/safe_write.dart';
import '../../services/fm/activity_log.dart';
import '../../services/fm/save_to_downloads.dart';
import '../../services/docx_editor.dart';
import '../../widgets/doc_action_bar.dart';
import '../../widgets/doc_find_bar.dart';
import '../../widgets/ai_rewrite_sheet.dart';
import '../../widgets/docx_view.dart';
import '../../widgets/office_ribbon.dart';
import '../../widgets/office_shell.dart';
import '../../widgets/translate_flow.dart';
import '../../widgets/quick_sheets.dart';
import '../../widgets/download_action.dart';
import '../chat_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../../core/app_colors.dart';

part 'word/actions.dart';
part 'word/shell.dart';
part 'word/page.dart';

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

class _WordEditorScreenState extends State<WordEditorScreen>
    with DraftRecoveryMixin<WordEditorScreen> {
  DocxEditor? _editor;
  /// WebView'a giden İŞARETLİ kopya (Faz 21a, `DocxEditor.viewBytes`). Yalnız
  /// yeniden çizim gerektiğinde değişir — eskiden her kayıtta dosya baytları
  /// değiştiği için sayfa baştan çiziliyor, imleç kayboluyordu.
  Uint8List? _viewBytes;
  String? _error;

  /// Faz 20: kirli durum, kaydetme durumu, taslak ve otomatik kaydetme.
  late final EditSession _session = EditSession(
    sourcePath: widget.path,
    editor: 'word',
    save: _writeFile,
    snapshot: () async => _editor?.saveAsync(),
  );
  bool get _dirty => _session.isDirty;

  /// true → yedek düz metin editörü (sayfa görünümü açılamadı veya kullanıcı seçti).
  bool _plainMode = false;
  bool _editing = false;

  /// Okuma kipi (Faz 18 / G20) — düzenleme kapalıyken.
  final ReadingBars _readingBars = ReadingBars();

  /// Yapısal bir değişiklikten (resim ekle/sil) sonra belge yeniden çiziliyor;
  /// çizim bitince düzenleme yeniden açılsın mı?
  bool _resumeEditing = false;

  /// Mobil akış görünümü açık mı? (SAYFA görünümü varsayılan — 2026-08-06
  /// ikinci karar: aynı gün akış varsayılan yapılmıştı, kullanıcı *"mobil
  /// görünüme geçmeden tam sayfada da net görünsün, asıl isteğim o"* deyince
  /// geri alındı. Netlik artık WebView'ın hybrid composition çizimiyle
  /// sağlanıyor — bkz. `DocxView._webView`.)
  bool _flow = false;
  bool _selB = false, _selI = false, _selU = false, _selS = false;
  String _selAlign = 'left';
  String _selList = '';

  /// Canlı görünümün kendi geri al / yinele yığını (W5).
  bool _viewCanUndo = false, _viewCanRedo = false;

  /// Düzenlemeye girerken sayfa görünümündeysek okunur boyut için mobil
  /// akışa geçildi mi (çıkışta geri dönülür — W6).
  bool _flowForEdit = false;

  /// Klavye ↔ Aa biçim paneli (Faz 20 çekirdeği).
  final _panel = FormatPanelController();

  /// İmlecin bulunduğu paragrafın yazı tipi/puntosu (araç çubuğu gösterir).
  String _selFont = '';
  double _selSize = 0;

  /// Belgenin toplam sayfa sayısı ve görünen sayfa (canlı görünümden gelir).
  int _pageCount = 0;
  int _page = 1;

  final _viewKey = GlobalKey<DocxViewState>();

  /// Biçim çubuğunda sunulan yazı tipleri — Excel/slaytla ORTAK liste
  /// (`kDocFonts`). Her adın `viewer.html` içinde metrik uyumlu gömülü bir
  /// karşılığı tanımlıdır (Carlito/Tinos/Arimo); tanımsız bir ad seçtirmek
  /// belgeyi cihazda bambaşka gösterirdi.
  static final _fonts = kDocFonts.map((f) => f.name).toList();

  static const _sizes = kDocFontSizes;

  /// Yedek editörde biçim araç çubuğunun üzerinde çalıştığı seçili paragraf.
  DocxParagraph? _sel;

  /// Belge içi bul/değiştir çubuğu (slayt ve Excel'dekiyle aynı davranış).
  bool _finding = false;
  bool _replacing = false;
  final _findCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();
  int _hitCount = 0;
  int _hitIndex = -1;

  /// Seçili metin geldiğinde çalışacak iş (AI ile yeniden yaz / çevir).
  /// JS köprüsü asenkron olduğu için istek ve sonuç ayrı yerlerde.
  void Function(String text)? _pendingSelection;

  /// Word'ün fosforlu kalem paleti + yazı rengi paleti. Vurgu renkleri Word'ün
  /// **adlandırılmış** vurgularına birebir eşleşecek şekilde seçildi (bkz.
  /// `DocxEditor._highlightNames`), yoksa `w:shd` yedeğine düşerlerdi.
  static const _highlightPalette = <String>[
    'FFFF00',
    '00FF00',
    '00FFFF',
    'FF00FF',
    'C0C0C0',
  ];
  static const _textColorPalette = <String>[
    '000000',
    'C00000',
    'FF0000',
    '0070C0',
    '00B050',
    '7030A0',
    '808080',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _session.dispose();
    _panel.dispose();
    _readingBars.dispose();
    super.dispose();
  }

  // ── belge içi bul / değiştir ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    final bytes = _viewBytes;
    // Geri tuşu önce DÜZENLEMEYİ kapatır (slaytlarla aynı kural, 2026-08-01):
    // yazarken yanlışlıkla ekrandan çıkmak yazılanı görünmez kılıyordu.
    return EditExitGuard(
      session: _session,
      hasOpenLayer: _editing,
      closeLayer: _toggleEdit,
      child: EditorShortcuts(
        undo: _canUndo ? _undoAny : null,
        redo: _canRedo ? _redoAny : null,
        bold: _liveEditing ? () => _viewKey.currentState?.format('bold') : null,
        italic:
            _liveEditing ? () => _viewKey.currentState?.format('italic') : null,
        underline: _liveEditing
            ? () => _viewKey.currentState?.format('underline')
            : null,
        save: editor == null ? null : _save,
        find: _plainMode || editor == null ? null : _toggleFind,
        child: _buildShell(editor, bytes),
      ),
    );
  }

  // ── geri al / yinele ────────────────────────────────────────────────────

  /// **Kapsam:** paragraf ekleme/silme ve hizalama gibi **yapısal** işlemler.
  /// Harf harf yazma buraya girmez — canlı görünümde tarayıcının kendi geri
  /// alması, akış görünümünde `TextField`in kendi geri alması zaten çalışıyor;
  /// her tuş vuruşunu ayrıca kaydetmek iki katmanlı ve şaşırtıcı bir geri alma
  /// yaratırdı.
  final _undo = UndoStack();


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
