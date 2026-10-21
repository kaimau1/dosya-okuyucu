import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../services/blank_docs.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/empty_folders.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/folder_size_cache.dart';
import '../../services/fm/folder_report.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/paste_conflict.dart';
import '../../widgets/fm/drag_select.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/paste_conflict_sheet.dart';
import '../../widgets/fm/pin_dialog.dart';
import 'archive_screen.dart';
import 'entry_actions.dart';
import 'organize_screen.dart';
import 'search_screen.dart';
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';

part 'browser/actions.dart';
part 'browser/views.dart';

/// Klasör gözatıcısı: listeleme, çoklu seçim, kopyala/kes/yapıştır, yeni
/// klasör/dosya, sıralama, ızgara/liste, favoriler.
///
/// Gezinme **push tabanlı**: her alt klasör yeni bir sayfadır → Android geri
/// tuşu doğal olarak bir üst klasöre çıkar, kaydırma konumu korunur.
class BrowserScreen extends StatefulWidget {
  final String path;

  /// Başlıkta klasör adı yerine gösterilecek etiket (ör. "Ana bellek").
  final String? title;

  const BrowserScreen({super.key, required this.path, this.title});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  List<FsEntry> _entries = const [];

  /// Sıralı liste önbelleği (Faz 3 / P8): sürükleyerek seçimde her
  /// `setState` 5-10 bin öğeyi baştan sıralıyordu. Anahtar = (liste
  /// kimliği, ölçüt, yön); yükleme ya da sıralama değişince yenilenir.
  List<FsEntry>? _sortedCache;
  (List<FsEntry>, FmSort, bool)? _sortedKey;
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};

  /// Liste ve ızgara aynı anda mount edilmediği için tek denetleyici yeterli;
  /// sürükleyerek seçimde kenara gelince otomatik kaydırma bunu kullanır.
  final ScrollController _scroll = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  /// Görünen tüm girdiler seçili mi? ("Tümünü seç" düğmesinin durumu.)
  bool get _allSelected =>
      _entries.isNotEmpty && _entries.every((e) => _selected.contains(e.path));

  /// Kilitli klasör açıldı ve PIN henüz doğrulanmadı → içerik gizlenir.
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    // Kilit denetimi ilk kareden sonra (context.read için mount gerekir).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLock());
    FolderSizeCache.revision.addListener(_onFolderSize);
    _load();
  }

  @override
  void dispose() {
    FolderSizeCache.revision.removeListener(_onFolderSize);
    _scroll.dispose();
    super.dispose();
  }

  /// Bir klasörün boyutu ölçüldü → o satırın alt yazısı tazelensin.
  void _onFolderSize() {
    if (mounted) setState(() {});
  }

  // ── işlemler ──────────────────────────────────────────────────────────────

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = _sorted;

    return Scaffold(
      appBar: _selecting ? _selectionBar(context, entries) : _normalBar(context),
      // Stack: alt eylem çubuğu gövdenin yüksekliğini DEĞİŞTİRMESİN (aksi
      // hâlde liste zıplıyor — 2026-07-29 hatası).
      body: Stack(
        children: [
          Column(
        children: [
          _Breadcrumb(
            path: widget.path,
            onTap: (target) {
              // Üst klasöre atlamak = yığında oraya kadar geri gitmek yerine
              // yeni sayfa açmak; geri tuşu yine çalışır, kod basit kalır.
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BrowserScreen(path: target),
              ));
            },
          ),
          Expanded(
            child: _locked
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Text(
                        context.t('fm.locked_prompt'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _body(entries),
          ),
          if (appState.hasClipboard && !_selecting) _pasteBar(appState),
        ],
          ),
          // Seçim varken alt eylem çubuğu: Taşı · Kopyala · Paylaş · Sil.
          // (Üst çubuktaki küçük simgeler başparmakla zor ve taşıma orada yoktu.)
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FmSelectionBar(
                selected: _selectedEntries,
                zipDestDir: widget.path,
                onChanged: () async {
                  // "Arka plana al" ile ekran kapanmış olabilir: `FmSelectionBar`
                  // işini bitirdiğinde bu State artık ölü olabiliyor ve
                  // `setState` "called after dispose" hatası atıyordu
                  // (2026-07-29 sadakat denetimi, 2. tur).
                  if (!mounted) return;
                  setState(_selected.clear);
                  _load();
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: _showCreateSheet,
              tooltip: context.t('fm.new_folder_or_file'),
              child: const Icon(Icons.add),
            ),
    );
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}

/// Yol çubuğu: her parçaya dokununca o klasöre gider.
class _Breadcrumb extends StatelessWidget {
  final String path;
  final void Function(String) onTap;
  const _Breadcrumb({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = <({String label, String path})>[];
    // Kök olarak birim köklerini kullan: kullanıcıya "/storage/emulated/0"
    // yerine "Ana bellek" gösterilir.
    var remainder = p.normalize(path);
    String? rootPath;
    String rootLabel = context.t('fm.root');
    for (final v in FmEnv.volumes) {
      if (FsPaths.isInside(v.path, remainder)) {
        rootPath = p.normalize(v.path);
        // `label` birincil bellekte BOŞ (ad çeviriden gelir): kökte yol
        // çubuğu boş bir şerit olarak görünüyordu (kullanıcı ekran
        // görüntüsü 2026-09-23). Panodaki kartla aynı ad kaynağı.
        rootLabel = v.displayLabel(context.t);
        break;
      }
    }
    rootPath ??= '/';
    segments.add((label: rootLabel, path: rootPath));
    if (remainder.length > rootPath.length) {
      final rest = remainder
          .substring(rootPath.length)
          .split('/')
          .where((s) => s.isNotEmpty);
      var acc = rootPath;
      for (final s in rest) {
        acc = p.join(acc, s);
        segments.add((label: s, path: acc));
      }
    }

    // Birimin KÖKÜNDE yol çubuğu gösterilmez: tek parçası başlıkla aynı
    // ("Ana bellek") — 45 dp'lik bir şerit yalnız tekrar ediyordu.
    if (segments.length < 2) return const SizedBox.shrink();

    // Hap biçimli yol parçaları (2026-09-23 tasarım turu): üst klasörler
    // dokunulabilir haplar, bulunulan klasör dolgulu hap.
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true, // uzun yolda son klasör görünür kalsın
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 8),
        itemCount: segments.length,
        itemBuilder: (context, i) {
          final seg = segments[segments.length - 1 - i];
          final isLast = i == 0;
          final isRoot = i == segments.length - 1;
          return Row(
            children: [
              if (!isRoot)
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
              Material(
                color: isLast
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isLast ? null : () => onTap(seg.path),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRoot) ...[
                          Icon(Icons.smartphone_rounded,
                              size: 15,
                              color: isLast
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          seg.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isLast ? FontWeight.w700 : FontWeight.w500,
                            color: isLast
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
