import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_state.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../models/document.dart';
import '../models/recent_file.dart';
import '../services/blank_docs.dart';
import '../models/download_task.dart';
import '../services/file_service.dart';
import '../services/fm/entry_opener.dart';
import '../widgets/file_type_icon.dart';
import '../widgets/fm/job_progress_bar.dart';
import '../widgets/scan_flow.dart';
import 'chat_screen.dart';
import 'fm/dashboard_screen.dart';
import 'fm/download_manager_screen.dart';
import 'pdf_tools_screen.dart';
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
    final first = files.first;
    final path = first.path;
    if (path.isEmpty) return;

    // Tarayıcıdan gelen bir BAĞLANTI ise dosya değil, indirme isteğidir
    // (kullanıcı isteği 2026-07-29: "Chrome/DuckDuckGo'dan bizim programımızla
    // indirmek istiyorum · indirme kısmında seçenek olarak çıkmalıyız").
    //
    // Tür alanına GÜVENMİYORUZ: paylaşım eklentisi kaynağa göre bu içeriği
    // `text`, `url` ya da `file` diye etiketleyebiliyor ve Android sürümüne
    // göre değişiyor. Karar tek ölçüte bağlı: içerik http(s) adresi mi ve
    // diskte böyle bir dosya YOK mu? Öyleyse indirilecek bir bağlantıdır.
    final url = extractUrl(path);
    if (url != null && !File(path).existsSync()) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DownloadManagerScreen(initialUrl: url),
      ));
      return;
    }
    await EntryOpener.open(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          // active: pano yalnız görünürken yeniden tarar (bkz. FsEvents).
          DashboardScreen(active: _tab == 0),
          const RecentDocsScreen(),
          const ChatScreen(),
        ],
      ),
      // Süren işlerin şeridi gezinme çubuğunun **üstünde**: kullanıcı hangi
      // sekmede olursa olsun "yer aç / boyut düşür / benzer ara" işinin nerede
      // olduğunu görür ve iptal edebilir (istek 2026-07-29: işlemler arka
      // planda çalışabilmeli).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const JobProgressBar(),
          NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: context.t('home.tab_files'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: context.t('home.tab_recent'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.smart_toy_outlined),
            selectedIcon: const Icon(Icons.smart_toy),
            label: context.t('home.tab_ai'),
          ),
        ],
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
    // Çeviri tablosu await'ten ÖNCE alınır: `context` asenkron boşluktan
    // sonra kullanılamaz (ekran bu arada kapanmış olabilir).
    final s = AppStrings.of(context);
    setState(() => _loading = true);
    try {
      final path = await _fileService.pickFilePath();
      if (path == null) return;
      if (!mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      _showError(s.t('home.open_error', {'error': e}));
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
                child: Text(ctx.t('home.new_document_title'),
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ),
            _newTile(ctx, DocKind.word, ctx.t('home.new_word'), '.docx', 'docx'),
            _newTile(ctx, DocKind.spreadsheet, ctx.t('home.new_excel'), '.xlsx',
                'xlsx'),
            _newTile(ctx, DocKind.text, ctx.t('home.new_text'), '.txt', 'txt'),
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
    final s = AppStrings.of(context);
    setState(() => _loading = true);
    try {
      final path = await BlankDocs.create(type);
      if (!mounted) return;
      await EntryOpener.open(context, path);
    } catch (e) {
      _showError(s.t('home.create_error', {'error': e}));
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
        ThemeMode.system =>
          (Icons.brightness_auto_outlined, context.t('home.theme_system')),
        ThemeMode.light =>
          (Icons.light_mode_outlined, context.t('home.theme_light')),
        ThemeMode.dark =>
          (Icons.dark_mode_outlined, context.t('home.theme_dark')),
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
        title: Text(context.t('home.tab_recent')),
        actions: [
          IconButton(
            tooltip: context.t('home.pdf_tools'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => PdfToolsScreen.open(context),
          ),
          IconButton(
            tooltip: context.t('home.new_document'),
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _newDocument,
          ),
          IconButton(
            tooltip: themeTip,
            icon: Icon(themeIc),
            onPressed: () => _cycleTheme(appState),
          ),
          IconButton(
            tooltip: context.t('common.settings'),
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
      // Belge tarama uygulamanın vitrin özelliği: dosya açmanın hemen üstünde,
      // kendi düğmesiyle duruyor.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => ScanFlow.run(context),
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(context.t('home.scan')),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'open',
            onPressed: _openNew,
            icon: const Icon(Icons.folder_open),
            label: Text(context.t('home.open_file')),
          ),
        ],
      ),
    );
  }

  /// Son dosya açılırken hata olursa (ör. dosya taşınmış) kullanıcıyı bilgilendir.
  Future<void> _openSafely(RecentFile r) async {
    final s = AppStrings.of(context);
    try {
      await EntryOpener.open(context, r.path);
    } catch (e) {
      _showError(s.t('home.open_error_moved', {'name': r.name}));
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
          hintText: context.t('home.search_recent'),
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
        child: Text(context.t('home.no_match'),
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
            Text(context.t('home.empty_title'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: Gap.sm),
            Text(
              context.t('home.empty_body'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open),
              label: Text(context.t('home.empty_cta')),
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
                        context.t('home.empty_ai_hint'),
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
                  '${kind.label} · ${_size(r.sizeBytes)} · '
                  '${_relTime(context, r.openedAtMs)}',
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

  String _relTime(BuildContext context, int ms) {
    if (ms <= 0) return '';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return context.t('home.time_now');
    if (d.inMinutes < 60) return context.t('home.time_minutes', {'n': d.inMinutes});
    if (d.inHours < 24) return context.t('home.time_hours', {'n': d.inHours});
    if (d.inDays < 7) return context.t('home.time_days', {'n': d.inDays});
    if (d.inDays < 30) {
      return context.t('home.time_weeks', {'n': (d.inDays / 7).floor()});
    }
    if (d.inDays < 365) {
      return context.t('home.time_months', {'n': (d.inDays / 30).floor()});
    }
    return context.t('home.time_years', {'n': (d.inDays / 365).floor()});
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
