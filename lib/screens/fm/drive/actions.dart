part of '../drive_screen.dart';

extension _DriveScreenActionsPart on _DriveScreenState {
  Future<void> _start() async {
    final ok = await _drive.signInSilently();
    if (!mounted) return;
    _partSetState(() {
      _signedIn = ok;
      _busy = false;
    });
    if (ok) await _refresh();
  }

  Future<void> _signIn() async {
    _partSetState(() => _busy = true);
    final result = await _drive.signIn();
    if (!mounted) return;
    _partSetState(() {
      _signedIn = result.success;
      _busy = false;
      _errorDetail = null;
      if (result.success) {
        _error = null;
      } else if (result.error == DriveSignInError.cancelled) {
        // Kullanıcı pencereyi kendi kapattı: hata şeridi göstermek onu
        // yaptığı şey için azarlamak olurdu.
        _error = null;
      } else {
        _error = _DriveScreenState._signInKeyFor(result.error!);
        if (result.error == DriveSignInError.failed) {
          _errorDetail = result.detail;
        }
      }
    });
    if (result.success) {
      await _refresh();
    } else if (result.error == DriveSignInError.notConfigured) {
      // Kayıt için gereken SHA-1, ÇALIŞAN APK'nın kendi imzasından okunur —
      // belgede yazılı değer eski bir anahtara ait olabilir.
      final sha1 = await AppSignature.sha1Colonized();
      if (mounted) _partSetState(() => _sha1 = sha1);
    }
  }

  /// **Yapılandırma GEREKTİRMEYEN yol:** Android'in sistem dosya seçicisi.
  ///
  /// Neden bu düğme var (kullanıcı hatası 2026-07-30: "drive olmadı"):
  /// Google hesabıyla giriş, APK'nın imzasının Google Cloud'a kaydedilmiş
  /// olmasını şart koşuyor. Bu bizim kodumuzla çözülebilecek bir şey değil ve
  /// kurulum yapılana kadar kullanıcının elinde HİÇBİR Drive yolu kalmıyordu.
  /// Oysa Android'in Depolama Erişim Çerçevesi Drive'ı bir dosya sağlayıcısı
  /// olarak listeler: kullanıcı oradan gerçek Drive'ının TAMAMINI gezip dosya
  /// açabilir, üstelik hiçbir yetki penceresi görmeden. Metinde tarif etmek
  /// yetmiyordu — düğme oldu.
  Future<void> _openViaSystemPicker() async {
    final failed = context.t('drive.download_failed');
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      if (mounted) _snack('$failed $e');
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    if (!mounted) return;
    _partSetState(() {
      _signedIn = false;
      _files = const [];
      _error = null;
    });
  }

  Future<void> _refresh() async {
    _partSetState(() {
      _busy = true;
      _error = null;
      _errorDetail = null;
    });
    try {
      final files = await _drive.list(
        parentId: _searching ? null : _current.$1,
        query: _searching ? _query : null,
        sort: _sort,
      );
      if (!mounted) return;
      _partSetState(() {
        _files = files;
        _busy = false;
      });
    } on DriveException catch (e) {
      if (!mounted) return;
      _partSetState(() {
        _busy = false;
        _error = _DriveScreenState._keyFor(e.error);
        // Google'ın kendi mesajı da gösteriliyor: sınıflandırmamız tutmazsa
        // kullanıcının elinde bildirebileceği TEK ipucu bu (2026-08-05'te
        // atıldığı için 403'ün nedeni ekran görüntüsünden okunamadı).
        _errorDetail = e.detail;
      });
    } catch (e) {
      if (!mounted) return;
      _partSetState(() {
        _busy = false;
        _error = 'drive.error_unknown';
        _errorDetail = '$e';
      });
    }
  }

  /// Klasöre girer. Arama sonucundan girilirse arama temizlenir: aksi hâlde
  /// "klasördeyim ama liste hâlâ arama sonucu" gibi bir ara durum kalırdı.
  void _enter(DriveFile folder) {
    _partSetState(() {
      _path.add((folder.id, folder.name));
      _query = '';
      _searchController.clear();
    });
    _refresh();
  }

  /// Bir üst klasöre. Kökteyken false döner → ekran kapanır (geri tuşu).
  bool _goUp() {
    if (_path.length <= 1) return false;
    _partSetState(() => _path.removeLast());
    _refresh();
    return true;
  }

  Future<void> _newFolder() async {
    final name = await _askName(
      title: context.t('drive.new_folder'),
      initial: context.t('drive.new_folder_default'),
    );
    if (name == null || name.isEmpty) return;
    _partSetState(() => _busy = true);
    try {
      await _drive.createFolder(name, parentId: _current.$1);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.new_folder_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  Future<void> _rename(DriveFile file) async {
    final name = await _askName(
      title: context.t('drive.rename'),
      initial: file.name,
    );
    if (name == null || name.isEmpty || name == file.name) return;
    _partSetState(() => _busy = true);
    try {
      await _drive.rename(file.id, name);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.rename_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  /// Ad soran ortak diyalog. Metin baştan seçili gelir — yeniden adlandırmada
  /// kullanıcı eski adı tek tek silmek zorunda kalmasın.
  Future<String?> _askName({
    required String title,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
    final cancel = context.t('common.cancel');
    final ok = context.t('common.ok');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ok),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Telefondan dosya seçip BULUNULAN klasöre yükler.
  Future<void> _uploadHere() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    _partSetState(() => _busy = true);
    try {
      await _drive.upload(File(path), parentId: _current.$1);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.upload_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  /// İndir → aç. Dosya önce **önbelleğe** iner (uygulamanın kendi klasörü),
  /// sonra mevcut görüntüleyici/editör zinciriyle açılır — böylece Drive
  /// dosyaları da tüm biçim desteğimizden ilk günden yararlanıyor.
  ///
  /// Önbellek TAZE ise hiç indirilmez (2026-08-06 kullanıcı bulgusu: *"her
  /// açma istediğimde tekrar tekrar indiriyor"*): boyut ve değişiklik zamanı
  /// Drive üstverisiyle tutuyorsa yerel kopya doğrudan açılır — 40 MB'lık
  /// PDF ikinci açılışta anında gelir, mobil veri yakmaz (bkz. `DriveCache`).
  ///
  /// İndirme sırasında ADLI ve YÜZDELİ bir pencere durur (2026-08-06 kullanıcı
  /// bulgusu: büyük PDF'te "yüklenme ekranı var ama açılıyor mu ne oluyor
  /// belli değil"). Toplam boyut bilinmiyorsa (Google biçimi `export` ile
  /// iner) çubuk belirsiz akar ama inen MB yine yazılır.
  Future<void> _open(DriveFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final ready = context.t('drive.ready_offscreen');
    final local = await _localCopy(file);
    if (local == null) return;
    // İndirme arka plana alındıysa kullanıcı bu ekranda olmayabilir. Sessizce
    // yutmuyoruz: dosya indi ve önbellekte duruyor, bir sonraki dokunuşta
    // anında açılacak — bunu SÖYLÜYORUZ.
    if (!mounted) {
      showSnackOn(messenger, '$ready ${file.name}'.trim());
      return;
    }
    await EntryOpener.open(context, local.path);
  }

  /// Dosyayı sistem paylaşım sayfasına **dosya olarak** verir (WhatsApp'a ek
  /// gider). Bağlantı paylaşımından ayrı: karşı tarafın Drive'a erişimi
  /// olmadığında ya da çevrimdışı okuyacaksa gereken bu.
  Future<void> _shareFile(DriveFile file) async {
    final local = await _localCopy(file);
    if (local == null) return;
    await Share.shareXFiles([XFile(local.path)], text: file.name);
  }

  /// Dosyanın yerel kopyası: önbellek tazeyse indirmez, değilse aşağıdaki
  /// adlı/yüzdeli pencereyle indirir. Hata kullanıcıya bildirilir, null döner.
  Future<File?> _localCopy(DriveFile file) async {
    final root = DriveCache.rootOf(FmEnv.appSupportDir);
    final cached = DriveCache.freshFile(file, root);
    if (cached != null) return cached;
    final local = await _downloadTo(file, DriveCache.dirFor(file, root));
    if (local != null) DriveCache.prune(root);
    return local;
  }

  /// **Telefondaki bir klasöre indirir.** Önbellek yolundan ayrı: oradaki kopya
  /// uygulamanın kendi gizli klasöründe durur ve temizlenebilir; buradaki
  /// kullanıcının kendi klasörüne iner, kalıcıdır ve gezginde görünür.
  Future<void> _downloadToFolder(DriveFile file) async {
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: const [],
          actionLabel: context.t('drive.download_here'),
        ),
      ),
    );
    if (target == null || !mounted) return;
    // Sonuç mesajı ekrandan bağımsız gösterilir: indirme arka plana alınıp
    // kullanıcı Drive'dan çıkmış olabilir, ama dosya klasöre indi ve bunu
    // bilmesi gerekiyor.
    final messenger = ScaffoldMessenger.of(context);
    final done = context.t('drive.downloaded', {'folder': target});
    final local = await _downloadTo(file, target);
    if (local == null) return;
    // Gezgin/pano ANINDA tazelensin diye sinyal: yoksa kullanıcı klasöre
    // gidip "inmemiş" sanırdı.
    FsEvents.changed();
    showSnackOn(messenger, done);
  }

  /// İndirme penceresiyle birlikte tek indirme adımı. Hata kullanıcıya
  /// bildirilir, null döner.
  ///
  /// KÖK NEDEN — niye ortak [showFmProgress] (kullanıcı 2026-08-30:
  /// *"Drive'da bir şeyler inerken durdur yok, arka planda devam etmiyor,
  /// iptal seçeneği yok"*): burası kendi penceresini kuruyordu ve o pencere
  /// `barrierDismissible: false` + **düğmesiz**ti. 200 MB'lık bir videoyu
  /// yanlışlıkla indirmeye başlayan kullanıcının tek çıkışı uygulamayı
  /// kapatmaktı; indirme sürerken de Drive ekranında kilitli kalıyordu.
  ///
  /// Uygulamanın kopyala/taşı/sıkıştır işlerinde bunun çözümü zaten vardı —
  /// "Arka plana al" + "Durdur" + kalıcı ilerleme şeridi. Kendi penceremizi
  /// düzeltmek yerine o ortak pencereye geçtik: davranış tek yerde, indirme
  /// de artık diğer uzun işlerle aynı dili konuşuyor.
  Future<File?> _downloadTo(DriveFile file, String dir) async {
    final failed = context.t('drive.download_failed');
    final stopped = context.t('drive.download_stopped');
    // Ekrandan bağımsız yaşayan messenger: kullanıcı indirmeyi arka plana
    // alıp Drive ekranından çıkarsa da sonucu görmeli.
    final messenger = ScaffoldMessenger.of(context);
    // Toplam boyut Drive üstverisinden; Google biçimleri `export` ile indiği
    // için önceden bilinmiyor (0 → belirsiz çubuk).
    final knownTotal =
        file.sizeBytes > 0 && file.exportAs == null ? file.sizeBytes : 0;
    try {
      return await showFmProgress<File?>(
        context,
        title: context.t('drive.downloading'),
        name: context.t('drive.downloading_name'),
        describe: _DriveScreenState._downloadLabel,
        task: (report, isCancelled) async {
          report(FmProgress(0, knownTotal, file.name));
          return _drive.download(
            file,
            dir,
            onProgress: (received, total) =>
                report(FmProgress(received, total ?? knownTotal, file.name)),
            isCancelled: isCancelled,
          );
        },
      );
    } on DriveDownloadCancelled {
      showSnackOn(messenger, stopped);
      return null;
    } catch (e) {
      showSnackOn(messenger, '$failed ${_DriveScreenState._detail(e)}');
      return null;
    }
  }

  /// "Bağlantısı olan herkes görüntüleyebilir" izni verip bağlantıyı paylaşır.
  /// Dosya İNMEZ — 1 GB'lık videoyu da anında paylaşır.
  Future<void> _shareLink(DriveFile file) async {
    _partSetState(() => _busy = true);
    try {
      final link = await _drive.shareLink(file.id);
      if (!mounted) return;
      _partSetState(() => _busy = false);
      await Share.share(link, subject: file.name);
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.share_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  /// Yıldızı ters çevirir. Liste tazelenir — yıldız satırda da görünüyor.
  Future<void> _toggleStar(DriveFile file) async {
    _partSetState(() => _busy = true);
    try {
      await _drive.setStarred(file.id, !file.starred);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.star_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  /// Dosya ayrıntıları. Elimizdeki üstveriden gösterilir — ek API çağrısı yok.
  ///
  /// Tarihler `FsPaths.humanDate` ile yazılıyor: burada eskiden
  /// `DateTime.toString()` vardı ve kullanıcıya "2026-08-06 23:41:18.573Z"
  /// gibi ham bir damga gösteriyordu.
  Future<void> _info(DriveFile file) async {
    final size = file.sizeBytes > 0 ? FsPaths.humanSize(file.sizeBytes) : '—';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(ctx.t('drive.info_kind'), _kindLabel(ctx, file)),
              if (!file.isFolder) _infoRow(ctx.t('drive.info_size'), size),
              _infoRow(ctx.t('drive.info_modified'),
                  FsPaths.humanDate(file.modifiedAtMs)),
              // Oluşturulma = Drive'a yüklenme anı; değiştirilmeden farklı
              // olduğu için ayrı satır.
              _infoRow(ctx.t('drive.info_created'),
                  FsPaths.humanDate(file.createdAtMs)),
              // Sahip yalnız BİLİNİYORSA yazılır: boş bir satır "sahibi yok"
              // gibi okunurdu.
              if (file.ownerName.isNotEmpty)
                _infoRow(ctx.t('drive.info_owner'), file.ownerName),
              _infoRow(
                ctx.t('drive.info_shared'),
                ctx.t(file.shared ? 'drive.shared_yes' : 'drive.shared_no'),
              ),
              _infoRow(ctx.t('drive.info_starred'),
                  ctx.t(file.starred ? 'common.yes' : 'common.no')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
  }

  /// "PDF · Belgeler" gibi okunur tür. Ham MIME (`application/vnd.openxml…`)
  /// kullanıcıya hiçbir şey anlatmıyordu; Google biçimlerinde ise indirilecek
  /// biçim yazılıyor ("Google E-Tablolar → XLSX").
  String _kindLabel(BuildContext ctx, DriveFile file) {
    if (file.isFolder) return ctx.t('drive.folder');
    final ext = file.extension.toUpperCase();
    final category = ctx.t(file.category.labelKey);
    final base = ext.isEmpty ? category : '$ext · $category';
    if (!file.isGoogleDoc) return base;
    final export = file.exportAs?.$2;
    return export == null
        ? base
        : '$category · ${ctx.t('drive.exports_as', {
              'format': export.toUpperCase()
            })}';
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$label: $value'),
      );

  /// Panoya al (kopyala/kes). Kaynak klasör şu an bulunulan klasördür;
  /// menü arama sonuçlarında gösterilmiyor, orada "hangi klasörden" sorusunun
  /// cevabı yok.
  void _clipSet(DriveFile file, {required bool cut}) {
    _partSetState(() =>
        _clip = (file: file, fromParentId: _current.$1, cut: cut));
  }

  Future<void> _paste() async {
    final clip = _clip;
    if (clip == null) return;
    final target = _current.$1;
    // Aynı klasöre taşımak hiçbir şeyi değiştirmez; Drive'a boşuna istek
    // atmak yerine pano kapatılır.
    if (clip.cut && clip.fromParentId == target) {
      _partSetState(() => _clip = null);
      return;
    }
    _partSetState(() => _busy = true);
    try {
      if (clip.cut) {
        await _drive.move(clip.file.id,
            toParentId: target, fromParentId: clip.fromParentId);
      } else {
        await _drive.copy(
          clip.file.id,
          toParentId: target,
          // Aynı klasördeyse ad değişir, yoksa listede ayırt edilemeyen iki
          // satır olurdu (Drive aynı adlı iki dosyaya izin verir).
          name: clip.fromParentId == target
              ? _copyName(clip.file.name)
              : null,
        );
      }
      _partSetState(() => _clip = null);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _busy = false);
      _snack('${context.t('drive.paste_failed')} ${_DriveScreenState._detail(e)}');
    }
  }

  /// "Rapor.pdf" → "Rapor (kopya).pdf". Etiket uzantıdan ÖNCE giriyor; sona
  /// eklenirse dosya "…pdf (kopya)" olur ve hiçbir uygulama açamaz.
  String _copyName(String name) {
    final tag = context.t('drive.copy_tag');
    final dot = name.lastIndexOf('.');
    return dot <= 0
        ? '$name ($tag)'
        : '${name.substring(0, dot)} ($tag)${name.substring(dot)}';
  }

  Future<void> _delete(DriveFile file) async {
    final title = context.t('drive.delete_confirm', {'name': file.name});
    final cancel = context.t('common.cancel');
    final del = context.t('common.delete');
    final failed = context.t('drive.delete_failed');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(del)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Kalıcı `delete` DEĞİL: Drive'ın kendi davranışı gibi çöp kutusuna
      // gider, 30 gün geri alınabilir.
      await _drive.trash(file.id);
      await _refresh();
    } catch (e) {
      if (mounted) _snack('$failed ${_DriveScreenState._detail(e)}');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    showSnack(context, m.trim());
  }
}
