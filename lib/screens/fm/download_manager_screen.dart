import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/download_task.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/download_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/github_release.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';
import 'folder_picker_screen.dart';

/// **İndirmeler** — bağlantıdan indirme kuyruğu ve geçmişi.
///
/// Kullanıcı isteği (2026-07-29): *"bir linkten indireceğim (GitHub release,
/// tarayıcı) — bizim programımızdan indirmek istiyorum"*. Tarayıcının indirdiği
/// dosya `Download` klasörüne düşüp kayboluyor; burada **hedef klasör seçilir**
/// (Önemli Dosyalar/Faturalar gibi), indirme duraklatılıp sürdürülebilir ve
/// biter bitmez dosya açılabilir.
class DownloadManagerScreen extends StatefulWidget {
  /// Ekran açılır açılmaz bu bağlantı için indirme sorulur (paylaşımdan gelen).
  final String? initialUrl;

  const DownloadManagerScreen({super.key, this.initialUrl});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  final _service = DownloadService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _boot();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Panoda bekleyen bağlantı (üstte şerit olarak önerilir).
  String? _clipboardUrl;

  Future<void> _boot() async {
    await _service.ensureLoaded();
    if (!mounted) return;
    final url = widget.initialUrl;
    if (url != null && url.isNotEmpty) {
      await startDownloadFlow(context, url);
      return;
    }
    // Kullanıcı tarayıcıda bağlantıyı kopyalayıp geldiyse elle yazmasın.
    // (Paylaşım yolu her cihazda çalışmayabilir; bu her zaman çalışır.)
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final fromClipboard = extractUrl(data?.text ?? '');
    if (!mounted || fromClipboard == null) return;
    if (_service.tasks.any((t) => t.url == fromClipboard)) return;
    setState(() => _clipboardUrl = fromClipboard);
  }

  Future<void> _addFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = extractUrl(data?.text ?? '');
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Panoda bir bağlantı yok. Tarayıcıda bağlantıyı '
              'kopyalayıp buraya dönün.')));
      return;
    }
    await startDownloadFlow(context, url);
  }

  Future<void> _addManual() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bağlantıdan indir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Bağlantı (https://…)',
            hintText: 'https://github.com/kullanici/depo/releases/latest',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Devam')),
        ],
      ),
    );
    controller.dispose();
    final clean = extractUrl(url ?? '') ?? url?.trim();
    if (clean == null || clean.isEmpty || !mounted) return;
    await startDownloadFlow(context, clean);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _service.tasks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İndirmeler'),
        actions: [
          IconButton(
            tooltip: 'Panodaki bağlantıyı indir',
            icon: const Icon(Icons.content_paste_go),
            onPressed: _addFromClipboard,
          ),
          if (tasks.any((t) => !t.state.isActive))
            IconButton(
              tooltip: 'Biten kayıtları temizle',
              icon: const Icon(Icons.clear_all),
              onPressed: _service.clearFinished,
            ),
        ],
      ),
      body: Column(children: [
        if (_clipboardUrl != null) _clipboardBanner(),
        Expanded(child: _list(tasks)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add_link),
        label: const Text('Bağlantı'),
      ),
    );
  }

  /// Panodaki bağlantı şeridi — tek dokunuşla indirme.
  Widget _clipboardBanner() {
    final url = _clipboardUrl!;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
        child: Row(
          children: [
            const Icon(Icons.link, size: 20),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Panodaki bağlantı',
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                setState(() => _clipboardUrl = null);
                await startDownloadFlow(context, url);
              },
              child: const Text('İndir'),
            ),
            IconButton(
              tooltip: 'Kapat',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _clipboardUrl = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<DownloadTask> tasks) => tasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(Gap.lg),
                child: Text(
                  'Henüz indirme yok.\n\n'
                  'Tarayıcıda bir bağlantıya uzun basıp “Paylaş → Dosya '
                  'Okuyucu” diyebilir, bağlantıyı kopyalayıp buradaki '
                  'yapıştır düğmesini kullanabilir ya da “+” ile elle '
                  'yazabilirsiniz.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _tile(tasks[i]),
            );

  Widget _tile(DownloadTask task) {
    final entry = FsEntry(
      path: task.destPath,
      name: task.fileName,
      isDir: false,
      sizeBytes: task.received,
      modifiedMs: task.updatedMs,
    );
    final eta = etaFor(
      received: task.received,
      total: task.total,
      bytesPerSecond: task.bytesPerSecond,
    );

    return ListTile(
      leading: FmEntryIcon(entry: entry, thumbnails: false),
      title: Text(task.fileName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (task.state) {
              DownloadState.running =>
                '${FsPaths.humanSize(task.received)}'
                    '${task.hasTotal ? " / ${FsPaths.humanSize(task.total)}" : ""}'
                    ' · ${formatSpeed(task.bytesPerSecond)}'
                    '${eta != null ? " · ${formatDuration(eta)} kaldı" : ""}',
              DownloadState.completed =>
                '${FsPaths.humanSize(task.received)} · ${p.dirname(task.destPath)}',
              DownloadState.failed => task.error ?? 'Başarısız',
              _ => '${task.state.label} · '
                  '${FsPaths.humanSize(task.received)}'
                  '${task.hasTotal ? " / ${FsPaths.humanSize(task.total)}" : ""}',
            },
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.state.isActive) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: task.fraction, minHeight: 3),
          ],
        ],
      ),
      isThreeLine: task.state.isActive,
      onTap: task.state == DownloadState.completed
          ? () => EntryOpener.open(context, task.destPath)
          : null,
      trailing: _actions(task),
    );
  }

  Widget _actions(DownloadTask task) => PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'pause':
              _service.pause(task.id);
            case 'resume':
              _service.resume(task.id);
            case 'cancel':
              await _service.cancel(task.id);
            case 'remove':
              await _service.remove(task.id);
            case 'open':
              if (mounted) await EntryOpener.open(context, task.destPath);
            case 'folder':
              if (mounted) {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      BrowserScreen(path: p.dirname(task.destPath)),
                ));
              }
            case 'copy':
              await Clipboard.setData(ClipboardData(text: task.url));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Bağlantı panoya kopyalandı.')));
              }
          }
        },
        itemBuilder: (_) => [
          if (task.state == DownloadState.running)
            const PopupMenuItem(value: 'pause', child: Text('Duraklat')),
          if (task.state.isResumable)
            const PopupMenuItem(value: 'resume', child: Text('Devam et')),
          if (task.state.isActive || task.state == DownloadState.paused)
            const PopupMenuItem(value: 'cancel', child: Text('İptal et')),
          if (task.state == DownloadState.completed) ...[
            const PopupMenuItem(value: 'open', child: Text('Aç')),
            const PopupMenuItem(value: 'folder', child: Text('Klasörünü aç')),
          ],
          const PopupMenuItem(value: 'copy', child: Text('Bağlantıyı kopyala')),
          const PopupMenuItem(value: 'remove', child: Text('Listeden kaldır')),
        ],
      );
}

/// **İndirme akışı:** bağlantıyı çözümler, GitHub sürümüyse dosya seçtirir,
/// hedef klasörü sorar ve kuyruğa ekler.
///
/// GitHub sürüm sayfasını olduğu gibi indirmek işe yaramaz (elde HTML kalır);
/// bu yüzden API'den dosya listesi çekilip seçtiriliyor.
Future<void> startDownloadFlow(BuildContext context, String rawUrl) async {
  final url = extractUrl(rawUrl) ?? rawUrl.trim();
  if (url.isEmpty) return;

  var target = url;
  String? suggestedName;

  final apiUrl = githubReleaseApiUrl(url);
  if (apiUrl != null) {
    final release = await _fetchRelease(context, apiUrl);
    if (!context.mounted) return;
    if (release != null && release.assets.isNotEmpty) {
      final asset = await _pickAsset(context, release);
      if (asset == null) return;
      target = asset.downloadUrl;
      suggestedName = asset.name;
    }
    // Sürüm bilgisi alınamadıysa (ağ/limit) adres olduğu gibi indirilir;
    // kullanıcı hiç değilse bir şey elde etsin.
  }

  if (!context.mounted) return;
  final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => FolderPickerScreen(
      sources: const [],
      actionLabel: 'Buraya indir',
      startPath: FmEnv.primaryRoot,
    ),
  ));
  if (dest == null || !context.mounted) return;

  await DownloadService.instance
      .enqueue(target, destDir: dest, fileName: suggestedName);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('İndirme başladı: ${suggestedName ?? p.basename(target)}'),
  ));
}

Future<GithubRelease?> _fetchRelease(BuildContext context, String apiUrl) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: Gap.md),
          Expanded(child: Text('Sürüm dosyaları alınıyor…')),
        ],
      ),
    ),
  );
  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: const {
        'accept': 'application/vnd.github+json',
        'user-agent': 'DosyaOkuyucu/1.0',
      },
    );
    if (context.mounted) Navigator.pop(context);
    if (response.statusCode >= 400) return null;
    return parseGithubRelease(response.body);
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    return null;
  }
}

Future<GithubAsset?> _pickAsset(
    BuildContext context, GithubRelease release) async {
  return showModalBottomSheet<GithubAsset>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(release.title),
              subtitle: Text('${release.assets.length} dosya · '
                  '${release.tag}'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final asset in release.assets)
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(asset.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(asset.sizeBytes > 0
                          ? FsPaths.humanSize(asset.sizeBytes)
                          : 'Boyut bilinmiyor'),
                      onTap: () => Navigator.pop(ctx, asset),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
