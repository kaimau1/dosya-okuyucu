import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/save_to_downloads.dart';
import '../services/pdf/pdf_markup.dart';
import '../widgets/download_action.dart';
import '../widgets/pdf_save_dialog.dart';
import '../core/user_error.dart';
import '../core/app_colors.dart';

part 'pdf_ink/input.dart';
part 'pdf_ink/views.dart';
part 'pdf_ink/widgets.dart';

/// Kalem ekranında seçili araç.
enum InkTool { pen, highlighter, eraser, text, hand }

/// **Kalemle düzenleme** — PDF'in üstüne elle çiz, fosforlu kalemle işaretle,
/// yazı ekle, sil; tek düğmeyle kaydet.
///
/// Kullanıcı 2026-09-22 (Chrome'un PDF görüntüleyicisindeki kalem düğmesinin
/// ekran görüntüsüyle): *"buradaki kalem işaretine basınca biz çıkmıyoruz,
/// Edge falan çıkıyor; biz çıkıp her türlü düzenleme kalem işlerini
/// yapabilmeliyiz ve kolayca kaydedebilmeliyiz."* O düğme Android'e
/// `android.intent.action.ANNOTATE` gönderir; manifest artık bu eylemi
/// karşılıyor ve dosya doğrudan bu ekranda açılıyor (bkz. `MainActivity`).
///
/// Hareketler: tek parmak çizer (ya da silgide siler); **iki parmak her
/// araçta kaydırır ve yakınlaştırır** (2026-09-27, kullanıcı: *"kalemle
/// düzenleme yapılırken sayfayı kaydıramıyorum"* — eskiden iki parmak yalnız
/// yakınlaştırıyordu: InteractiveViewer'ın `panEnabled: false`ı iki parmakla
/// sürüklemeyi de kapatıyordu). Yakınlaşmamışken iki parmakla yukarı/aşağı
/// kaydırmak sayfa çevirir; "Kaydır" aracında tek parmakla da.
///
/// İzler kaydedilince sayfa içeriğine vektör olarak işlenir
/// ([applyPdfMarks]). Dosya başka uygulamanın önbelleğinden geldiyse
/// (kullanıcının göremediği yer) sorulmadan **İndirilenler**'e yazılır;
/// depolamadaki dosyada her zamanki "üzerine yaz / kopya" seçimi çıkar.
class PdfInkScreen extends StatefulWidget {
  const PdfInkScreen({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.testPageSizes,
    this.returnMarks = false,
  });

  final String path;

  /// PDF düzenleyicinin **Çiz** sekmesinden açıldı (Faz 31 kalanı): kaydetmez,
  /// izleri geri verir — düzenleyici onları kendi işlem listesine (geri al /
  /// yinele) tek adım olarak ekler; çalışma kopyası ortak kalır.
  final bool returnMarks;

  /// Düzenleyici için: izler (vazgeçilirse null).
  static Future<List<PdfMark>?> pickMarks(
    BuildContext context,
    String path, {
    int initialPage = 1,
  }) async {
    final r = await Navigator.of(context).push<Object?>(MaterialPageRoute(
      builder: (_) =>
          PdfInkScreen(path: path, initialPage: initialPage, returnMarks: true),
    ));
    return r is List<PdfMark> && r.isNotEmpty ? r : null;
  }

  /// Testler için: pdfium olmadan sayfa ölçüleri (sayfalar düz beyaz çizilir).
  @visibleForTesting
  final List<Size>? testPageSizes;

  /// 1 tabanlı.
  final int initialPage;

  /// Özgün dosyanın üzerine yazıldıysa `true` (açık görüntüleyici tazelensin).
  static Future<bool?> open(
    BuildContext context,
    String path, {
    int initialPage = 1,
  }) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PdfInkScreen(path: path, initialPage: initialPage),
      ));

  @override
  State<PdfInkScreen> createState() => _PdfInkScreenState();
}

class _PdfInkScreenState extends State<PdfInkScreen> {
  static const _penColors = [
    0xFF111111, // siyah
    0xFF1565C0, // mavi
    0xFFD32F2F, // kırmızı
    0xFF2E7D32, // yeşil
  ];
  static const _highlightColors = [
    0xFFFFEB3B, // sarı
    0xFF76FF03, // yeşil
    0xFFFF80AB, // pembe
    0xFF40C4FF, // mavi
  ];

  /// Kalem kalınlıkları (sayfa genişliğine oran): A4'te ≈ 1,2 / 2,4 / 4,8 pt.
  static const _penWidths = [0.002, 0.004, 0.008];

  /// Fosforlu kalınlıkları: A4'te ≈ 8 / 12 / 18 pt (bir satırı örter).
  static const _highlightWidths = [0.014, 0.02, 0.03];

  /// Yazı boyları: A4'te ≈ 10 / 14 / 20 pt.
  static const _textSizes = [0.017, 0.024, 0.034];

  List<PdfMark> _marks = const [];
  final List<List<PdfMark>> _undo = [];
  final List<List<PdfMark>> _redo = [];

  InkTool _tool = InkTool.pen;
  int _penColor = _penColors.first;
  int _highlightColor = _highlightColors.first;
  int _penWidth = 1;
  int _highlightWidth = 1;
  int _textSize = 0;

  late int _page = widget.initialPage - 1;
  final _tx = TransformationController();

  /// Çizilmekte olan darbe (parmak kalkınca [_marks]'a girer).
  InkMark? _live;

  /// Ekrandaki parmak sayısı: ikinci parmak gelirse çizim iptal
  /// (yakınlaştırma hareketi).
  int _pointers = 0;

  /// Silgi sürüklemesi başlamadan önceki durum — tek geri al adımı olsun.
  List<PdfMark>? _eraseStart;

  // ── İki parmak (kaydır + yakınlaştır + sayfa çevir) ─────────────────────
  final _viewportKey = GlobalKey();
  final Map<int, Offset> _touches = {};
  Matrix4? _g0Matrix;
  Offset _g0Focal = Offset.zero;
  double _g0Dist = 1;
  double _g0Scale = 1;

  /// Yakınlaşmamışken parmakların dikey yolu (sayfa çevirme kararı için).
  double _flipDy = 0;
  bool _flipArmed = false;

  /// "Kaydır" aracında tek parmakla sayfa çevirme.
  Offset? _handStart;

  bool _busy = false;

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  // ── Geçmiş ───────────────────────────────────────────────────────────────

  void _commit(List<PdfMark> next, {List<PdfMark>? before}) {
    setState(() {
      _undo.add(before ?? _marks);
      _redo.clear();
      _marks = next;
    });
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_marks);
      _marks = _undo.removeLast();
    });
  }

  void _redoLast() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_marks);
      _marks = _redo.removeLast();
    });
  }

  // ── Çizim ────────────────────────────────────────────────────────────────

  Offset _norm(Offset local, Size fitted) => Offset(
        (local.dx / fitted.width).clamp(0.0, 1.0),
        (local.dy / fitted.height).clamp(0.0, 1.0),
      );

  // ── Yazı ─────────────────────────────────────────────────────────────────

  // ── Kaydetme ─────────────────────────────────────────────────────────────

  // ── Arayüz ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _marks.isEmpty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmLeave();
      },
      child: widget.testPageSizes != null
          ? _scaffold(context, widget.testPageSizes, (_) => const SizedBox())
          : PdfDocumentViewBuilder.file(
              widget.path,
              builder: (context, document) {
                final pages = document?.pages;
                return _scaffold(
                  context,
                  pages == null
                      ? null
                      : [for (final pg in pages) Size(pg.width, pg.height)],
                  (i) => PdfPageView(
                    document: document,
                    pageNumber: i + 1,
                    decoration: const BoxDecoration(color: AppColors.page),
                  ),
                );
              },
            ),
    );
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
