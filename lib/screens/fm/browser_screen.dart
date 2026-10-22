import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import '../../services/fm/storage_stats.dart' show StorageKind;
import '../../services/fm/paste_conflict.dart';
import '../../core/app_icons.dart';
import '../../models/fm_filter.dart';
import '../../widgets/fm/fm_file_list_view.dart';
import '../../widgets/fm/fm_path_bar.dart';
import '../../widgets/scan_flow.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_type_chips.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/paste_conflict_sheet.dart';
import '../../widgets/fm/pin_dialog.dart';
import 'archive_screen.dart';
import 'entry_actions.dart';
import 'organize_screen.dart';
import 'search_screen.dart';
import '../../core/snack.dart';
import '../../widgets/motion.dart';
import '../../core/user_error.dart';

part 'browser/actions.dart';
part 'browser/views.dart';

/// Gezgin sayfası yolu: [screen] bir [BrowserScreen] ise rota, yol hapı
/// atlamasının ([BrowserScreen.jumpTo]) tanıyabilmesi için klasör yoluyla
/// işaretlenir. Başka ekranlar düz `MaterialPageRoute` olarak açılır.
Route<T> browserRoute<T>(Widget screen) => MaterialPageRoute<T>(
      settings: screen is BrowserScreen
          ? RouteSettings(
              name: BrowserScreen.routeName,
              arguments: p.normalize(screen.path))
          : null,
      builder: (_) => screen,
    );

/// Klasör gözatıcısı: listeleme, çoklu seçim, kopyala/kes/yapıştır, yeni
/// klasör/dosya, sıralama, filtre, ızgara/liste, favoriler.
///
/// Gezinme **push tabanlı**: her alt klasör yeni bir sayfadır → Android geri
/// tuşu doğal olarak bir üst klasöre çıkar, kaydırma konumu korunur. Yol
/// haplarına dokunmak ise yeni sayfa açmaz, yığında GERİ gider ([jumpTo]).
class BrowserScreen extends StatefulWidget {
  final String path;

  /// Başlıkta klasör adı yerine gösterilecek etiket (ör. "Ana bellek").
  final String? title;

  const BrowserScreen({super.key, required this.path, this.title});

  /// [browserRoute] ile açılan gezgin rotalarının adı.
  static const routeName = 'fm.browser';

  /// Yol hapına dokunuş (Faz 6 / B2, 2026-10-21): yığında [target]
  /// klasörüne kadar **geri** gider.
  ///
  /// KÖK NEDEN: hap `push` ediyordu — yığın her dokunuşta büyüyor, geri tuşu
  /// kullanıcıyı az önce çıktığı derin klasöre götürüyordu. Şimdi [target]'ın
  /// İÇİNDEKİ gezgin sayfaları kapatılır; [target]'ın kendisi yığında varsa
  /// orada durulur (kaydırma konumu da korunur), yoksa (ör. derin bir klasör
  /// doğrudan "Göster" ile açıldıysa) kapatılan sayfaların YERİNE açılır —
  /// yığın hiçbir durumda büyümez.
  static void jumpTo(BuildContext context, String target) {
    final nav = Navigator.of(context);
    final want = p.normalize(target);
    var found = false;
    var popped = 0;
    nav.popUntil((route) {
      final s = route.settings;
      if (s.name != routeName || s.arguments is! String) return true;
      final at = s.arguments as String;
      if (at == want) {
        found = true;
        return true;
      }
      // Hedefin altındaki (daha derin) sayfa kapanır; hedefin dışındaki
      // bir sayfaya (üst klasör ya da başka birim) gelince durulur.
      if (FsPaths.isInside(want, at)) {
        popped++;
        return false;
      }
      return true;
    });
    if (found) return;
    if (popped > 0) {
      nav.push(browserRoute(BrowserScreen(path: want)));
    } else {
      // Hiçbir sayfa kapanmadı (hedef başka bir dalda) → bulunulan sayfanın
      // YERİNE aç: geri tuşu yine bir öncekine döner, yığın büyümez.
      nav.pushReplacement(browserRoute(BrowserScreen(path: want)));
    }
  }

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

  /// Gezgin süzgeci (Faz 6 / U3; Faz 13'ten beri ortak tür modeliyle — PDF,
  /// Word… ayrı çip): tür + tarih/boyut. Sayfaya özel — alt klasöre geçince
  /// sıfırdan başlar (süzgeç bir bakış, ayar değil).
  FmFilter _filter = FmFilter.none;

  /// Çip satırı açık mı? Süzgeç etkinse her zaman açık kalır (aksi hâlde
  /// liste "neden eksik" belli olmazdı).
  bool _showFilters = false;

  /// Liste ve ızgara aynı anda mount edilmediği için tek denetleyici yeterli;
  /// sürükleyerek seçimde kenara gelince otomatik kaydırma bunu kullanır.
  final ScrollController _scroll = ScrollController();

  bool get _selecting => _selected.isNotEmpty;

  int get _filterCount => _filter.activeCount;

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

  /// Süzgeçten geçen girdiler (sıralı).
  List<FsEntry> _visible(List<FsEntry> sorted) {
    if (!_filter.isActive) return sorted;
    return [
      for (final e in sorted)
        if (_passesFilter(e)) e,
    ];
  }

  bool _passesFilter(FsEntry e) {
    if (!_filter.isActive) return true;
    if (!e.isDir) return _filter.matches(e);
    // Klasörün "boyutu" yok: boyut süzgeci açıkken klasörler gizlenir,
    // tarih süzgeci klasörün değiştirilme zamanına bakar.
    if (_filter.sizeRange != FmSizeRange.any) return false;
    return _filter.matches(e);
  }

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final sorted = _sorted(appState);
    final entries = _visible(sorted);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final listColumn = Column(
      children: [
        FmPathBar(
          path: widget.path,
          onTap: (target) => BrowserScreen.jumpTo(context, target),
        ),
        if (!_locked && _error == null && (!_loading || _entries.isNotEmpty))
          FmListToolbar(
            count: entries.length,
            totalBytes: _bytesOf(entries),
            sort: appState.fmSort,
            descending: appState.fmSortDesc,
            onSort: (s, d) => appState.setFmSort(s, descending: d),
            filterCount: _filterCount,
            onFilter: () => _partSetState(() => _showFilters = !_showFilters),
          ),
        if (!_locked && (_showFilters || _filterCount > 0) && _entries.isNotEmpty)
          FmFilterBar(children: [
            ...FmTypeChips.forEntries(
              context,
              source: _entries,
              filter: _filter,
              onChanged: (f) => _partSetState(() => _filter = f),
            ),
            ...fmDateSizePills(
              context,
              filter: _filter,
              onChanged: (f) => _partSetState(() => _filter = f),
            ),
          ]),
        Expanded(
          child: _locked
              ? FmEmptyState(
                  icon: AppIcons.locked,
                  title: context.t('fm.locked_prompt'),
                )
              : _body(entries, appState),
        ),
      ],
    );

    return Scaffold(
      appBar: _selecting ? _selectionBar(context, entries) : _normalBar(context),
      // Stack: alt eylem çubuğu gövdenin yüksekliğini DEĞİŞTİRMESİN (aksi
      // hâlde liste zıplıyor — 2026-07-29 hatası).
      body: Stack(
        children: [
          // ≥ 840 dp (tablet, açık katlanabilir — Faz 6 / U11): solda
          // birimler + favoriler, sağda liste.
          if (wide)
            Row(
              children: [
                SizedBox(width: 280, child: _sidePane(context, appState)),
                const VerticalDivider(width: 1),
                Expanded(child: listColumn),
              ],
            )
          else
            listColumn,
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
      floatingActionButton: _selecting ? null : _fab(appState),
    );
  }

  /// Bağlamsal "+" (Faz 6 / U7): panoda öğe varsa düğme **"Yapıştır (3)"**
  /// olur (yanında küçük "vazgeç"); yoksa oluşturma levhasını açar.
  Widget _fab(AppState appState) {
    if (appState.hasClipboard) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fm.paste_cancel',
            tooltip: context.t('common.cancel'),
            onPressed: appState.clearClipboard,
            child: const Icon(AppIcons.close),
          ),
          const SizedBox(width: Gap.sm),
          FloatingActionButton.extended(
            heroTag: 'fm.paste',
            onPressed: _paste,
            icon: Icon(appState.clipboardCut ? AppIcons.cut : AppIcons.paste),
            label: Text(context.t(
                'create.paste_n', {'n': appState.clipboard.length})),
          ),
        ],
      );
    }
    return FloatingActionButton(
      onPressed: _showCreateSheet,
      tooltip: context.t('fm.new_folder_or_file'),
      child: const Icon(AppIcons.add),
    );
  }

  int _bytesOf(List<FsEntry> entries) {
    var total = 0;
    for (final e in entries) {
      if (!e.isDir) total += e.sizeBytes;
    }
    return total;
  }

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
