import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'important_screen.dart';

/// **Hedef klasör seçici** — "şu dosyaları nereye koyayım?" sorusunun tek
/// ekranlık cevabı.
///
/// Kullanıcı isteği (2026-07-29): *"indirilenleri, dosyaları, resimleri,
/// videoları taşıma/kopyalama, önemli klasöre taşıma şu an çok zor"*.
/// Eski akış üç adımdı: kopyala → Dosyalar sekmesine git → hedef klasörü bul →
/// yapıştır. Panoyu ve sekme değiştirmeyi hatırlamak gerekiyordu; kullanıcı
/// haklı olarak "çok zor" dedi.
///
/// Buradaki akış tek adım: uzun bas → **Taşı/Kopyala** → hedefe dokun → bitti.
///
/// Tasarım kararları:
/// - **Kısayollar üstte:** Önemli Dosyalar, İndirilenler, Belgeler, Resimler,
///   Kamera… + favoriler + **son kullanılan hedefler**. İnsanlar dosyayı hep
///   aynı birkaç yere koyar; ağaçta gezinmek istisna olmalı.
/// - Gezinme yine mümkün (klasöre dokun → içine gir), ama **yalnız klasörler**
///   listelenir: dosya göstermek burada gürültü.
/// - **Yeni klasör** buradan açılabilir: hedef henüz yoksa akış kesilmesin.
/// - Kaynağın kendisi ya da kaynağın içi hedef olarak seçilemez (klasörü kendi
///   içine taşıma tuzağı); ilgili satır sönük ve dokunulamaz.
class FolderPickerScreen extends StatefulWidget {
  /// Taşınacak/kopyalanacak yollar — kendi içine taşımayı engellemek için.
  final List<String> sources;

  /// Onay düğmesinin metni ("Buraya taşı" / "Buraya kopyala").
  final String actionLabel;

  /// Başlangıç klasörü (yoksa ana bellek).
  final String? startPath;

  const FolderPickerScreen({
    super.key,
    required this.sources,
    required this.actionLabel,
    this.startPath,
  });

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  late String _path = widget.startPath ?? FmEnv.primaryRoot;
  List<FsEntry> _dirs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await FsScan.list(_path);
      if (!mounted) return;
      setState(() {
        _dirs = FsScan.sort(
          entries.where((e) => e.isDir).toList(),
          FmSort.name,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dirs = const [];
        _loading = false;
        _error = context.t('picker.unreadable');
      });
    }
  }

  void _enter(String path) {
    setState(() => _path = path);
    _load();
  }

  /// Hedef geçerli mi? Kaynağın kendisi ya da kaynağın altı olamaz.
  bool _allowed(String dir) {
    for (final src in widget.sources) {
      if (FsPaths.isInside(src, dir)) return false;
    }
    return true;
  }

  Future<void> _newFolder() async {
    final name = await promptForName(
      context,
      title: context.t('fm.new_folder'),
      label: context.t('fm.folder_name'),
      initial: context.t('fm.new_folder'),
    );
    if (name == null) return;
    try {
      final created = await FileOps.createFolder(_path, name);
      _enter(created); // yeni klasörün içine gir: hedef büyük olasılıkla burası
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Klasör oluşturulamadı: $e')));
    }
  }

  /// Kısayollar: sabit klasörler + favoriler + son kullanılan hedefler.
  /// Var olmayan yollar gösterilmez (ölü kısayol kullanıcıyı yanıltır);
  /// Önemli Dosyalar istisna — yoksa **oluşturulur**, zaten amacı bu.
  List<({IconData icon, String label, String path, bool create})> _shortcuts(
    AppState appState,
  ) {
    final out = <({IconData icon, String label, String path, bool create})>[
      (
        icon: Icons.star_outline,
        label: ImportantScreen.folderName,
        path: ImportantScreen.pathIn(FmEnv.primaryRoot),
        create: true,
      ),
    ];
    for (final f in StorageStats.standardFolders(FmEnv.primaryRoot)) {
      out.add((
        icon: _iconForShortcut(f.icon),
        label: f.label,
        path: f.path,
        create: false,
      ));
    }
    for (final path in appState.fmRecentDestinations) {
      if (out.any((s) => s.path == path)) continue;
      if (!Directory(path).existsSync()) continue;
      out.add((
        icon: Icons.history,
        label: p.basename(path),
        path: path,
        create: false,
      ));
    }
    for (final path in appState.bookmarks) {
      if (out.any((s) => s.path == path)) continue;
      if (!Directory(path).existsSync()) continue;
      out.add((
        icon: Icons.star,
        label: p.basename(path),
        path: path,
        create: false,
      ));
    }
    return out.where((s) => _allowed(s.path)).toList();
  }

  static IconData _iconForShortcut(String key) => switch (key) {
        'download' => Icons.download_outlined,
        'document' => Icons.description_outlined,
        'camera' => Icons.photo_camera_outlined,
        'image' => Icons.image_outlined,
        'audio' => Icons.music_note_outlined,
        'video' => Icons.movie_outlined,
        'chat' => Icons.chat_outlined,
        _ => Icons.folder_outlined,
      };

  /// Kısayola dokunma: klasörü (gerekirse oluşturup) **doğrudan hedef seçer**.
  /// İki dokunuş (gir + onayla) yerine tek dokunuş — kısayolun bütün amacı bu.
  Future<void> _pickShortcut(
      ({IconData icon, String label, String path, bool create}) s) async {
    if (s.create) {
      try {
        final dir = Directory(s.path);
        if (!dir.existsSync()) await dir.create(recursive: true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Klasör oluşturulamadı: $e')));
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context, s.path);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shortcuts = _shortcuts(appState);
    final canPickHere = _allowed(_path);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('picker.title')),
            Text(
              context.t('picker.summary', {'n': widget.sources.length, 'name': p.basename(_path)}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('fm.new_folder'),
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _newFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          if (shortcuts.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                children: [
                  for (final s in shortcuts)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.sm, top: Gap.sm),
                      child: ActionChip(
                        avatar: Icon(s.icon, size: 18),
                        label: Text(s.label),
                        onPressed: () => _pickShortcut(s),
                      ),
                    ),
                ],
              ),
            ),
          _breadcrumb(),
          const Divider(height: 1),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _path,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  FilledButton.icon(
                    onPressed:
                        canPickHere ? () => Navigator.pop(context, _path) : null,
                    icon: const Icon(Icons.check),
                    label: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb() {
    final parent = p.dirname(_path);
    // Birim kökünün (ana bellek / SD kart) ÜSTÜNE çıkılmaz: `/storage`,
    // `/` gibi klasörlerde kullanıcının yazma izni yok, oraya çıkmak yalnız
    // "boş klasör / izin yok" ekranı gösterirdi.
    final atTop = parent == _path ||
        FmEnv.volumes.any((v) => p.equals(v.path, _path)) ||
        p.equals(_path, FmEnv.primaryRoot);
    return Row(
      children: [
        IconButton(
          tooltip: context.t('picker.parent'),
          icon: const Icon(Icons.arrow_upward),
          onPressed: atTop ? null : () => _enter(parent),
        ),
        Expanded(
          child: Text(
            p.basename(_path).isEmpty ? _path : p.basename(_path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final v in FmEnv.volumes)
          IconButton(
            tooltip: v.label,
            icon: Icon(v.isPrimary ? Icons.smartphone : Icons.sd_card),
            onPressed: () => _enter(v.path),
          ),
      ],
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_dirs.isEmpty && !_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Gap.lg),
          child: Text(
            'Bu klasörde alt klasör yok.\n'
            'Aşağıdaki düğmeyle buraya koyabilir ya da üstteki '
            '“yeni klasör” ile bir tane açabilirsiniz.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _dirs.length,
      itemBuilder: (context, i) {
        final dir = _dirs[i];
        final allowed = _allowed(dir.path);
        return ListTile(
          enabled: allowed,
          leading: const Icon(Icons.folder, color: FmColors.folder),
          title: Text(dir.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: allowed ? null : Text(context.t('picker.source_itself')),
          trailing: const Icon(Icons.chevron_right),
          onTap: allowed ? () => _enter(dir.path) : null,
        );
      },
    );
  }
}
