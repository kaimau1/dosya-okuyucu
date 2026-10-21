part of '../entry_actions.dart';

/// Özellikler penceresi. Klasörlerde boyut istek üzerine hesaplanır (büyük
/// ağaçta saniyeler sürebilir — pencere açılışını bekletmeyiz).
Future<void> showProperties(BuildContext context, FsEntry entry) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _PropertiesDialog(entry: entry),
  );
}

class _PropertiesDialog extends StatefulWidget {
  final FsEntry entry;
  const _PropertiesDialog({required this.entry});

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  int? _folderSize;
  bool _calculating = false;

  /// Hesaplanmış SHA-256 özeti (2026-09-06 denetim turu).
  ///
  /// **İSTEK ÜZERİNE** hesaplanıyor: 4 GB'lık bir videoyu okumak saniyeler
  /// sürer ve özelliklere bakan kullanıcıların çoğu özeti merak etmiyor.
  /// Pencere açılışında başlatmak, her dokunuşta diski baştan sona okumak
  /// olurdu.
  String? _digest;
  bool _hashing = false;
  double _hashProgress = 0;

  /// Fotoğrafın EXIF künyesi (varsa). Dosya küçük bir başlık kadar okunuyor,
  /// o yüzden pencere açılırken başlatılabiliyor.
  ExifData? _exif;

  /// Metin dosyasının kodlaması ("UTF-8", "UTF-16 LE", "Windows-1254").
  ///
  /// Niye görünür olmalı (2026-09-06): kullanıcı bozuk görünen bir dosyada
  /// "bu neden böyle" diye soruyor; cevabı kodlama. Yalnız ilk baytlar
  /// okunuyor.
  String? _encoding;

  /// Son açılma zamanı (bizim kaydımız). Kullanıcı isteği 2026-07-29:
  /// *"son açılma tarihi TÜM DOSYALAR içinde yapılabilmeli"* — ayrı ekranın
  /// yanında dosyanın kendi özelliklerinde de görünmesi gerekiyor, çünkü
  /// kullanıcı tek bir dosyayı merak ettiğinde listeye değil buraya bakar.
  /// Dosya sisteminin "erişilme" damgası (`accessedMs`) bunun yerine
  /// KULLANILAMAZ: Android'de tarama/yedekleme gibi işler de onu güncelliyor,
  /// yani "kullanıcı ne zaman açtı" sorusunu yanıtlamıyor.
  int? _openedAtMs;

  @override
  void initState() {
    super.initState();
    _loadOpenedAt();
    _loadExif();
    _loadEncoding();
  }

  Future<void> _loadEncoding() async {
    final entry = widget.entry;
    if (entry.isDir || entry.category != FmCategory.document) return;
    if (!ContentSearch.isSearchable(entry.path)) return;
    try {
      final head = await File(entry.path).openRead(0, 64).first;
      if (!mounted) return;
      setState(() => _encoding = TextDecode.describeEncoding(head));
    } catch (_) {
      // Okunamayan dosya için satır hiç çizilmiyor.
    }
  }

  Future<void> _loadExif() async {
    final entry = widget.entry;
    if (entry.isDir || entry.category != FmCategory.image) return;
    final data = await ExifReader.read(entry.path);
    if (!mounted || data.isEmpty) return;
    setState(() => _exif = data);
  }

  /// SHA-256'yı hesaplar. Pencere kapanırsa iş de durur (`mounted`): açık
  /// olmayan bir pencere için diski okumaya devam etmenin anlamı yok.
  Future<void> _computeDigest() async {
    setState(() {
      _hashing = true;
      _hashProgress = 0;
    });
    final value = await FileDigest.sha256Of(
      widget.entry.path,
      isCancelled: () => !mounted,
      onProgress: (done, total) {
        if (!mounted || total <= 0) return;
        final next = done / total;
        // Her blokta setState çağırmak yerine %1'lik adımlarda: 4 GB'lık
        // dosyada 4000 yeniden çizim, hesaplamanın kendisinden pahalı.
        if (next - _hashProgress >= 0.01) {
          setState(() => _hashProgress = next);
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _digest = value;
      _hashing = false;
    });
  }

  Future<void> _loadOpenedAt() async {
    await OpenHistory.ensureLoaded();
    if (!mounted) return;
    setState(() => _openedAtMs = OpenHistory.forPath(widget.entry.path));
  }

  /// Klasörün içindeki dosya ve klasör sayısı (2026-09-06 denetim turu).
  ///
  /// Boyut tek başına "bu klasörde ne kadar iş var" sorusunu yanıtlamıyor:
  /// 2 GB bir video da olabilir, 40 000 küçük dosya da — ve ikisi kopyalarken
  /// bambaşka sürüyor.
  ({int files, int dirs})? _counts;

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    final size = await FsScan.folderSize(widget.entry.path);
    final counts = await _countChildren(widget.entry.path);
    if (!mounted) return;
    setState(() {
      _folderSize = size;
      _counts = counts;
      _calculating = false;
    });
  }

  /// Özyinelemeli sayım — arada nefes alır (binlerce girdide arayüz donmasın).
  static Future<({int files, int dirs})> _countChildren(String root) async {
    var files = 0;
    var dirs = 0;
    var steps = 0;
    Future<void> walk(Directory dir, int depth) async {
      if (depth > 24) return;
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        return;
      }
      for (final child in children) {
        if (++steps % 256 == 0) await Future<void>.delayed(Duration.zero);
        if (child is Directory) {
          dirs++;
          await walk(child, depth + 1);
        } else {
          files++;
        }
      }
    }

    await walk(Directory(root), 0);
    return (files: files, dirs: dirs);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return AlertDialog(
      title: Text(context.t('fm.properties')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(context.t('prop.name'), e.name),
            _row(context.t('fm.type'), e.isDir ? context.t('fm.folder') : e.category.label),
            if (!e.isDir) _row(context.t('prop.size'), FsPaths.humanSize(e.sizeBytes)),
            if (e.isDir)
              _row(
                context.t('prop.size'),
                _folderSize != null
                    ? FsPaths.humanSize(_folderSize!)
                    : (_calculating ? context.t('fm.computing') : context.t('fm.not_computed')),
              ),
            _row(context.t('fm.modified'), FsPaths.humanDate(e.modifiedMs)),
            // Yalnız gerçekten bir kaydımız varsa yazılır: "—" göstermek
            // "hiç açılmadı" ile "bilmiyorum"u karıştırırdı.
            if (_openedAtMs != null)
              _row(context.t('fm.last_opened'), FsPaths.humanDate(_openedAtMs!)),
            _row(context.t('prop.location'), e.path),
            if (_counts != null)
              _row(
                context.t('prop.contents'),
                context.t('prop.contents_value',
                    {'files': _counts!.files, 'dirs': _counts!.dirs}),
              ),
            if (_encoding != null) _row(context.t('prop.encoding'), _encoding!),
            if (!e.isDir) ..._digestSection(context),
            if (_exif != null) ..._exifSection(context, _exif!),
          ],
        ),
      ),
      actions: [
        if (e.isDir && _folderSize == null)
          TextButton(
            onPressed: _calculating ? null : _calculate,
            child: Text(context.t('fm.calc_size')),
          ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: e.name));
            Navigator.pop(context);
          },
          child: Text(context.t('prop.copy_name')),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: e.path));
            Navigator.pop(context);
          },
          child: Text(context.t('fm.copy_path')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }

  /// **Özet satırı** — "indirdiğim dosya bozuk mu?" sorusunun cevabı.
  ///
  /// Hesaplanmadan önce bir düğme, hesaplanırken ilerleme, sonra dokununca
  /// panoya kopyalanan bir değer. Değer `SelectableText`: kullanıcı yayıncının
  /// sitesindeki özetle GÖZLE de karşılaştırabilmeli.
  List<Widget> _digestSection(BuildContext context) {
    if (_digest != null) {
      return [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _digest!));
            _snack(context, context.t('prop.digest_copied'));
          },
          child: _row(context.t('prop.digest'), _digest!),
        ),
      ];
    }
    if (_hashing) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('prop.digest'),
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: _hashProgress > 0 ? _hashProgress : null),
            ],
          ),
        ),
      ];
    }
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _computeDigest,
          icon: const Icon(Icons.tag, size: 18),
          label: Text(context.t('prop.compute_digest')),
        ),
      ),
    ];
  }

  /// Fotoğrafın künyesi. **Konum (GPS) BİLİNÇLİ OLARAK YOK** — bkz.
  /// `services/fm/exif_reader.dart`.
  List<Widget> _exifSection(BuildContext context, ExifData exif) {
    final rows = <Widget>[
      const SizedBox(height: 8),
      Text(context.t('prop.photo_info'),
          style: Theme.of(context).textTheme.titleSmall),
    ];
    void add(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(_row(label, value));
    }

    add(context.t('prop.taken_at'),
        exif.taken == null ? null : FsPaths.humanDate(
            exif.taken!.millisecondsSinceEpoch));
    add(context.t('prop.camera'), exif.camera);
    add(context.t('prop.lens'), exif.lens);
    if (exif.width != null && exif.height != null) {
      add(context.t('prop.resolution'), '${exif.width} × ${exif.height}');
    }
    add(context.t('prop.iso'), exif.iso?.toString());
    add(context.t('prop.exposure'), exif.exposureLabel);
    add(context.t('prop.aperture'),
        exif.aperture == null ? null : 'f/${exif.aperture!.toStringAsFixed(1)
            .replaceAll('.', ',')}');
    add(context.t('prop.focal'),
        exif.focalLength == null ? null : '${exif.focalLength!.round()} mm');
    add(
      context.t('prop.flash'),
      exif.flash == null
          ? null
          : (exif.flash! ? context.t('prop.flash_on') : context.t('prop.flash_off')),
    );
    add(context.t('prop.software'), exif.software);
    return rows;
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            SelectableText(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

String _parentOf(String path) {
  final i = path.lastIndexOf('/');
  return i <= 0 ? '/' : path.substring(0, i);
}

void _snack(BuildContext context, String message) {
  showSnack(context, message);
}

/// [entry] için telefonun ana ekranına kısayol ister (bkz. [HomeShortcuts]).
///
/// Simge dosya türünün renginde çizilir: PDF kırmızı, klasör kehribar…
/// Başlatıcı onayı kendisi sorar; desteklemiyorsa kullanıcıya söylenir.
Future<void> addHomeShortcut(BuildContext context, FsEntry entry) async {
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final IconData icon;
  final Color color;
  if (entry.isDir) {
    icon = FmColors.forFolderName(entry.name) ?? Icons.folder_rounded;
    color = FmColors.folder;
  } else {
    final ext = entry.extension.toLowerCase();
    final special = FmColors.forExtension(ext);
    if (special != null) {
      (icon, color) = special;
    } else if (entry.category == FmCategory.document) {
      final kind = FileService.iconKindForExtension(ext);
      color = OfficeColors.forKind(kind);
      icon = switch (ext) {
        'pdf' => Icons.picture_as_pdf_rounded,
        'doc' || 'docx' || 'odt' || 'rtf' => Icons.article_rounded,
        'xls' || 'xlsx' || 'csv' || 'ods' => Icons.table_chart_rounded,
        'ppt' || 'pptx' || 'odp' => Icons.slideshow_rounded,
        _ => Icons.description_rounded,
      };
    } else {
      icon = FmColors.iconFor(entry.category);
      color = FmColors.forCategory(entry.category);
    }
  }
  if (!await HomeShortcuts.supported()) {
    showSnackOn(messenger, strings.t('ea.shortcut_unsupported'));
    return;
  }
  final ok = await HomeShortcuts.pin(
    path: entry.path,
    label: entry.name,
    icon: icon,
    color: color,
  );
  showSnackOn(
      messenger,
      ok
          ? strings.t('ea.shortcut_requested', {'name': entry.name})
          : strings.t('ea.shortcut_failed'));
}

/// Öğeleri gizler = **şifreli kasaya taşır** (2026-10-21, Faz 2 "tek Kasa";
/// eskiden şifresiz [HiddenVault]'a taşıyordu). Onay sorulur; kasa kilitliyse
/// kilit ekranı açılır. Bir şey taşındıysa true (liste tazelensin).
Future<bool> hideEntries(BuildContext context, List<String> paths) async {
  if (paths.isEmpty) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.enhanced_encryption_outlined),
      title: Text(ctx.t('hv.confirm_title', {'n': paths.length})),
      content: Text(ctx.t('hv.confirm_body')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('ea.hide'))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  return addToVault(context, paths);
}
