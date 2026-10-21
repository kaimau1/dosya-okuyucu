part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenFileOpsPart on _SpreadsheetEditorScreenState {
  Future<void> _save() async {
    _endEdit();
    final editor = _editor;
    if (editor == null) return;
    final target = widget.savePath ?? widget.path;
    try {
      final bytes = editor.save();
      await SafeWrite.bytes(target, bytes);
      // Çevrilmiş dosyada çalışma kopyası da tazelenir: kullanıcı kaydettikten
      // sonra düzenlemeye devam edip yine kaydedebilsin.
      if (widget.savePath != null) {
        await SafeWrite.bytes(widget.path, bytes);
      }
      // "Yaptıklarım" defteri: kaydedilen HEDEF yazılır (.xls açıldıysa
      // kullanıcının elindeki dosya .xlsx olan odur).
      unawaited(ActivityLog.add(ActivityKind.documentEdit, target));
      _dirty = false;
      if (mounted) {
        showSnack(context, widget.savePath == null
              ? context.t('common.saved_hint')
              : context.t('excel.saved_as_xlsx',
                  {'name': p.basename(target)}));
        _partSetState(() {});
      }
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    }
  }

  /// Editörün o anki içeriğini İndirilenler'e yazar (bkz. [SaveToDownloads]).
  /// Eski `.xls` açıldıysa içerik `.xlsx`tir; ad da kaydetme hedefinden.
  Future<void> _download() async {
    _endEdit();
    final editor = _editor;
    if (editor == null) return;
    final name = widget.savePath == null
        ? widget.name
        : p.basename(widget.savePath!);
    await runDownloadAction(
        context, () => SaveToDownloads.saveBytes(name, editor.save()));
  }

  Future<void> _export() async {
    final editor = _editor;
    if (editor == null) return;
    final f = File('${Directory.systemTemp.path}/${widget.name}');
    await f.writeAsBytes(editor.save());
    await Share.shareXFiles([XFile(f.path)], text: widget.name);
  }

  /// Etkin sayfayı CSV olarak dışa aktarır — hücreler **ekranda göründüğü
  /// gibi** yazılır (tarih seri numarası değil `21.07.2026`, para `₺1.500,00`).
  Future<void> _exportCsv() async {
    final sheet = _sheet;
    if (sheet == null) return;
    // Hata metni await'ten ÖNCE çevrilir (asenkron boşluktan sonra `context`
    // kullanılamaz).
    final csvFailed = context.t('excel.csv_failed');
    final enc = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(context.t('excel.csv_encoding')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'utf8'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('excel.csv_utf8')),
              subtitle: Text(context.t('excel.csv_utf8_sub')),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'cp1254'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Windows-1254'),
              subtitle: Text(context.t('excel.csv_legacy')),
            ),
          ),
        ],
      ),
    );
    if (enc == null) return;
    try {
      final engine = _engineFor(sheet);
      final rows = <List<String>>[];
      for (var r = 0; r < sheet.rows.length; r++) {
        final row = <String>[];
        for (var c = 0; c < sheet.rows[r].length; c++) {
          row.add(sheet.viewAt(r, c, engine.displayValue(r, c)).text);
        }
        rows.add(row);
      }
      final csv = CsvCodec.encode(rows, delimiter: ';');
      final base = widget.name.replaceAll(RegExp(r'\.[^.]*$'), '');
      final f = File('${Directory.systemTemp.path}/$base.csv');
      final bytes = enc == 'cp1254'
          ? TextDecode.encodeCp1254(csv)
          : utf8.encode('\u{FEFF}$csv');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: '$base.csv');
    } catch (e) {
      _snack(csvFailed.replaceAll('{error}', '$e'));
    }
  }

  /// Etkin sayfada dosyadan gelen dondurulmuş bölme var mı?
  bool get _sheetHasFreeze {
    final sheet = _sheet;
    return sheet != null && (sheet.frozenRows > 0 || sheet.frozenCols > 0);
  }

  /// Sabit satır/sütunları açıp kapatır. Telefonda sabit bölme ekranın
  /// önemli bir kısmını yiyebiliyor; kullanıcı "sağ/sol ayrı oynamasın"
  /// diyebilsin.
  void _toggleFreeze() {
    _partSetState(() {
      _freeze = !_freeze;
      _firstCol = 0;
      _lastCol = 0;
    });
    if (_hBody.hasClients) _hBody.jumpTo(0);
    if (_vBody.hasClients) _vBody.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
  }

  /// Sayfa yönünü (soldan sağa / sağdan sola) değiştirir — Excel'in
  /// *Sayfa Düzeni → Sayfayı Sağdan Sola* düğmesinin karşılığı.
  ///
  /// Yön **dosyanın** özelliği: kaydetmede `<sheetView rightToLeft>` olarak
  /// geri yazılır (bkz. `XlsxSavePatch`), arayüz dilini değiştirmez.
  void _toggleSheetDirection() {
    final sheet = _sheet;
    if (sheet == null) return;
    final next = !sheet.rightToLeft;
    _partSetState(() {
      sheet.setRightToLeft(next);
      _dirty = true;
      // Sanallaştırma penceresi ve kaydırma konumu yön değişince anlamsızlaşır.
      _firstCol = 0;
      _lastCol = 0;
    });
    if (_hBody.hasClients) _hBody.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
    _snack(context.t(next ? 'excel.sheet_rtl_on' : 'excel.sheet_rtl_off'));
  }

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }
}
