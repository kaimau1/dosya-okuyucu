part of '../remote_browser_screen.dart';

extension _RemoteBrowserScreenActionsPart on _RemoteBrowserScreenState {
  Future<void> _start() async {
    try {
      await _fs.connect();
      _connected = true;
      await _load(_path);
      unawaited(_loadUsage());
    } catch (e) {
      if (!mounted) return;
      _partSetState(() {
        _busy = false;
        _error = errorTextFor(context, e);
      });
    }
  }

  Future<void> _load(String path) async {
    _partSetState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await _fs.list(path);
      if (!mounted) return;
      _partSetState(() {
        _path = path;
        _entries = entries;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      _partSetState(() {
        _busy = false;
        _error = errorTextFor(context, e);
      });
    }
  }

  /// Ekranda gösterilecek liste: süzülmüş ve sıralanmış.
  ///
  /// Klasörler HER ZAMAN önce gelir (boyuta göre sıralarken bile): dosya
  /// yöneticisinde gezinti klasörlerden geçer, onları büyüklüğe göre araya
  /// serpiştirmek gezinmeyi zorlaştırır.
  List<RemoteEntry> get _visible => _RemoteBrowserScreenState.sortEntries(
        _filter.trim().isEmpty
            ? _entries
            : [
                for (final e in _entries)
                  if (e.name.toLowerCase().contains(_filter.trim().toLowerCase()))
                    e,
              ],
        _sort,
        ascending: _ascending,
      );

  /// Ham USB'de doluluğu okur (yalnız bir kez; pahalı değil ama boşuna da
  /// tekrarlanmasın). Diğer protokollerde kapasite kavramı yok.
  Future<void> _loadUsage() async {
    final fs = _fs;
    if (fs is! UsbFs) return;
    final usage = await fs.usage();
    if (!mounted || usage == null) return;
    _partSetState(() => _usage =
        '${FsPaths.humanSize(usage.$1 - usage.$2)} / ${FsPaths.humanSize(usage.$1)}');
  }

  /// Donanımdan yazma korumalı bir bellekte başlıkta gösterilen uyarı.
  ///
  /// Kullanıcı hatası 2026-09-03: yazma düğmeleri sönük duruyordu ve neden
  /// söndükleri hiçbir yerde yazmıyordu ("bu usbde sorun oldu"). Korumalı bir
  /// bellekte sebep artık başlıkta.
  String get _readOnlyNote {
    final fs = _fs;
    if (fs is! UsbFs || !fs.hardwareWriteProtected) return '';
    return context.t('usb.write_protected');
  }

  bool get _atRoot => _path == widget.connection.rootPath || _path == '/';

  Future<void> _up() async {
    if (_atRoot) return;
    await _load(_fs.parentPath(_path));
  }

  Future<void> _open(RemoteEntry entry) async {
    if (entry.isDir) {
      await _load(entry.path);
      return;
    }
    final failed = context.t('nas.error_unknown');
    _partSetState(() => _busy = true);
    try {
      final dir =
          p.join(FmEnv.appSupportDir, 'remote', safeCacheName(widget.connection.id));
      final local = await _fs.download(entry, p.join(dir, entry.name));
      // Düzenleme geri yazımının ölçütü: dosyanın açılmadan ÖNCEKİ hâli.
      // Boyut + değiştirilme damgası birlikte alınıyor; yalnız damga
      // güvenilmez (aynı saniyede kaydeden editörler var), yalnız boyut da
      // güvenilmez (aynı uzunlukta düzeltme).
      // `statSync` bilinçli: `stat()` (asenkron) `flutter_test`in sahte saat
      // zonunda HİÇ tamamlanmıyor ve ekran sonsuza dek "yükleniyor" kalıyor
      // (HAFIZA 2026-07-25 §F'deki tuzağın aynısı). Damga okuma birkaç
      // baytlık bir üstveri işi, dosya içeriği okunmuyor.
      final before = local.statSync();
      final beforeLength = before.size;
      final beforeModified = before.modified;
      if (!mounted) return;
      _partSetState(() => _busy = false);
      await openLocalFile(context, local.path);
      // Ekran geri geldiğinde yerel kopya değiştiyse kullanıcı dosyayı
      // düzenlemiş demektir; sunucudaki sürüm HÂLÂ ESKİ.
      await _offerWriteBack(entry, local, beforeLength, beforeModified);
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack(mounted ? errorTextFor(context, e) : failed);
    }
  }

  /// Yerel kopya düzenlendiyse sunucuya geri yüklemeyi TEKLİF eder.
  ///
  /// **Neden sorulup otomatik yapılmıyor:** yükleme sunucudaki sürümün
  /// üzerine yazıyor. Kullanıcı dosyayı yalnız incelemek için açmış ve
  /// editör dokunmuş olabilir; sessizce üzerine yazmak, geri alınamayan bir
  /// karar vermek olurdu. Sormak da şart: hiç sormamak "kaydettim sandım,
  /// sunucuda eski hâli duruyor" demek — sessiz veri kaybı gibi görünür.
  Future<void> _offerWriteBack(
    RemoteEntry entry,
    File local,
    int beforeLength,
    DateTime beforeModified,
  ) async {
    if (!mounted) return;
    FileStat after;
    try {
      after = local.statSync();
    } catch (_) {
      return;
    }
    final changed =
        after.size != beforeLength || after.modified.isAfter(beforeModified);
    if (!changed || !mounted) return;

    final title = context.t('nas.writeback_title');
    final body = context.t('nas.writeback_body', {'name': entry.name});
    final upload = context.t('nas.writeback_upload');
    final keep = context.t('nas.writeback_keep_local');
    final uploading = context.t('nas.uploading');
    final done = context.t('nas.writeback_done');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(keep)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(upload)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _snack(uploading);
    try {
      await _fs.upload(local, _fs.parentPath(entry.path),
          name: entry.name);
      if (!mounted) return;
      _snack(done);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _delete(RemoteEntry entry) async {
    final ok = await _confirm(
        context.t('nas.delete_confirm', {'name': entry.name}));
    if (ok != true) return;
    try {
      await _fs.delete(entry);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _rename(RemoteEntry entry) async {
    final name = await _prompt(
        context.t('nas.rename'), context.t('nas.new_name'), entry.name);
    if (name == null || name.trim().isEmpty || name == entry.name) return;
    try {
      await _fs.rename(entry, name.trim());
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<void> _newFolder() async {
    final name =
        await _prompt(context.t('nas.new_folder'), context.t('nas.folder_name'), '');
    if (name == null || name.trim().isEmpty) return;
    try {
      await _fs.makeDirectory(_fs.childPath(_path, name.trim()));
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  /// Yerel bir dosyayı buraya yükler (dosya seçici sistemin kendisi).
  Future<void> _upload() async {
    final uploading = context.t('nas.uploading');
    final done = context.t('nas.upload_done');
    final path = await pickLocalFile();
    if (path == null) return;
    if (!mounted) return;
    _snack(uploading);
    try {
      await _fs.upload(File(path), _path);
      if (!mounted) return;
      _snack(done);
      await _load(_path);
    } catch (e) {
      if (mounted) _snack(errorTextFor(context, e));
    }
  }

  Future<bool?> _confirm(String message) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.ok'))),
          ],
        ),
      );

  Future<String?> _prompt(String title, String label, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
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

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m);
  }
}
