
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/state/focused_states.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_hash.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/similar_finder.dart';
import '../../widgets/motion.dart' show FmEmptyState, PressScale;
import '../../widgets/state_views.dart' show AppErrorView;
import '../../widgets/fm/fm_entry_icon.dart';
import 'entry_actions.dart';
import '../../core/user_error.dart';
import '../../core/safe_insets.dart';
import '../../core/app_colors.dart';

/// **Benzer fotoğraf/videolar** — algısal parmak iziyle bulunan kümeler.
///
/// `DuplicatesScreen`'den ayrımı bilinçli: orada dosyalar **bayt bayt** aynı,
/// burada yalnız *aynı görünüyor*. Bu yüzden:
/// - hiçbir şey kendiliğinden silinmez, her grupta **en büyük** (en az
///   sıkıştırılmış) dosya korunacak diye önceden işaretlenir;
/// - küçük resimler yan yana çizilir, kullanıcı gözüyle doğrular;
///
/// Tarama [JobQueue]'da koşar: kullanıcı ekranı kapatıp başka işe geçebilir,
/// döndüğünde sonuç hazır bekler.
class SimilarScreen extends StatefulWidget {
  /// Taranacak dosyalar (kategori ekranının elindeki liste).
  final List<FsEntry> files;

  /// Liste hazır değilse (ör. panodan girildi) **eksiksiz** listeyi getiren
  /// yükleyici. Yükleme de işin parçası olur, ilerleme aynı şeritte görünür.
  final Future<List<FsEntry>> Function()? loadAll;

  /// Başlık; verilmezse “Benzer görüntüler” çevirisi kullanılır.
  final String? title;

  /// Bu taramanın **kapsam kimliği** — kuyruk kimliği buradan üretilir
  /// (bkz. [SimilarFinder.jobIdFor]). Aynı kapsamdan tekrar girmek taramayı
  /// baştan başlatmaz; farklı kapsam (Görüntüler / Videolar / tüm medya) kendi
  /// sonucunu tutar.
  final String scopeId;

  /// Seçimi dışarıyla PAYLAŞ (B18): Yer aç'tan açılınca buradaki işaretler
  /// Yer aç'ın seçimidir — geri dönünce toplam ve "X yer aç" düğmesi onu
  /// sayar. Verilmezse ekranın kendi seçimi.
  final Set<String>? picks;

  const SimilarScreen({
    super.key,
    this.files = const [],
    this.loadAll,
    this.title,
    this.scopeId = 'all',
    this.picks,
  });

  /// Bu kapsamın son taramasında kullanılan kademe (hiç taranmadıysa null).
  static SimilarityLevel? levelOf(String scopeId) =>
      _SimilarScreenState._levelByScope[scopeId];

  /// Taramayı kuyruğa verir (ekran açık olmasa da — Yer aç arka planda
  /// başlatır, B18). Aynı kapsam sürüyorsa süren iş döner.
  static FmJob startScan({
    required String scopeId,
    List<FsEntry> files = const [],
    Future<List<FsEntry>> Function()? loadAll,
    SimilarityLevel level = SimilarityLevel.normal,
    String? title,
  }) {
    // Kuyruk işi ekran kapansa da sürer → metinler ŞİMDİ çözülür.
    // `AppStrings.current` (bağlamsız): `initState`ten de çağrılıyor ve orada
    // `AppStrings.of(context)` = `Localizations`a bağımlılık kurmak yasak.
    final strings = AppStrings.current;
    _SimilarScreenState._levelByScope[scopeId] = level;
    return JobQueue.instance.enqueue(
      id: SimilarFinder.jobIdFor(scopeId),
      title: strings.t('sim.scanning_title',
          {'level': strings.t(level.labelKey)}),
      name: strings
          .t('sim.scanning_name', {'level': strings.t(level.labelKey)}),
      total: files.length,
      // Sonuç bu kapsamın ekranında duruyor; hedef onu geri açar (tarama
      // baştan başlamaz, sonuç kuyrukta kayıtlı).
      target: FmJobTarget.similar(scopeId: scopeId, title: title),
      run: (handle) async {
        var list = files;
        if (loadAll != null) {
          handle.report(detail: strings.t('sim.preparing_list'));
          final all = await loadAll();
          // Kısa liste dönerse elimizdekini koru (bkz. kategori ekranları).
          if (all.length > list.length) list = all;
        }
        handle.result = await SimilarFinder.run(
          list,
          level: level,
          handle: handle,
          strings: strings,
        );
      },
    );
  }

  /// SAF: [gone] yolları düşülmüş gruplar; tek dosyası kalan grup kalkar.
  static List<SimilarGroup> without(
      List<SimilarGroup> groups, Set<String> gone) {
    final kept = <SimilarGroup>[];
    for (final g in groups) {
      final rest = g.files.where((f) => !gone.contains(f.path)).toList();
      if (rest.length > 1) kept.add(SimilarGroup(rest));
    }
    return kept;
  }

  @override
  State<SimilarScreen> createState() => _SimilarScreenState();
}

class _SimilarScreenState extends State<SimilarScreen> {
  late final Set<String> _selected = widget.picks ?? <String>{};
  SimilarityLevel _level = SimilarityLevel.normal;

  /// Kapsam başına **son kullanılan benzerlik kademesi**.
  ///
  /// `_level` ekranın kendi durumu ve her girişte "Normal"e dönüyordu; oysa
  /// kuyruk kimliği kademeyi içermiyor (bilinçli: kademe değiştirmek yeniden
  /// tarama demek, geri dönmek değil). Sonuç: "Sıkı" ile tarayıp geri dönen
  /// kullanıcı, çipte "Normal" seçili ve altında Normal'in açıklaması yazarken
  /// ekranda SIKI sonuçlarını görüyordu — silme kararını kullanılmayan bir
  /// eşiğe göre veriyordu (2026-07-29 sadakat denetimi, 2. tur).
  static final Map<String, SimilarityLevel> _levelByScope = {};

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    // Sonuç zaten varsa (kullanıcı geri döndü) yeniden tarama YOK.
    //
    // `cancelled` de yeniden taranır: iptal edilmiş bir taramanın sonucu YARIM
    // (ya da hiç yok) ve ekran bunu "benzer bulunamadı 🎉" diye gösteriyordu —
    // kullanıcı taramayı kendi durdurduğunu bilse bile ekranın bir daha asla
    // taramaması, "Yeniden tara"ya basmadan yanlış bir güvence vermekti.
    final job = _job;
    if (job == null ||
        job.status == JobStatus.failed ||
        job.status == JobStatus.cancelled) {
      _start();
    } else {
      // Gösterilen sonuç hangi kademeyle üretildiyse çip de onu göstermeli.
      _level = _levelByScope[widget.scopeId] ?? _level;
    }
  }

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    super.dispose();
  }

  void _onQueue() {
    if (mounted) setState(() {});
  }

  String get _jobId => SimilarFinder.jobIdFor(widget.scopeId);

  FmJob? get _job => JobQueue.instance.find(_jobId);

  List<SimilarGroup> get _groups {
    final result = _job?.result;
    return result is List<SimilarGroup> ? result : const [];
  }

  void _start() {
    SimilarScreen.startScan(
      scopeId: widget.scopeId,
      files: widget.files,
      loadAll: widget.loadAll,
      level: _level,
      title: widget.title,
    );
    setState(() => _selected.clear());
  }

  /// Her gruptan en iyisi (ilk) korunur, kalanlar işaretlenir.
  void _selectExtras() {
    setState(() {
      _selected.clear();
      for (final g in _groups) {
        for (final f in g.files.skip(1)) {
          _selected.add(f.path);
        }
      }
    });
  }

  int get _selectedBytes => _groups
      .expand((g) => g.files)
      .where((f) => _selected.contains(f.path))
      .fold(0, (sum, f) => sum + f.sizeBytes);

  Future<void> _deleteSelected() async {
    final files = _groups
        .expand((g) => g.files)
        .where((f) => _selected.contains(f.path))
        .toList();
    if (files.isEmpty) return;
    if (!await deleteEntries(context, files)) return;
    if (!mounted) return;
    // Silinenler listeden düşsün: yeniden tarama gerekmez, sonuçtaki kayıtları
    // ayıklamak yeter (parmak izleri önbellekte, tekrar tarama bedava değil).
    final job = _job;
    if (job != null) {
      job.result =
          SimilarScreen.without(_groups, files.map((f) => f.path).toSet());
    }
    setState(() => _selected.removeAll(files.map((f) => f.path)));
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final running = job?.status.isActive ?? false;
    final groups = _groups;
    final wasted = groups.fold<int>(0, (sum, g) => sum + g.wastedBytes);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.t('sim.title')),
        actions: [
          IconButton(
            tooltip: context.t('common.rescan'),
            icon: const Icon(AppIcons.refresh),
            onPressed: running ? null : _start,
          ),
        ],
      ),
      body: Column(
        children: [
          _levelPicker(running),
          const Divider(height: 1),
          if (running) _progress(job!),
          if (!running && groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('sim.groups_summary', {
                        'n': groups.length,
                        'size': FsPaths.humanSize(wasted),
                      }),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _selectExtras,
                    child: Text(context.t('sim.select_extras')),
                  ),
                ],
              ),
            ),
          Expanded(
            child: running
                ? const SizedBox.shrink()
                : groups.isEmpty
                    // H10.3: ham hata metni yok — kısa açıklama + Yeniden dene;
                    // ham metin yalnız "Ayrıntıyı kopyala"da.
                    ? job?.status == JobStatus.failed
                        ? AppErrorView(
                            title: context.t('sim.scan_failed'),
                            message: userErrorText(job?.error ?? ''),
                            details: job?.error,
                            onRetry: _start,
                          )
                        : FmEmptyState(
                            icon: AppIcons.verified,
                            title: context.t('sim.none'))
                    : ListView.builder(
                        padding: withNavInset(
                            context, const EdgeInsets.only(bottom: 96)),
                        itemCount: groups.length,
                        itemBuilder: (context, i) => _groupCard(groups[i]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: FilledButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(AppIcons.delete),
                  // Etiket ayarı okur: çöp kutusu kapalıyken "çöpe taşı" demek
                  // kullanıcıya geri alabileceğini söylemek olurdu.
                  label: Text('${deleteActionText(
                    useTrash: context.watchBrowse().fmUseTrash,
                    what: context.t('sim.n_files', {'n': _selected.length}),
                    strings: AppStrings.of(context),
                  )} (${FsPaths.humanSize(_selectedBytes)})'),
                ),
              ),
            ),
    );
  }

  Widget _progress(FmJob job) => Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          children: [
            LinearProgressIndicator(value: job.progress),
            const SizedBox(height: Gap.sm),
            Text(job.detail.isEmpty ? context.t('sim.scanning') : job.detail),
            const SizedBox(height: Gap.xs),
            Text(
              context.t('sim.background_note'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _levelPicker(bool running) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Gap.sm,
              children: [
                for (final l in SimilarityLevel.values)
                  ChoiceChip(
                    label: Text(context.t(l.labelKey)),
                    selected: _level == l,
                    onSelected: running
                        ? null
                        : (_) {
                            setState(() => _level = l);
                            _start();
                          },
                  ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(context.t(_level.descriptionKey),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _groupCard(SimilarGroup group) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('sim.group_summary', {
                        'n': group.files.length,
                        'size': FsPaths.humanSize(group.wastedBytes),
                      }),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 132,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                children: [
                  for (var i = 0; i < group.files.length; i++)
                    _thumb(group.files[i], best: i == 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(FsEntry file, {required bool best}) {
    final selected = _selected.contains(file.path);
    final scheme = Theme.of(context).colorScheme;
    final tags = FileTags.forPath(file.path);
    final isVideo = file.category == FmCategory.video;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  if (!_selected.remove(file.path)) _selected.add(file.path);
                }),
                onLongPress: () => EntryOpener.open(context, file.path),
                child: PressScale(
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FmEntryIcon(entry: file, size: 96, radius: 8),
                    if (selected)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    // Videoyu OYNATMAK için ayrı, görünür bir düğme (istek
                    // 2026-07-29: "benzer videolar oynatma yapılabilmeli emin
                    // olabilmek için"). Tek dokunuş burada zaten seçime
                    // ayrılmış; oynatma uzun basışta gizli kalıyordu ve
                    // kullanıcı silmeden önce videoyu GÖRMEDEN karar veriyordu.
                    // İçteki düğme kendi dokunuşunu yakalar, dıştaki
                    // GestureDetector'ın seçim davranışını tetiklemez (aynı
                    // desen `FmEntryRow`'daki iç-içe "⋮" düğmesinde de var).
                    if (isVideo)
                      Center(
                        child: Material(
                          color: AppColors.mediaScrimLight,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => EntryOpener.open(context, file.path),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(AppIcons.play,
                                  color: AppColors.onMedia, size: 20),
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: Icon(
                        selected
                            ? AppIcons.deleteForever
                            : AppIcons.dot,
                        size: 18,
                        color: selected ? scheme.error : AppColors.onMedia,
                        shadows: const [
                          Shadow(blurRadius: 4, color: AppColors.mediaScrim)
                        ],
                      ),
                    ),
                    if (best)
                      PositionedDirectional(
                        start: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          color: scheme.primary,
                          child: Text(context.t('common.best'),
                              style: context.type.micro.copyWith(
                                  color: scheme.onPrimary,
                                )),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              FsPaths.humanSize(file.sizeBytes),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              tags.isNotEmpty ? tags.join(', ') : p.basename(p.dirname(file.path)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
