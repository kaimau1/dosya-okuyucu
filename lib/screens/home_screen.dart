import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/document.dart';
import '../models/recent_file.dart';
import '../services/file_service.dart';
import '../widgets/file_type_icon.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fileService = FileService();
  bool _loading = false;

  Future<void> _openNew() async {
    setState(() => _loading = true);
    try {
      final path = await _fileService.pickFilePath();
      if (path == null) return;
      await _openPath(path);
    } catch (e) {
      _showError('Dosya açılamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPath(String path) async {
    final appState = context.read<AppState>();
    final doc = await _fileService.load(path);
    await appState.addRecent(RecentFile(
      path: path,
      name: doc.name,
      sizeBytes: _fileService.sizeOf(path),
      openedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerScreen(doc: doc)),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final recents = appState.recents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Okuyucu'),
        actions: [
          IconButton(
            tooltip: 'AI Sohbet',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : recents.isEmpty
              ? _EmptyState(onOpen: _openNew, hasApiKey: appState.hasApiKey)
              : _RecentList(
                  recents: recents,
                  onTap: (r) => _openPath(r.path),
                  onRemove: (r) => appState.removeRecent(r.path),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.folder_open),
        label: const Text('Dosya Aç'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onOpen;
  final bool hasApiKey;
  const _EmptyState({required this.onOpen, required this.hasApiKey});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Henüz dosya açmadınız',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'PDF, Word, Excel, Slayt ve metin dosyalarını açıp okuyabilir, '
              'düzenleyebilir ve yapay zeka ile üzerinde çalışabilirsiniz.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open),
              label: const Text('İlk dosyanı aç'),
            ),
            if (!hasApiKey) ...[
              const SizedBox(height: 12),
              Text(
                'İpucu: AI özellikleri için Ayarlar’dan Gemini API anahtarı ekleyin.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<RecentFile> recents;
  final void Function(RecentFile) onTap;
  final void Function(RecentFile) onRemove;

  const _RecentList({
    required this.recents,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: recents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final r = recents[i];
        final kind = FileService.kindForExtension(r.extension);
        return Dismissible(
          key: ValueKey(r.path + r.openedAtMs.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => onRemove(r),
          child: Card(
            child: ListTile(
              leading: FileTypeIcon(kind: kind),
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${kind.label} • ${_size(r.sizeBytes)}'),
              onTap: () => onTap(r),
            ),
          ),
        );
      },
    );
  }

  String _size(int bytes) {
    if (bytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size < 10 && unit > 0 ? 1 : 0)} ${units[unit]}';
  }
}
