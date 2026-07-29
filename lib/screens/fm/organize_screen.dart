import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/auto_organize.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/op_history.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'browser_screen.dart';

/// **Otomatik düzenle** — dağınık bir klasörü tek dokunuşla türe/tarihe/kaynağa
/// göre alt klasörlere ayırır.
///
/// Akış bilinçli olarak **önizle → onayla → uygula**:
/// 3.000 dosyayı taşımadan önce kaç klasör oluşacağı ve nereye ne gideceği
/// görülmeli. Plan saf bir fonksiyondan gelir (`planOrganize`, birim testli);
/// bu ekran yalnız gösterir ve `FileOps.moveAll` ile uygular.
///
/// Uygulama sonrası işlem **geçmişe yazılır** → yanlış bir düzenleme toplu
/// olarak geri alınabilir (bkz. `OpHistory`).
class OrganizeScreen extends StatefulWidget {
  /// Düzenlenecek klasör.
  final String path;
  const OrganizeScreen({super.key, required this.path});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  List<FsEntry> _files = const [];
  OrganizeBy _by = OrganizeBy.type;
  bool _loading = true;
  bool _onlyTopLevel = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Üst düzey varsayılan: alt klasörleri dağıtmak kullanıcının kendi
    // düzenini bozabilir; isteyen "alt klasörler dahil"i açar.
    final files = _onlyTopLevel
        ? (await FsScan.list(widget.path)).where((e) => !e.isDir).toList()
        : await FsScan.collect([widget.path]);
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  OrganizePlan get _plan => planOrganize(_files, _by);

  Future<void> _apply() async {
    final plan = _plan;
    if (plan.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Düzenlensin mi?'),
        content: Text(
          '${plan.fileCount} dosya, ${plan.folderCount} klasöre taşınacak '
          '(${FsPaths.humanSize(plan.bytes)}).\n\n'
          'Dosyalar aynı klasörün içinde yer değiştirir; silinmez. '
          'İşlem geçmişinden geri alabilirsiniz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Düzenle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // Klasör başına tek `moveAll` çağrısı: hedef klasör bir kez oluşturulur ve
    // ilerleme çubuğu anlamlı ilerler.
    final byFolder = <String, List<String>>{};
    for (final move in plan.moves) {
      (byFolder[move.folder] ??= []).add(move.entry.path);
    }

    final transfers = <FmTransfer>[];
    final errors = <String>[];
    await showFmProgress<void>(
      context,
      title: 'Düzenleniyor',
      task: (report, isCancelled) async {
        var done = 0;
        for (final entry in byFolder.entries) {
          if (isCancelled()) break;
          final dest = p.join(widget.path, entry.key);
          try {
            await Directory(dest).create(recursive: true);
          } catch (e) {
            errors.add('${entry.key}: $e');
            continue;
          }
          final result = await FileOps.moveAll(
            entry.value,
            dest,
            isCancelled: isCancelled,
          );
          transfers.addAll(result.transfers);
          errors.addAll(result.errors);
          done += entry.value.length;
          report(FmProgress(done, plan.fileCount, entry.key));
        }
      },
    );

    if (transfers.isNotEmpty) {
      await OpHistory.add(OpRecord(
        kind: OpKind.organize,
        whenMs: DateTime.now().millisecondsSinceEpoch,
        summary: '${transfers.length} dosya · ${_by.label} · '
            '${p.basename(widget.path)}',
        transfers: transfers,
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errors.isEmpty
          ? '${transfers.length} dosya düzenlendi.'
          : 'Bazı dosyalar taşınamadı: ${errors.first}'),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Otomatik düzenle'),
            Text(p.basename(widget.path),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Klasörü aç',
            icon: const Icon(Icons.folder_open),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BrowserScreen(path: widget.path),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 120),
              children: [
                Text('Neye göre ayrılsın?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gap.sm),
                for (final by in OrganizeBy.values)
                  RadioListTile<OrganizeBy>(
                    value: by,
                    groupValue: _by,
                    onChanged: (v) => setState(() => _by = v ?? _by),
                    title: Text(by.label),
                    subtitle: Text(by.description),
                    contentPadding: EdgeInsets.zero,
                  ),
                SwitchListTile(
                  value: !_onlyTopLevel,
                  onChanged: (v) {
                    setState(() => _onlyTopLevel = !v);
                    _load();
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alt klasörler dahil'),
                  subtitle: const Text(
                      'Kapalıyken yalnız bu klasördeki dosyalar düzenlenir; '
                      'mevcut alt klasörlerinize dokunulmaz.'),
                ),
                const Divider(height: Gap.lg),
                Text('Önizleme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Gap.sm),
                if (plan.isEmpty)
                  Text(plan.alreadyPlaced > 0
                      ? 'Her şey zaten yerinde görünüyor '
                          '(${plan.alreadyPlaced} dosya).'
                      : 'Bu klasörde düzenlenecek dosya yok.')
                else ...[
                  Text('${plan.fileCount} dosya → ${plan.folderCount} klasör '
                      '(${FsPaths.humanSize(plan.bytes)})'),
                  if (plan.alreadyPlaced > 0)
                    Text('${plan.alreadyPlaced} dosya zaten doğru klasörde.',
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: Gap.sm),
                  for (final entry in (plan.folderCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value))))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.folder, color: FmColors.folder),
                      title: Text(entry.key),
                      trailing: Text('${entry.value} dosya'),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: FilledButton.icon(
            onPressed: plan.isEmpty ? null : _apply,
            icon: const Icon(Icons.auto_awesome_motion),
            label: Text(plan.isEmpty
                ? 'Düzenlenecek dosya yok'
                : '${plan.fileCount} dosyayı düzenle'),
          ),
        ),
      ),
    );
  }
}
