import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/op_history.dart';
import 'browser_screen.dart';

/// **Son işlemler** — "neyi nereye taşımıştım?" ve toplu geri alma.
///
/// Bildirimdeki "Geri al" düğmesi birkaç saniyede kaybolur; yanlış taşımayı
/// beş dakika sonra fark eden kullanıcının elinde hiçbir şey kalmıyordu.
/// Burada son 50 işlem duruyor ve yeri değişen işlemler (taşıma, otomatik
/// düzenleme) geri alınabiliyor.
class OpHistoryScreen extends StatefulWidget {
  const OpHistoryScreen({super.key});

  @override
  State<OpHistoryScreen> createState() => _OpHistoryScreenState();
}

class _OpHistoryScreenState extends State<OpHistoryScreen> {
  List<OpRecord> _records = const [];
  bool _loading = true;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await OpHistory.load();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _undo(OpRecord record) async {
    setState(() => _busy.add(record.whenMs));
    final result = await FileOps.undoMove(record.transfers);
    // Kayıt yalnız **tamamı** geri alındıysa düşer. Eskiden `succeeded > 0`
    // yetiyordu: 60 dosyanın 40'ı dönmüşse kayıt siliniyor, kalan 20'nin nereye
    // gittiğini söyleyen tek bilgi (kaynak→hedef eşlemesi) yok oluyor ve o
    // dosyalar bir daha ASLA geri alınamıyordu (2026-07-29 denetimi, 4. tur).
    final complete = !result.hasError &&
        result.succeeded >= record.transfers.length;
    if (complete) await OpHistory.remove(record);
    if (!mounted) return;
    setState(() => _busy.remove(record.whenMs));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(complete
          ? '${result.succeeded} öğe eski yerine döndü.'
          : '${result.succeeded}/${record.transfers.length} öğe geri alındı; '
              '${result.errors.length} hata (${result.errors.first}). '
              'Kayıt duruyor, yeniden deneyebilirsin.'),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Son işlemler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'Geçmişi temizle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                // Geçmişi silmek DOSYALARA dokunmaz; yalnız kayıt listesi
                // temizlenir — kullanıcıya da böyle söylenir.
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Geçmiş temizlensin mi?'),
                    content: const Text(
                        'Yalnızca işlem kayıtları silinir; dosyalarınıza '
                        'hiçbir şey olmaz. Geri alma imkânı kaybolur.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Temizle')),
                    ],
                  ),
                );
                if (ok == true) {
                  await OpHistory.clear();
                  await _load();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Gap.lg),
                    child: Text(
                      'Henüz kayıtlı işlem yok.\n'
                      'Taşıma ve otomatik düzenleme işlemleri burada birikir '
                      've buradan geri alınabilir.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(_records[i]),
                ),
    );
  }

  Widget _tile(OpRecord record) {
    final busy = _busy.contains(record.whenMs);
    final dest = record.transfers.isEmpty
        ? null
        : p.dirname(record.transfers.first.dest);
    return ListTile(
      leading: Icon(switch (record.kind) {
        OpKind.move => Icons.drive_file_move_outline,
        OpKind.copy => Icons.folder_copy_outlined,
        OpKind.delete => Icons.delete_outline,
        OpKind.rename => Icons.drive_file_rename_outline,
        OpKind.organize => Icons.auto_awesome_motion,
      }),
      title: Text(record.summary,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${record.kind.label} · ${FsPaths.humanDate(record.whenMs)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: dest == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BrowserScreen(path: dest),
              )),
      trailing: record.canUndo
          ? (busy
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: () => _undo(record),
                  child: const Text('Geri al'),
                ))
          : null,
    );
  }
}
