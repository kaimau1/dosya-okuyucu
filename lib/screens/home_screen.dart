import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_state.dart';
import '../models/document.dart';
import '../models/recent_file.dart';
import '../services/file_service.dart';
import '../widgets/file_type_icon.dart';
import 'chat_screen.dart';
import 'editors/slides_editor_screen.dart';
import 'editors/spreadsheet_editor_screen.dart';
import 'editors/word_editor_screen.dart';
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
  String _query = '';
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  @override
  void initState() {
    super.initState();
    _initShareIntake();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  /// "Birlikte aç" / paylaş ile başka uygulamalardan gelen dosyaları yakalar:
  /// uygulama kapalıyken açıldıysa (initial) ve açıkken paylaşıldıysa (stream).
  void _initShareIntake() {
    // Uygulama bir dosyayla açıldıysa.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _openShared(files);
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});

    // Uygulama açıkken yeni dosya paylaşılırsa.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _openShared(files);
      },
      onError: (_) {},
    );
  }

  /// Gelen paylaşımdaki ilk açılabilir dosyayı açar.
  Future<void> _openShared(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final path = files.first.path;
    if (path.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _openPath(path);
    } catch (e) {
      _showError('Paylaşılan dosya açılamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final route = MaterialPageRoute(builder: (_) {
      switch (doc.kind) {
        case DocKind.spreadsheet:
          return SpreadsheetEditorScreen(
              path: doc.path, name: doc.name, plainText: doc.plainText);
        case DocKind.word:
          return WordEditorScreen(
              path: doc.path, name: doc.name, plainText: doc.plainText);
        case DocKind.slides:
          return SlidesEditorScreen(
              path: doc.path, name: doc.name, plainText: doc.plainText);
        default:
          return ViewerScreen(doc: doc);
      }
    });
    Navigator.of(context).push(route);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _cycleTheme(AppState appState) {
    final next = switch (appState.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    appState.setThemeMode(next);
  }

  (IconData, String) _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => (Icons.brightness_auto_outlined, 'Tema: Sistem'),
        ThemeMode.light => (Icons.light_mode_outlined, 'Tema: Açık'),
        ThemeMode.dark => (Icons.dark_mode_outlined, 'Tema: Koyu'),
      };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final recents = appState.recents;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? recents
        : recents.where((r) => r.name.toLowerCase().contains(q)).toList();
    final (themeIc, themeTip) = _themeIcon(appState.themeMode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Okuyucu'),
        actions: [
          IconButton(
            tooltip: themeTip,
            icon: Icon(themeIc),
            onPressed: () => _cycleTheme(appState),
          ),
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
              : Column(
                  children: [
                    if (recents.length > 4) _searchBar(),
                    Expanded(
                      child: filtered.isEmpty
                          ? const _NoMatch()
                          : _RecentList(
                              recents: filtered,
                              onTap: (r) => _openSafely(r),
                              onRemove: (r) => appState.removeRecent(r.path),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.folder_open),
        label: const Text('Dosya Aç'),
      ),
    );
  }

  /// Son dosya açılırken hata olursa (ör. dosya taşınmış) kullanıcıyı bilgilendir.
  Future<void> _openSafely(RecentFile r) async {
    try {
      await _openPath(r.path);
    } catch (e) {
      _showError('Dosya açılamadı (taşınmış olabilir): ${r.name}');
    }
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Son dosyalarda ara…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _query = ''),
                ),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();
  @override
  Widget build(BuildContext context) => Center(
        child: Text('Eşleşen dosya yok',
            style: Theme.of(context).textTheme.bodyMedium),
      );
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
              'PDF, Word, Excel, Slayt, görsel ve metin dosyalarını açıp '
              'inceleyebilir, düzenleyebilir ve yapay zeka ile üzerinde '
              'çalışabilirsiniz.',
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          onDismissed: (_) => onRemove(r),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: FileTypeIcon(kind: kind),
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${kind.label} • ${_size(r.sizeBytes)} • ${_relTime(r.openedAtMs)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(r),
            ),
          ),
        );
      },
    );
  }

  String _relTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} saat önce';
    if (d.inDays < 7) return '${d.inDays} gün önce';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()} hafta önce';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()} ay önce';
    return '${(d.inDays / 365).floor()} yıl önce';
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
