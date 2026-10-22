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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await AudiobookMaker.library();
    if (mounted) setState(() => _books = books);
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
                            'size': FsPaths.humanSize(files.fold<int>(
                                0, (a, f) => a + f.lengthSync())),
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
