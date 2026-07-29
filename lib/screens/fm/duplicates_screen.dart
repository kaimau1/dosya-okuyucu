import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/duplicate_finder.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_scan.dart';
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
  List<DuplicateGroup> _groups = const [];
  final Set<String> _selected = {};
  bool _scanning = true;

  /// Yerinde arama (kullanıcı isteği 2026-07-29: "arama kısmı her yerde
  /// olmalı"). Grup, dosyalarından herhangi biri eşleşirse görünür.
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _selected.clear();
    });
    final groups = await DuplicateFinder.scan(widget.roots);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _scanning = false;
      // Varsayılan: her gruptan EN ESKİ dosya korunur, kalanlar seçilir.
      for (final g in groups) {
        final sorted = [...g.files]
          ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
        for (final f in sorted.skip(1)) {
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
    await _scan();
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: Gap.md),
                  Text('Dosyalar karşılaştırılıyor…'),
                ],
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
