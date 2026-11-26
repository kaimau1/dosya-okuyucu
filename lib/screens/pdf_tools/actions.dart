part of '../pdf_tools_screen.dart';

extension _PdfToolsScreenActionsPart on _PdfToolsScreenState {
  Future<void> _load() async {
    try {
      // Faz 42 / 2 (anayasa k.10): araçlar belgeyi bayt olarak tutar; bütçe
      // üstü PDF'te bellek öldürmesi yerine açıklayıcı hata (görüntüleyici
      // pdfium ile dosyadan akışla okur, orada sınır yok).
      final size = File(widget.path).lengthSync();
      final max = DeviceProfile.budget.pdfInMemoryMaxBytes;
      if (size > max) {
        if (mounted) {
          _partSetState(() => _error = _str.t(
              'lf.pdf_too_big', {'mb': size >> 20, 'max': max >> 20}));
        }
        return;
      }
      final bytes = await File(widget.path).readAsBytes();
      // Şifreli belge: sayfa sayısı okunamıyorsa parola sor.
      try {
        await PdfTools.pageCount(bytes);
      } catch (_) {
        if (!mounted) return;
        final pw = await _askPassword(
            _str.t('pt.locked_title'), _str.t('pt.enter_password'));
        if (pw == null || !mounted) {
          if (mounted) popOwnPage(context);
          return;
        }
        await PdfTools.pageCount(bytes, password: pw);
        _password = pw;
      }
      // Pro araçlar bayrağı — dosya okunurken (açılışta değil, k.2).
      final pro = (await SharedPreferences.getInstance())
              .getBool(_PdfToolsProPart.flagKey) ??
          true;
      if (!mounted) return;
      _partSetState(() {
        _bytes = bytes;
        _proEnabled = pro;
      });
      if (widget.openStudio) await _reorderPages();
    } catch (e) {
      if (mounted) _partSetState(() => _error = userErrorText(e));
    }
  }

  /// Tüm işlemlerin tek kapısı: yeni baytı üretir, geri almayı besler, önizlemeyi
  /// tazeler. Hata olursa belge dokunulmadan kalır.
  ///
  /// [op] artık **arka plan isolate'inde** koşan `…InBackground` sürümlerini
  /// çağırır; ana izlek boş kalır, ekran donmaz ve [_busyLabel] süreci gösterir.
  Future<void> _apply(
    String label,
    Future<List<int>> Function(Uint8List bytes) op,
  ) async {
    final current = _bytes;
    if (current == null || _busy) return;
    _partSetState(() => _busyLabel = '$label…');
    // 1,5 sn'yi geçen işlem (büyük PDF'i sıkıştırma/birleştirme) ana ekran
    // şeridinde ve bildirimde de görünür; uygulamadan çıkılırsa ön plan
    // servisi işi korur (bkz. `TrackedTask`).
    final task = TrackedTask(
      title: '$label…',
      name: _str.t('pt.job_name', {'label': label}),
    );
    task.report(detail: p.basename(widget.path));
    _task = task;
    bool watched() => TrackedTask.userWatching;
    try {
      final out = Uint8List.fromList(await op(current));
      await task.complete(quiet: watched());
      if (!mounted) return;
      _partSetState(() {
        _undo.add(current);
        if (_undo.length > 5) _undo.removeAt(0);
        _bytes = out;
        _dirty = true;
        _rev++;
      });
      _selection.value = <int>{};
    } on JobCancelled {
      await task.stopped(quiet: watched());
      if (mounted) _snack(_str.t('pt.op_stopped', {'label': label}));
    } catch (e) {
      await task.fail(e, quiet: watched());
      if (mounted) {
        // Hata metni KOPYALANABİLİR: kullanıcı ekran görüntüsü almadan
        // aktarabilsin (2026-09-04).
        _snackError(_str.t('pt.op_failed', {'label': label, 'error': userErrorText(e)}));
      }
    } finally {
      _endTask();
    }
  }

  /// İş bitti: bekleme kartı kalkar, ilerleme/durdurma durumu sıfırlanır.
  void _endTask() {
    _task = null;
    _stop = false;
    _cancellable = false;
    if (mounted) _partSetState(() => _busyLabel = '');
  }

  /// Sayfa sayfa ilerleyen ağır iş başlarken çağrılır: kartta Durdur görünür.
  void _beginCancellable() {
    _cancellable = true;
    if (mounted) _partSetState(() {});
  }

  /// Durdur istendi mi (kart düğmesi ya da şerit/bildirim "Durdur").
  bool _stopAsked() => _stop || (_task?.cancelRequested ?? false);

  /// Ağır işte "Etiket… 12/80" ilerlemesi (kart + iş kaydı).
  void _progress(String label, int done, int total) {
    _task?.report(done: done, total: total);
    if (mounted && _busy) {
      _partSetState(() => _busyLabel = '$label… $done/$total');
    }
  }

  /// Kopyalanabilir hata şeridi (uzun teknik mesajlar için).
  void _snackError(String message) =>
      showSnack(context, message, copyable: true);

  Future<int> _pageCount() =>
      PdfTools.pageCount(_bytes!, password: _password);

  /// **Sayfa numarası ekle** (2026-08-28).
  ///
  /// Seçenekler tek bir kısa sayfada: kapağı atla, "n / toplam" yaz, sağa
  /// hizala. Varsayılanlar en sık istenen hâl (ortada, 1'den, sade sayı) —
  /// kullanıcı hiçbir şeye dokunmadan "Ekle" diyebilmeli.
  Future<void> _addPageNumbers() async {
    final options = await showModalBottomSheet<_NumberOptions>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PageNumberSheet(),
    );
    if (options == null || !mounted) return;
    final pw = _password;
    await _apply(
      _str.t('pt.op_page_numbers'),
      (b) => PdfTools.addPageNumbersInBackground(
        b,
        password: pw,
        skipFirstPage: options.skipFirst,
        startAt: options.skipFirst ? 2 : 1,
        withTotal: options.withTotal,
        position: options.right
            ? PdfTools.numberBottomRight
            : PdfTools.numberBottomCenter,
      ),
    );
  }

  /// **Filigran (damga) ekle** (2026-08-28).
  ///
  /// Yazı tipi baytları ASSET'ten geçiliyor: gömülü standart PDF fontları
  /// WinAnsi kodlamasında ve `ş/ğ/ı/İ` orada YOK — "BAŞLIK" bozuk çıkardı.
  /// Font okunamazsa işlem iptal edilmez, standart fonta düşülür.
  Future<void> _addWatermark() async {
    final text = await _askText(
        _str.t('pt.watermark'), _str.t('pt.watermark_hint'));
    if (text == null || text.trim().isEmpty || !mounted) return;
    List<int>? fontBytes;
    try {
      final data = await rootBundle.load('assets/fonts/Carlito-Bold.ttf');
      fontBytes = data.buffer.asUint8List();
    } catch (_) {
      fontBytes = null;
    }
    if (!mounted) return;
    final pw = _password;
    await _apply(
      _str.t('pt.op_watermark'),
      (b) => PdfTools.addWatermarkInBackground(b,
          text: text, password: pw, fontBytes: fontBytes),
    );
  }

  /// **Sayfaları görsel (PNG) olarak dışa aktar** (2026-08-28).
  ///
  /// "PDF'i JPG yap" bir PDF aracından en çok istenen dönüşümlerden biri
  /// (sunum/sosyal medya/mesajla gönderme). Belge zaten pdfrx ile açık
  /// olduğundan yeni bir bağımlılık gerekmedi; render `OcrService`in
  /// kullandığı yolun aynısı (1600 px genişliğe ölçekli).
  ///
  /// Seçili sayfa varsa yalnız onlar, yoksa tüm belge. **Sınır 30 sayfa:**
  /// her sayfa tam boyutlu bir bitmap; 300 sayfalık bir kitabı tek seferde
  /// açmak belleği şişirir ve paylaşım penceresi zaten o kadar dosyayı
  /// taşıyamaz. Aşarsa kullanıcıya sayfa seçmesi söylenir.
  Future<void> _exportImages() async {
    final bytes = _bytes;
    if (bytes == null || _busy) return;
    final total = await _pageCount();
    if (!mounted) return;
    final pages = _selected.isEmpty
        ? List.generate(total, (i) => i)
        : (_selected.toList()..sort());
    if (pages.length > 30) {
      _snack(_str.t('pt.export_images_limit', {'n': 30}));
      return;
    }
    _partSetState(() => _busyLabel = '${_str.t('pt.op_export_images')}…');
    final password = _password;
    try {
      final document = await PdfDocument.openData(
        bytes,
        passwordProvider: password == null ? null : () async => password,
      );
      final files = <XFile>[];
      try {
        for (final index in pages) {
          final rendered = await OcrService.renderPageToPng(
              document.pages[index],
              tag: 'export');
          if (rendered == null) continue;
          // Paylaşım penceresinde dosya adı görünüyor: "belge-3.png" gibi
          // anlamlı olsun, "ocr_page_export_3.png" değil.
          final name =
              '${p.basenameWithoutExtension(widget.path)}-${index + 1}.png';
          final target = File(p.join(
              Directory.systemTemp.path, name));
          await File(rendered.path).rename(target.path);
          files.add(XFile(target.path));
        }
      } finally {
        await document.dispose();
      }
      if (files.isEmpty) {
        if (mounted) _snack(_str.t('pt.export_images_failed'));
        return;
      }
      await SharePlus.instance.share(ShareParams(files: files, text: _str.t('pt.export_images_count', {'n': files.length})));
    } catch (e) {
      if (mounted) {
        _snack(_str.t('pt.op_failed',
            {'label': _str.t('pt.op_export_images'), 'error': userErrorText(e)}));
      }
    } finally {
      if (mounted) _partSetState(() => _busyLabel = '');
    }
  }

  /// Sayfa kopyalayan işlemler vurguları taşıyamaz — kullanıcı bilmeden
  /// kaybetmesin diye yalnız belgede vurgu VARSA sorulur.
  Future<bool> _confirmAnnotationLoss(String action) async {
    final count = await PdfTools.annotationCount(_bytes!, password: _password);
    if (count == 0 || !mounted) return count == 0;
    final ok = await showAppConfirm(
        context,
        title: context.t('pt.annot_title'),
        message: context.t('pt.annot_body', {'n': count, 'action': action}),
        confirmLabel: context.t('pt.continue'),
    );
    return ok;
  }

  /// Tüm sayfaları seçer / seçimi kaldırır.
  Future<void> _selectAll() async {
    final total = await _pageCount();
    if (!mounted) return;
    _selection.value = _selected.length == total
        ? <int>{}
        : {for (var i = 0; i < total; i++) i};
  }

  /// Seçimi tersine çevirir ("üç sayfa hariç hepsini sil" için tek dokunuş).
  Future<void> _invertSelection() async {
    final total = await _pageCount();
    if (!mounted) return;
    _selection.value = {
      for (var i = 0; i < total; i++)
        if (!_selected.contains(i)) i,
    };
  }

  /// Sıkıştırma: **önce onay, sonra arka planda**.
  ///
  /// 2026-07-26 kullanıcı bulgusu: "sıkıştır denince donma". Kök neden
  /// Syncfusion'ın belgeyi ana izlekte baştan yazmasıydı (bkz.
  /// [PdfTools.compressInBackground]). Ayrıca ne olacağı önceden söylenmiyordu:
  /// taranmış belgede kazanç küçüktür, kullanıcı bunu beklemeden bilmeli.
  Future<void> _compress() async {
    final before = _bytes!.length;
    final ok = await showAppConfirm(
        context,
        title: context.t('pt.compress_title'),
        message: context.t('pt.compress_body', {'size': _kb(before)}),
        confirmLabel: context.t('pt.compress'),
    );
    if (ok != true || !mounted) return;
    final pw = _password;
    await _apply(_str.t('pt.op_compress'),
        (b) => PdfTools.compressInBackground(b, password: pw));
    if (!mounted) return;
    final after = _bytes!.length;
    _snack(after < before
        ? _str.t('pt.size_change',
            {'before': _kb(before), 'after': _kb(after)})
        : _str.t('pt.already_compact', {'size': _kb(before)}));
  }

  Future<void> _setPassword() async {
    final pw = await _askPassword(
        _str.t('pt.set_password'), _str.t('pt.new_password'));
    if (pw == null || pw.isEmpty) return;
    final current = _password;
    await _apply(
      _str.t('pt.op_set_password'),
      (b) => PdfTools.setPasswordInBackground(b,
          password: pw, currentPassword: current),
    );
    if (mounted) _partSetState(() => _password = pw);
  }

  Future<void> _removePassword() async {
    final pw = _password;
    if (pw == null) return;
    await _apply(_str.t('pt.op_remove_password'),
        (b) => PdfTools.removePasswordInBackground(b, currentPassword: pw));
    if (mounted) _partSetState(() => _password = null);
  }

  /// Kaydet — **üzerine yaz** ya da **kopyasını kaydet**.
  ///
  /// Kopya kaydedilirse ekran o dosyayı düzenlemeye devam etmez: özgün belge
  /// açık kalır (çağıran görüntüleyici hâlâ onu gösteriyor), kullanıcıya yeni
  /// dosyanın adı söylenir.
  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || !_dirty) return;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.path,
      bytes: bytes,
    );
    if (outcome == null || !mounted) return;
    // Kopya kaydedildiyse ekrandaki belge hâlâ özgün dosya: "kaydedilmemiş
    // değişiklik" durumu sürüyor demektir.
    _partSetState(() => _dirty = !outcome.overwritten);
  }

  Future<void> _share() async {
    if (_bytes == null) return;
    final path = await _conversion.writeToTemp(
        p.basename(widget.path), _bytes!);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'PDF'));
  }

  /// Ekrandaki (düzenlenmiş, kaydedilmemiş olabilir) belgeyi sistem
  /// yazdırma penceresine verir (B4/P21).
  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      await Printing.layoutPdf(
          onLayout: (_) async => bytes, name: p.basename(widget.path));
    } catch (e) {
      if (mounted) _snackError(userErrorText(e));
    }
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    _partSetState(() {
      _bytes = _undo.removeLast();
      _dirty = true;
      _rev++;
    });
    _selection.value = <int>{};
  }

  Future<String?> _askPassword(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    );
  }

  /// [_askPassword]'ün görünür metin karşılığı (filigran yazısı gibi).
  Future<String?> _askText(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(ctx.t('common.ok'))),
        ],
      ),
    );
  }

  String _kb(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).round()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.unsaved_title')),
        content: Text(ctx.t('pt.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('pt.stay'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.leave'))),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Kaydedilmemiş değişiklikle geri tuşu: onay al, sonra kapat.
  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final leave = await _confirmLeave();
    if (!mounted || !leave) return;
    Navigator.of(context).pop(false);
  }
}
