import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/copy_text.dart';
import '../core/l10n/app_strings.dart';
import '../services/pdf/pdf_ocr_text.dart';

/// **Okuma görünümü** — PDF'i (taranmış olsa bile) bir e-kitap gibi sunar
/// (2026-08-06 kullanıcı isteği: *"tarandıktan sonra PDF'i okutmak
/// istediğimizde iyi bir e-kitap gibi okuyacak sistem kurmalıyız"*).
///
/// Sayfa görüntüsü yerine sayfanın **metni** akar: yazılmış PDF'te pdfium
/// metni, taranmış PDF'te cihaz-içi OCR ([PdfOcrText] — önbellekli, ücretsiz,
/// çevrimdışı). Metin [cleanPdfCopyText] ile toparlanır (satır kırıkları
/// birleşir, görünmez karakterler atılır) — kitap sayfası gibi okunur.
///
/// Punto büyütülüp küçültülebilir; zemin üçlüsü (açık/sepya/koyu) e-kitap
/// okuyucuların bilinen düzeni. Metin seçilebilir (kopyala/paylaş serbest).
class ReaderScreen extends StatefulWidget {
  final PdfDocument document;
  final String title;

  const ReaderScreen({super.key, required this.document, required this.title});

  static Future<void> open(
    BuildContext context, {
    required PdfDocument document,
    required String title,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReaderScreen(document: document, title: title),
      ));

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _ReaderTheme { light, sepia, dark }

class _ReaderScreenState extends State<ReaderScreen> {
  static const _minFont = 13.0, _maxFont = 30.0;

  /// Oturum içi hatırlanan tercihler (ekran kapanıp açılınca korunur;
  /// uygulama yeniden başlayınca varsayılana döner — kalıcılaştırmak istenirse
  /// AppState'e taşınır).
  static double _fontSize = 17;
  static _ReaderTheme _theme = _ReaderTheme.sepia;

  /// Sayfa metinleri (null = yüklenemedi/boş). Ekran ömrünce tutulur;
  /// OCR zaten `PdfOcrText` önbelleğinde, burası ikinci kez sormamak için.
  final _texts = <int, String?>{};
  final _loading = <int, Future<String?>>{};

  Future<String?> _textFor(int pageNumber) {
    if (_texts.containsKey(pageNumber)) {
      return Future.value(_texts[pageNumber]);
    }
    return _loading[pageNumber] ??= _load(pageNumber);
  }

  Future<String?> _load(int pageNumber) async {
    String text = '';
    try {
      final page = widget.document.pages[pageNumber - 1];
      text = (await page.loadText()).fullText;
      // "İnce" metin (yalnız sayfa numarası gibi kırıntılar) = taranmış
      // sayfa → OCR (seçim katmanıyla aynı eşik ve aynı önbellek).
      if (text.trim().length < 8 && PdfOcrText.isSupported) {
        final ocr = await PdfOcrText.forPage(page);
        if (ocr != null) text = ocr.fullText;
      }
    } catch (_) {}
    final clean = cleanPdfCopyText(text);
    final result = clean.isEmpty ? null : clean;
    _texts[pageNumber] = result;
    _loading.remove(pageNumber);
    return result;
  }

  (Color bg, Color fg) get _colors => switch (_theme) {
        _ReaderTheme.light => (Colors.white, const Color(0xFF1F1F1F)),
        _ReaderTheme.sepia =>
          (const Color(0xFFF6EFDF), const Color(0xFF453A28)),
        _ReaderTheme.dark =>
          (const Color(0xFF121212), const Color(0xFFD5D5D5)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    final pageCount = widget.document.pages.length;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.t('vw.text_smaller'),
            icon: const Icon(Icons.text_decrease),
            onPressed: _fontSize <= _minFont
                ? null
                : () => setState(() => _fontSize =
                    (_fontSize - 2).clamp(_minFont, _maxFont)),
          ),
          IconButton(
            tooltip: context.t('vw.text_bigger'),
            icon: const Icon(Icons.text_increase),
            onPressed: _fontSize >= _maxFont
                ? null
                : () => setState(() => _fontSize =
                    (_fontSize + 2).clamp(_minFont, _maxFont)),
          ),
          PopupMenuButton<_ReaderTheme>(
            tooltip: context.t('reader.theme'),
            icon: const Icon(Icons.palette_outlined),
            onSelected: (t) => setState(() => _theme = t),
            itemBuilder: (_) => [
              _themeItem(_ReaderTheme.light, context.t('reader.theme_light')),
              _themeItem(_ReaderTheme.sepia, context.t('reader.theme_sepia')),
              _themeItem(_ReaderTheme.dark, context.t('reader.theme_dark')),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        itemCount: pageCount,
        itemBuilder: (context, i) => _pageItem(context, i + 1, fg),
      ),
    );
  }

  PopupMenuItem<_ReaderTheme> _themeItem(_ReaderTheme value, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(_theme == value ? Icons.check : null, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );

  Widget _pageItem(BuildContext context, int pageNumber, Color fg) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: fg.withValues(alpha: 0.25))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              context.t('tf.page_header', {'n': pageNumber}),
              style: TextStyle(
                  color: fg.withValues(alpha: 0.55), fontSize: 12),
            ),
          ),
          Expanded(child: Divider(color: fg.withValues(alpha: 0.25))),
        ],
      ),
    );
    return FutureBuilder<String?>(
      future: _textFor(pageNumber),
      builder: (context, snap) {
        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: fg.withValues(alpha: 0.5)),
              ),
            ),
          );
        } else if (snap.data == null) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.t('reader.page_empty'),
              style: TextStyle(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: _fontSize - 2,
                  fontStyle: FontStyle.italic),
            ),
          );
        } else {
          body = SelectableText(
            snap.data!,
            style: TextStyle(
              color: fg,
              fontSize: _fontSize,
              height: 1.55,
              fontFamily: 'Tinos', // kitap hissi: gömülü serif (OFL)
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (pageNumber > 1) divider, body],
        );
      },
    );
  }
}
