part of '../viewer_screen.dart';

extension _ViewerScreenPendingSavePart on _ViewerScreenState {
  /// Yeni belge baytlarını dosyaya yazar ve görüntüyü tazeler.
  ///
  /// İlk yazıştan ÖNCE özgün baytlar bir yedeğe kopyalanır; kullanıcı
  /// "üzerine yaz" demeden çıkarsa ekran kapanırken o yedek geri yazılır.
  /// Görüntüleyicinin gördüğü yol hiç değişmez — tazeleme [PdfReload] ile,
  /// yani kullanıcı sayfasında ve ölçeğinde kalır.
  Future<void> _writePending(List<int> bytes) async {
    // Boş/bozuk çıktı kullanıcının dosyasının yerine KONMAZ.
    if (!PdfBytesCheck.looksValid(bytes)) {
      throw const FileSystemException('Üretilen PDF geçersiz; dosyaya dokunulmadı');
    }
    _partSetState(() => _pdfWriting++);
    try {
      if (_pdfBackupPath == null) {
        final root = PdfEditJournal.backupRoot();
        final Directory dir;
        if (root != null) {
          await Directory(root).create(recursive: true);
          dir = await Directory(root).createTemp('oturum');
        } else {
          dir = await Directory.systemTemp.createTemp('dosya_okuyucu_edit');
        }
        final backup = p.join(dir.path, p.basename(widget.doc.path));
        // `copy`: dosya Dart belleğine alınmadan çekirdekte kopyalanır.
        await File(widget.doc.path).copy(backup);
        _pdfBackupPath = backup;
        // Uygulama bu ekrandayken öldürülürse `dispose` çalışmaz; günlük,
        // açılışta özgünün geri yüklenmesini sağlar (bkz. PdfEditJournal).
        PdfEditJournal.add(widget.doc.path, backup);
      }
      // Bölünmez yazma: süreç yarıda ölse de dosya ya eski ya yeni hâlinde.
      await SafeWrite.bytes(widget.doc.path, bytes);
    } finally {
      if (mounted) _partSetState(() => _pdfWriting--);
    }
    if (!mounted) return;
    _partSetState(() {
      _pdfDirty = true;
      _pdfText = '';
    });
    await _reloadPdf();
  }

  /// Yedeği geri yazar (kullanıcı "üzerine yaz" demediyse) ve yedeği siler.
  ///
  /// **Artık eşzamanlı değil** (2026-09-27): `dispose` içinden de çağrılıyor
  /// ve eskiden orada büyük dosyayı ana izlekte `copySync` ile kopyalıyordu —
  /// ekran donuyor, tam o anda öldürülen süreç kullanıcının dosyasını YARIM
  /// bırakıyordu (0 bayt PDF bulgusu). Geri yazma bölünmez ve
  /// [PdfRestoreQueue]'da sürer; aynı dosya yeniden açılırsa beklenir.
  /// Başarısızsa günlük kaydı KALIR ve açılışta yeniden denenir.
  Future<void> _restoreOriginal() {
    final backup = _pdfBackupPath;
    if (backup == null) return Future.value();
    _pdfBackupPath = null;
    final keep = _pdfKeepEdits;
    _pdfKeepEdits = false;
    final original = widget.doc.path;
    return PdfRestoreQueue.run(original, () async {
      try {
        final file = File(backup);
        if (!keep && await file.exists()) {
          await SafeWrite.copy(backup, original);
        }
        if (await file.exists()) await file.delete();
        final dir = file.parent;
        if (await dir.exists() && await dir.list().isEmpty) {
          await dir.delete();
        }
        PdfEditJournal.remove(original);
      } catch (_) {
        // Günlük kaydı kalır; açılışta yeniden denenir.
      }
    });
  }

  /// Düzenlemeleri atar: özgün baytları geri yazar ve görüntüyü tazeler.
  Future<void> _discardPending() async {
    final hadFileEdits = _pdfBackupPath != null;
    await _restoreOriginal();
    if (!mounted) return;
    _partSetState(() {
      _pdfDirty = false;
      _pendingMarks.clear();
      _lastMark = null;
      _pdfText = '';
    });
    if (hadFileEdits) await _reloadPdf();
  }

  /// Bekleyen değişiklikleri kaydeder (nasıl kaydedileceğini SORARAK).
  /// Kaydedildiyse true, vazgeçildiyse false döner.
  Future<bool> _savePendingPdf() async {
    if (!_hasUnsaved) return true;
    final marks = List<_PendingMark>.of(_pendingMarks);
    List<int> bytes;
    try {
      bytes = await File(widget.doc.path).readAsBytes();
      // Ekranda bekleyen vurgular kaydedilecek baytlara İZOLATTA işlenir;
      // özgün dosyaya henüz dokunulmaz (kullanıcı "kopya" diyebilir).
      if (marks.isNotEmpty) {
        if (mounted) _partSetState(() => _pdfWriting++);
        try {
          bytes = await PdfAnnotator.addHighlightsInBackground(
              bytes, [for (final m in marks) m.spec]);
        } finally {
          if (mounted) _partSetState(() => _pdfWriting--);
        }
      }
    } catch (e) {
      if (mounted) _snack(context.t('vw.highlight_failed', {'error': userErrorText(e)}));
      return false;
    }
    if (!mounted) return false;
    final outcome = await savePdfWithChoice(
      context,
      originalPath: widget.doc.path,
      bytes: bytes,
      note: context.t('vw.edits_applied'),
    );
    if (outcome == null) return false;
    if (outcome.overwritten) {
      // Kaydedildi: oturum KAPANIR. Yedek silinir, günlük düşer (çökme sonrası
      // geri yükleme artık yanlış olurdu); sonraki düzenleme yeni bir yedekle
      // başlar. Eskiden `_pdfKeepEdits` true kalıyordu ve kaydettikten sonra
      // yapılıp "kaydetme" denen düzenlemeler dosyada KALIYORDU.
      if (_pdfBackupPath != null) {
        _pdfKeepEdits = true;
        await _restoreOriginal(); // bayrağı da sıfırlar
      }
      if (marks.isNotEmpty && mounted) {
        // Vurgular artık dosyada: belge tazelenince pdfium çizer, üstümüzdeki
        // çizim ancak ondan SONRA kalkar (arada bir kare boş kalmasın).
        await _reloadPdf();
      }
    }
    if (mounted) {
      _partSetState(() {
        _pdfDirty = false;
        _pendingMarks.removeWhere(marks.contains);
        _lastMark = null;
      });
    }
    return true;
  }

  /// Bekleyen vurguları dosyaya yazar (kaydedilmemiş düzenleme olarak).
  ///
  /// Dosyayı değiştiren başka bir işten (yerinde metin düzenleme, sayfa
  /// döndürme, dosyadaki vurguyu silme) HEMEN ÖNCE çağrılır: o iş dosyanın
  /// baytlarıyla çalışır ve bekleyen vurguları bilmez.
  Future<bool> _flushPendingMarks() async {
    if (_pendingMarks.isEmpty) return true;
    final marks = List<_PendingMark>.of(_pendingMarks);
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final out = await PdfAnnotator.addHighlightsInBackground(
          bytes, [for (final m in marks) m.spec]);
      if (!mounted) return false;
      await _writePending(out);
      if (mounted) {
        _partSetState(() {
          _pendingMarks.removeWhere(marks.contains);
          if (marks.contains(_lastMark)) _lastMark = null;
        });
      }
      return true;
    } catch (e) {
      if (mounted) _snack(context.t('vw.highlight_failed', {'error': userErrorText(e)}));
      return false;
    }
  }

  /// Ekrandan çıkarken / başka bir PDF aracına geçerken sorulan soru.
  /// Devam edilebilirse true döner.
  Future<bool> _confirmLeavePending() async {
    if (_pdfWriting > 0) {
      _snack(context.t('vw.saving_wait'));
      return false;
    }
    if (!_hasUnsaved) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('vw.unsaved_title')),
        content: Text(context.t('vw.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(context.t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(context.t('vw.dont_save'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(context.t('common.save'))),
        ],
      ),
    );
    if (choice == 'save') return _savePendingPdf();
    if (choice == 'discard') {
      await _discardPending();
      return true;
    }
    return false;
  }
}
