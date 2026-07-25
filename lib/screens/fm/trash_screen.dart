import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/trash_service.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_search_field.dart';

/// Geri Dönüşüm Kutusu: silinen dosyaları geri yükle ya da kalıcı sil.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _items = const [];
  bool _loading = true;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  /// Çöpteki kayıtlar bellektedir → arama anlıktır, disk okunmaz.
  List<TrashItem> get _filtered => _query.trim().isEmpty
      ? _items
      : _items.where((i) => fmMatches(i.name, _query)).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await FmEnv.ensureInit();
    final items = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _restore(TrashItem item) async {
    try {
      final target = await FmEnv.trash.restore(item);
      if (!mounted) return;
      _snack('“${item.name}” geri yüklendi → ${target.split('/').last}');
    } catch (e) {
      _snack('Geri yüklenemedi: $e');
    }
    _load();
  }

  Future<void> _delete(TrashItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalıcı olarak silinsin mi?'),
        content: Text('“${item.name}” geri alınamaz şekilde silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await FmEnv.trash.deleteForever(item);
    if (!mounted) return;
    _snack('“${item.name}” kalıcı olarak silindi.');
    _load();
  }

  /// Çöp kutusunu boşaltır — **ilerleme penceresiyle**.
  ///
  /// Eskiden bu işlem sessizdi: yüzlerce dosya silinirken ekran donmuş gibi
  /// görünüyor, bitince de hiçbir şey söylenmiyordu (kullanıcı bulgusu
  /// 2026-07-25). Artık kaç öğenin silineceği önce yazılır, silme sırasında
  /// çubuk ve dosya adı görünür, sonunda özet bildirilir.
  Future<void> _empty() async {
    final count = _items.length;
    final total = _items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çöp kutusu boşaltılsın mı?'),
        content: Text('$count öğe (${FsPaths.humanSize(total)}) kalıcı olarak '
            'silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Boşalt')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: 'Çöp kutusu boşaltılıyor',
      task: (report, isCancelled) =>
          FmEnv.trash.empty(onProgress: report, isCancelled: isCancelled),
    );
    if (!mounted) return;
    if (result.hasError) {
      _snack('${result.succeeded} öğe silindi, '
          '${result.errors.length} öğe silinemedi: ${result.errors.first}');
    } else if (result.cancelled) {
      _snack('Durduruldu — ${result.succeeded} öğe silindi.');
    } else {
      _snack('Çöp kutusu boşaltıldı · ${result.succeeded} öğe · '
          '${FsPaths.humanSize(total)} yer açıldı.');
    }
    _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    final shown = _filtered;
    return Scaffold(
      appBar: _searching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                }),
              ),
              title: FmSearchField(
                controller: _searchController,
                hint: 'Çöp kutusunda ara…',
                onChanged: (v) => setState(() => _query = v),
              ),
            )
          : AppBar(
              title: const Text('Geri Dönüşüm Kutusu'),
              actions: [
                if (_items.isNotEmpty)
                  IconButton(
                    tooltip: 'Çöp kutusunda ara',
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _searching = true),
                  ),
                if (_items.isNotEmpty)
                  TextButton(onPressed: _empty, child: const Text('Boşalt')),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Çöp kutusu boş'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep_outlined),
                          const SizedBox(width: Gap.sm),
                          Text(_query.trim().isEmpty
                              ? '${_items.length} öğe · '
                                  '${FsPaths.humanSize(total)}'
                              : '${shown.length} / ${_items.length} öğe'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final item = shown[i];
                          return ListTile(
                            leading: Icon(item.isDir
                                ? Icons.folder_outlined
                                : Icons.insert_drive_file_outlined),
                            title: Text(item.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${FsPaths.humanDate(item.deletedAtMs)} · '
                              '${item.originalPath}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Geri yükle',
                                  icon: const Icon(Icons.restore),
                                  onPressed: () => _restore(item),
                                ),
                                IconButton(
                                  tooltip: 'Kalıcı sil',
                                  icon: const Icon(Icons.delete_forever),
                                  onPressed: () => _delete(item),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
