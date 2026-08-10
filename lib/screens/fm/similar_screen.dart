import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/image_hash.dart';
import '../../services/fm/image_resize.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/similar_finder.dart';
import '../../services/fm/thumbnail_cache.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'entry_actions.dart';

/// **Benzer fotoğraf/videolar** — algısal parmak iziyle bulunan kümeler.
///
/// `DuplicatesScreen`'den ayrımı bilinçli: orada dosyalar **bayt bayt** aynı,
/// burada yalnız *aynı görünüyor*. Bu yüzden:
/// - hiçbir şey kendiliğinden silinmez, her grupta **en büyük** (en az
///   sıkıştırılmış) dosya korunacak diye önceden işaretlenir;
/// - küçük resimler yan yana çizilir, kullanıcı gözüyle doğrular;
/// - istenirse grup Gemini'ye sorulur ("aynı sahnenin iki karesi mi?").
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

  const SimilarScreen({
    super.key,
    this.files = const [],
    this.loadAll,
    this.title,
    this.scopeId = 'all',
  });

  @override
  State<SimilarScreen> createState() => _SimilarScreenState();
}

class _SimilarScreenState extends State<SimilarScreen> {
  final Set<String> _selected = {};
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
    // Kuyruk işi ekran kapansa da sürer → metinler ŞİMDİ çözülür.
    final strings = AppStrings.of(context);
    final level = _level;
    _levelByScope[widget.scopeId] = level;
    final loader = widget.loadAll;
    JobQueue.instance.enqueue(
      id: _jobId,
      title: strings.t('sim.scanning_title',
          {'level': strings.t(level.labelKey)}),
      total: widget.files.length,
      // Sonuç bu kapsamın ekranında duruyor; hedef onu geri açar (tarama
      // baştan başlamaz, sonuç kuyrukta kayıtlı).
      target: FmJobTarget.similar(
          scopeId: widget.scopeId, title: widget.title),
      run: (handle) async {
        var files = widget.files;
        if (loader != null) {
          handle.report(detail: strings.t('sim.preparing_list'));
          final all = await loader();
          // Kısa liste dönerse elimizdekini koru (bkz. kategori ekranları).
          if (all.length > files.length) files = all;
        }
        final groups = await SimilarFinder.run(
          files,
          level: level,
          handle: handle,
          strings: strings,
        );
        handle.result = groups;
      },
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
      final gone = files.map((f) => f.path).toSet();
      final kept = <SimilarGroup>[];
      for (final g in _groups) {
        final rest = g.files.where((f) => !gone.contains(f.path)).toList();
        if (rest.length > 1) kept.add(SimilarGroup(rest));
      }
      job.result = kept;
    }
    setState(() => _selected.removeAll(files.map((f) => f.path)));
  }

  /// Gemini'ye gönderilecek küçük önizleme — **video dahil**.
  ///
  /// Kullanıcının isteği *"video ve fotoğraflarda ai ile aynı resimleri
  /// tespit"* idi; cihaz-içi parmak izi videoda zaten çalışıyor (küçük resim
  /// karesini hash'liyor) ama Gemini yolu "video desteklenmiyor" diyordu —
  /// yani AI karşılaştırması isteğin yarısını karşılıyordu. Video için aynı
  /// native küçük resim karesi (`ThumbnailCache`, MediaMetadataRetriever)
  /// kullanılıp o JPEG küçültülüyor. Kare üretilemezse null döner ve dosya
  /// karşılaştırmaya girmez.
  Future<Uint8List?> _previewFor(FsEntry file) async {
    if (file.category != FmCategory.video) {
      return ImageResizer.previewJpeg(file.path);
    }
    // 512 px: Gemini'ye giden önizleme zaten küçültülüyor, karenin daha
    // büyük üretilmesinin faydası yok.
    final frame = await ThumbnailCache.forVideo(file.path, size: 512);
    if (frame == null) return null;
    return ImageResizer.previewJpeg(frame);
  }

  /// Grubu Gemini'ye sorar (kullanıcı isteği: cihaz-içi + AI birlikte seçenek).
  Future<void> _askGemini(SimilarGroup group) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    if (!appState.hasApiKey) {
      messenger.showSnackBar(SnackBar(content: Text(str.t('sim.need_key'))));
      return;
    }
    // En çok 6 görsel: daha fazlası hem pahalı hem yanıtı bulanıklaştırır.
    final chosen = group.files.take(6).toList();
    messenger.showSnackBar(SnackBar(content: Text(str.t('sim.sending'))));
    final previews = <({String name, Uint8List bytes})>[];
    for (final f in chosen) {
      final bytes = await _previewFor(f);
      if (bytes != null) previews.add((name: f.name, bytes: bytes));
    }
    if (!mounted) return;
    if (previews.length < 2) {
      messenger.showSnackBar(
          SnackBar(content: Text(str.t('sim.too_few_previews'))));
      return;
    }
    try {
      final service =
          appState.gemini;
      final answer = await service.compareImages([
        for (final preview in previews)
          (name: preview.name, bytes: preview.bytes),
      ]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('sim.gemini_opinion')),
          content: SingleChildScrollView(child: Text(answer)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.close')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Gemini: $e')));
      }
    }
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
            icon: const Icon(Icons.refresh),
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.lg),
                          child: Text(
                            job?.status == JobStatus.failed
                                ? context.t(
                                    'sim.scan_failed', {'error': job?.error})
                                : context.t('sim.none'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
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
                  icon: const Icon(Icons.delete_outline),
                  // Etiket ayarı okur: çöp kutusu kapalıyken "çöpe taşı" demek
                  // kullanıcıya geri alabileceğini söylemek olurdu.
                  label: Text('${deleteActionText(
                    useTrash: context.watch<AppState>().fmUseTrash,
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
                  TextButton.icon(
                    onPressed: () => _askGemini(group),
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: Text(context.t('fm.ask_gemini')),
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
                    // desen `FmEntryListTile`'daki iç-içe "⋮" düğmesinde de var).
                    if (isVideo)
                      Center(
                        child: Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => EntryOpener.open(context, file.path),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.play_arrow,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        selected
                            ? Icons.delete_forever
                            : Icons.circle_outlined,
                        size: 18,
                        color: selected ? scheme.error : Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54)
                        ],
                      ),
                    ),
                    if (best)
                      Positioned(
                        left: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          color: scheme.primary,
                          child: Text(context.t('common.best'),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onPrimary)),
                        ),
                      ),
                  ],
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
