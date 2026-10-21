import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/pdf/pdf_ocr_text.dart';
import '../services/pdf/pdf_scanned_retype.dart';
import '../services/pdf/pdf_text_stamp.dart';
import '../services/pdf_page_edit.dart';
import '../services/pdf_reload.dart';
import '../services/pdf_tools.dart';
import '../services/scan_ai_fix.dart';
import '../services/scan_text_fix.dart';
import '../widgets/pdf_edit_overlay.dart';
import '../widgets/pdf_save_dialog.dart';
import '../core/snack.dart';
import '../core/user_error.dart';
import '../widgets/ai_key_gate.dart';

part 'pdf_editor/actions.dart';
part 'pdf_editor/views.dart';

/// **Tek PDF düzenleme ekranı** — metin, görsel, filigran ve sayfa işlerinin
/// hepsi burada (2026-07-27 kullanıcı isteği: *"tüm bu işler tek bir pdf
/// düzenleme editör sayfasında yapılmalı"*).
///
/// Akış tasarımı, kullanıcının tarif ettiği gibi:
/// 1. Bir mod seç (alt çubuk: Metin · Görsel · Filigran · Sayfa),
/// 2. sayfada düzenlenecek öğeye dokun — çerçeveli kutular neyin
///    düzenlenebilir olduğunu peşinen gösterir, kullanıcı aramak zorunda değil,
/// 3. küçük bir pencerede düzenle → **Uygula** → sonuç HEMEN sayfada görünür,
/// 4. beğenmediysen **Geri al**,
/// 5. **Kaydet** → *Orijinali değiştir* / *Kopyasını kaydet* / *Klasör seç*.
///
/// Özgün dosyaya kaydedilene kadar DOKUNULMAZ: bütün düzenlemeler geçici bir
/// çalışma kopyasında yapılır. Kullanıcı vazgeçerse hiçbir iz kalmaz.
class PdfEditorScreen extends StatefulWidget {
  final String path;
  final int initialPage;

  const PdfEditorScreen({
    super.key,
    required this.path,
    this.initialPage = 1,
  });

  /// Ekranı açar; bir şey kaydedildiyse `true` döner (çağıran tazelesin).
  static Future<bool> open(
    BuildContext context, {
    required String path,
    int initialPage = 1,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PdfEditorScreen(path: path, initialPage: initialPage),
      ),
    );
    return saved ?? false;
  }

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

enum _EditMode { text, image, background, page }

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  /// Bu ekranın mesajları uzun asenkron işlerin **içinden** üretiliyor
  /// (`_run`, `_apply`, `catch` dalları); orada `context` kullanmak
  /// `use_build_context_synchronously` demektir. Dil uygulama genelinde tek
  /// olduğu için statik olan okunur. Doğrudan çizilen parçalarda `context.t`.
  AppStrings get _str => AppStrings.current;

  final _controller = PdfViewerController();

  /// Çalışma kopyası — özgün dosyaya kaydedene kadar hiç dokunulmaz.
  Directory? _workDir;
  String? _workPath;

  /// Geri alma yığını: her değişiklikten ÖNCEki hâlin dosya yolu.
  final List<String> _undo = [];

  _EditMode _mode = _EditMode.text;
  int _page = 1;
  int _pageCount = 0;
  PdfPageOutline _outline = PdfPageOutline.empty;

  /// Sayfa çözümlemesi REDDEDİLDİYSE sebebi (şeritte kalıcı olarak yazar).
  ///
  /// Kullanıcı bulgusu 2026-09-04: bir belgede hem "gömülü görsel yok" hem
  /// "düzenlenebilir metin yok" yazıyordu, oysa sayfada iki büyük görsel
  /// duruyordu. Çözümleme aslında HATA vermişti; hata bir anlık şeritte
  /// geçip gidiyor, geriye "boş sayfa" mesajı kalıyordu. Artık sebep ekranda
  /// duruyor — kullanıcı da, biz de neyin olmadığını görebiliyoruz.
  String? _outlineError;
  List<PdfBackgroundEntry> _background = const [];
  final Set<int> _backgroundPicked = {};

  int? _selectedObject;
  bool _busy = false;
  bool _dirty = false;
  bool _ready = false;
  String? _error;

  // ── Taranmış sayfa düzenleme (2026-08-06: "taranmış belge deyip düzenleme
  // yaptırmıyor — PDF'de yapılabilmeli") ───────────────────────────────────
  /// Bu oturumda "taranmış" olarak sınıflanan sayfalar (1-tabanlı). YAPIŞKAN:
  /// bir satırın üstüne yazılınca sayfada gerçek metin oluşur ve paragraf
  /// sayısı artar; sınıf değişseydi kalan OCR satırları düzenlenemez kalırdı.
  final Set<int> _scannedPages = {};

  /// Açık sayfanın OCR satırları (yalnız taranmış sayfada dolu).
  List<ScannedLine> _scannedLines = const [];

  /// [_scannedLines] hangi (belge sürümü, sayfa) için yüklendi.
  String _scannedKey = '';
  bool _scannedLoading = false;

  /// Her başarılı düzenlemede artar — OCR kutuları yeniden yüklensin.
  int _docRev = 0;

  /// "Yazı ekle" yerleştirme kipi: sıradaki dokunuş yazının yeridir.
  bool _placingText = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _prepare();
  }

  @override
  void dispose() {
    // Kaydedilmemiş çalışma kopyasını bırakma: geçici klasör silinir.
    final dir = _workDir;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Silinemezse sistem geçici klasörü zaten temizler.
      }
    }
    super.dispose();
  }

  // ── Veri ──────────────────────────────────────────────────────────────────

  // ── İşlemler ──────────────────────────────────────────────────────────────

  // ── Kaydetme ──────────────────────────────────────────────────────────────

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator ÖNCE alınıyor: `await`ten sonra `context` kullanmak
        // ekran kapanmışsa hatalı (use_build_context_synchronously).
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop(!_dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(widget.path),
              overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: context.t('common.undo'),
              icon: const Icon(Icons.undo),
              onPressed: _undo.isEmpty || _busy ? null : _undoLast,
            ),
            IconButton(
              tooltip: context.t('common.save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: !_dirty || _busy
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      if (await _save() && mounted) navigator.pop(true);
                    },
            ),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
        ),
        body: _body(),
        bottomNavigationBar: _modeBar(),
      ),
    );
  }

  // ── Küçük yardımcılar ─────────────────────────────────────────────────────

  /// `10.0` → `10`, `10.5` → `10.5`.
  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
