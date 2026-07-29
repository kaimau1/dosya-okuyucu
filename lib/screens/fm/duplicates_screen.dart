import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
    final roots = widget.roots;
    JobQueue.instance.enqueue(
      id: _jobId,
      title: 'Yinelenen dosyalar aranıyor',
      run: (handle) async {
        handle.report(detail: 'Dosyalar bayt bayt karşılaştırılıyor…');
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
              ? 'Yinelenen dosya yok'
              : '${groups.length} grup · '
                  '${FsPaths.humanSize(wasted)} kazanılabilir',
        );
      },
    );
    // İmza sıfırlanır, yoksa içerik değişmemişse (aynı gruplar) yeni sonuç
    // geldiğinde [_seedSelection] "değişmedi" deyip çıkar ve varsayılan seçim
    // bir daha hiç kurulmazdı — "Yeniden tara"dan sonra silme şeridi kaybolur.
    _seedSignature = null;
    setState(() => _selected.clear());
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
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    final wasted = _groups.fold<int>(0, (sum, g) => sum + g.wastedBytes);

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
                        : 'Dosyalar karşılaştırılıyor…'),
                    const SizedBox(height: Gap.sm),
                    const Text(
                      'Ekranı kapatabilirsin — tarama arka planda sürer, '
                      'geri döndüğünde sonuç hazır olur.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _groups.isEmpty
              ? const Center(child: Text('Yinelenen dosya bulunamadı 🎉'))
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
                              '${_visibleGroups.length} / ${_groups.length} '
                              'grup · ${FsPaths.humanSize(wasted)} boşa '
                              'gidiyor',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _visibleGroups.isEmpty
                          ? Center(child: Text('“$_query” için sonuç yok.'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: _visibleGroups.length,
                              itemBuilder: (context, i) =>
                                  _groupTile(_visibleGroups[i], i),
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: _selected.isEmpty || _scanning
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: FilledButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('${_selected.length} kopyayı çöpe taşı '
                      '(${FsPaths.humanSize(_selectedBytes)})'),
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
                '${files.length} kopya · ${FsPaths.humanSize(group.sizeBytes)} '
                '· ${FsPaths.humanSize(group.wastedBytes)} kazanılabilir',
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
