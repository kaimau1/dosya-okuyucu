part of '../viewer_screen.dart';

extension _ViewerScreenDocActionsPart on _ViewerScreenState {
  void _handleImgDoubleTap() {
    if (_imgTx.value != Matrix4.identity()) {
      _imgTx.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      _imgTx.value = Matrix4.identity()
        ..translate(-pos.dx * 2, -pos.dy * 2)
        ..scale(3.0);
    }
  }

  /// Görseli düğmeyle yakınlaştırır/uzaklaştırır (pinch ve çift-dokunmaya ek).
  void _zoomImg(double factor) {
    final current = _imgTx.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 6.0);
    if (target == current) return;
    _imgTx.value = _imgTx.value.clone()..scale(target / current);
  }

  Future<void> _save() async {
    final doc = widget.doc;
    final text = _textController?.text ?? '';
    // Etiketler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    try {
      if (doc.kind == DocKind.text) {
        // Özgün satır sonu geri uygulanıyor (CRLF dosyası CRLF kalsın).
        await _fileService.saveText(
            doc.path, LineEndings.apply(text, _lineEnding));
        _dirty = false;
        _snack(str.t('common.saved'));
      } else {
        // Word/Slayt: özgün formata güvenli yazım yerine dışa aktarma öner.
        await _exportPdf();
      }
    } catch (e) {
      _snack(str.t('common.save_failed', {'error': e}));
    }
    if (mounted) _partSetState(() {});
  }

  Future<void> _exportPdf() async {
    // Etiket await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final exportedLabel = context.t('vw.pdf_exported');
    // Görselde plainText boştur: metin yoluna sokulursa PDF'e "(Boş belge)"
    // yazılıp resim tamamen kaybolurdu — görsel kendi yolundan gider.
    if (widget.doc.kind == DocKind.image) {
      await _exportImagePdf();
      return;
    }
    final text = _textController?.text ?? widget.doc.plainText;
    final bytes = await _conversion.textToPdf(widget.doc.name, text);
    final path = await _conversion.writeToTemp(
      '${_stem(widget.doc.name)}.pdf',
      bytes,
    );
    await Share.shareXFiles([XFile(path)], text: exportedLabel);
  }

  /// Görseli tam çözünürlükte PDF'e gömer; istenirse OCR ile görünmez metin
  /// katmanı ekleyip PDF'i aranabilir yapar.
  Future<void> _exportImagePdf() async {
    final pdfPreparing = context.t('vw.pdf_preparing');
    final withOcr = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('vw.image_to_pdf')),
        content: Text(
            context.t('vw.image_to_pdf_body') + context.t('vw.ocr_in_pdf')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('vw.image_only')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('vw.ocr_also')),
          ),
        ],
      ),
    );
    if (withOcr == null || !mounted) return;

    // Canlı süre satırı + uzun sürerse ana ekran şeridi ve bildirim (bkz.
    // `widgets/tracked_busy.dart`).
    final busy = showTrackedBusy(
      context,
      title: pdfPreparing,
      name: context.t('vw.image_pdf_job_name'),
      message: withOcr ? context.t('vw.scanning_text') : pdfPreparing,
    );

    String? path;
    String? error;
    try {
      final lines = withOcr
          ? await OcrService.recognizeImageLines(widget.doc.path)
          : const <OcrLine>[];
      busy.status(pdfPreparing);
      final bytes =
          await _conversion.imageToPdf(widget.doc.path, ocrLines: lines);
      path =
          await _conversion.writeToTemp('${_stem(widget.doc.name)}.pdf', bytes);
    } catch (e) {
      error = '$e';
    }
    if (error != null) {
      await busy.failed(error);
    } else {
      await busy.done(detail: p.basename(path!));
    }
    if (!mounted) return;

    if (error != null) {
      _snack(context.t('vw.pdf_failed', {'error': error}));
      return;
    }
    await Share.shareXFiles([XFile(path!)], text: context.t('vw.pdf_exported'));
  }

  /// Belgeyi **düzenlenebilir bir sunuma** (.pptx) çevirir.
  ///
  /// Eskiden çıktı PDF'ti (`textToSlidesPdf`); "PDF'ten slayta" isteğinin
  /// karşılığı düzenlenebilir bir dosyadır, o yüzden gerçek .pptx üretiliyor.
  /// Dosya hem bizim slayt düzenleyicimizde hem PowerPoint'te açılır.
  ///
  /// Metin `_documentText`ten geliyor: eski hâli `_textController?.text ??
  /// doc.plainText` idi ve PDF'te ikisi de BOŞTU (PDF metin türü değil, metni
  /// `_pdfText`te duruyor) — yani asıl hedef olan PDF'te boş deste üretiyordu.
  /// Belgeyi sunuma çevirir: **AI ile** (okuyup özetleyerek) ya da hızlı
  /// sezgiyle; çıktı .pptx (düzenlenebilir) ya da PDF deste.
  ///
  /// Metin `_documentText`ten geliyor: eski hâli `_textController?.text ??
  /// doc.plainText` idi ve PDF'te ikisi de BOŞTU (PDF metin türü değil, metni
  /// `_pdfText`te durur) — yani asıl hedef olan PDF'te boş deste üretiyordu.
  Future<void> _exportSlides() async {
    await _ensurePdfText();
    if (!mounted) return;
    await AiSlidesFlow.run(context, _documentText, fileName: widget.doc.name);
  }

  /// Paylaş / yazdır: PDF'te GÖRÜLEN hâli gönderilir — bekleyen düzenlemeler
  /// çalışma kopyasındadır, özgün dosya henüz eski hâlindedir.
  /// Dosyayı İndirilenler'e kopyalar. Bekleyen düzenleme varsa önce sorulur
  /// (kaydedilmeyen işaretler kopyaya girmezdi).
  Future<void> _download() async {
    if (!await _confirmLeavePending() || !mounted) return;
    if (_dirty && widget.doc.isEditableText) await _save();
    if (!mounted) return;
    await runDownloadAction(
        context, () => SaveToDownloads.saveFile(widget.doc.path));
  }

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.doc.path)]);
  }

  Future<void> _print() async {
    if (widget.doc.kind == DocKind.pdf) {
      final bytes = await _fileService.readBytes(widget.doc.path);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final bytes = await _conversion.textToPdf(
        widget.doc.name,
        _textController?.text ?? widget.doc.plainText,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }

  /// PDF'in metin katmanını GEREKİNCE çıkarır (Faz 4, P4) — AI sohbeti,
  /// sunuma çevirme, çeviri örneği, sesli okuma ve AI düzenleme bunu
  /// `_documentText`i okumadan önce bekler. Bir kez çıkarılır.
  Future<void> _ensurePdfText() async {
    final doc = _pdfDoc;
    if (!_isPdf || doc == null || _pdfText.isNotEmpty) return;
    await _extractPdfText(doc);
  }

  /// PDF sayfalarının metnini çıkarır (AI sohbet bağlamı için).
  /// Taranmış/metinsiz PDF'te sessizce boş kalır — görüntüleme etkilenmez.
  ///
  Future<void> _extractPdfText(PdfDocument document) async {
    if (_pdfText.isNotEmpty) return;
    try {
      final sb = StringBuffer();
      for (final page in document.pages) {
        // dynamic: loadText dönüşü sürümler arasında nullable/nonnull değişti;
        // her iki imzayla da derlensin.
        final dynamic t = await page.loadText();
        final full = t == null ? '' : (t.fullText as String? ?? '');
        if (full.trim().isNotEmpty) sb.writeln(full);
        if (sb.length > 100000) break; // AI bağlamı için fazlası gereksiz
      }
      _pdfText = sb.toString().trim();
    } catch (_) {}
  }

  /// Belgenin okunabilir metni: PDF'te metin katmanı, görselde OCR sonucu,
  /// diğerlerinde ham içerik. AI bağlamı ve çeviri aynı kaynağı kullanır.
  String get _documentText {
    if (widget.doc.kind == DocKind.pdf && _pdfText.isNotEmpty) return _pdfText;
    if (widget.doc.kind == DocKind.image && _ocrImageText.isNotEmpty) {
      return _ocrImageText;
    }
    return _textController?.text ?? widget.doc.plainText;
  }

  /// AI sohbeti — PDF'te okunan sayfa odak bağlamı olarak gider (uzun
  /// kitapta bağlam belgenin başından kesiliyordu; soru çoğu zaman bu sayfa).
  Future<void> _openChat() async {
    String? focus;
    // Etiket await'ten ÖNCE (asenkron boşluktan sonra `context` kullanılmaz).
    final label = context.t('chat.page_label', {'n': _pdfPage});
    final doc = _pdfDoc;
    if (_isPdf && doc != null && _pdfPage >= 1 && _pdfPage <= doc.pages.length) {
      try {
        final text = await doc.pages[_pdfPage - 1].loadText();
        focus = text.fullText;
      } catch (_) {}
    }
    await _ensurePdfText();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        fileContext: _documentText,
        fileName: widget.doc.name,
        focusText: focus,
        focusLabel: label,
      ),
    ));
  }

  /// Tüm belgeyi cihaz-içi çevirir. Metin katmanı olmayan taranmış PDF'te
  /// önce OCR gerekir (kullanıcı menüden "Metni tanı" ile çalıştırır).
  /// Belge açıkken dosya işlemleri (taşı / kopyala / paylaş / yeniden
  /// adlandır / sil) — dosya yöneticisiyle AYNI sayfa kullanılır, iki yerde
  /// ayrı menü tutmak tutarsızlığa yol açardı.
  Future<void> _fileActions() async {
    await showEntryActions(
      context,
      FsEntry.fromEntity(File(widget.doc.path)),
    );
  }

  /// **Tek düğme çeviri** (istek 2026-07-31): metin nereden gelirse gelsin
  /// kullanıcı ayrıca OCR çalıştırmaz.
  ///
  /// - PDF: her sayfa için önce metin katmanı, boşsa OCR (bkz.
  ///   [DocTranslate.collectPdfPages]) → sayfa yapısı korunarak çevrilir.
  /// - Görsel: OCR (bir kez tanındıysa sonucu yeniden kullanılır).
  /// - Diğer belgeler: zaten yüklü olan metin.
  Future<void> _translateDocument() async {
    final doc = widget.doc;
    if (doc.kind == DocKind.pdf) {
      final pdf = _pdfDoc;
      if (pdf == null) {
        _snack(context.t('vw.pdf_loading'));
        return;
      }
      // **İki farklı iş, ikisi de "çeviri"** (kullanıcı 2026-08-30): biri
      // okumak/kopyalamak için metin, öteki *belgenin kendisi* hedef dilde.
      // Hangisinin istendiği belgeden anlaşılamaz — soruyoruz.
      final inPlace = await _askTranslateMode();
      if (inPlace == null || !mounted) return;
      await _ensurePdfText();
      if (!mounted) return;
      if (inPlace) {
        // Bekleyen düzenleme varsa önce çözülür: çeviri DİSKTEKİ baytları
        // okuyor, kaydedilmemiş bir düzeltme sessizce kaybolmasın.
        if (!await _confirmLeavePending() || !mounted) return;
        final bytes = await _fileService.readBytes(widget.doc.path);
        if (!mounted) return;
        await TranslateFlow.runPdfInPlace(
          context,
          path: widget.doc.path,
          bytes: bytes,
          pageCount: pdf.pages.length,
          sampleText: _pdfText.length > 3000
              ? _pdfText.substring(0, 3000)
              : _pdfText,
        );
        return;
      }
      await TranslateFlow.runDocument(
        context,
        title: doc.name,
        sample: _pdfText.length > 3000 ? _pdfText.substring(0, 3000) : _pdfText,
        load: (progress) => DocTranslate.collectPdfPages(
          pdf,
          onLayer: (done, total) => progress.status(
              context.t('tf.page_reading', {'n': done + 1, 'total': total})),
          onOcr: (done, total) => progress.status(
              context.t('tf.page_ocr', {'n': done + 1, 'total': total})),
          cancelled: () => progress.cancelled,
        ),
      );
      return;
    }
    if (doc.kind == DocKind.image) {
      await TranslateFlow.runDocument(
        context,
        title: doc.name,
        load: (progress) async {
          if (_ocrImageText.trim().isNotEmpty) {
            return [OcrPage(1, _ocrImageText.trim())];
          }
          progress.status(context.t('vw.ocr_running'));
          final text = await OcrService.recognizeImageFile(doc.path);
          if (text.trim().isEmpty) return const <OcrPage>[];
          // Tanınan metin ekranda da kalsın: AI sohbeti ve "Metni tanı"
          // sayfası aynı sonucu yeniden taramasın.
          if (mounted) _partSetState(() => _ocrImageText = text);
          return [OcrPage(1, text.trim())];
        },
      );
      return;
    }
    final text = _documentText.trim();
    if (text.isEmpty) {
      _snack(context.t('vw.no_text_to_translate'));
      return;
    }
    await TranslateFlow.run(context, text, title: doc.name);
  }

  /// "Belgenin kendisi mi, metin mi?" — PDF çevirisinde tek soru.
  ///
  /// Vazgeçilirse null; true = yerinde (düzeni koruyan) çeviri.
  Future<bool?> _askTranslateMode() => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('tf.mode_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(ctx.t('tf.mode_inplace')),
                subtitle: Text(ctx.t('tf.mode_inplace_hint')),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subject),
                title: Text(ctx.t('tf.mode_text')),
                subtitle: Text(ctx.t('tf.mode_text_hint')),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel')),
            ),
          ],
        ),
      );

  bool get _hasText =>
      (_textController?.text.trim().isNotEmpty ?? false) ||
      widget.doc.plainText.trim().isNotEmpty;

  /// Sözcük/karakter/satır/paragraf sayısını gösteren bilgi kutusu.
  void _showStats() {
    final text = _textController?.text ?? widget.doc.plainText;
    final s = TextStats.of(text);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.t('vw.doc_info')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(context.t('vw.word'), s.words),
            _statRow(context.t('vw.chars'), s.characters),
            _statRow(context.t('vw.chars_nospace'), s.charactersNoSpaces),
            _statRow(context.t('vw.line'), s.lines),
            _statRow(context.t('vw.paragraph'), s.paragraphs),
            // **Satır sonu biçimi** (2026-09-06): Windows'tan gelen bir
            // dosyayı düzenleyen kullanıcı, kaydettiğinde dosyanın tamamının
            // "değişmiş" görünmesinin sebebini burada görüyor. Biçim
            // korunuyor (bkz. `core/line_endings.dart`), bu satır da neyin
            // korunduğunu söylüyor.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.t('vw.line_ending')),
                  Text(switch (_lineEnding) {
                    LineEnding.crlf => 'CRLF (Windows)',
                    LineEnding.cr => 'CR',
                    LineEnding.lf => 'LF (Unix)',
                  }),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            const SizedBox(width: 24),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? name : name.substring(0, dot);
  }
}
