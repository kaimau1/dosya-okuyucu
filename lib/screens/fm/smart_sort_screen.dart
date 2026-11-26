import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_folder_prefs.dart';
import '../../services/fm/smart_folders.dart';
import '../../services/fm/smart_learn.dart';
import '../../services/fm/smart_quota.dart';
import '../../services/fm/smart_scope_pick.dart';
import '../../services/fm/smart_sort.dart';
import '../../services/fm/smart_sort_bg.dart';
import '../../services/fm/smart_sort_taxonomy.dart';
import '../../services/fm/smart_user_cats.dart';
import '../../widgets/ai_key_gate.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/pro_gate.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/pin_dialog.dart';
import '../../widgets/fm/smart_cat_style.dart';
import '../../widgets/section_header.dart';
import 'category_screen.dart';
import 'entry_actions.dart' show showUndoToast;
import 'folder_picker_screen.dart';
import 'smart_clutter_screen.dart';
import 'smart_folders_screen.dart';
import 'smart_scope_screen.dart';
import 'smart_user_cat_screen.dart';

/// **Akıllı düzen** ana ekranı (2026-11-18): aç/kapat ve gizlilik metni,
/// "Şimdi düzenle", anlık arama, akıllı süzgeçler (yaklaşan/geçmiş ödeme,
/// süre, tutar, belge yılı, kurum, düşük güven, Ayıkla), grup süzgeçli
/// akıllı klasörler ve ayarlar. Bkz. [SmartSort].
///
/// **Klasör düzeni (2026-11-18, kullanıcı):** akıllı klasörler yeniden
/// adlandırılır, sırası değiştirilir (basılı tut → menü ya da "Sırala ve
/// adlandır"), 2/3/4 sütun seçilir — menüden ya da İKİ PARMAKLA sıkıştırıp
/// açarak ([Listener]: hareket yarışına girmez, tek parmak kaydırma bozulmaz).
/// **Öğrenme:** dosyanın ⋮ menüsü → "Kategori yanlış mı?" ([SmartLearn]).
class SmartSortScreen extends StatefulWidget {
  const SmartSortScreen({super.key});

  static Future<void> open(BuildContext context) async {
    if (!await ProGate.check(context, Feature.smartFolders)) return;
    if (!context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SmartSortScreen()));
  }

  @override
  State<SmartSortScreen> createState() => _SmartSortScreenState();
}

class _SmartSortScreenState extends State<SmartSortScreen> {
  /// Bir "Başlat" dokunuşunda en çok bu kadar tur (tur başına sınır kadar
  /// dosya) art arda koşar; sonsuz döngü olmasın.
  static const _maxTurns = 10;

  bool _ready = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  SmartCatGroup _group = SmartCatGroup.all;

  // İki parmak sıkıştırma → sütun sayısı.
  final Map<int, Offset> _pointers = {};
  double? _pinchStart;

  double _span() {
    final v = _pointers.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _pointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) _pinchStart = _span();
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStart;
    if (_pointers.length != 2 || start == null || start < 24) return;
    final ratio = _span() / start;
    final cols = SmartFolderPrefs.columns;
    // Açmak (yakınlaştırma) = daha büyük kutu = daha az sütun.
    final next = ratio > 1.3
        ? cols - 1
        : (ratio < 0.77 ? cols + 1 : cols);
    if (next == cols ||
        next < SmartFolderPrefs.minColumns ||
        next > SmartFolderPrefs.maxColumns) {
      return;
    }
    _pinchStart = _span();
    AppHaptics.selection();
    unawaited(SmartFolderPrefs.setColumns(next));
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(Future.wait([
      SmartSort.ensureLoaded(),
      SmartQuota.read(),
      SmartFolders.instance.ensureLoaded(),
    ])
        .then((_) async {
      if (mounted) setState(() => _ready = true);
      // Silinmiş dosyaların kaydı düşsün: klasör sayıları gerçek olsun (U4).
      await SmartSort.pruneMissing();
    }));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    await SmartSort.setSettings(enabled: true);
    if (mounted) await _run();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // API anahtarı olmadan da yerel kurallar (0 kredi, çevrimdışı) çalışır;
    // belirsiz dosyalar için kullanıcı dilerse AI anahtarını ekleyebilir.
    if (state.aiCredentials.normalized.keys.isEmpty) {
      final r = await SmartSort.runLocalOnly(scope: state.aiScopeRules);
      if (!mounted) return;
      final msg = switch (r.hold) {
        SmartHold.noScope => s.t('sm.hold_scope'),
        _ => r.processed > 0
            ? s.t('sm.local_saved', {'n': r.processed})
            : s.t('sm.nothing_new'),
      };
      showSnackOn(messenger, msg);
      if (mounted && SmartFolderPrefs.rules.isNotEmpty) await _applyRules();
      return;
    }
    if (!await ensureAiKey(context) || !mounted) return;
    // Sınırsızda bir turda daha çok dosya (havuz zaten TÜM dosyalar — bkz.
    // SmartSort.scanAll).
    final limit = SmartQuota.isUnlimited ? 2000 : 300;
    // Kalıcı tur (2026-11-25, "sık sık duruyor, sürekli başlata basıyorum"):
    // dakikalık sınır / ağ kopması turu bitirmez, bekleyip sürer. Tur
    // sınırı dolunca ve engel yoksa sıradaki tura KENDİLİĞİNDEN geçilir
    // (ekran açıkken; en çok [_maxTurns]).
    var r = await SmartSort.run(
        credentials: state.aiCredentials,
        scope: state.aiScopeRules,
        limit: limit,
        persistent: true);
    var processed = r.processed;
    var failed = r.failed;
    var reused = r.reused;
    for (var turn = 1;
        turn < _maxTurns &&
            mounted &&
            r.hold == null &&
            r.stoppedBy == null &&
            !SmartSort.cancelRequested &&
            r.processed + r.failed >= limit;
        turn++) {
      r = await SmartSort.run(
          credentials: state.aiCredentials,
          scope: state.aiScopeRules,
          limit: limit,
          persistent: true);
      processed += r.processed;
      failed += r.failed;
      reused += r.reused;
    }
    var msg = switch (r.hold) {
      SmartHold.wifi => s.t('sm.hold_wifi'),
      SmartHold.cap =>
        s.t('sm.hold_cap', {'n': processed, 'cap': SmartQuota.dailyCap}),
      SmartHold.offline => s.t('sm.hold_offline'),
      SmartHold.noKey => s.t('uerr.ai_key'),
      SmartHold.noScope => s.t('sm.hold_scope'),
      // Durma nedeni kullanıcı dilinde (anahtar / kota / bağlantı) — eskiden
      // her durmada "günlük kota doldu" yazıyordu.
      null => r.stoppedBy != null
          ? s.t('sm.stopped', {'n': processed, 'reason': r.stoppedBy})
          : (processed == 0 && failed == 0
              ? s.t('sm.nothing_new')
              : s.t('sm.done', {'n': processed})),
    };
    // Yerelden 0 belirteçle eşlenen kopya varsa bildir.
    if (reused > 0 && r.hold == null) {
      msg += ' · ${s.t('sm.reused_n', {'n': reused})}';
    }
    // Yapılamayanlar da söylenir (eskiden sessizdi: "300'den 27 çıktı").
    if (failed > 0 && r.stoppedBy == null) {
      msg += ' · ${s.t('sm.failed', {'n': failed})}'
          '${r.lastError != null ? ': ${r.lastError}' : ''}';
    }
    showSnackOn(messenger, msg);
    // Taşıma kuralı varsa (varsayılan yok) yeni düzenlenenler de taşınır.
    if (mounted && SmartFolderPrefs.rules.isNotEmpty) await _applyRules();
  }

  /// **Taşıma kuralı** (B2 dilim 2): açıksa kapatır; kapalıysa klasör seçtirir,
  /// kaç dosyanın taşınacağını söyleyip ONAY ister, sonra uygular.
  Future<void> _rule(String cat) async {
    if (SmartFolderPrefs.ruleOf(cat) != null) {
      await SmartFolderPrefs.setRule(cat, null);
      return;
    }
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        homeCards: true,
        actionLabel: context.t('smo.rule_pick'),
      ),
    ));
    if (dest == null || !mounted) return;
    final n = SmartSort.pendingRuleMoves({cat: dest})
        .values
        .fold<int>(0, (a, l) => a + l.length);
    final ok = await showAppConfirm(
      context,
      title: context.t('smo.rule_title'),
      message: context.t('smo.rule_body', {
        'cat': SmartCatStyle.label(context, cat),
        'folder': p.basename(dest),
        'n': n,
      }),
      confirmLabel: context.t('smo.rule_ok'),
    );
    if (!ok || !mounted) return;
    await SmartFolderPrefs.setRule(cat, dest);
    if (mounted) await _applyRules({cat: dest});
  }

  /// Kuralların bekleyen taşımalarını yapar; hepsi tek "Geri al"la döner.
  Future<void> _applyRules([Map<String, String>? rules]) async {
    final plan = SmartSort.pendingRuleMoves(rules);
    if (plan.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    final results = await showFmProgress<List<FmOpResult>>(
      context,
      title: strings.t('fm.moving'),
      name: strings.t('fm.moving_name'),
      task: (report, isCancelled) async {
        final out = <FmOpResult>[];
        for (final e in plan.entries) {
          try {
            await Directory(e.key).create(recursive: true);
          } catch (_) {
            // Bilinçli: oluşturulamazsa taşıma hatası satır satır söyler.
          }
          out.add(await FileOps.moveAll(e.value, e.key,
              onProgress: report, isCancelled: isCancelled));
        }
        return out;
      },
    );
    final transfers = [for (final r in results) ...r.transfers];
    final errors = [for (final r in results) ...r.errors];
    final n = results.fold<int>(0, (a, r) => a + r.succeeded);
    if (n == 0 && errors.isEmpty) return;
    showUndoToast(
        messenger,
        strings,
        errors.isEmpty
            ? strings.t('smo.rule_moved', {'n': n})
            : strings.t('smo.rule_failed',
                {'n': n, 'fail': errors.length, 'error': errors.first}),
        () async {
      final back = await FileOps.undoMove(transfers);
      if (back.hasError) throw FileSystemException(back.errors.first);
    });
  }

  Future<void> _openCat(String cat) async {
    final nav = Navigator.of(context);
    final title = SmartCatStyle.label(context, cat);
    final list = SmartSort.pathsOf(cat);
    if (list.any(_isSensitive) && !await unlockSensitiveCats(context)) return;
    final hasDrill = SmartSort.subtypeCounts(cat).isNotEmpty ||
        SmartSort.yearsOf(cat).length > 1 ||
        SmartSort.institutionsOf(cat).isNotEmpty;
    final files = await FsScan.statPaths(list);
    if (!mounted) return;
    await nav.push(MaterialPageRoute(
      builder: (_) => hasDrill
          ? _SmartCatDetailScreen(
              cat: cat,
              title: title,
              initialFiles: files,
            )
          : CategoryScreen(
              title: title,
              files: files,
              loadAll: () => FsScan.statPaths(SmartSort.pathsOf(cat)),
              replaceOnLoad: true,
              memoryId: 'smart.$cat',
              header: const _FixHint(),
            ),
    ));
  }

  /// Akıllı düzen listesi (rozet, tutar, yıl, kurum ya da düşük güven süzgeci):
  /// yollar her açılışta kayıttan yeniden alınır.
  Future<void> _openList(
      String title, String memoryId, List<String> Function() paths) async {
    final nav = Navigator.of(context);
    final list = paths();
    if (list.any(_isSensitive) && !await unlockSensitiveCats(context)) return;
    final files = await FsScan.statPaths(list);
    if (!mounted) return;
    await nav.push(MaterialPageRoute(
      builder: (_) => CategoryScreen(
        title: title,
        files: files,
        loadAll: () => FsScan.statPaths(paths()),
        replaceOnLoad: true,
        memoryId: memoryId,
        // Öğrenme kapısı: yanlış düzenlenen dosya nasıl düzeltilir.
        header: const _FixHint(),
      ),
    ));
  }

  Future<void> _openSearchHit(SmartRecord r) async {
    if (_isSensitive(r.path) && !await unlockSensitiveCats(context)) return;
    if (!mounted) return;
    await EntryOpener.open(context, r.path);
  }

  static bool _isSensitive(String path) =>
      SmartTaxonomy.sensitive.contains(SmartSort.of(path)?.cat);

  static List<String> _paths(List<SmartRecord> list) =>
      [for (final r in list) r.path];

  /// Akıllı süzgeç şeridi öğeleri: acil ödeme/süre uyarıları, yaklaşanlar,
  /// gözden geçirilecek düşük güvenli dosyalar, tutar aralıkları, belge yılları,
  /// kurum/bankalar ve Ayıkla. Boş olanlar hiç gösterilmez.
  List<_ExtraTile> _filterChips(BuildContext context, int clutter, int hidden) {
    final overdue = SmartSort.overdue().length;
    final upcoming = SmartSort.upcomingDue().length;
    final expired = SmartSort.expired().length;
    final expiring = SmartSort.expiringSoon().length;
    final lowConf = SmartSort.lowConfidence().length;
    final amounts = SmartSort.amountCounts();
    final years = SmartSort.yearCounts();
    final insts = SmartSort.institutionCounts();
    final error = Theme.of(context).colorScheme.error;
    return [
      if (overdue > 0)
        _ExtraTile(
          key: 'ss-overdue',
          icon: AppIcons.warning,
          color: error,
          label: context.t('sm.overdue'),
          n: overdue,
          onTap: () => unawaited(_openList(context.t('sm.overdue'),
              'smart.overdue', () => _paths(SmartSort.overdue()))),
        ),
      if (upcoming > 0)
        _ExtraTile(
          key: 'ss-upcoming-due',
          icon: AppIcons.schedule,
          color: AppHues.orange,
          label: context.t('sm.upcoming_due'),
          n: upcoming,
          onTap: () => unawaited(_openList(context.t('sm.upcoming_due'),
              'smart.upcoming_due', () => _paths(SmartSort.upcomingDue()))),
        ),
      if (expired > 0)
        _ExtraTile(
          key: 'ss-expired',
          icon: AppIcons.badge,
          color: error,
          label: context.t('sm.expired'),
          n: expired,
          onTap: () => unawaited(_openList(context.t('sm.expired'),
              'smart.expired', () => _paths(SmartSort.expired()))),
        ),
      if (expiring > 0)
        _ExtraTile(
          key: 'ss-expiring-soon',
          icon: AppIcons.eventNote,
          color: AppHues.amber,
          label: context.t('sm.expiring_soon'),
          n: expiring,
          onTap: () => unawaited(_openList(context.t('sm.expiring_soon'),
              'smart.expiring_soon', () => _paths(SmartSort.expiringSoon()))),
        ),
      if (lowConf > 0)
        _ExtraTile(
          key: 'ss-low-conf',
          icon: AppIcons.rule,
          color: AppHues.indigo,
          label: context.t('sm.low_conf'),
          n: lowConf,
          onTap: () => unawaited(_openList(context.t('sm.low_conf'),
              'smart.low_conf', () => _paths(SmartSort.lowConfidence()))),
        ),
      for (final b in SmartTaxonomy.amountOrder)
        if ((amounts[b] ?? 0) > 0)
          _ExtraTile(
            key: 'ss-amount-$b',
            icon: AppIcons.topicInvoice,
            color: AppHues.green,
            label: context.t('sm.amount_title', {'range': context.t('sm.a_$b')}),
            n: amounts[b]!,
            onTap: () => unawaited(_openList(
                context.t('sm.amount_title', {'range': context.t('sm.a_$b')}),
                'smart.amount.$b',
                () => _paths(SmartSort.withAmount(b)))),
          ),
      for (final entry in years.entries.take(4))
        _ExtraTile(
          key: 'ss-year-${entry.key}',
          icon: AppIcons.calendarMonth,
          color: AppHues.teal,
          label: '${entry.key}',
          n: entry.value,
          onTap: () => unawaited(_openList(
              context.t('sm.year_title', {'y': entry.key}),
              'smart.year.${entry.key}',
              () => _paths(SmartSort.withYear(entry.key)))),
        ),
      for (final entry in insts.entries.take(5))
        _ExtraTile(
          key: 'ss-inst-${entry.key}',
          icon: AppIcons.topicBank,
          color: AppHues.blue,
          label: entry.key,
          n: entry.value,
          onTap: () => unawaited(_openList(
              context.t('sm.inst_title', {'name': entry.key}),
              'smart.inst.${entry.key}',
              () => _paths(SmartSort.withInstitution(entry.key)))),
        ),
      if (clutter > 0 || hidden > 0)
        _ExtraTile(
          key: 'ss-clutter',
          icon: AppIcons.cleanEmpty,
          color: AppHues.slate,
          label: context.t('ui.clutter_tile'),
          n: clutter,
          onTap: () => SmartClutterScreen.open(context),
        ),
    ];
  }

  /// Üstteki birleşik özet + eylem kartı: "470 dosya · 19 kategori",
  /// altında belirteç/tasarruf özeti, yanında "Şimdi düzenle" (`ss-run`)
  /// ya da çalışırken canlı ilerleme + "Durdur" (`ss-stop`).
  Widget _statusCard(
    BuildContext context,
    int catCount,
    SmartProgress? prog,
    SmartUsage? usage,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = (prog != null && prog.total > 0)
        ? ((prog.done / prog.total) * 100).round().clamp(0, 100)
        : null;
    return Material(
      key: const ValueKey('ss-status'),
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      // Kullanıcı 2026-11-24: "üst alan çok yer kaplıyor" → simge kutusu ve
      // açıklama paragrafı kalktı; kullanım tek satır alt yazıya indi.
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            Gap.md, Gap.sm, Gap.sm, Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('sm.status',
                            {'n': SmartSort.records.length, 'c': catCount}),
                        key: const ValueKey('ss-strip'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (usage != null && usage.requests > 0)
                            Flexible(
                              child: Text(
                                context.t('sm.usage', {
                                  'n': usage.requests,
                                  't': usage.tokensPerFile,
                                  'q': usage.questionsPerFile,
                                }),
                                key: const ValueKey('ss-usage'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            )
                          else
                            Flexible(
                              child: Text(
                                context.t('sm.status_sub'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          if (usage != null && usage.reused > 0) ...[
                            const SizedBox(width: Gap.xs),
                            Text(
                              context.t('sm.reused_n', {'n': usage.reused}),
                              key: const ValueKey('ss-reused'),
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppHues.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (prog == null) ...[
                  const SizedBox(width: Gap.sm),
                  FilledButton.icon(
                    key: const ValueKey('ss-run'),
                    onPressed: _run,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(AppIcons.ai, size: 17),
                    label: Text(context.t('sm.run')),
                  ),
                ],
              ],
            ),
            if (prog != null) ...[
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: prog.total == 0 ? null : prog.done / prog.total,
                ),
              ),
              const SizedBox(height: Gap.xs),
              Row(
                children: [
                  Expanded(
                    // Kalıcı tur geçici bir engelde bekliyorsa (dakikalık
                    // sınır / ağ) "durdu" sanılmasın: neden + "kendiliğinden
                    // sürecek" yazar (2026-11-25).
                    child: ValueListenableBuilder<int?>(
                      valueListenable: SmartSort.waitingUntilMs,
                      builder: (context, waitUntil, _) {
                        final base = pct != null
                            ? '${context.t('sm.progress', {'done': prog.done, 'total': prog.total})} · %$pct'
                            : context.t('sm.progress',
                                {'done': prog.done, 'total': prog.total});
                        return Text(
                          waitUntil == null
                              ? base
                              : '$base · ${context.t('sm.waiting')}',
                          key: const ValueKey('ss-progress-text'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('ss-stop'),
                    onPressed: SmartSort.cancelRun,
                    icon: const Icon(AppIcons.stop, size: 16),
                    label: Text(context.t('sm.stop')),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSettingsSheet() => showAppSheet<void>(
        context,
        title: context.t('sm.settings'),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SmartSortSettings(learning: true),
            if (SmartSort.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: TextButton.icon(
                  key: const ValueKey('ss-disable'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    unawaited(SmartSort.setSettings(enabled: false));
                  },
                  icon: const Icon(AppIcons.close),
                  label: Text(ctx.t('sm.disable')),
                ),
              ),
          ],
        ),
      );

  Future<void> _rename(String cat) async {
    final def = SmartCatStyle.defaultLabel(context, cat);
    final v = await showAppPrompt(
      context,
      title: context.t('smo.rename_title'),
      label: context.t('smo.rename_label', {'name': def}),
      initial: SmartCatStyle.label(context, cat),
      maxLength: 32,
    );
    if (v == null) return;
    final name = v.trim();
    await SmartFolderPrefs.setName(cat, name == def ? null : name);
    SmartSort.invalidateLabels();
  }

  Future<void> _tileMenu(String cat, List<String> cats) async {
    AppHaptics.selection();
    final i = cats.indexOf(cat);
    final pick = await showAppSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(SmartCatStyle.icon(cat), color: SmartCatStyle.color(cat)),
            title: Text(SmartCatStyle.label(ctx, cat)),
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('smo-rename'),
            leading: const Icon(AppIcons.rename),
            title: Text(ctx.t('smo.rename')),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          if (i > 0)
            ListTile(
              leading: const Icon(AppIcons.arrowUp),
              title: Text(ctx.t('smo.move_first')),
              onTap: () => Navigator.pop(ctx, 'first'),
            ),
          ListTile(
            key: const ValueKey('smo-rule'),
            leading: const Icon(AppIcons.move),
            title: Text(SmartFolderPrefs.ruleOf(cat) == null
                ? ctx.t('smo.rule')
                : ctx.t('smo.rule_off')),
            subtitle: SmartFolderPrefs.ruleOf(cat) == null
                ? null
                : Text(ctx.t('smo.rule_on',
                    {'folder': p.basename(SmartFolderPrefs.ruleOf(cat)!)})),
            onTap: () => Navigator.pop(ctx, 'rule'),
          ),
          ListTile(
            leading: const Icon(AppIcons.dragIndicator),
            title: Text(ctx.t('smo.arrange')),
            onTap: () => Navigator.pop(ctx, 'arrange'),
          ),
          if (SmartFolderPrefs.nameOf(cat) != null)
            ListTile(
              leading: const Icon(AppIcons.reset),
              title: Text(ctx.t('smo.default_name',
                  {'name': SmartCatStyle.defaultLabel(ctx, cat)})),
              onTap: () => Navigator.pop(ctx, 'default'),
            ),
        ]),
      ),
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case 'rename':
        await _rename(cat);
      case 'first':
        await SmartFolderPrefs.setOrder([cat, ...cats.where((c) => c != cat)]);
      case 'arrange':
        await _arrange(cats);
      case 'rule':
        await _rule(cat);
      case 'default':
        await SmartFolderPrefs.setName(cat, null);
        SmartSort.invalidateLabels();
    }
  }

  Future<void> _arrange(List<String> cats) => showAppSheet<void>(
        context,
        scrollable: false,
        builder: (_) => _ArrangeSheet(cats: cats, onRename: _rename),
      );

  @override
  Widget build(BuildContext context) {
    if (!Edition.current.has(Feature.smartFolders)) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(context.t('sm.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.pro,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: Gap.md),
                  Text(
                    context.t('pro.smart_locked_title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    context.t('pro.smart_locked_sub'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  FilledButton.icon(
                    onPressed: () =>
                        showProSheet(context, Feature.smartFolders),
                    icon: const Icon(AppIcons.pro),
                    label: Text(context.t('ab.pro_unlock')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('sm.title')),
        actions: [
          IconButton(
            key: const ValueKey('ss-settings-btn'),
            tooltip: context.t('sm.settings'),
            icon: const Icon(AppIcons.settings),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: Listenable.merge([
                SmartSort.revision,
                SmartSort.progress,
                SmartSort.lastUsage,
                SmartFolderPrefs.revision,
                SmartLearn.revision,
                SmartUserCats.revision,
                SmartQuota.revision,
                SmartFolders.instance,
              ]),
              builder: (context, _) => SmartSort.enabled
                  ? Listener(
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: _pointerUp,
                      child: _main(context),
                    )
                  : _intro(context),
            ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w > 960 ? (w - 960) / 2 + Gap.lg : Gap.lg;
    return ListView(
      padding: withNavInset(
          context, EdgeInsets.symmetric(horizontal: hPad, vertical: Gap.lg)),
      children: [
        Icon(AppIcons.ai, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: Gap.md),
        Text(context.t('sm.intro_title'),
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: Gap.sm),
        Text(context.t('sm.intro_body'), style: theme.textTheme.bodyLarge),
        const SizedBox(height: Gap.md),
        for (final k in ['sm.point_place', 'sm.point_name', 'sm.point_clean'])
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(AppIcons.check,
                  size: AppIcons.small, color: theme.colorScheme.primary),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(context.t(k))),
            ]),
          ),
        const SizedBox(height: Gap.md),
        const Card(margin: EdgeInsets.zero, child: SmartSortSettings()),
        const SizedBox(height: Gap.md),
        Text(context.t('sm.privacy'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (!context.select<AppState, bool>((s) => s.hasApiKey)) ...[
          const SizedBox(height: Gap.md),
          _localReadyBanner(context),
        ],
        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          key: const ValueKey('ss-enable'),
          onPressed: _enable,
          icon: const Icon(AppIcons.ai),
          label: Text(context.t('sm.enable')),
        ),
      ],
    );
  }

  Widget _localReadyBanner(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      key: const ValueKey('ss-local-ready'),
      margin: EdgeInsets.zero,
      color: cs.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.offlineBolt, color: cs.primary, size: 20),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('sm.local_ready_title'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    context.t('sm.local_ready_sub'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _main(BuildContext context) {
    final theme = Theme.of(context);
    final counts = SmartSort.counts();
    // "Diğer" de klasör (U4, B15 m.4): Akıllı düzenin yerleştiremediği
    // dosyalar eskiden hiçbir yerde görünmüyordu — kullanıcı onları bulup
    // "Kategori yanlış mı?" ile öğretebilsin. Varsayılan sırada en sonda.
    final allCats = SmartFolderPrefs.arrange([
      for (final c in SmartTaxonomy.categoryIds)
        if ((counts[c] ?? 0) > 0) c
    ]);
    final availableGroups = <SmartCatGroup>{
      for (final c in allCats) ?SmartTaxonomy.groupOf(c),
    };
    final activeGroup =
        _group != SmartCatGroup.all && !availableGroups.contains(_group)
            ? SmartCatGroup.all
            : _group;
    final visibleCats = activeGroup == SmartCatGroup.all
        ? allCats
        : [
            for (final c in allCats)
              if (SmartTaxonomy.groupOf(c) == activeGroup) c,
          ];
    final cols = SmartFolderPrefs.columns;
    final clutter = SmartSort.clutter().length;
    final hidden = SmartSort.hiddenRecords().length;
    final prog = SmartSort.progress.value;
    final usage = SmartSort.lastUsage.value;
    final filters = _filterChips(context, clutter, hidden);
    final query = _query.trim();
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w > 960 ? (w - 960) / 2 + Gap.md : Gap.md;
    return ListView(
      padding: withNavInset(
          context, EdgeInsets.fromLTRB(hPad, Gap.sm, hPad, Gap.md)),
      children: [
        // En üstte tek net özet + eylem kartı.
        _statusCard(context, allCats.length, prog, usage),
        if (!context.select<AppState, bool>((s) => s.hasApiKey) &&
            SmartSort.records.isEmpty) ...[
          const SizedBox(height: Gap.sm),
          _localReadyBanner(context),
        ],
        if (SmartSort.records.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          _searchBar(context),
        ],
        if (query.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          ..._searchResults(context, query),
        ] else ...[
          // Başlıksız şerit: ayrı "Akıllı süzgeçler" başlığı dikey yer yiyordu.
          if (filters.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            _smartFiltersStrip(context, filters),
          ],
          SectionHeader(context.t('sm.folders'),
              trailing: allCats.isEmpty ? null : _layoutMenu(context, allCats),
              padding: const EdgeInsets.only(top: Gap.sm, bottom: 0)),
          if (allCats.isEmpty && filters.isEmpty)
            Text(context.t('sm.folders_empty'))
          else if (allCats.isNotEmpty) ...[
            if (availableGroups.length >= 2) ...[
              _groupFilterBar(context, allCats, counts, activeGroup),
              const SizedBox(height: Gap.sm),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(context.t('smo.hint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            // Sütun değişimi TEK ADIMDA (kasma listesi m.1/6: ızgarada opaklık
            // ya da boy animasyonu yok).
            GridView.builder(
              key: const ValueKey('ss-grid'),
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: _tileExtent(context, cols),
                crossAxisSpacing: Gap.sm,
                mainAxisSpacing: Gap.sm,
              ),
              itemCount: visibleCats.length,
              itemBuilder: (context, i) => RepaintBoundary(
                child: _catTile(context, visibleCats[i],
                    counts[visibleCats[i]] ?? 0, cols, allCats),
              ),
            ),
          ],
          // Kayıtlı akıllı aramalar (U4): eskiden yalnız Akıllı dosya
          // asistanının menüsündeydi; asıl yeri akıllı klasörlerin yanı.
          const SizedBox(height: Gap.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('ss-searches'),
              leading: const Icon(AppIcons.savedSearch),
              title: Text(context.t('smart.title')),
              subtitle: Text(SmartFolders.instance.folders.isEmpty
                  ? context.t('smart.entry_sub')
                  : context.t('smart.entry_n',
                      {'n': SmartFolders.instance.folders.length})),
              trailing: const Icon(AppIcons.chevron),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SmartFoldersScreen())),
            ),
          ),
          ..._userCats(context),
        ],
      ],
    );
  }

  Widget _searchBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      key: const ValueKey('ss-search'),
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.t('sm.search_hint'),
        prefixIcon: const Icon(AppIcons.search, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('ss-search-clear'),
                tooltip: context.t('common.close'),
                icon: const Icon(AppIcons.close, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  List<Widget> _searchResults(BuildContext context, String query) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hits = SmartSort.matches(query, limit: 80);
    if (hits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xl),
          child: Column(
            children: [
              Icon(AppIcons.searchOff, size: 36, color: cs.onSurfaceVariant),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('sm.search_empty'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.xs),
        child: Text(
          context.t('sm.search_results', {'n': hits.length}),
          style: theme.textTheme.labelMedium
              ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ),
      for (final r in hits) _searchHitRow(context, r),
    ];
  }

  Widget _searchHitRow(BuildContext context, SmartRecord r) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = SmartCatStyle.color(r.cat);
    final alias = SmartSort.aliasOf(r.path, AppStrings.of(context));
    final fileName = p.basename(r.path);
    final catLabel = SmartCatStyle.label(context, r.cat);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_openSearchHit(r)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.sm, vertical: Gap.sm),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(SmartCatStyle.icon(r.cat), color: color, size: 20),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (alias.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Gap.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    catLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smartFiltersStrip(BuildContext context, List<_ExtraTile> items) {
    final theme = Theme.of(context);
    return SizedBox(
      key: const ValueKey('ss-filters'),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
        itemBuilder: (context, i) {
          final t = items[i];
          return Material(
            color: t.color.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: t.color.withValues(alpha: 0.28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey(t.key),
              onTap: t.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 16, color: t.color),
                    const SizedBox(width: 6),
                    Text(
                      t.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${t.n}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: t.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _groupFilterBar(
    BuildContext context,
    List<String> allCats,
    Map<String, int> counts,
    SmartCatGroup active,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groups = <SmartCatGroup>[
      SmartCatGroup.all,
      for (final g in SmartCatGroup.values)
        if (g != SmartCatGroup.all &&
            allCats.any((c) => SmartTaxonomy.groupOf(c) == g))
          g,
    ];
    String labelOf(SmartCatGroup g) => switch (g) {
          SmartCatGroup.all => context.t('sm.group_all'),
          SmartCatGroup.finance => context.t('sm.group_finance'),
          SmartCatGroup.docs => context.t('sm.group_docs'),
          SmartCatGroup.images => context.t('sm.group_images'),
          SmartCatGroup.media => context.t('sm.group_media'),
        };
    int countOf(SmartCatGroup g) => g == SmartCatGroup.all
        ? allCats.length
        : allCats.where((c) => SmartTaxonomy.groupOf(c) == g).length;
    return SizedBox(
      key: const ValueKey('ss-groups'),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
        itemBuilder: (context, i) {
          final g = groups[i];
          final selected = g == active;
          return Material(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
              side: BorderSide(
                color: selected
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('ss-group-${g.name}'),
              onTap: () => setState(() => _group = g),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelOf(g),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${countOf(g)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Kullanıcı kategorileri (PLAN §1.1 m.3) ─────────────────────────────
  /// "Kategorilerim": kullanıcının tarif ettiği kategoriler, sayı, henüz
  /// sorulmamış dosya sayısı, geriye dönük uygulama ilerlemesi.
  List<Widget> _userCats(BuildContext context) {
    final theme = Theme.of(context);
    final cats = SmartUserCats.all;
    final counts = SmartSort.userCounts();
    return [
      SectionHeader(context.t('suc.section'),
          trailing: IconButton(
            key: const ValueKey('ss-uc-add'),
            tooltip: context.t('suc.add'),
            icon: const Icon(AppIcons.add),
            onPressed: () => unawaited(_addUserCat()),
          ),
          padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs)),
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(context.t(cats.isEmpty ? 'suc.empty' : 'suc.sub'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
      for (final c in cats)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.xs),
          child: _userCatTile(context, c, counts[c.id] ?? 0),
        ),
    ];
  }

  Widget _userCatTile(BuildContext context, SmartUserCat c, int n) {
    final color = SmartCatStyle.userColor(c.color);
    final pending = SmartUserCats.pendingCount(c.id);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        ListTile(
          key: ValueKey('ss-uc-${c.id}'),
          leading: Icon(SmartCatStyle.userIcon(c.icon), color: color),
          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              pending > 0
                  ? context.t('suc.pending', {'n': n, 'p': pending})
                  : context.t('suc.count', {'n': n}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          onTap: () => unawaited(_openCat(c.id)),
          trailing: PopupMenuButton<String>(
            key: ValueKey('ss-uc-menu-${c.id}'),
            tooltip: context.t('suc.menu'),
            icon: const Icon(AppIcons.more),
            onSelected: (v) => unawaited(switch (v) {
              'apply' => _applyUserCat(c.id),
              'edit' => _editUserCat(c),
              _ => _deleteUserCat(c),
            }),
            itemBuilder: (ctx) => [
              if (pending > 0)
                PopupMenuItem(
                  value: 'apply',
                  child: Text(ctx.t('suc.apply', {'n': pending})),
                ),
              PopupMenuItem(value: 'edit', child: Text(ctx.t('suc.edit'))),
              PopupMenuItem(
                  value: 'delete', child: Text(ctx.t('common.delete'))),
            ],
          ),
        ),
        // Yalnız ilerleme satırı dinler (ekranın tamamı her dosyada çizilmez).
        ValueListenableBuilder<SmartApplyProgress?>(
          valueListenable: SmartUserCats.applying,
          builder: (context, prog, _) => prog == null || prog.id != c.id
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      Gap.md, 0, Gap.xs, Gap.sm),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(
                              value: prog.total == 0
                                  ? null
                                  : prog.done / prog.total),
                          const SizedBox(height: Gap.xs),
                          Text(
                              context.t('suc.applying',
                                  {'done': prog.done, 'total': prog.total}),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('ss-uc-stop'),
                      onPressed: SmartUserCats.stopApply,
                      child: Text(context.t('suc.stop')),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }

  Future<void> _addUserCat() async {
    if (SmartUserCats.isFull) {
      showSnack(
          context, context.t('suc.full', {'n': SmartUserCats.maxCats}));
      return;
    }
    final cat = await SmartUserCatScreen.open(context);
    if (cat == null || !mounted) return;
    // Kaydedildi: eski dosyalara yalnız bu soru (durdurulabilir).
    if (SmartUserCats.pendingCount(cat.id) > 0) await _applyUserCat(cat.id);
  }

  Future<void> _editUserCat(SmartUserCat c) async {
    final next = await SmartUserCatScreen.open(context, initial: c);
    if (next == null || !mounted) return;
    // Soru değiştiyse eski yanıtlar silindi; yeniden uygulanır.
    if (next.about != c.about || next.name != c.name) {
      await _applyUserCat(next.id);
    }
  }

  Future<void> _deleteUserCat(SmartUserCat c) async {
    final ok = await showAppConfirm(context,
        message: context.t('suc.delete_q', {'name': c.name}),
        destructive: true);
    if (!ok) return;
    await SmartUserCats.remove(c.id);
  }

  Future<void> _applyUserCat(String id) async {
    if (!await ensureAiKey(context) || !mounted) return;
    final state = context.read<AppState>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await SmartUserCats.apply(id,
        credentials: state.aiCredentials, scope: state.aiScopeRules);
    showSnackOn(
        messenger,
        r.stoppedBy != null
            ? s.t('suc.stopped', {'reason': r.stoppedBy})
            : s.t('suc.applied', {'n': r.asked, 'm': r.matched}));
  }

  /// Sütun menüsü: 2/3/4 sütun, sırala ve adlandır, varsayılana dön.
  Widget _layoutMenu(BuildContext context, List<String> cats) =>
      PopupMenuButton<Object>(
        key: const ValueKey('ss-layout'),
        tooltip: context.t('smo.layout'),
        icon: const Icon(AppIcons.viewComfy),
        onSelected: (v) {
          if (v is int) {
            unawaited(SmartFolderPrefs.setColumns(v));
          } else if (v == 'arrange') {
            unawaited(_arrange(cats));
          } else if (v == 'reset') {
            unawaited(SmartFolderPrefs.reset()
                .then((_) => SmartSort.invalidateLabels()));
          }
        },
        itemBuilder: (ctx) => [
          for (var n = SmartFolderPrefs.minColumns;
              n <= SmartFolderPrefs.maxColumns;
              n++)
            CheckedPopupMenuItem(
              value: n,
              checked: SmartFolderPrefs.columns == n,
              child: Text(ctx.t('smo.cols', {'n': n})),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'arrange',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.dragIndicator),
              title: Text(ctx.t('smo.arrange')),
            ),
          ),
          if (SmartFolderPrefs.hasCustomNames ||
              SmartFolderPrefs.order.isNotEmpty)
            PopupMenuItem(
              value: 'reset',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.reset),
                title: Text(ctx.t('smo.reset')),
              ),
            ),
        ],
      );

  /// Hücre yüksekliği yazı ölçeğiyle büyür (büyük yazıda taşma yok).
  static double _tileExtent(BuildContext context, int cols) {
    final sc = MediaQuery.textScalerOf(context);
    return switch (cols) {
      2 => math.max(88.0, 24 + sc.scale(14) * 1.3 * 2 + sc.scale(12) * 1.4),
      3 => math.max(
          112.0, 28 + 34 + 6 + sc.scale(12) * 1.3 * 2 + sc.scale(11) * 1.4),
      _ => math.max(
          104.0, 26 + 30 + 6 + sc.scale(11) * 1.3 * 2 + sc.scale(11) * 1.4),
    };
  }

  Widget _catTile(
      BuildContext context, String cat, int n, int cols, List<String> cats) {
    return _tile(
      context,
      _ExtraTile(
        key: 'ss-cat-$cat',
        icon: SmartCatStyle.icon(cat),
        color: SmartCatStyle.color(cat),
        label: SmartCatStyle.label(context, cat),
        n: n,
        onTap: () => unawaited(_openCat(cat)),
        onLongPress: () => unawaited(_tileMenu(cat, cats)),
      ),
      cols,
    );
  }

  Widget _tile(BuildContext context, _ExtraTile t, int cols) {
    final theme = Theme.of(context);
    final color = t.color;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
    );
    if (cols >= 3) {
      final small = cols >= 4;
      final iconBox = small ? 30.0 : 34.0;
      return Material(
        color: color.withValues(alpha: 0.10),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(t.key),
          onTap: t.onTap,
          onLongPress: t.onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.xs, vertical: Gap.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.icon, color: color, size: small ? 18 : 20),
                ),
                const SizedBox(height: 5),
                Text(t.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (small
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.18)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${t.n}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: color.withValues(alpha: 0.10),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(t.key),
        onTap: t.onTap,
        onLongPress: t.onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(t.icon, color: color, size: 22),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${t.n}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Akıllı klasör ızgarasındaki bir kutu (kategori ya da özel süzgeç).
class _ExtraTile {
  final String key;
  final IconData icon;
  final Color color;
  final String label;
  final int n;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ExtraTile({
    required this.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.n,
    required this.onTap,
    this.onLongPress,
  });
}

/// Akıllı klasör listesinin başındaki öğrenme ipucu.
class _FixHint extends StatelessWidget {
  const _FixHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xs),
      child: Row(children: [
        Icon(AppIcons.rule,
            size: AppIcons.small, color: theme.colorScheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(context.t('smf.list_hint'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

/// Alt türü, belge yılı ya da kurumu olan akıllı klasörün etkileşimli süzgeçli
/// görünümü: tek dokunuşla alt tür (`Tahlil sonucu`, `Reçete`, `Bordro`…),
/// belge yılı (`2026`, `2025`…) ve kurum/bankaya göre anında daraltır.
class _SmartCatDetailScreen extends StatefulWidget {
  final String cat;
  final String title;
  final List<FsEntry> initialFiles;

  const _SmartCatDetailScreen({
    required this.cat,
    required this.title,
    required this.initialFiles,
  });

  @override
  State<_SmartCatDetailScreen> createState() => _SmartCatDetailScreenState();
}

class _SmartCatDetailScreenState extends State<_SmartCatDetailScreen> {
  String? _sub;
  int? _year;
  String? _inst;

  List<FsEntry> _filterEntries(List<FsEntry> all) {
    if (_sub == null && _year == null && _inst == null) return all;
    final allowed = SmartSort.pathsOfFiltered(
      widget.cat,
      sub: _sub,
      year: _year,
      institution: _inst,
    ).toSet();
    return [
      for (final e in all)
        if (allowed.contains(e.path)) e,
    ];
  }

  Widget _chip({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
    int? count,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.20)
          : cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(99),
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.65)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : cs.onSurfaceVariant,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? accent
                        : cs.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final subs = SmartSort.subtypeCounts(widget.cat);
    final years = SmartSort.yearsOf(widget.cat);
    final insts = SmartSort.institutionsOf(widget.cat);
    final accent = SmartCatStyle.color(widget.cat);
    final hasAny = _sub != null || _year != null || _inst != null;

    final chips = <Widget>[
      if (hasAny)
        _chip(
          key: const ValueKey('ss-sub-clear'),
          label: context.t('sm.sub_all'),
          selected: false,
          accent: accent,
          onTap: () => setState(() {
            _sub = null;
            _year = null;
            _inst = null;
          }),
        ),
      for (final e in subs.entries)
        _chip(
          key: ValueKey('ss-sub-${e.key}'),
          label: context.t('sm.s_${e.key}'),
          count: e.value,
          selected: _sub == e.key,
          accent: accent,
          onTap: () => setState(() => _sub = _sub == e.key ? null : e.key),
        ),
      if (years.length > 1)
        for (final y in years)
          _chip(
            key: ValueKey('ss-cat-year-$y'),
            label: '$y',
            selected: _year == y,
            accent: AppHues.teal,
            onTap: () => setState(() => _year = _year == y ? null : y),
          ),
      for (final inst in insts)
        _chip(
          key: ValueKey('ss-cat-inst-$inst'),
          label: inst,
          selected: _inst == inst,
          accent: AppHues.blue,
          onTap: () => setState(() => _inst = _inst == inst ? null : inst),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
              itemBuilder: (_, i) => Center(child: chips[i]),
            ),
          ),
        const _FixHint(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterKey = '${_sub ?? ''}|${_year ?? ''}|${_inst ?? ''}';
    return CategoryScreen(
      key: ValueKey('smart-cat-${widget.cat}-$filterKey'),
      title: widget.title,
      files: _filterEntries(widget.initialFiles),
      loadAll: () => FsScan.statPaths(SmartSort.pathsOfFiltered(
        widget.cat,
        sub: _sub,
        year: _year,
        institution: _inst,
      )),
      replaceOnLoad: true,
      memoryId: 'smart.${widget.cat}',
      header: _buildHeader(context),
    );
  }
}

/// "Sırala ve adlandır": tutamaçtan sürükle, kalemle yeniden adlandır.
class _ArrangeSheet extends StatefulWidget {
  final List<String> cats;
  final Future<void> Function(String cat) onRename;

  const _ArrangeSheet({required this.cats, required this.onRename});

  @override
  State<_ArrangeSheet> createState() => _ArrangeSheetState();
}

class _ArrangeSheetState extends State<_ArrangeSheet> {
  late final List<String> _order = [...widget.cats];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(context.t('smo.arrange')),
              subtitle: Text(context.t('smo.arrange_sub')),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListenableBuilder(
                listenable: SmartFolderPrefs.revision,
                builder: (context, _) => ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorderStart: (_) => AppHaptics.longPress(),
                  itemCount: _order.length,
                  // onReorderItem: [to] çıkarılan öğeye göre düzeltilmiş gelir.
                  onReorderItem: (from, to) {
                    if (from == to) return;
                    setState(() {
                      final c = _order.removeAt(from);
                      _order.insert(to, c);
                    });
                    unawaited(SmartFolderPrefs.setOrder(List.of(_order)));
                  },
                  itemBuilder: (context, i) {
                    final cat = _order[i];
                    return ListTile(
                      key: ValueKey('smo-row-$cat'),
                      leading: Icon(SmartCatStyle.icon(cat),
                          color: SmartCatStyle.color(cat)),
                      title: Text(SmartCatStyle.label(context, cat),
                          style: theme.textTheme.bodyLarge),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: context.t('smo.rename'),
                          icon: const Icon(AppIcons.rename),
                          onPressed: () => unawaited(widget.onRename(cat)),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(Gap.sm),
                            child: Icon(AppIcons.dragHandle),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Akıllı düzen ayarları** — kamera, kendiliğinden düzen, arka plan
/// (şarj + Wi-Fi), yalnız Wi-Fi, günlük sınır ve ([learning]) öğrenilenler.
/// Akıllı düzen ekranı ile Ayarlar > Yapay zekâ AYNI denetimi kullanır (U4,
/// 2026-11-20: ayarlar eskiden yalnız bu ekrandaydı). Değerler durağan
/// depolarda; değişiklikleri kendisi dinler (const kurulabilir).
class SmartSortSettings extends StatelessWidget {
  final bool learning;
  const SmartSortSettings({super.key, this.learning = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge(
            [SmartSort.revision, SmartQuota.revision, SmartLearn.revision]),
        builder: (context, _) => _tiles(context),
      );

  Widget _tiles(BuildContext context) => Column(children: [
        if (learning)
          ListTile(
            key: const ValueKey('ss-learn'),
            leading: const Icon(AppIcons.insights),
            title: Text(context.t('smo.learn_title')),
            subtitle: Text(SmartLearn.count == 0
                ? context.t('smo.learn_none')
                : context.t('smo.learn_n', {'n': SmartLearn.count})),
            trailing: SmartLearn.count == 0
                ? null
                : TextButton(
                    onPressed: () => unawaited(_forgetLearning(context)),
                    child: Text(context.t('smo.learn_reset')),
                  ),
          ),
        // Kamera anahtarı "Neyi düzenleyelim?" ekranındaki Yerler'e taşındı
        // (2026-11-22, Aşama 1).
        ListTile(
          key: const ValueKey('ss-scope'),
          leading: const Icon(AppIcons.tune),
          title: Text(context.t('scp.title')),
          subtitle: Text(context.t('scp.tile_sub', {
            'g': SmartGroup.values.where(SmartScopePick.groupOn).length,
            'gt': SmartGroup.values.length,
            's': SmartSource.values.where(SmartScopePick.sourceOn).length,
            'st': SmartSource.values.length,
          })),
          trailing: const Icon(AppIcons.chevron),
          onTap: () async {
            await SmartScopePick.read();
            if (!context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const SmartScopeScreen()));
          },
        ),
        SwitchListTile(
          key: const ValueKey('ss-auto'),
          secondary: const Icon(AppIcons.moveToInbox),
          title: Text(context.t('sm.auto')),
          subtitle: Text(context.t('sm.auto_sub')),
          value: SmartSort.autoNew,
          onChanged: (v) => unawaited(SmartSort.setSettings(auto: v)),
        ),
        // 2026-11-19: yalnız şarjda + Wi-Fi'de, uygulama kapalıyken de.
        if (SmartSort.autoNew)
          SwitchListTile(
            key: const ValueKey('ss-bg'),
            secondary: const Icon(AppIcons.batteryChargingFull),
            title: Text(context.t('sm.bg')),
            subtitle: Text(context.t('sm.bg_sub', {'n': SmartSortBg.limit})),
            value: SmartSort.chargeWifiOnly,
            onChanged: (v) => unawaited(SmartSort.setSettings(bg: v)),
          ),
        SwitchListTile(
          key: const ValueKey('ss-wifi'),
          secondary: const Icon(AppIcons.wifi),
          title: Text(context.t('sm.wifi')),
          subtitle: Text(context.t('sm.wifi_sub')),
          value: SmartQuota.wifiOnly,
          onChanged: (v) => unawaited(SmartQuota.setSettings(wifiOnly: v)),
        ),
        ListTile(
          key: const ValueKey('ss-cap'),
          leading: const Icon(AppIcons.dataUsage),
          title: Text(SmartQuota.isUnlimited
              ? context.t('sm.cap_none')
              : context.t('sm.cap', {'cap': SmartQuota.dailyCap})),
          subtitle: Text(SmartQuota.isUnlimited
              ? context.t('sm.cap_sub_none', {
                  'n': SmartQuota.usedToday,
                  'l': SmartQuota.limitedToday,
                })
              : context.t('sm.cap_sub', {
                  'n': SmartQuota.usedToday,
                  'cap': SmartQuota.dailyCap,
                  'l': SmartQuota.limitedToday,
                })),
          onTap: () => unawaited(_pickCap(context)),
        ),
      ]);

  Future<void> _forgetLearning(BuildContext context) async {
    final ok = await showAppConfirm(
      context,
      title: context.t('smo.learn_reset_title'),
      message: context.t('smo.learn_reset_body'),
      confirmLabel: context.t('smo.learn_reset'),
      destructive: true,
    );
    if (ok) await SmartLearn.forgetAll();
  }

  /// Günlük istek sınırı seçimi (son günlerin sayımıyla: sınırın doğru
  /// olup olmadığı görülsün).
  Future<void> _pickCap(BuildContext context) async {
    final days = SmartQuota.days;
    final cap = await showAppSheet<int>(
      context,
      title: context.t('sm.cap_title'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in SmartQuota.capChoices)
            ListTile(
              key: ValueKey('ss-cap-$c'),
              title: Text(c >= SmartQuota.unlimited
                  ? ctx.t('sm.cap_unlimited')
                  : ctx.t('sm.cap_n', {'n': c})),
              trailing: c == SmartQuota.dailyCap
                  ? const Icon(AppIcons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, c),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Text(
              [
                for (final d in days)
                  ctx.t('sm.cap_day',
                      {'d': d.day, 'n': d.requests, 'l': d.limited}),
              ].join('\n'),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
    if (cap != null) await SmartQuota.setSettings(cap: cap);
  }
}
