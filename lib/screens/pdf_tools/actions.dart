part of '../pdf_tools_screen.dart';

extension _PdfToolsScreenActionsPart on _PdfToolsScreenState {
  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      // Şifreli belge: sayfa sayısı okunamıyorsa parola sor.
      try {
        await PdfTools.pageCount(bytes);
      } catch (_) {
        final pw = await _askPassword(
            _str.t('pt.locked_title'), _str.t('pt.enter_password'));
        if (pw == null) {
          if (mounted) popOwnPage(context);
          return;
        }
        await PdfTools.pageCount(bytes, password: pw);
        _password = pw;
      }
      if (!mounted) return;
      _partSetState(() => _bytes = bytes);
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
    } catch (e) {
      await task.fail(e, quiet: watched());
      if (mounted) {
        // Hata metni KOPYALANABİLİR: kullanıcı ekran görüntüsü almadan
        // aktarabilsin (2026-09-04).
        _snackError(_str.t('pt.op_failed', {'label': label, 'error': userErrorText(e)}));
      }
    } finally {
      if (mounted) _partSetState(() => _busyLabel = '');
    }
  }

  /// Kopyalanabilir hata şeridi (uzun teknik mesajlar için).
  void _snackError(String message) =>
      showSnack(context, message, copyable: true);

  Future<int> _pageCount() =>
      PdfTools.pageCount(_bytes!, password: _password);

  Future<void> _rotate() async {
    final pages = _selected.isEmpty
        ? List.generate(await _pageCount(), (i) => i)
        : _selected.toList();
    final pw = _password;
    await _apply(
      _str.t('pt.op_rotate'),
      (b) => PdfTools.rotatePagesInBackground(b,
          pageIndexes: pages, quarterTurns: 1, password: pw),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.length >= await _pageCount()) {
      _snack(_str.t('pt.cannot_delete_all'));
      return;
    }
    final pages = _selected.toList();
    final pw = _password;
    await _apply(_str.t('pt.op_delete'),
        (b) => PdfTools.deletePagesInBackground(b, pages, password: pw));
  }

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
    if (options == null) return;
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
    if (text == null || text.trim().isEmpty) return;
    List<int>? fontBytes;
    try {
      final data = await rootBundle.load('assets/fonts/Carlito-Bold.ttf');
      fontBytes = data.buffer.asUint8List();
    } catch (_) {
      fontBytes = null;
    }
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
      await Share.shareXFiles(files,
          text: _str.t('pt.export_images_count', {'n': files.length}));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.annot_title')),
        content:
            Text(ctx.t('pt.annot_body', {'n': count, 'action': action})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.continue'))),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Seçili sayfaları **yeni bir PDF** olarak paylaşır (böl / sayfa çıkar).
  Future<void> _extractSelected() async {
    if (_selected.isEmpty || _bytes == null) return;
    final pages = _selected.toList()..sort();
    final str = _str;
    _partSetState(() => _busyLabel = str.t('pt.extracting'));
    try {
      final out = await PdfTools.selectPagesInBackground(_bytes!, pages,
          password: _password);
      final name = '${p.basenameWithoutExtension(widget.path)}'
          '_sayfa${pages.length == 1 ? pages.first + 1 : '${pages.length}'}.pdf';
      final path =
          await _conversion.writeToTemp(name, Uint8List.fromList(out));
      await Share.shareXFiles([XFile(path)],
          text: str.t('pt.extracted'));
    } catch (e) {
      if (mounted) _snack(str.t('pt.extract_failed', {'error': userErrorText(e)}));
    } finally {
      if (mounted) _partSetState(() => _busyLabel = '');
    }
  }

  /// Tek seçili sayfayı bir sıra öne/arkaya taşır.
  ///
  /// ponytail: sürükle-bırak yerine ok düğmeleri — çok daha az kod, aynı iş.
  /// Uzun belgede sıkıcı olursa `ReorderableGridView` benzeri bir çözüme geç.
  Future<void> _move(int delta) async {
    if (_selected.length != 1) return;
    final from = _selected.first;
    final total = await _pageCount();
    final to = from + delta;
    if (to < 0 || to >= total) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_move_page'))) return;
    final order = movePageOrder(total, from, to);
    final pw = _password;
    await _apply(_str.t('pt.op_move'),
        (b) => PdfTools.selectPagesInBackground(b, order, password: pw));
    if (mounted) _selection.value = {to};
  }

  /// **Sayfayı istenen konuma taşı** (kullanıcı isteği 2026-09-03).
  ///
  /// Tek adımlık ileri/geri düğmeleri duruyor (bir komşuyla yer değiştirmek
  /// en sık iş) ama 200 sayfalık bir belgede 60. sayfayı başa almak 60
  /// dokunuş demekti. Burada hedef sayfa numarası soruluyor.
  Future<void> _moveTo() async {
    if (_selected.length != 1) return;
    final from = _selected.first;
    final total = await _pageCount();
    if (!mounted) return;
    final controller = TextEditingController(text: '${from + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.move_to')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: ctx.t('pt.move_to_hint', {'n': '$total'}),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
    if (target == null || target < 1 || target > total) return;
    final to = target - 1;
    if (to == from) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_move_page'))) return;
    final pw = _password;
    await _apply(_str.t('pt.op_move'),
        (b) => PdfTools.movePageInBackground(b, from: from, to: to, password: pw));
    if (mounted) _selection.value = {to};
  }

  /// Seçili sayfaları hemen arkalarına çoğaltır.
  Future<void> _duplicateSelected() async {
    if (_selected.isEmpty) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_duplicate'))) return;
    final pages = _selected.toList();
    final pw = _password;
    await _apply(_str.t('pt.op_duplicate'),
        (b) => PdfTools.duplicatePagesInBackground(b, pages, password: pw));
  }

  /// Belgeyi ters sıraya çevirir (ters taranmış belgelerin tek adımlık çözümü).
  Future<void> _reverse() async {
    if (!await _confirmAnnotationLoss(_str.t('pt.op_reverse'))) return;
    final pw = _password;
    await _apply(_str.t('pt.op_reverse'),
        (b) => PdfTools.reversePagesInBackground(b, password: pw));
  }

  /// Seçili sayfadan ÖNCE (seçim yoksa sona) boş sayfa ekler.
  ///
  /// Yerinde çalışıyor: vurgular korunuyor, bu yüzden uyarı sorulmuyor.
  Future<void> _insertBlank() async {
    final total = await _pageCount();
    final at = _selected.isEmpty ? total : _selected.reduce((a, b) => a < b ? a : b);
    final pw = _password;
    await _apply(_str.t('pt.op_insert_blank'),
        (b) => PdfTools.insertBlankPageInBackground(b, index: at, password: pw));
  }

  /// Belgeyi N sayfalık parçalara böler ve **ayrı dosyalar** olarak yazar.
  Future<void> _splitEvery() async {
    final total = await _pageCount();
    if (total < 2) {
      _snack(_str.t('pt.split_too_short'));
      return;
    }
    if (!mounted) return;
    final size = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.t('pt.split_every')),
        children: [
          for (final n in const [1, 2, 5, 10])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text(ctx.t('pt.split_size', {'n': '$n'})),
            ),
        ],
      ),
    );
    if (size == null) return;
    final bytes = _bytes;
    if (bytes == null) return;
    final pw = _password;
    _partSetState(() => _busyLabel = '${_str.t('pt.op_split')}…');
    try {
      final parts = await PdfTools.splitEvery(bytes, size: size, password: pw);
      final dir = p.dirname(widget.path);
      final base = p.basenameWithoutExtension(widget.path);
      final written = <String>[];
      for (var i = 0; i < parts.length; i++) {
        // Var olan dosyanın üstüne YAZMA: kullanıcının belgesi gitmesin.
        var target = p.join(dir, '$base-${i + 1}.pdf');
        var n = 1;
        while (File(target).existsSync()) {
          target = p.join(dir, '$base-${i + 1}($n).pdf');
          n++;
        }
        await File(target).writeAsBytes(parts[i], flush: true);
        written.add(target);
      }
      if (mounted) _snack(_str.t('pt.split_done', {'n': written.length}));
    } catch (e) {
      if (mounted) {
        _snack(_str.t('pt.op_failed',
            {'label': _str.t('pt.op_split'), 'error': userErrorText(e)}));
      }
    } finally {
      if (mounted) _partSetState(() => _busyLabel = '');
    }
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

  Future<void> _mergeOther() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    final paths = res?.files.map((f) => f.path).whereType<String>().toList();
    if (paths == null || paths.isEmpty) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_merge'))) return;
    final others = [
      for (final path in paths) await File(path).readAsBytes(),
    ];
    await _apply(_str.t('pt.op_merge'),
        (b) => PdfTools.mergeInBackground([b, ...others]));
    if (mounted) _snack(_str.t('pt.merged', {'n': paths.length}));
  }

  /// Kameradan yeni sayfa(lar) tarayıp belgenin sonuna ekler — kâğıt eki olan
  /// sözleşme/rapor için asıl işe yarayan birleşim.
  Future<void> _scanAndAppend() async {
    final scanned = await DocumentScanner.scanPages();
    if (scanned == null || scanned.isEmpty || !mounted) return;
    if (!await _confirmAnnotationLoss(_str.t('pt.op_scan_append'))) return;
    // Ana tarama akışıyla aynı kural: tarayıcının verdiği sayfa OLDUĞU GİBİ
    // eklenir (kendiliğinden kırpma/düzleştirme/netleştirme yok — kullanıcı
    // sayfayı ML Kit ekranında onayladı, bkz. `ScanPrepare`).
    // Hata/ilerleme yönetimi _apply'da; taranan sayfalar ızgarada görünür.
    await _apply(_str.t('pt.op_scan_append'), (b) async {
      final pages = ScanPage.displays(await ScanPrepare.pages(scanned));
      final doc = await _conversion.imagesToPdf(pages,
          uniformPage: PdfPageFormat.a4);
      return PdfTools.mergeInBackground([b, doc]);
    });
  }

  /// Sıkıştırma: **önce onay, sonra arka planda**.
  ///
  /// 2026-07-26 kullanıcı bulgusu: "sıkıştır denince donma". Kök neden
  /// Syncfusion'ın belgeyi ana izlekte baştan yazmasıydı (bkz.
  /// [PdfTools.compressInBackground]). Ayrıca ne olacağı önceden söylenmiyordu:
  /// taranmış belgede kazanç küçüktür, kullanıcı bunu beklemeden bilmeli.
  Future<void> _compress() async {
    final before = _bytes!.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('pt.compress_title')),
        content: Text(ctx.t('pt.compress_body', {'size': _kb(before)})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('pt.compress'))),
        ],
      ),
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
    await Share.shareXFiles([XFile(path)], text: 'PDF');
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
