import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/sd_union.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/motion.dart';
import '../settings/settings_group.dart';
import '../settings/settings_widgets.dart';
import '../../core/safe_insets.dart';

/// **SD kartla birleşik depolama** ayar ve durum ekranı (2026-10-17).
///
/// İş Android'de koşar (`ci/SdUnion.kt`); bu ekran ayarı kurar, "şu an ne
/// taşınır" önizlemesini gösterir, son çalışmanın özetini ve süren işin
/// ilerlemesini okur. Ayar her değişimde hemen kaydedilir — "Kaydet" düğmesi
/// yok, çünkü ayarlardaki öteki anahtarlar da öyle çalışıyor.
class SdUnionScreen extends StatefulWidget {
  const SdUnionScreen({super.key});

  @override
  State<SdUnionScreen> createState() => _SdUnionScreenState();
}

class _SdUnionScreenState extends State<SdUnionScreen> {
  SdUnionSettings? _settings;
  SdUnionStatus _status = const SdUnionStatus();
  SdUnionPreview? _preview;
  bool _previewing = false;
  int _previewToken = 0;
  Timer? _poll;
  List<StorageVolume> _cards = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await FmEnv.ensureInit();
    var settings = await SdUnion.load();
    final cards = SdUnion.sdCards();
    // Kart seçilmemişse (ya da kayıtlı kart artık takılı değilse ve yerine
    // tek bir kart varsa) takılı kart önerilir. Ayar AÇIK değilken
    // önermek zararsız; açıkken kullanıcının seçimine dokunulmaz.
    if (cards.isNotEmpty &&
        !cards.any((c) => c.path == settings.sdPath) &&
        !settings.enabled) {
      settings = settings.copyWith(sdPath: cards.first.path);
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _cards = cards;
    });
    await _refreshStatus();
    _refreshPreview();
  }

  Future<void> _refreshStatus() async {
    final status = await SdUnion.status();
    if (!mounted) return;
    final wasRunning = _status.running;
    setState(() => _status = status);
    // Süren iş varken ekran canlı: ilerleme ve sonuç kendiliğinden gelsin.
    if (status.running) {
      _poll ??= Timer.periodic(
          const Duration(milliseconds: 1500), (_) => _refreshStatus());
    } else {
      _poll?.cancel();
      _poll = null;
      if (wasRunning) {
        // Dosyalar yer değiştirdi: listeler ve önizleme tazelensin.
        FsEvents.changed();
        _refreshPreview();
      }
    }
  }

  void _refreshPreview() {
    final settings = _settings;
    if (settings == null) return;
    final token = ++_previewToken;
    setState(() => _previewing = true);
    SdUnion.preview(settings).then((preview) {
      if (!mounted || token != _previewToken) return;
      setState(() {
        _preview = preview;
        _previewing = false;
      });
    }).catchError((Object _) {
      if (mounted && token == _previewToken) {
        setState(() => _previewing = false);
      }
    });
  }

  Future<void> _update(SdUnionSettings next, {bool preview = false}) async {
    setState(() => _settings = next);
    await SdUnion.save(next, strings: AppStrings.of(context));
    if (preview) _refreshPreview();
    await _refreshStatus();
  }

  Future<void> _runNow() async {
    final settings = _settings;
    if (settings == null) return;
    // "Şimdi taşı" kayıtlı ayarla çalışır; önce son hâl Android'e gitsin.
    await SdUnion.save(settings, strings: AppStrings.of(context));
    final ok = await SdUnion.runNow(settings: settings);
    if (!mounted) return;
    if (!ok) {
      showSnack(context, context.t('sdu.run_failed'));
      return;
    }
    showSnack(context, context.t('sdu.run_started'));
    // İş sistem kuyruğundan birkaç yüz ms içinde başlar.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refreshStatus();
    _poll ??= Timer.periodic(
        const Duration(milliseconds: 1500), (_) => _refreshStatus());
  }

  Future<void> _stop() async {
    await SdUnion.stop();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sdu.title'))),
      body: settings == null
          ? const FmListSkeleton()
          : !SdUnion.supported
              ? FmEmptyState(
                  icon: AppIcons.sdCard,
                  title: context.t('sdu.android_only'),
                )
              : _cards.isEmpty && settings.sdPath.isEmpty
                  ? FmEmptyState(
                      icon: AppIcons.sdCardAlert,
                      title: context.t('sdu.no_card'),
                      hint: context.t('sdu.no_card_hint'),
                    )
                  : _body(settings),
    );
  }

  Widget _body(SdUnionSettings settings) {
    final cardPresent = _cards.any((c) => c.path == settings.sdPath);
    return ListView(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      children: [
        _hero(settings),
        if (!cardPresent && settings.sdPath.isNotEmpty)
          _warning(AppIcons.sdCardAlert, context.t('sdu.card_missing')),
        if (_status.lastError == 'sd_readonly')
          _warning(AppIcons.lock, context.t('sdu.err_readonly')),
        SettingsGroup(
          children: [
            SettingSwitch(
              icon: AppIcons.batteryChargingFull,
              title: context.t('sdu.enable'),
              subtitle: context.t('sdu.enable_sub'),
              value: settings.enabled,
              onChanged: settings.sdPath.isEmpty || settings.folders.isEmpty
                  ? null
                  : (v) => _update(settings.copyWith(enabled: v)),
            ),
          ],
        ),
        _statusCard(settings),
        SettingsGroup(
          title: context.t('sdu.sec_target'),
          children: [
            RadioGroup<String>(
              groupValue: settings.sdPath,
              onChanged: (v) {
                if (v != null) _update(settings.copyWith(sdPath: v));
              },
              child: Column(children: [
                for (final card in _cards)
                  RadioListTile<String>(
                    value: card.path,
                    secondary: const Icon(AppIcons.sdCard),
                    title: Text(card.displayLabel(context.t)),
                    subtitle: Text(context.t('sdu.card_free', {
                      'free': FsPaths.humanSize(card.freeBytes),
                      'total': FsPaths.humanCapacity(card.capacityBytes),
                    })),
                  ),
              ]),
            ),
            _modeTile(settings),
          ],
        ),
        SettingsGroup(
          title: context.t('sdu.sec_what'),
          children: [
            _foldersTile(settings),
            _ageTile(settings),
            _previewTile(settings),
          ],
        ),
        SettingsGroup(
          children: [
            SettingSwitch(
              icon: AppIcons.notificationsNone,
              title: context.t('sdu.notify'),
              value: settings.notify,
              onChanged: (v) => _update(settings.copyWith(notify: v)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
          child: Text(
            context.t('sdu.rules'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Paper.faint(context)),
          ),
        ),
      ],
    );
  }

  Widget _hero(SdUnionSettings settings) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: PopIn(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer,
                scheme.tertiaryContainer.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Radii.card + 4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(AppIcons.sdCard,
                          size: 28, color: scheme.primary),
                      PositionedDirectional(
                        end: 8,
                        bottom: 8,
                        child: Icon(AppIcons.bolt,
                            size: 18, color: scheme.tertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('sdu.hero_title'),
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: Gap.xs),
                      Text(context.t('sdu.hero_body'),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.85),
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _warning(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.onErrorContainer),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(text,
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(SdUnionSettings settings) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _status;
    final lines = <String>[];
    if (status.running) {
      lines.add(context.t('sdu.running', {
        'n': status.lastMoved,
        'size': FsPaths.humanSize(status.lastBytes),
      }));
    } else if (status.lastRun != null) {
      final when = status.lastRun!;
      final loc = MaterialLocalizations.of(context);
      final stamp =
          '${loc.formatMediumDate(when)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(when))}';
      lines.add(context.t('sdu.last_run', {
        'when': stamp,
        'n': status.lastMoved,
        'size': FsPaths.humanSize(status.lastBytes),
      }));
      final error = switch (status.lastError) {
        'sd_missing' => 'sdu.err_sd_missing',
        'sd_full' => 'sdu.err_sd_full',
        'stopped' => 'sdu.err_stopped',
        _ => null, // sd_readonly üstte uyarı kartı olarak
      };
      if (error != null) lines.add(context.t(error));
      if (status.lastFailed > 0) {
        lines.add(context.t('sdu.failed_n', {'n': status.lastFailed}));
      }
      if (status.totalMoved > 0) {
        lines.add(context.t('sdu.total', {
          'n': status.totalMoved,
          'size': FsPaths.humanSize(status.totalBytes),
        }));
      }
    } else {
      lines.add(context.t('sdu.never'));
    }
    final chip = status.charging
        ? (AppIcons.batteryChargingFull, context.t('sdu.charging'))
        : (AppIcons.batteryStd, context.t('sdu.not_charging'));
    return SettingsGroup(
      title: context.t('sdu.sec_status'),
      children: [
        Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(chip.$1, size: 18, color: scheme.primary),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      settings.enabled
                          ? '${chip.$2} · ${context.t(status.charging ? 'sdu.will_run_now' : 'sdu.will_run_charging')}'
                          : chip.$2,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              if (status.running) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: Gap.sm),
              ],
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: Gap.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: status.running
                    ? OutlinedButton.icon(
                        onPressed: _stop,
                        icon: const Icon(AppIcons.stop),
                        label: Text(context.t('common.stop')),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: settings.sdPath.isEmpty ||
                                settings.folders.isEmpty ||
                                !_cards.any((c) => c.path == settings.sdPath)
                            ? null
                            : _runNow,
                        icon: const Icon(AppIcons.move),
                        label: Text(context.t(settings.mode == SdUnionMode.move
                            ? 'sdu.run_now_move'
                            : 'sdu.run_now_copy')),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeTile(SdUnionSettings settings) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SdUnionMode>(
                segments: [
                  ButtonSegment(
                    value: SdUnionMode.move,
                    icon: const Icon(AppIcons.move),
                    label: Text(context.t('sdu.mode_move')),
                  ),
                  ButtonSegment(
                    value: SdUnionMode.copy,
                    icon: const Icon(AppIcons.copyAll),
                    label: Text(context.t('sdu.mode_copy')),
                  ),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) =>
                    _update(settings.copyWith(mode: s.first)),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              context.t(settings.mode == SdUnionMode.move
                  ? 'sdu.mode_move_sub'
                  : 'sdu.mode_copy_sub'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Paper.faint(context)),
            ),
          ],
        ),
      );

  Widget _foldersTile(SdUnionSettings settings) {
    final primary = FmEnv.primaryRoot;
    // Yalnız ana bellekte VAR olan klasörler (ve daha önce seçilmiş olanlar)
    // sunulur — "Podcasts" klasörü olmayan telefonda boş çip kafa karıştırır.
    final shown = [
      for (final folder in SdUnionSettings.candidateFolders)
        if (settings.folders.contains(folder) ||
            Directory(p.join(primary, folder)).existsSync())
          folder,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
      // Tam genişlik: grup kartının sütunu dar çocukları ORTALIYOR.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('sdu.folders'),
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                for (final folder in shown)
                  FilterChip(
                    // Seçili hâl dolguyla belli; onay işareti simgenin
                    // ÜSTÜNE biniyordu.
                    showCheckmark: false,
                    avatar: Icon(_folderIcon(folder), size: 18),
                    label: Text(_folderLabel(folder)),
                    selected: settings.folders.contains(folder),
                    onSelected: (on) {
                      final next = List.of(settings.folders);
                      on ? next.add(folder) : next.remove(folder);
                      _update(
                        settings.copyWith(
                          folders: next,
                          // Klasörsüz açık kalmasın: iş hiçbir şey yapmazdı.
                          enabled: next.isEmpty ? false : settings.enabled,
                        ),
                        preview: true,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ageTile(SdUnionSettings settings) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('sdu.age'),
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.xs,
                children: [
                  for (final days in SdUnionSettings.ageChoices)
                    ChoiceChip(
                      label: Text(days == 0
                          ? context.t('sdu.age_all')
                          : context.t('sdu.age_days', {'n': days})),
                      selected: settings.minAgeDays == days,
                      onSelected: (_) => _update(
                          settings.copyWith(minAgeDays: days),
                          preview: true),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _previewTile(SdUnionSettings settings) {
    final preview = _preview;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      leading: _previewing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : Icon(AppIcons.insights, color: theme.colorScheme.primary),
      title: Text(
        preview == null
            ? context.t('sdu.preview_wait')
            : context.t(
                settings.mode == SdUnionMode.move
                    ? 'sdu.preview_move'
                    : 'sdu.preview_copy',
                {'n': preview.files, 'size': FsPaths.humanSize(preview.bytes)}),
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(context.t('sdu.preview_sub'),
          style:
              theme.textTheme.bodySmall?.copyWith(color: Paper.faint(context))),
    );
  }

  static IconData _folderIcon(String folder) => switch (folder) {
        'DCIM' => AppIcons.photoCamera,
        'Pictures' => AppIcons.image,
        'Movies' => AppIcons.video,
        'Music' => AppIcons.audio,
        'Download' => AppIcons.download,
        'Documents' => AppIcons.newWord,
        'Recordings' => AppIcons.micNone,
        'Podcasts' => AppIcons.podcasts,
        'Audiobooks' => AppIcons.menuBook,
        _ => AppIcons.folder,
      };

  String _folderLabel(String folder) => switch (folder) {
        'DCIM' => context.t('sdu.f_camera'),
        'Pictures' => context.t('sdu.f_pictures'),
        'Movies' => context.t('sdu.f_movies'),
        'Music' => context.t('sdu.f_music'),
        'Download' => context.t('sdu.f_download'),
        'Documents' => context.t('sdu.f_documents'),
        'Recordings' => context.t('sdu.f_recordings'),
        _ => folder,
      };
}
