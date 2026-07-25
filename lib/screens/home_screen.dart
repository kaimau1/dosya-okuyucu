import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/document.dart';
import '../models/recent_file.dart';
import '../services/blank_docs.dart';
import '../services/file_service.dart';
import '../services/fm/entry_opener.dart';
import '../widgets/file_type_icon.dart';
import 'chat_screen.dart';
import 'fm/dashboard_screen.dart';
import 'settings_screen.dart';

/// Uygulama kabuğu: alt gezinme çubuğuyla üç bölme —
/// **Dosyalar** (dosya yöneticisi panosu), **Son belgeler**, **AI**.
///
/// Kabuk aynı zamanda "birlikte aç"/paylaş ile gelen dosyaları yakalar; bu iş
/// eskiden son-belgeler ekranındaydı, artık hangi sekme açık olursa olsun
/// çalışır.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
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
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _openShared(files);
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _openShared(files);
      },
      onError: (_) {},
    );
  }

  Future<void> _openShared(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final path = files.first.path;
    if (path.isEmpty) return;
    await EntryOpener.open(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          DashboardScreen(),
          RecentDocsScreen(),
          ChatScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Dosyalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Son belgeler',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
        ],
      ),
    );
  }
}

/// "Son belgeler" sekmesi: uygulamada açılmış belgeler + hızlı dosya açma ve
/// yeni belge oluşturma (eski ana ekranın işlevleri).
class RecentDocsScreen extends StatefulWidget {
  const RecentDocsScreen({super.key});

  @override
  State<RecentDocsScreen> createState() => _RecentDocsScreenState();
}

class _RecentDocsScreenState extends State<RecentDocsScreen> {
  final _fileService = FileService();
  bool _loading = false;
  String _query = '';

  Future<void> _openNew() async {
    setState(() => _loading = true);
    try {
      final path = await _fileService.pickFilePath();
      if (path == null) return;
      if (!mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      _showError('Dosya açılamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// "Yeni belge" seçim sayfası (Word / Excel / Metin oluşturur).
  void _newDocument() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Yeni belge oluştur',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ),
            _newTile(ctx, DocKind.word, 'Word belgesi', '.docx', 'docx'),
            _newTile(ctx, DocKind.spreadsheet, 'Excel tablosu', '.xlsx', 'xlsx'),
            _newTile(ctx, DocKind.text, 'Metin dosyası', '.txt', 'txt'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _newTile(BuildContext ctx, DocKind kind, String title, String sub,
      String type) {
    return ListTile(
      leading: FileTypeIcon(kind: kind),
      title: Text(title),
      subtitle: Text(sub),
      onTap: () {
        Navigator.pop(ctx);
        _createAndOpen(type);
      },
    );
  }

  Future<void> _createAndOpen(String type) async {
    setState(() => _loading = true);
    try {
      final path = await BlankDocs.create(type);
      if (!mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      _showError('Yeni belge oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: const Text('Son belgeler'),
        actions: [
          IconButton(
            tooltip: 'Yeni belge',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _newDocument,
          ),
          IconButton(
            tooltip: themeTip,
            icon: Icon(themeIc),
            onPressed: () => _cycleTheme(appState),
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
                              onTap: _openSafely,
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
      await EntryOpener.open(context, r.path);
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        // Büyük sistem yazı tipinde/yatay modda taşmasın diye kaydırılabilir.
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.sheet),
              ),
              child: Icon(Icons.folder_copy_outlined,
                  size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: Gap.lg),
            Text('Henüz belge açmadınız',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: Gap.sm),
            Text(
              'PDF, Word, Excel, Slayt, görsel ve metin dosyalarını açıp '
              'inceleyebilir, düzenleyebilir ve yapay zeka ile üzerinde '
              'çalışabilirsiniz. Telefonundaki tüm dosyalar için alttaki '
              '“Dosyalar” sekmesini kullanın.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open),
              label: const Text('İlk dosyanı aç'),
            ),
            if (!hasApiKey) ...[
              const SizedBox(height: Gap.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md, vertical: Gap.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Text(
                        'AI özellikleri için Ayarlar’dan Gemini API anahtarı ekleyin.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
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
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      // Alt boşluk FAB'ın altında kalan son kartı kurtarır (sabit öğe ile
      // kaydırma içeriği çakışmasın).
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 96),
      itemCount: recents.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
      itemBuilder: (context, i) {
        final r = recents[i];
        final kind = FileService.kindForExtension(r.extension);
        return Dismissible(
          key: ValueKey(r.path + r.openedAtMs.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Gap.lg),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ),
          onDismissed: (_) => onRemove(r),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: FileTypeIcon(kind: kind),
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${kind.label} · ${_size(r.sizeBytes)} · ${_relTime(r.openedAtMs)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Icon(Icons.chevron_right,
                  size: 20, color: scheme.onSurfaceVariant),
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
