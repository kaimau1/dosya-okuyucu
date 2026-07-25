import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/trash_service.dart';

/// Geri Dönüşüm Kutusu: silinen dosyaları geri yükle ya da kalıcı sil.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _items = const [];
  bool _loading = true;

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
    _load();
  }

  Future<void> _empty() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çöp kutusu boşaltılsın mı?'),
        content: const Text('Tüm öğeler kalıcı olarak silinir.'),
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
    if (ok != true) return;
    await FmEnv.trash.empty();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geri Dönüşüm Kutusu'),
        actions: [
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
                          Text('${_items.length} öğe · '
                              '${FsPaths.humanSize(total)}'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
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
