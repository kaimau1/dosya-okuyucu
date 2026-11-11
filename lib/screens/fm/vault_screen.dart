import '../../core/secure_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/pin_backoff.dart';
import '../../services/fm/hidden_vault.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/secure_vault.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_category_tile.dart';
import 'hidden_files_screen.dart';
import 'important_screen.dart' show ImportantGalleryTile;
import '../../core/user_error.dart';
import '../../widgets/app_dialog.dart';

/// **Şifreli kasa** ekranı (bkz. [SecureVault]): kurulum → kilit → içerik.
///
/// Ekrandan çıkınca kasa KİLİTLENİR (anahtar bellekten, açılan geçici
/// kopyalar önbellekten silinir) — "açık unutulan kasa" olmasın.
class VaultScreen extends StatefulWidget {
  /// Gezginden "kasaya taşı" akışında kilit açma ekranı olarak kullanılınca
  /// kapanırken KİLİTLEMEZ (taşıma bitince akış kendisi kilitler).
  final bool keepUnlocked;

  const VaultScreen({super.key, this.keepUnlocked = false});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _canBio = false;
  bool _bioOn = false;

  /// Eski (şifresiz) gizli dosya sayısı — kasa açılınca taşıma kartı için.
  int _legacyHidden = 0;

  /// Galeri tür süzgeci (null = tümü). Ad kasada düz tutulduğu için tür
  /// addan çıkar — içerik çözülmez.
  FmCategory? _cat;
  final _galleryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBio();
    unawaited(_loadAutoLock());
    _countLegacy();
  }

  Future<void> _countLegacy() async {
    final n = (await HiddenVault.list()).length;
    if (mounted) setState(() => _legacyHidden = n);
  }

  /// **Tek Kasa göçü** (2026-10-21): eski gizli dosyalar şifrelenip kasaya
  /// taşınır (kopyala → doğrula → sil; bkz. [SecureVault.importHidden]).
  Future<void> _importLegacy() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showFmProgress<FmOpResult>(
      context,
      title: strings.t('vault.adding'),
      name: strings.t('vault.legacy_move'),
      task: (report, isCancelled) => SecureVault.instance
          .importHidden(onProgress: report, isCancelled: isCancelled),
    );
    await _countLegacy();
    showSnackOn(
      messenger,
      result.hasError
          ? result.errors.first
          : strings.t('vault.added_n', {'n': result.succeeded}),
    );
  }

  Future<void> _initBio() async {
    final can = await NativeExtras.canAuthenticate();
    final on = await SecureVault.instance.biometricEnabled;
    if (!mounted) return;
    setState(() {
      _canBio = can;
      _bioOn = on;
    });
    // Kilitliyse ve parmak izi kuruluysa doğrudan sor.
    if (can && on && SecureVault.instance.exists && !SecureVault.instance.unlocked) {
      unawaited(_unlockBio());
    }
  }

  /// G3.5: arka plana geçiş anı ve gecikmeli kilit sayacı.
  DateTime? _pausedAt;
  Timer? _autoLock;
  int _autoLockSecs = 0;

  Future<void> _loadAutoLock() async {
    final secs = await VaultAutoLock.seconds();
    if (mounted) setState(() => _autoLockSecs = secs);
  }

  Future<void> _setAutoLock(int? secs) async {
    if (secs == null) return;
    await VaultAutoLock.setSeconds(secs);
    if (mounted) setState(() => _autoLockSecs = secs);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana geçince kasa kilitlenir — G3.5: ayarlı gecikmeyle
    // (`vault_autolock_secs`, varsayılan 0 = hemen). Dönüşte geçen süreye de
    // bakılır: arka planda sayaç durmuş olsa bile süre dolduysa kilitli kalır.
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      _autoLock?.cancel();
      if (_autoLockSecs <= 0) {
        unawaited(SecureVault.instance.lock());
      } else {
        _autoLock = Timer(Duration(seconds: _autoLockSecs),
            () => unawaited(SecureVault.instance.lock()));
      }
    } else if (state == AppLifecycleState.resumed) {
      _autoLock?.cancel();
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null &&
          VaultAutoLock.expired(at, DateTime.now(), _autoLockSecs)) {
        unawaited(SecureVault.instance.lock());
      }
    }
  }

  @override
  void dispose() {
    _autoLock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    _pin2.dispose();
    if (!widget.keepUnlocked) unawaited(SecureVault.instance.lock());
    super.dispose();
  }

  Future<void> _create() async {
    final pin = _pin.text.trim();
    if (pin.length < 4) {
      setState(() => _error = context.t('vault.pin_short'));
      return;
    }
    if (pin != _pin2.text.trim()) {
      setState(() => _error = context.t('vault.pin_mismatch'));
      return;
    }
    // **Tek PIN** (2026-10-21): kasa, klasör kilidi ve uygulama kilidiyle
    // AYNI PIN'i kullanır. PIN zaten kuruluysa o girilmeli; değilse kasanın
    // PIN'i klasör/uygulama kilidinin de PIN'i olur.
    final appState = context.read<AppState>();
    final strings = AppStrings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    if (appState.fmHasLockPin) {
      final backoff = await PinBackoff.instance();
      final wait = backoff.remaining();
      if (wait > Duration.zero) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = pinWaitText(strings, wait);
          });
        }
        return;
      }
      if (!await appState.verifyLockPin(pin)) {
        await backoff.recordFailure();
        if (mounted) {
          setState(() {
            _busy = false;
            _error = strings.t('vault.pin_use_lock');
          });
        }
        return;
      }
      await backoff.recordSuccess();
    }
    await SecureVault.instance.create(pin);
    if (!appState.fmHasLockPin) await appState.setFmLockPin(pin);
    _pin.clear();
    _pin2.clear();
    if (_canBio) await _toggleBio(true);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unlockPin() async {
    final strings = AppStrings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    // G3.2: kalıcı yanlış deneme beklemesi (uygulama/klasör kilidiyle ortak).
    final backoff = await PinBackoff.instance();
    final wait = backoff.remaining();
    if (wait > Duration.zero) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = pinWaitText(strings, wait);
        });
      }
      return;
    }
    final ok = await SecureVault.instance.unlockWithPin(_pin.text);
    if (ok) {
      await backoff.recordSuccess();
    } else {
      await backoff.recordFailure();
    }
    if (!mounted) return;
    _pin.clear();
    final after = backoff.remaining();
    setState(() {
      _busy = false;
      if (!ok) {
        _error = after > Duration.zero
            ? pinWaitText(strings, after)
            : strings.t('vault.wrong_pin');
      }
    });
    // G3.4 göçü: eski (doğrulamasız anahtarlı) parmak izi kaydı silindi —
    // PIN'le açılınca yeni anahtarla yeniden kur (parmak izi penceresi açılır).
    if (ok && await SecureVault.instance.takeLegacyBiometric() && _canBio) {
      await _toggleBio(true);
    }
  }

  Future<void> _unlockBio() async {
    final status = await SecureVault.instance.unlockWithBiometric(
      title: context.t('vault.title'),
      subtitle: context.t('vault.bio_prompt'),
      cancel: context.t('vault.use_pin'),
    );
    if (!mounted) return;
    if (status == 'invalidated') {
      setState(() {
        _bioOn = false;
        _error = context.t('vault.bio_invalidated');
      });
    } else if (status == 'error') {
      setState(() => _error = context.t('vault.bio_failed'));
    }
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      final ok = await SecureVault.instance.enableBiometric(
        title: context.t('vault.title'),
        subtitle: context.t('vault.bio_prompt'),
        cancel: context.t('common.cancel'),
      );
      if (!ok && mounted) showSnack(context, context.t('vault.bio_failed'));
    } else {
      await SecureVault.instance.disableBiometric();
    }
    final now = await SecureVault.instance.biometricEnabled;
    if (mounted) setState(() => _bioOn = now);
  }

  Future<void> _add() async {
    final paths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const _VaultFilePicker()),
    );
    if (paths == null || paths.isEmpty || !mounted) return;
    await addToVault(context, paths);
  }

  Future<void> _open(VaultItem item) async {
    try {
      final path = await SecureVault.instance.openTemp(item);
      if (mounted) await EntryOpener.open(context, path);
    } catch (e) {
      if (mounted) showSnack(context, context.t('vault.open_failed', {'error': userErrorText(e)}));
    }
  }

  Future<void> _itemMenu(VaultItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.open),
              title: Text(ctx.t('common.open')),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(AppIcons.unlock),
              title: Text(ctx.t('vault.restore')),
              subtitle: Text(ctx.t('vault.restore_sub')),
              onTap: () => Navigator.pop(ctx, 'restore'),
            ),
            ListTile(
              leading: Icon(AppIcons.deleteForever,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(ctx.t('vault.delete')),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _open(item);
      case 'restore':
        try {
          final path = await SecureVault.instance.restore(item);
          if (mounted) showSnack(context, context.t('vault.restored', {'path': path}));
        } catch (e) {
          if (mounted) showSnack(context, context.t('vault.open_failed', {'error': userErrorText(e)}));
        }
      case 'delete':
        final ok = await showAppConfirm(
            context,
            title: context.t('vault.delete'),
            message: context.t('vault.delete_body', {'name': item.name}),
            confirmLabel: context.t('vault.delete'),
            destructive: true,
        );
        if (ok == true) await SecureVault.instance.delete(item);
    }
  }

  @override
  Widget build(BuildContext context) =>
      SecureScreen(child: _secureBody(context));

  Widget _secureBody(BuildContext context) {
    return ListenableBuilder(
      listenable: SecureVault.instance,
      builder: (context, _) {
        final vault = SecureVault.instance;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.t('vault.title')),
            actions: [
              if (vault.unlocked)
                IconButton(
                  tooltip: context.t('vault.lock'),
                  icon: const Icon(AppIcons.lock),
                  onPressed: () => vault.lock(),
                ),
            ],
          ),
          floatingActionButton: vault.unlocked
              ? FloatingActionButton.extended(
                  onPressed: _add,
                  icon: const Icon(AppIcons.add),
                  label: Text(context.t('vault.add')),
                )
              : null,
          body: !vault.exists
              ? _setup(context)
              : vault.unlocked
                  ? _content(context)
                  : _locked(context),
        );
      },
    );
  }

  Widget _hero(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: scheme.primaryContainer, shape: BoxShape.circle),
          child: Icon(AppIcons.shield,
              size: 36, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: Gap.md),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Gap.xs),
        Text(body,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _pinField(TextEditingController c, String label,
          {VoidCallback? onSubmit}) =>
      TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 12,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      );

  Widget _setup(BuildContext context) => ListView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
        children: [
          _hero(context, context.t('vault.setup_title'),
              context.t('vault.setup_body')),
          const SizedBox(height: Gap.sm),
          Text(
            context.t(context.read<AppState>().fmHasLockPin
                ? 'vault.pin_same_existing'
                : 'vault.pin_same_new'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Gap.lg),
          _pinField(_pin, context.t('vault.pin')),
          const SizedBox(height: Gap.sm),
          _pinField(_pin2, context.t('vault.pin_again'), onSubmit: _create),
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(AppIcons.shield),
            label: Text(context.t('vault.create')),
          ),
          const SizedBox(height: Gap.md),
          Text(context.t('vault.pin_warning'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _locked(BuildContext context) => ListView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
        children: [
          _hero(context, context.t('vault.locked_title'),
              context.t('vault.locked_body')),
          const SizedBox(height: Gap.lg),
          _pinField(_pin, context.t('vault.pin'), onSubmit: _unlockPin),
          if (_error != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: Gap.md),
          FilledButton(
            onPressed: _busy ? null : _unlockPin,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.t('vault.unlock')),
          ),
          if (_canBio && _bioOn) ...[
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              onPressed: _unlockBio,
              icon: const Icon(AppIcons.fingerprint),
              label: Text(context.t('vault.unlock_bio')),
            ),
          ],
        ],
      );

  static const _kinds = [
    FmCategory.image,
    FmCategory.video,
    FmCategory.document,
    FmCategory.audio,
    FmCategory.archive,
    FmCategory.apk,
    FmCategory.other,
  ];

  static FmCategory _catOf(VaultItem i) =>
      FsEntry.categoryForExtension(p.extension(i.name).replaceFirst('.', ''));

  /// 2026-11-10 (kullanıcı): kasa içi Önemli Dosyalar'ın aynısı — özet kart,
  /// "Türlere göre" kutuları, süzgeçli galeri. Fark: içerik şifreli; küçük
  /// resim için görsel/PDF geçici düz kopyaya açılır (kilitlenince silinir).
  Widget _content(BuildContext context) {
    final all = [...SecureVault.instance.items]
      ..sort((a, b) => b.addedMs.compareTo(a.addedMs));
    final filter = _cat;
    final items =
        filter == null ? all : [for (final i in all) if (_catOf(i) == filter) i];
    final kinds = {for (final i in all) _catOf(i)};
    final theme = Theme.of(context);
    final total = all.fold<int>(0, (s, i) => s + i.size);
    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 96)),
      children: [
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    Icon(AppIcons.shield,
                        color: theme.colorScheme.primary, size: 32),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.t('count.files', {'n': all.length})} · '
                            '${FsPaths.humanSize(total)}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(context.t('vault.encrypted_note'),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_canBio)
                SwitchListTile(
                  secondary: const Icon(AppIcons.fingerprint),
                  title: Text(context.t('vault.bio_toggle')),
                  value: _bioOn,
                  onChanged: _toggleBio,
                ),
              ListTile(
                leading: const Icon(AppIcons.lock),
                title: Text(context.t('vault.autolock')),
                trailing: DropdownButton<int>(
                  value: VaultAutoLock.choices.contains(_autoLockSecs)
                      ? _autoLockSecs
                      : 0,
                  underline: const SizedBox.shrink(),
                  onChanged: _setAutoLock,
                  items: [
                    for (final secs in VaultAutoLock.choices)
                      DropdownMenuItem(
                        value: secs,
                        child: Text(secs == 0
                            ? context.t('vault.autolock_now')
                            : secs < 60
                                ? context.t('vault.autolock_secs', {'n': secs})
                                : context.t('vault.autolock_mins',
                                    {'n': secs ~/ 60})),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_legacyHidden > 0) ...[
          const SizedBox(height: Gap.sm),
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('vault.legacy_title', {'n': _legacyHidden}),
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: Gap.xs),
                  Text(context.t('vault.legacy_body'),
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: _importLegacy,
                        icon: const Icon(AppIcons.vault),
                        label: Text(context.t('vault.legacy_move')),
                      ),
                      TextButton(
                        onPressed: () async {
                          await HiddenFilesScreen.open(context);
                          await _countLegacy();
                        },
                        child: Text(context.t('vault.legacy_show')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.md),
        Text(context.t('important.by_type'), style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.sm),
        FmCategoryGrid(tiles: _categoryTiles(all)),
        const SizedBox(height: Gap.lg),
        Text(context.t('important.gallery'),
            key: _galleryKey, style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(context.t('important.gallery_all')),
                selected: filter == null,
                onSelected: (_) => setState(() => _cat = null),
              ),
              for (final c in _kinds)
                if (kinds.contains(c))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: Gap.xs),
                    child: ChoiceChip(
                      avatar: Icon(FmColors.iconFor(c), size: 18),
                      label: Text(c.label),
                      selected: filter == c,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Text(context.t('vault.empty'),
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          )
        else if (items.isEmpty)
          Text(context.t('important.gallery_empty'))
        else
          LayoutBuilder(builder: (context, box) {
            final cols = (box.maxWidth / 120).floor().clamp(3, 8);
            final cell = (box.maxWidth - (cols - 1) * 4) / cols;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final item in items)
                  _VaultTile(
                    key: ValueKey(item.id),
                    item: item,
                    size: cell,
                    onTap: () => _open(item),
                    onMore: () => _itemMenu(item),
                  ),
              ],
            );
          }),
      ],
    );
  }

  /// Önemli Dosyalar'daki kutuların aynısı; dokununca galeri o türe süzülür.
  List<FmTileData> _categoryTiles(List<VaultItem> all) {
    final counts = <FmCategory, int>{};
    final bytes = <FmCategory, int>{};
    for (final i in all) {
      final c = _catOf(i);
      counts[c] = (counts[c] ?? 0) + 1;
      bytes[c] = (bytes[c] ?? 0) + i.size;
    }
    return [
      for (final c in _kinds)
        FmTileData(
          icon: FmColors.iconFor(c),
          color: FmColors.forCategory(c),
          label: c.label,
          subtitle: (counts[c] ?? 0) == 0
              ? context.t('fm.none')
              : '${FsPaths.humanSize(bytes[c] ?? 0)} (${counts[c]})',
          onTap: () {
            setState(() => _cat = (counts[c] ?? 0) == 0 ? null : c);
            final target = _galleryKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(target,
                  duration: Motion.medium);
            }
          },
        ),
    ];
  }
}

/// Kasa galerisi hücresi. Görsel ve PDF (≤ [_thumbLimit]) küçük resim için
/// geçici düz kopyaya açılır — açma sırayla (aynı anda tek isolate), kopya
/// kasa kilitlenince silinir. Diğerleri tür simgesi.
class _VaultTile extends StatefulWidget {
  final VaultItem item;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _VaultTile({
    super.key,
    required this.item,
    required this.size,
    required this.onTap,
    required this.onMore,
  });

  @override
  State<_VaultTile> createState() => _VaultTileState();
}

class _VaultTileState extends State<_VaultTile> {
  static const _thumbLimit = 15 * 1024 * 1024;
  static Future<void> _queue = Future.value();

  String? _plain;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final ext = p.extension(item.name).toLowerCase();
    final cat = _VaultScreenState._catOf(item);
    final eligible = item.size <= _thumbLimit &&
        (cat == FmCategory.image || ext == '.pdf');
    if (!eligible) return;
    _queue = _queue.then((_) async {
      if (!mounted || !SecureVault.instance.unlocked) return;
      try {
        final path = await SecureVault.instance.openTemp(item);
        if (mounted) setState(() => _plain = path);
      } catch (_) {
        // En iyi çaba: önizleme açılamazsa tür simgesi kalır; dokununca
        // açma hatası kullanıcıya zaten söylenir.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Stack(
      children: [
        ImportantGalleryTile(
          entry: FsEntry(
            path: _plain ?? item.name,
            name: item.name,
            isDir: false,
            sizeBytes: item.size,
            modifiedMs: item.addedMs,
          ),
          size: widget.size,
          thumbnails: _plain != null,
          onTap: widget.onTap,
          onLongPress: widget.onMore,
        ),
        PositionedDirectional(
          top: 4,
          end: 4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.lock,
                size: 14, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

/// Dosyaları kasaya taşır (kasa açık olmalı; değilse kasa ekranı açılır).
/// Gezgindeki "Şifreli kasaya taşı" eylemi de burayı çağırır.
Future<bool> addToVault(BuildContext context, List<String> paths) async {
  final vault = SecureVault.instance;
  final wasLocked = !vault.unlocked;
  if (wasLocked) {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const _VaultGate()));
    if (!vault.unlocked || !context.mounted) return false;
  }
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await showFmProgress<FmOpResult>(
    context,
    title: strings.t('vault.adding'),
    name: strings.t('vault.add'),
    task: (report, isCancelled) =>
        vault.add(paths, onProgress: report, isCancelled: isCancelled),
  );
  showSnackOn(
    messenger,
    result.hasError
        ? result.errors.first
        : strings.t('vault.added_n', {'n': result.succeeded}),
  );
  // Gezginden açılan kilit iş bitince kapanır.
  if (wasLocked) await vault.lock();
  return result.succeeded > 0;
}

/// Gezginden kasaya taşırken kilidi açtıran ara ekran: kilit açılınca
/// kendiliğinden kapanır (kasa ekranı dispose'ta kilitlediği için ayrı).
class _VaultGate extends StatefulWidget {
  const _VaultGate();

  @override
  State<_VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<_VaultGate> {
  @override
  void initState() {
    super.initState();
    SecureVault.instance.addListener(_check);
  }

  void _check() {
    if (SecureVault.instance.unlocked && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    SecureVault.instance.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const _GateBody();
}

class _GateBody extends StatelessWidget {
  const _GateBody();

  @override
  Widget build(BuildContext context) => const VaultScreen(keepUnlocked: true);
}

/// Kasaya eklenecek dosyaları seçtiren basit gezgin: klasöre gir, dosyaları
/// işaretle, "Kasaya taşı". (Sistem seçicisi Android'de önbellek KOPYASI
/// veriyor — aslını silemezdik, dosya kasaya girdiği hâlde açıkta kalırdı.)
class _VaultFilePicker extends StatefulWidget {
  const _VaultFilePicker();

  @override
  State<_VaultFilePicker> createState() => _VaultFilePickerState();
}

class _VaultFilePickerState extends State<_VaultFilePicker> {
  late String _dir = FmEnv.primaryRoot;
  List<FsEntry> _entries = const [];
  final Set<String> _picked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<FsEntry> list;
    try {
      list = (await FsScan.list(_dir))
          .where((e) => !e.name.startsWith('.'))
          .toList()
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    } catch (_) {
      list = const [];
    }
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  void _go(String dir) {
    _dir = dir;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final atRoot = p.equals(_dir, FmEnv.primaryRoot);
    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !atRoot) _go(p.dirname(_dir));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('vault.pick_title')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  atRoot ? context.t('fm.internal_storage') : p.basename(_dir),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: _picked.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => Navigator.pop(context, _picked.toList()),
                icon: const Icon(AppIcons.vault),
                label: Text(context.t('vault.move_n', {'n': _picked.length})),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: withNavInset(context, const EdgeInsets.only(bottom: 96)),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  if (e.isDir) {
                    return ListTile(
                      leading: FmEntryIcon(entry: e, size: 40),
                      title: Text(e.name),
                      trailing: const Icon(AppIcons.chevron),
                      onTap: () => _go(e.path),
                    );
                  }
                  final on = _picked.contains(e.path);
                  return CheckboxListTile(
                    value: on,
                    secondary: FmEntryIcon(entry: e, size: 40),
                    title: Text(e.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(FsPaths.humanSize(e.sizeBytes)),
                    onChanged: (v) => setState(() =>
                        v == true ? _picked.add(e.path) : _picked.remove(e.path)),
                  );
                },
              ),
      ),
    );
  }
}
