import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/audiobook/audiobook_maker.dart';
import '../../services/fm/fs_scan.dart' show FsPaths;
import '../../widgets/app_dialog.dart';
import '../../widgets/motion.dart';
import '../fm/media_player_screen.dart';
import 'voices_screen.dart';

/// **Sesli kitaplarım** — üretilmiş kitaplar; dokununca bölüm listesiyle
/// çalar (tekrar üretmeden). Oynatıcı kaldığı yeri hatırlar.
class AudiobookLibraryScreen extends StatefulWidget {
  const AudiobookLibraryScreen({super.key});

  @override
  State<AudiobookLibraryScreen> createState() => _AudiobookLibraryScreenState();
}

class _AudiobookLibraryScreenState extends State<AudiobookLibraryScreen> {
  List<(Directory, List<File>)>? _books;

  /// Kitap klasörü → toplam bayt (arka planda okunur; `build` diske dokunmaz).
  Map<String, int> _sizes = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await AudiobookMaker.library();
    if (!mounted) return;
    setState(() => _books = books);
    final sizes = <String, int>{};
    for (final (dir, files) in books) {
      var total = 0;
      for (final f in files) {
        try {
          total += await f.length();
        } catch (_) {
          // Bilinçli: silinmiş/okunamayan parça toplama katılmaz.
        }
      }
      sizes[dir.path] = total;
    }
    if (mounted) setState(() => _sizes = sizes);
  }

  void _play(List<File> files, [int start = 0]) {
    final paths = [for (final f in files) f.path];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaPlayerScreen(path: paths[start], playlist: paths),
    ));
  }

  Future<void> _delete(Directory dir) async {
    final ok = await showAppConfirm(context,
        message: context.t('ab.delete_q', {'name': p.basename(dir.path)}),
        destructive: true);
    if (!ok) return;
    await dir.delete(recursive: true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ab.library')),
        actions: [
          IconButton(
            tooltip: context.t('voice.title'),
            icon: const Icon(AppIcons.voice),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VoicesScreen())),
          ),
        ],
      ),
      body: books == null
          ? const Center(child: CircularProgressIndicator())
          : books.isEmpty
              ? FmEmptyState(
                  icon: AppIcons.audiobook,
                  title: context.t('ab.library_empty'),
                  hint: context.t('ab.library_empty_hint'),
                )
              : ListView(
                  padding: const EdgeInsets.all(Gap.sm),
                  children: [
                    for (final (dir, files) in books)
                      Card(
                        child: ExpansionTile(
                          leading: const Icon(AppIcons.audiobook),
                          title: Text(p.basename(dir.path)),
                          subtitle: Text(context.t('ab.book_sub', {
                            'n': files.length,
                            'size': _sizes[dir.path] == null
                                ? '…'
                                : FsPaths.humanSize(_sizes[dir.path]!),
                          })),
                          trailing: IconButton(
                            tooltip: context.t('ab.play_all'),
                            icon: const Icon(AppIcons.play),
                            onPressed: () => _play(files),
                          ),
                          children: [
                            for (var i = 0; i < files.length; i++)
                              ListTile(
                                dense: true,
                                title: Text(p.basenameWithoutExtension(
                                    files[i].path)),
                                onTap: () => _play(files, i),
                              ),
                            TextButton.icon(
                              onPressed: () => _delete(dir),
                              icon: const Icon(AppIcons.delete),
                              label: Text(context.t('common.delete')),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
