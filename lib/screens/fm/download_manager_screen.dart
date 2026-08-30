import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/download_task.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/download_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/github_release.dart';
import '../../services/fm/storage_permission.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';
import 'folder_picker_screen.dart';
import '../../core/snack.dart';

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
      showSnack(context, context.t('dl.no_link'));
      return;
    }
    await startDownloadFlow(context, url);
  }

  Future<void> _addManual() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('dl.from_link')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: context.t('dl.link_label'),
            hintText: 'https://github.com/kullanici/depo/releases/latest',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(context.t('dl.continue'))),
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
        title: Text(context.t('dl.title')),
        actions: [
          IconButton(
            tooltip: context.t('dl.clipboard_download'),
            icon: const Icon(Icons.content_paste_go),
            onPressed: _addFromClipboard,
          ),
          IconButton(
            tooltip: context.t('dl.how_to'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDownloadHelp(context),
          ),
          if (tasks.any((t) => !t.state.isActive))
            IconButton(
              tooltip: context.t('dl.clear_finished'),
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
        label: Text(context.t('dl.link')),
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
                  Text(context.t('dl.clipboard_link'),
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
              child: Text(context.t('dl.download')),
            ),
            IconButton(
              tooltip: context.t('common.close'),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _clipboardUrl = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<DownloadTask> tasks) => tasks.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: [
                Text(context.t('dl.empty'),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: Gap.md),
                const _HowToCard(),
              ],
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
                    '${eta != null ? " · ${context.t('dl.remaining', {'time': formatDuration(eta)})}" : ""}',
              DownloadState.completed =>
                '${FsPaths.humanSize(task.received)} · ${p.dirname(task.destPath)}',
              DownloadState.failed =>
                task.error ?? context.t('enum.dl_failed'),
              _ => '${context.t(task.state.labelKey)} · '
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

  Widget _actions(DownloadTask task) {
    // Asenkron boşluktan sonra `context` kullanılamaz → metin şimdi alınır.
    final copiedMsg = context.t('dl.link_copied');
    return PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'pause':
              await _service.pause(task.id);
            case 'resume':
              await _service.resume(task.id);
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
                showSnack(context, copiedMsg);
              }
          }
        },
        itemBuilder: (_) => [
          if (task.state == DownloadState.running)
            PopupMenuItem(value: 'pause', child: Text(context.t('dl.pause'))),
          if (task.state.isResumable)
            PopupMenuItem(value: 'resume', child: Text(context.t('dl.resume'))),
          if (task.state.isActive || task.state == DownloadState.paused)
            PopupMenuItem(
                value: 'cancel', child: Text(context.t('dl.cancel_task'))),
          if (task.state == DownloadState.completed) ...[
            PopupMenuItem(value: 'open', child: Text(context.t('common.open'))),
            PopupMenuItem(
                value: 'folder', child: Text(context.t('dl.open_folder'))),
          ],
          PopupMenuItem(value: 'copy', child: Text(context.t('dl.copy_link'))),
          PopupMenuItem(value: 'remove', child: Text(context.t('dl.remove'))),
        ],
      );
  }
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
      actionLabel: context.t('dl.download_here'),
      startPath: FmEnv.primaryRoot,
    ),
  ));
  if (dest == null || !context.mounted) return;

  await DownloadService.instance
      .enqueue(target, destDir: dest, fileName: suggestedName);
  if (!context.mounted) return;
  showSnack(context, context.t(
        'dl.started', {'name': suggestedName ?? p.basename(target)}));
}

Future<GithubRelease?> _fetchRelease(BuildContext context, String apiUrl) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(ctx.t('dl.fetching_release'))),
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
              subtitle: Text(ctx.t('dl.asset_count',
                  {'n': release.assets.length, 'tag': release.tag})),
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
                          : ctx.t('dl.size_unknown')),
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


/// Tarayıcıdan indirme yollarını anlatan kart.
///
/// **Niye böyle bir açıklama var (2026-07-29 kullanıcı hatası):** kullanıcı
/// tarayıcıda bir `.apk` bağlantısına dokundu ve çıkan "birlikte aç"
/// listesinde yalnız DuckDuckGo/Chrome vardı, biz yoktuk.
///
/// **Kök neden Android 12 (API 31) kuralı:** `http/https` şemalı bir
/// `VIEW` + `BROWSABLE` filtresi artık YALNIZCA o alan adı için **doğrulanmış**
/// uygulamalara gösteriliyor. Doğrulama, alan adının sunucusuna
/// `.well-known/assetlinks.json` koymayı gerektirir — `github.com` bizim
/// olmadığı için bunu yapamayız. Yani "linke dokun → listede biz de çıkalım"
/// modern Android'de **kullanıcı elle izin vermeden mümkün değil**.
/// (Filtreler yine duruyor: Android 11 ve öncesinde çalışıyor, ayrıca
/// "Varsayılan olarak aç" ekranında görünmemizi sağlıyor.)
///
/// Bu yüzden ekranda dürüst bir açıklama ve **gerçekten çalışan** iki yol var:
/// paylaş menüsü ve bağlantıyı kopyalama.
class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('dl.how_to'), style: text.titleSmall),
            const SizedBox(height: Gap.sm),
            _Step(
              icon: Icons.share_outlined,
              title: context.t('dl.step1_title'),
              body: context.t('dl.step1_body'),
            ),
            _Step(
              icon: Icons.content_paste_go,
              title: context.t('dl.step2_title'),
              body: context.t('dl.step2_body'),
            ),
            // Menü adı markaya göre değişiyor; tek bir yol yazmak
            // "bulamıyorum"a çıkıyor (kullanıcı geri bildirimi 2026-07-29).
            // Bu yüzden aşağıdaki düğme doğrudan uygulama bilgisi ekranını
            // açıyor ve metin oradan sonrasını marka marka anlatıyor.
            _Step(
              icon: Icons.settings_outlined,
              title: context.t('dl.step3_title'),
              body: context.t('dl.step3_body'),
            ),
            const SizedBox(height: Gap.xs),
            Text(context.t('dl.how_to_note'), style: text.bodySmall),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: StoragePermission.openSettings,
                icon: const Icon(Icons.open_in_new),
                label: Text(context.t('dl.open_app_info')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Step({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Yardım sayfasını açar (üst çubuktaki “?” düğmesi).
Future<void> showDownloadHelp(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Gap.md),
          child: _HowToCard(),
        ),
      ),
    );
