import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_search_field.dart';
import 'entry_actions.dart';

/// Yinelenen dosyalar: birebir aynı içerikli dosyaları bulur, her gruptan
/// birini bırakıp kalanları tek dokunuşla çöpe taşır.
///
/// Güvenlik: eşleşme **bayt bayt** doğrulanır (sadece hash'e güvenilmez) ve
/// her grupta en eski dosya varsayılan olarak KORUNUR — kullanıcı isterse
/// seçimi değiştirir.
class DuplicatesScreen extends StatefulWidget {
  final List<String> roots;
  const DuplicatesScreen({super.key, required this.roots});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  /// Kuyruktaki kararlı kimlik: ekran kapanıp açılsa da tarama baştan
  /// başlamaz (bayt bayt karşılaştırma dakikalar sürebilir — istek
  /// 2026-07-29: "işlemler arka planda çalışabilmeli").
  static const _jobId = 'duplicate_scan';

  final Set<String> _selected = {};

  /// Varsayılan seçim (her gruptan en eskisi hariç) yalnız sonuç
  /// DEĞİŞTİĞİNDE kurulur; yoksa kullanıcının kaldırdığı işaret her kuyruk
  /// bildiriminde geri gelirdi.
  String? _seedSignature;

  /// Yerinde arama (kullanıcı isteği 2026-07-29: "arama kısmı her yerde
  /// olmalı"). Grup, dosyalarından herhangi biri eşleşirse görünür.
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    JobQueue.instance.removeListener(_onQueue);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueue() {
    if (mounted) setState(_seedSelection);
  }

  FmJob? get _job => JobQueue.instance.find(_jobId);

  bool get _scanning => _job?.status.isActive ?? false;

  List<DuplicateGroup> get _groups {
    final result = _job?.result;
    return result is List<DuplicateGroup> ? result : const [];
  }

  void _seedSelection() {
    final groups = _groups;
    final signature = groups
        .map((g) => '${g.sizeBytes}:${g.files.length}:${g.files.first.path}')
        .join('|');
    if (signature == _seedSignature) return;
    _seedSignature = signature;
    _selected.clear();
    // Varsayılan: her gruptan EN ESKİ dosya korunur, kalanlar seçilir.
    for (final g in groups) {
      final sorted = [...g.files]
        ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      for (final f in sorted.skip(1)) {
        _selected.add(f.path);
      }
    }
  }

  List<DuplicateGroup> get _visibleGroups {
    if (_query.trim().isEmpty) return _groups;
    return _groups
        .where((g) => g.files.any((f) => fmMatches(f.name, _query)))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    JobQueue.instance.addListener(_onQueue);
    final job = _job;
    final hasResult = job?.result is List<DuplicateGroup>;
    // Sonuç varsa yeniden taramıyoruz; kullanıcı geri döndüğünde beklemesin.
    // Sonucu OLMAYAN ve artık koşmayan bir iş (başarısız **ya da iptal
    // edilmiş**) yeniden taranır: eskiden yalnız `failed` bakılıyordu, iptal
    // edilmiş bir taramadan sonra ekran "Yinelenen dosya bulunamadı 🎉" diye
    // yanlış bir güvence veriyordu (2026-07-29 sadakat denetimi).
    if (job == null || (!hasResult && !job.status.isActive)) {
      _scan();
    } else if (hasResult) {
      // Geri dönüşte varsayılan seçim burada kurulur: `_onQueue` yalnız kuyruk
      // bildiriminde çalışır, bitmiş bir iş bir daha bildirim üretmez — ekran
      // sonuçları gösteriyor ama "N kopyayı çöpe taşı" şeridi hiç görünmüyordu.
      _seedSelection();
    }
  }

  /// Taramayı arka plan kuyruğuna verir.
  void _scan() {
    // Kuyruk işi ekran kapansa da sürer → metinler ŞİMDİ çözülür.
    final strings = AppStrings.of(context);
    final roots = widget.roots;
    JobQueue.instance.enqueue(
      id: _jobId,
      title: strings.t('dup.scanning_title'),
      run: (handle) async {
        handle.report(detail: strings.t('dup.comparing'));
        final groups = await DuplicateFinder.scan(roots);
        // Sonuç iptal yoklamasından ÖNCE saklanır: `DuplicateFinder.scan`
        // ortasında durdurulamıyor, yani buraya gelindiğinde bayt bayt
        // karşılaştırma bitmiş demektir. Sırası tersken, tarama biterken
        // "Durdur"a basmak dakikalarca süren işi çöpe atıyordu (2026-07-29
        // sadakat denetimi). İş yine "İptal edildi" damgalanır — kullanıcı
        // durdurmayı istedi — ama elimizdeki geçerli sonuç korunur.
        handle.result = groups;
        handle.throwIfCancelled();
        final wasted = groups.fold<int>(0, (sum, g) => sum + g.wastedBytes);
        handle.report(
          detail: groups.isEmpty
              ? strings.t('dup.none_short')
              : strings.t('dup.job_summary', {
                  'n': groups.length,
                  'size': FsPaths.humanSize(wasted),
                }),
        );
      },
    );
    // İmza sıfırlanır, yoksa içerik değişmemişse (aynı gruplar) yeni sonuç
    // geldiğinde [_seedSelection] "değişmedi" deyip çıkar ve varsayılan seçim
    // bir daha hiç kurulmazdı — "Yeniden tara"dan sonra silme şeridi kaybolur.
    _seedSignature = null;
    setState(() => _selected.clear());
  }

  /// Şeritteki bayt sayısı da **görünen** gruplardan sayılır: düğmenin yazdığı
  /// sayı ile sildiği dosya kümesi aynı olmak zorunda ([_selectedFiles]).
  int get _selectedBytes =>
      _selectedFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  /// Silinecek dosyalar: **görünen** gruplardan seçili olanlar.
  ///
  /// `_groups` DEĞİL `_visibleGroups`: varsayılan seçim tüm gruplara kurulu ve
  /// arama kutusu yalnız çizimi daraltıyordu → kullanıcı tek bir çifti
  /// incelemek için "IMG_2024" yazdığında ekran "1 / 47 grup" derken alttaki
  /// şerit hâlâ 94 dosyayı çöpe atıyordu; hiç görmediği 46 grup dahil
  /// (2026-07-29 sadakat denetimi, 2. tur).
  List<FsEntry> get _selectedFiles => _visibleGroups
      .expand((g) => g.files)
      .where((f) => _selected.contains(f.path))
      .toList();

  Future<void> _deleteSelected() async {
    final files = _selectedFiles;
    if (files.isEmpty) return;
    if (!await deleteEntries(context, files)) return;
    if (!mounted) return; // "Arka plana al" → ekran kapanmış olabilir.
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    final wasted = _groups.fold<int>(0, (sum, g) => sum + g.wastedBytes);
    final selectedFiles = _selectedFiles;

    return Scaffold(
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                }),
              )
            : null,
        title: _searching
            ? FmSearchField(
                controller: _searchController,
                hint: 'Yinelenenlerde ara…',
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Yinelenen dosyalar'),
        actions: [
          if (!_searching)
            IconButton(
              tooltip: 'Ara',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            tooltip: 'Yeniden tara',
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: _scanning
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: _job?.progress),
                    const SizedBox(height: Gap.md),
                    Text(_job?.detail.isNotEmpty ?? false
                        ? _job!.detail
                        : context.t('dup.comparing_short')),
                    const SizedBox(height: Gap.sm),
                    Text(context.t('sim.background_note'),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : _groups.isEmpty
              ? Center(child: Text(context.t('dup.none')))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Row(
                        children: [
                          const Icon(Icons.cleaning_services_outlined),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(
                              context.t('dup.visible_summary', {
                                'shown': _visibleGroups.length,
                                'total': _groups.length,
                                'size': FsPaths.humanSize(wasted),
                              }),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _visibleGroups.isEmpty
                          ? Center(
                              child: Text(
                                  context.t('dup.no_match', {'query': _query})))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: _visibleGroups.length,
                              itemBuilder: (context, i) =>
                                  _groupTile(_visibleGroups[i], i),
                            ),
                    ),
                  ],
                ),
      // Şerit sayısı = gerçekten silinecek dosya sayısı ([_selectedFiles]).
      // Etiket ayarı da okur: çöp kutusu kapalıyken "çöpe taşı" demek yanlış.
      bottomNavigationBar: selectedFiles.isEmpty || _scanning
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: FilledButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('${deleteActionText(
                    useTrash: context.watch<AppState>().fmUseTrash,
                    what: context.t('dup.n_copies', {'n': selectedFiles.length}),
                    strings: AppStrings.of(context),
                  )} (${FsPaths.humanSize(_selectedBytes)})'),
                ),
              ),
            ),
    );
  }

  Widget _groupTile(DuplicateGroup group, int index) {
    final files = [...group.files]
      ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
    return Card(
      margin: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Text(
                context.t('dup.tile_summary', {
                  'n': files.length,
                  'size': FsPaths.humanSize(group.sizeBytes),
                  'waste': FsPaths.humanSize(group.wastedBytes),
                }),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final f in files) _fileRow(f, keep: f == files.first),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(FsEntry file, {required bool keep}) {
    final selected = _selected.contains(file.path);
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: selected,
        onChanged: (v) => setState(() {
          if (v ?? false) {
            _selected.add(file.path);
          } else {
            _selected.remove(file.path);
          }
        }),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(file.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (keep && !selected)
            Padding(
              padding: const EdgeInsets.only(left: Gap.sm),
              child: Text('en eski',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
      subtitle: Text(p.dirname(file.path),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FmEntryIcon(entry: file, size: 32),
      onTap: () => EntryOpener.open(context, file.path),
      onLongPress: () async {
        await showEntryActions(context, file);
        if (mounted) _scan();
      },
    );
  }
}
