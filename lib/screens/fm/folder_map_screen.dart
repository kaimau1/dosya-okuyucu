import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/folder_usage.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/search_index.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'browser_screen.dart';

/// **Klasör haritası** — "57 GB nerede?" sorusunun cevabı.
///
/// Kullanıcı isteği (2026-08-17, ekran görüntüsü): bellek analizinde klasörler
/// boyuta göre sıralı, yanlarında oransal çubuk ve toplam depolamaya göre
/// yüzde görünsün; içine girilerek inilebilsin.
///
/// Analiz ekranı bunu **türe göre** (Videolar / Görüntüler …) zaten kırıyordu
/// ama tür "hangi klasörü temizlemeliyim" sorusuna cevap vermiyor: 53 GB video
/// gördükten sonra da kullanıcı DCIM mi, WhatsApp mı, indirilenler mi
/// bilmiyordu. Ölçüm arama dizininden gelir (ek tarama yok) — bkz.
/// [FolderUsageScan].
class FolderMapScreen extends StatefulWidget {
  final String path;

  /// Yüzdeler bu kapasiteye göre yazılır (0 ise klasörün kendi toplamına
  /// göre). Cihazın toplam belleği verilirse ekrandaki yüzde "telefonumun
  /// yüzde kaçı" anlamına gelir — kullanıcının beklediği sayı bu.
  final int capacityBytes;

  /// Başlıkta gösterilecek ad (verilmezse klasör adı).
  final String? title;

  const FolderMapScreen({
    super.key,
    required this.path,
    this.capacityBytes = 0,
    this.title,
  });

  @override
  State<FolderMapScreen> createState() => _FolderMapScreenState();
}

class _FolderMapScreenState extends State<FolderMapScreen> {
  FolderBreakdown _data = FolderBreakdown.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await FolderUsageScan.of(
      widget.path,
      indexPath: SearchIndex.isReady ? SearchIndex.indexPath : null,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  /// Toplam depolamaya (ya da klasörün kendi toplamına) göre yüzde.
  double _percentOf(int bytes) {
    final base =
        widget.capacityBytes > 0 ? widget.capacityBytes : _data.totalBytes;
    if (base <= 0) return 0;
    return bytes * 100 / base;
  }

  Future<void> _open(FolderUsage child) async {
    if (!child.isDir) {
      await EntryOpener.open(context, child.path);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FolderMapScreen(
        path: child.path,
        capacityBytes: widget.capacityBytes,
      ),
    ));
    // Dönüşte tazele: kullanıcı alt klasörde dosya silmiş olabilir.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Çubuk oranı EN BÜYÜK çocuğa göre: kapasiteye göre çizilseydi 512 GB'lık
    // bir telefonda tüm çubuklar görünmez birer çizgi olurdu.
    final maxBytes =
        _data.children.isEmpty ? 1 : _data.children.first.bytes.clamp(1, 1 << 62);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title ?? p.basename(widget.path)),
            Text(
              context.t('fmap.summary', {
                'n': _data.totalFiles,
                'size': FsPaths.humanSize(_data.totalBytes),
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('important.open_in_browser'),
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BrowserScreen(path: widget.path),
              ));
              if (mounted) await _load();
            },
          ),
          IconButton(
            tooltip: context.t('common.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (!_loading && _data.children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Center(child: Text(context.t('fmap.empty'))),
              ),
            for (final child in _data.children)
              _UsageRow(
                child: child,
                fraction: child.bytes / maxBytes,
                percent: _percentOf(child.bytes),
                onTap: () => _open(child),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tek satır: simge + ad/öğe sayısı + oransal çubuk + yüzde.
///
/// Çubuk **adın arkasında değil altında** durur: koyu bir zemin üstünde ad
/// okunmaz hâle geliyordu ve kağıt teması zaten gölge değil çizgi kullanıyor.
class _UsageRow extends StatelessWidget {
  final FolderUsage child;
  final double fraction;
  final double percent;
  final VoidCallback onTap;

  const _UsageRow({
    required this.child,
    required this.fraction,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = FsEntry(
      path: child.path,
      name: child.name,
      isDir: child.isDir,
      sizeBytes: child.bytes,
      modifiedMs: 0,
    );
    final color = child.isDir
        ? FmColors.folder
        : FmColors.forCategory(entry.category);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FmEntryIcon(entry: entry, size: 40),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(child.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        // Yüzde bir ondalıkla: 512 GB'lık bir telefonda 5 GB
                        // "%1" diye yuvarlanınca hepsi aynı görünüyordu.
                        '%${percent.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${context.t('count.files', {'n': child.files})} · '
                    '${FsPaths.humanSize(child.bytes)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Paper.faint(context)),
                  ),
                  const SizedBox(height: Gap.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.02, 1).toDouble(),
                      minHeight: 8,
                      color: color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            if (child.isDir)
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
