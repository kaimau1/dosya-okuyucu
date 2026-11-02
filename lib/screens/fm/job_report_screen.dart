import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'folder_picker_screen.dart';

part 'job_report_screen/parts.dart';

/// **İş sonucu ayrıntısı** — bir işin dosya dosya ne yaptığı (ya da önerdiği).
///
/// Kullanıcı isteği 2026-10-30: *"üzerine basınca ne yapıldığını gösteren,
/// tek tek hangi resimler/dosyalar neye etiketlendi gösteren, geri alınabilen,
/// silinebilen, düzenlenebilen (etiket adları vs.), taşıma yapılabilen bir
/// sayfa açılmalı — tüm bu tür işlerde"*.
///
/// **2026-10-30 (2) — baştan yazıldı.** Kullanıcı: *"ne yapılmış, hangi
/// fotoğraflara yapılmış bakmak anlamak çok zor; görseller önizlemesiyle
/// birlikte görülmeli"*. İlk sürüm yalnız dosya ADI listesiydi
/// (`IMG-2026…-WA0004.jpg` × 276) — hangi fotoğrafın "#Harita" önerildiği
/// gözle doğrulanamıyordu. Şimdi:
/// - **Üstte düz cümleyle özet:** "AI 640 dosyaya baktı, 38 etiket önerdi ·
///   henüz hiçbiri uygulanmadı" + ilerleme çubuğu + ne yapılacağı.
/// - **Etikete göre** (varsayılan): etiket çipleriyle süzülür; her etiket
///   bir **küçük resim ızgarası** (fotoğraf, video karesi, PDF kapağı,
///   belge simgesi + adı). Dokun = bu dosyayı çıkar / geri kat (✕ ↔ ✓),
///   basılı tut = dosyayı aç.
/// - **Dosyaya göre:** her dosya küçük resmiyle, önerilen etiketleri çip
///   olarak — tek dokunuşla tak/çıkar.
///
/// Değişiklikler [FmJob.changes]'ten okunur. Tek tek dokunuşlar ekranı
/// BEKLETMEZ: durum hemen değişir, disk yazımı sıralı bir kuyrukta yürür.
/// Tanınmayan türler (ileride eklenecek işler) yalnız listelenir ve açılabilir.
class JobReportScreen extends StatefulWidget {
  final FmJob job;

  /// Küçük resimler (testte kapatılır — gerçek çözücü yok).
  final bool thumbnails;

  const JobReportScreen({super.key, required this.job, this.thumbnails = true});

  @override
  State<JobReportScreen> createState() => _JobReportScreenState();
}

enum _View { tags, files }

class _JobReportScreenState extends State<JobReportScreen> {
  FmJob get _job => widget.job;
  bool _busy = false;
  _View _view = _View.tags;

  /// Etiket çipiyle seçilen tek grup (null = hepsi).
  String? _only;

  /// "Tümünü göster"e basılmış gruplar.
  final Set<String> _expanded = {};

  /// Yol → girdi (stat bir kez; ızgara tembel kurulduğu için yalnız görünenler).
  final Map<String, FsEntry?> _entries = {};

  /// Disk yazımları sırayla; dokunuşlar beklemez.
  Future<void> _writes = Future<void>.value();
  int _inFlight = 0;

  @override
  void initState() {
    super.initState();
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  FsEntry? _entry(String path) =>
      _entries.putIfAbsent(path, () => FsEntry.ofPath(path));

  static String _groupKey(JobChange c) => '${c.kind}\u0000${c.value}';

  /// (tür, değer) → değişiklikler; en kalabalık grup üstte.
  List<MapEntry<String, List<JobChange>>> get _groups {
    final map = <String, List<JobChange>>{};
    for (final c in _job.changes) {
      (map[_groupKey(c)] ??= []).add(c);
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
  }

  void _saved() {
    JobQueue.instance.touch(_job);
    if (mounted) setState(() {});
  }

  /// Etiket yazımını kuyruğa koyar; ekran hemen güncellenmiş durumu gösterir.
  void _enqueue(Future<void> Function() op) {
    setState(() => _inFlight++);
    _writes = _writes.then((_) => op()).catchError((Object _) {}).whenComplete(() {
      _inFlight--;
      _saved();
    });
  }

  Future<void> _guard(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _writes;
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
      _saved();
    }
  }

  // ── Etiket eylemleri ──────────────────────────────────────────────────────

  /// [list]'teki etiket önerilerini [on] durumuna getirir. Uygularken
  /// çıkarılmış (✕) öneriler atlanır; geri alırken öneri kalır (çıkarılmaz).
  void _setApplied(Iterable<JobChange> list, bool on) {
    final byTag = <String, List<String>>{};
    for (final c in list) {
      if (c.kind != 'tag' || c.applied == on) continue;
      if (on && c.rejected) continue;
      c.applied = on;
      (byTag[c.value] ??= []).add(c.path);
    }
    if (byTag.isEmpty) return;
    _enqueue(() async {
      for (final e in byTag.entries) {
        if (on) {
          await FileTags.add(e.value, e.key);
        } else {
          await FileTags.remove(e.value, e.key);
        }
      }
    });
  }

  /// Izgarada dokunuş: dosyayı bu etiketten çıkar ya da geri kat.
  /// Uygulanmış etiket çıkarılırken dosyadan da kaldırılır; çıkarılmış öneri
  /// geri katılırken grup zaten uygulanmışsa (ya da [applyNow]) hemen yazılır.
  void _toggle(JobChange c, {bool applyNow = false}) {
    if (c.kind != 'tag') return;
    if (c.applied) {
      c.rejected = true;
      _setApplied([c], false);
      return;
    }
    if (c.rejected) {
      c.rejected = false;
      final groupApplied = _job.changes
          .any((o) => o.kind == 'tag' && o.value == c.value && o.applied);
      if (applyNow || groupApplied) {
        _setApplied([c], true);
      } else {
        setState(() {});
        JobQueue.instance.touch(_job);
      }
      return;
    }
    // Bekleyen öneri: ızgarada "çıkar", dosya görünümünde (çip) "uygula".
    if (applyNow) {
      _setApplied([c], true);
    } else {
      setState(() => c.rejected = true);
      JobQueue.instance.touch(_job);
    }
  }

  Future<void> _renameTag(String from, List<JobChange> list) async {
    final to = await showAppPrompt(context,
        title: context.t('jr.rename_tag'), initial: from);
    if (to == null || to.isEmpty || to == from || !mounted) return;
    await _guard(() async {
      final paths = [for (final c in list) if (c.applied) c.path];
      // Yalnız BU işin dosyalarındaki etiket değişir; aynı adlı etiketin
      // başka dosyalardaki kullanımı olduğu gibi kalır.
      if (paths.isNotEmpty) {
        await FileTags.remove(paths, from);
        await FileTags.add(paths, to);
      }
      for (final c in list) {
        c.value = to;
      }
      if (_only == from) _only = to;
    });
  }

  Future<void> _removeGroup(String tag, List<JobChange> list) async {
    final ok = await showAppConfirm(context,
        title: context.t('jr.remove_tag'),
        message: context.t('jr.remove_tag_body', {'tag': tag, 'n': list.length}),
        confirmLabel: context.t('common.delete'),
        destructive: true);
    if (!ok) return;
    await _guard(() async {
      final paths = [for (final c in list) if (c.applied) c.path];
      if (paths.isNotEmpty) await FileTags.remove(paths, tag);
      _job.changes.removeWhere(list.contains);
      if (_only == tag) _only = null;
    });
  }

  Future<void> _removeOne(JobChange c) => _guard(() async {
        if (c.kind == 'tag' && c.applied) {
          await FileTags.remove([c.path], c.value);
        }
        _job.changes.remove(c);
      });

  /// Grubun dosyalarını bir klasöre taşır; etiketler ve kayıttaki yollar
  /// yeni yere göre güncellenir.
  /// Taşımayı geri al: dosyalar eski klasörlerine döner; kayıttan düşer.
  Future<void> _undoMove(List<JobChange> list) async {
    final str = AppStrings.of(context);
    await _guard(() async {
      final byDir = <String, List<JobChange>>{};
      for (final c in list) {
        final before = c.before;
        if (c.kind != 'move' || before == null) continue;
        if (!File(c.path).existsSync()) continue;
        (byDir[p.dirname(before)] ??= []).add(c);
      }
      var n = 0;
      for (final e in byDir.entries) {
        final result =
            await FileOps.moveAll([for (final c in e.value) c.path], e.key);
        n += result.succeeded;
        for (final t in result.transfers) {
          await FileTags.movePath(t.source, t.dest);
        }
        // Geri dönen (artık hedefte olmayan) dosyalar kayıttan düşer.
        for (final c in e.value) {
          if (!File(c.path).existsSync()) {
            _job.changes.remove(c);
            _entries.remove(c.path);
          }
        }
      }
      if (mounted) showSnack(context, str.t('jr.moved_back', {'n': n}));
    });
  }

  /// Yeniden adlandırmayı geri al (2026-11-02): her dosya eski adına döner;
  /// eski ad bu arada başka dosyaya verilmişse o dosya atlanır.
  Future<void> _undoRename(List<JobChange> list) async {
    final str = AppStrings.of(context);
    await _guard(() async {
      var n = 0;
      for (final c in [...list]) {
        final before = c.before;
        if (c.kind != 'rename' || before == null) continue;
        if (await FileSystemEntity.type(c.path) ==
            FileSystemEntityType.notFound) {
          continue;
        }
        try {
          await FileOps.rename(c.path, p.basename(before));
        } on FileSystemException {
          continue; // eski ad dolu → bu dosya yeni adında kalır
        }
        n++;
        _job.changes.remove(c);
        _entries.remove(c.path);
      }
      if (mounted) showSnack(context, str.t('jr.renamed_back', {'n': n}));
    });
  }

  /// Çöpe taşımayı geri al (2026-11-02): kayıttaki çöp yolu çöp dizininde
  /// aranır ve eski yerine geri yüklenir (eski yol doluysa " (1)" ekiyle).
  /// Çöp bu arada boşaltıldıysa o dosya için yapılacak bir şey yok.
  Future<void> _untrash(List<JobChange> list) async {
    final str = AppStrings.of(context);
    await _guard(() async {
      await FmEnv.ensureInit();
      final wanted = {
        for (final c in list)
          if (c.kind == 'trash') c.path: c
      };
      var n = 0;
      for (final item in await FmEnv.trash.list()) {
        final c = wanted[item.storedPath];
        if (c == null) continue;
        await FmEnv.trash.restore(item);
        n++;
        _job.changes.remove(c);
        _entries.remove(c.path);
      }
      if (mounted) showSnack(context, str.t('jr.restored', {'n': n}));
    });
  }

  Future<void> _moveGroup(List<JobChange> list) async {
    final paths = {
      for (final c in list)
        if (!c.rejected && File(c.path).existsSync()) c.path
    }.toList();
    if (paths.isEmpty) {
      showSnack(context, context.t('jr.nothing_to_move'));
      return;
    }
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
          sources: paths, actionLabel: context.t('fm.move_here')),
    ));
    if (dest == null || !mounted) return;
    final str = AppStrings.of(context);
    await _guard(() async {
      final result = await FileOps.moveAll(paths, dest);
      for (final t in result.transfers) {
        await FileTags.movePath(t.source, t.dest);
        for (final c in _job.changes) {
          if (c.path == t.source) c.path = t.dest;
        }
        _entries.remove(t.source);
      }
      if (mounted) {
        showSnack(context, str.t('jr.moved', {'n': result.succeeded}));
      }
    });
  }

  void _open(JobChange c, List<JobChange> group) {
    if (!File(c.path).existsSync()) {
      showSnack(context, context.t('jr.missing'));
      return;
    }
    EntryOpener.open(context, c.path, siblings: [
      for (final g in group)
        if (g.path != c.path || identical(g, c)) g.path
    ]);
  }

  /// Basılı tut: dosyayı aç ya da öneriyi listeden sil.
  Future<void> _fileMenu(JobChange c, List<JobChange> group) async {
    final action = await showAppSheet<String>(
      context,
      title: p.basename(c.path),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.open),
            title: Text(ctx.t('common.open')),
            onTap: () => Navigator.pop(ctx, 'open'),
          ),
          ListTile(
            leading: const Icon(AppIcons.delete),
            title: Text(ctx.t('jr.remove_one')),
            subtitle: Text(ctx.t('jr.remove_one_hint')),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'open') _open(c, group);
    if (action == 'remove') await _removeOne(c);
  }

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final changes = _job.changes;
    final hasTags = changes.any((c) => c.kind == 'tag');
    final working = _busy || _inFlight > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_job.shownTitle, overflow: TextOverflow.ellipsis),
        bottom: working
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: changes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Text(context.t('jr.empty'), textAlign: TextAlign.center),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _summary(context, groups)),
                if (hasTags) SliverToBoxAdapter(child: _controls(context, groups)),
                if (_view == _View.files)
                  _fileSliver(context)
                else
                  for (final g in groups)
                    if (_only == null || g.value.first.value == _only)
                      ..._groupSlivers(context, g.value),
                const SliverPadding(padding: EdgeInsets.only(bottom: Gap.xl)),
              ],
            ),
    );
  }

  /// Bölüm dosyası (extension) `setState`i doğrudan çağıramaz (korumalı üye).
  void _update(VoidCallback fn) => setState(fn);
}
