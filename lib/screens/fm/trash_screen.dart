import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/trash_service.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/section_header.dart';
import 'fm_settings_screen.dart';

/// Geri Dönüşüm Kutusu: silinen dosyaları geri yükle ya da kalıcı sil.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _items = const [];
  bool _loading = true;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  /// Çöpteki kayıtlar bellektedir → arama anlıktır, disk okunmaz.
  List<TrashItem> get _filtered => _query.trim().isEmpty
      ? _items
      : _items.where((i) => fmMatches(i.name, _query)).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await FmEnv.ensureInit();
    final items = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _restore(TrashItem item) async {
    try {
      final target = await FmEnv.trash.restore(item);
      if (!mounted) return;
      _snack(context.t('tr.restored',
          {'name': item.name, 'folder': target.split('/').last}));
    } catch (e) {
      _snack(context.t('trash.restore_failed', {'error': e}));
    }
    _load();
  }

  Future<void> _delete(TrashItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('fm.delete_permanent_title')),
        content: Text(context.t('trash.delete_one_body', {'name': item.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await FmEnv.trash.deleteForever(item);
    if (!mounted) return;
    _snack(context.t('trash.deleted_one', {'name': item.name}));
    _load();
  }

  /// Çöp kutusunu boşaltır — **ilerleme penceresiyle**.
  ///
  /// Eskiden bu işlem sessizdi: yüzlerce dosya silinirken ekran donmuş gibi
  /// görünüyor, bitince de hiçbir şey söylenmiyordu (kullanıcı bulgusu
  /// 2026-07-25). Artık kaç öğenin silineceği önce yazılır, silme sırasında
  /// çubuk ve dosya adı görünür, sonunda özet bildirilir.
  Future<void> _empty() async {
    final count = _items.length;
    final total = _items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('trash.empty_confirm_title')),
        content: Text(ctx.t('tr.delete_body',
            {'n': count, 'size': FsPaths.humanSize(total)})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('trash.empty_action'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Pencere "Arka plana al" ile kapatılabildiği için kullanıcı bu ekrandan
    // çıkmış olabilir. Messenger'ı ŞİMDİ yakalıyoruz: MaterialApp seviyesindeki
    // örnek ekrandan bağımsız yaşar, sonuç mesajı nerede olursa olsun görünür.
    final messenger = ScaffoldMessenger.of(context);
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    final result = await showFmProgress<FmOpResult>(
      context,
      title: context.t('trash.emptying'),
      task: (report, isCancelled) =>
          FmEnv.trash.empty(onProgress: report, isCancelled: isCancelled),
    );
    final String message;
    if (result.hasError) {
      message = str.t('tr.partial', {
        'n': result.succeeded,
        'fail': result.errors.length,
        'first': result.errors.first,
      });
    } else if (result.cancelled) {
      message = str.t('tr.cancelled', {'n': result.succeeded});
    } else {
      message = str.t('tr.emptied',
          {'n': result.succeeded, 'size': FsPaths.humanSize(total)});
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (mounted) _load();
  }

  /// **Tümünü geri yükle** — bugüne kadar yalnız tek tek geri yükleme vardı;
  /// yanlışlıkla 40 dosya silen kullanıcı 40 kez dokunmak zorundaydı.
  /// Boşaltmadaki ilerleme penceresinin aynısı kullanılır.
  Future<void> _restoreAll() async {
    final items = List<TrashItem>.from(_items);
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final str = AppStrings.of(context);
    final result = await showFmProgress<FmOpResult>(
      context,
      title: str.t('trash.restore_all'),
      task: (report, isCancelled) async {
        var done = 0;
        final errors = <String>[];
        for (final item in items) {
          if (isCancelled()) {
            return FmOpResult(
                succeeded: done, errors: errors, cancelled: true);
          }
          report(FmProgress(done, items.length, item.name));
          try {
            await FmEnv.trash.restore(item);
            done++;
          } catch (e) {
            errors.add('$e');
          }
        }
        return FmOpResult(succeeded: done, errors: errors);
      },
    );
    final message = result.hasError
        ? str.t('tr.partial', {
            'n': result.succeeded,
            'fail': result.errors.length,
            'first': result.errors.first,
          })
        : str.t('trash.restore_all_done', {'n': result.succeeded});
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (mounted) _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    final shown = _filtered;
    return Scaffold(
      appBar: _searching
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _searching = false;
                  _query = '';
                  _searchController.clear();
                }),
              ),
              title: FmSearchField(
                controller: _searchController,
                hint: context.t('trash.search_hint'),
                onChanged: (v) => setState(() => _query = v),
              ),
            )
          : AppBar(
              title: Text(context.t('trash.title')),
              actions: [
                if (_items.isNotEmpty)
                  IconButton(
                    tooltip: context.t('trash.search'),
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _searching = true),
                  ),
                // "Boşalt" DOLU KIRMIZI: yıkıcı eylem TextButton olarak
                // sıradan bir metin gibi duruyordu.
                if (_items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: FilledButton(
                      onPressed: _empty,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                        foregroundColor:
                            Theme.of(context).colorScheme.onError,
                        minimumSize: const Size(0, 40),
                        padding:
                            const EdgeInsets.symmetric(horizontal: Gap.md),
                      ),
                      child: Text(context.t('trash.empty_action')),
                    ),
                  ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text(context.t('trash.empty')))
              : Column(
                  children: [
                    _summaryBand(total, shown.length),
                    const Divider(height: 1),
                    Expanded(
                      // Kart yerine 1px ayraç: liste ekranlarında kağıt
                      // temasının kuralı (kart yalnız pano ve son belgelerde).
                      child: ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = shown[i];
                          return ListTile(
                            leading: Icon(item.isDir
                                ? Icons.folder_outlined
                                : Icons.insert_drive_file_outlined),
                            title: Text(item.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: MonoText(
                              '${FsPaths.humanDate(item.deletedAtMs)} · '
                              '${item.originalPath}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _rowAction(
                                  Icons.restore,
                                  context.t('trash.restore'),
                                  Paper.success(context),
                                  () => _restore(item),
                                ),
                                const SizedBox(width: Gap.xs),
                                _rowAction(
                                  Icons.delete_forever,
                                  context.t('trash.delete_forever'),
                                  Theme.of(context).colorScheme.error,
                                  () => _delete(item),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Özet şeridi: kaç öğe / ne kadar yer + **otomatik temizleme bilgisi**.
  /// Kullanıcı "çöpteki dosya ne zaman gidiyor" sorusunun cevabını ayarlara
  /// girmeden göremiyordu; kapalıysa ayara kısayol verilir.
  Widget _summaryBand(int total, int shownCount) {
    final scheme = Theme.of(context).colorScheme;
    final days = context.watch<AppState>().fmTrashAutoDays;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_sweep_outlined, size: 20),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(_query.trim().isEmpty
                    ? context.t('tr.count_size', {
                        'n': _items.length,
                        'size': FsPaths.humanSize(total),
                      })
                    : context.t('trash.filtered', {
                        'n': shownCount,
                        'total': _items.length,
                      })),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Paper.faint(context)),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  days > 0
                      ? context.t('trash.auto_days', {'n': days})
                      : context.t('trash.auto_off'),
                  style:
                      TextStyle(fontSize: 12, color: Paper.faint(context)),
                ),
              ),
              if (days <= 0)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FmSettingsScreen()),
                  ),
                  child: Text(context.t('common.settings')),
                ),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _restoreAll,
                icon: const Icon(Icons.restore, size: 18),
                label: Text(context.t('trash.restore_all')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Satır eylemi kenarlıklı kutu içinde — 44dp dokunma hedefi korunur.
  Widget _rowAction(
          IconData icon, String tooltip, Color color, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      );
}
