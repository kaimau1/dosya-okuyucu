part of '../entry_actions.dart';

/// Özellikler levhası. Klasörlerde boyut istek üzerine hesaplanır (büyük
/// ağaçta saniyeler sürebilir — levha açılışını bekletmeyiz).
///
/// **Alt levha, menüyle aynı dil** (2026-11-15, kullanıcı: *"Özellikler
/// sayfasını da yeniden tasarla, görsel birliğe uysun"*): eskiden düz bir
/// AlertDialog'du (etiket/değer alt alta, metin düğmeleri). Şimdi işlem
/// levhasının başlık kartı, bilgi kartı (`MenuGroupCard`) ve Bento karoları.
Future<void> showProperties(BuildContext context, FsEntry entry) async {
  // Ortak levha kabuğu (tasarım tokenı mandalı: ham showModalBottomSheet yok).
  await showAppSheet<void>(
    context,
    scrollable: false,
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
        children = await dir.list(followLinks: false).toList();
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
    final scheme = Theme.of(context).colorScheme;
    final info = <Widget>[
      _row(context.t('fm.type'),
          e.isDir ? context.t('fm.folder') : e.category.label),
      if (!e.isDir) _row(context.t('prop.size'), FsPaths.humanSize(e.sizeBytes)),
      if (e.isDir)
        _row(
          context.t('prop.size'),
          _folderSize != null
              ? FsPaths.humanSize(_folderSize!)
              : (_calculating
                  ? context.t('fm.computing')
                  : context.t('fm.not_computed')),
        ),
      if (_counts != null)
        _row(
          context.t('prop.contents'),
          context.t('prop.contents_value',
              {'files': _counts!.files, 'dirs': _counts!.dirs}),
        ),
      _row(context.t('fm.modified'), FsPaths.humanDate(e.modifiedMs)),
      // Yalnız gerçekten bir kaydımız varsa yazılır: "—" göstermek
      // "hiç açılmadı" ile "bilmiyorum"u karıştırırdı.
      if (_openedAtMs != null)
        _row(context.t('fm.last_opened'), FsPaths.humanDate(_openedAtMs!)),
      if (_encoding != null) _row(context.t('prop.encoding'), _encoding!),
    ];
    final exif = _exif == null ? const <Widget>[] : _exifRows(context, _exif!);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık kartı — işlem levhasınınkiyle aynı (simge, ad, boyut · tarih).
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(MenuKit.cardRadius),
              ),
              child: _sheetHeader(context, e),
            ),
            MenuGroupTitle(context.t('fm.properties'),
                padding: const EdgeInsetsDirectional.fromSTEB(4, Gap.md, 4, 6)),
            MenuGroupCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: _divided(info)),
            ),
            const SizedBox(height: 8),
            // Konum ayrı kart: uzun yol tam genişlikte sarsın, yanında
            // kopyalama düğmesi dursun.
            MenuGroupCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _row(context.t('prop.location'), e.path, stacked: true),
            ),
            if (!e.isDir) ...[
              const SizedBox(height: 8),
              _digestTile(context),
            ],
            if (exif.isNotEmpty) ...[
              MenuGroupTitle(context.t('prop.photo_info'),
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(4, Gap.md, 4, 6)),
              MenuGroupCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: _divided(exif)),
              ),
            ],
            const SizedBox(height: Gap.md),
            // Eylemler Bento karoları: iki sütun, simge üstte.
            Row(
              children: [
                if (e.isDir && _folderSize == null) ...[
                  Expanded(
                    child: _PropTile(
                      icon: AppIcons.storage,
                      label: context.t('fm.calc_size'),
                      onTap: _calculating ? null : _calculate,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _PropTile(
                    icon: AppIcons.textFields,
                    label: context.t('prop.copy_name'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: e.name));
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PropTile(
                    icon: AppIcons.link,
                    label: context.t('fm.copy_path'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: e.path));
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bilgi kartındaki satırların arasına ince ayraç.
  List<Widget> _divided(List<Widget> rows) => [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.5),
            ),
          rows[i],
        ],
      ];

  /// **Özet karosu** — "indirdiğim dosya bozuk mu?" sorusunun cevabı.
  ///
  /// Hesaplanmadan önce dokunulacak bir karo, hesaplanırken ilerleme, sonra
  /// dokununca panoya kopyalanan değer. Değer `SelectableText`: kullanıcı
  /// yayıncının sitesindeki özetle GÖZLE de karşılaştırabilmeli.
  Widget _digestTile(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Widget body;
    if (_digest != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('prop.digest'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          SelectableText(_digest!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace', color: scheme.onSurface)),
        ],
      );
    } else if (_hashing) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('prop.computing_digest'),
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: _hashProgress > 0 ? _hashProgress : null,
              borderRadius: BorderRadius.circular(4)),
        ],
      );
    } else {
      body = Text(context.t('prop.compute_digest'),
          style: theme.textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface));
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _hashing
            ? null
            : _digest != null
                ? () {
                    Clipboard.setData(ClipboardData(text: _digest!));
                    _snack(context, context.t('prop.digest_copied'));
                  }
                : _computeDigest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(AppIcons.fingerprint, size: 22, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: body),
                if (_digest != null) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.copy, size: 20, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fotoğrafın künyesi. **Konum (GPS) BİLİNÇLİ OLARAK YOK** — bkz.
  /// `services/fm/exif_reader.dart`.
  List<Widget> _exifRows(BuildContext context, ExifData exif) {
    final rows = <Widget>[];
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

  /// Bilgi satırı: etiket solda soluk, değer sağda (uzun değer — konum —
  /// [stacked] ile alt satırda tam genişlik).
  Widget _row(String label, String value, {bool stacked = false}) {
    final theme = Theme.of(context);
    final labelText = Text(label,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    final valueText = SelectableText(value,
        textAlign: stacked ? TextAlign.start : TextAlign.end,
        style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 2), valueText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelText,
                const SizedBox(width: 16),
                Expanded(child: valueText),
              ],
            ),
    );
  }
}

/// Özellikler levhasının eylem karosu — Bento kare karosunun dili
/// (simge üstte, kalın etiket altta).
class _PropTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PropTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    icon = FmColors.forFolderName(entry.name) ?? AppIcons.folder;
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
        'pdf' => AppIcons.pdf,
        'doc' || 'docx' || 'odt' || 'rtf' => AppIcons.newText,
        'xls' || 'xlsx' || 'csv' || 'ods' => AppIcons.newSheet,
        'ppt' || 'pptx' || 'odp' => AppIcons.slideshow,
        _ => AppIcons.newWord,
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
      icon: const Icon(AppIcons.vault),
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
