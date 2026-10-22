import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/fm/fm_entry_tiles.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/folder_lock.dart';
import '../../services/fm/hidden_vault.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/secure_vault.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_type_chips.dart';
import 'hidden_files_screen.dart';
import '../../core/user_error.dart';

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

  /// Tür süzgeci (Faz 13; boş = tümü). Ad kasada düz tutulduğu için türü
  /// addan çıkar — içerik çözülmez.
  Set<FmType> _types = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBio();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana geçince kasa kilitlenir.
    if (state == AppLifecycleState.paused) unawaited(SecureVault.instance.lock());
  }

  @override
  void dispose() {
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
    if (appState.fmHasLockPin &&
        !FolderLock.verify(pin, appState.fmLockPinHash)) {
      setState(() => _error = context.t('vault.pin_use_lock'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await SecureVault.instance.create(pin);
    if (!appState.fmHasLockPin) await appState.setFmLockPin(pin);
    _pin.clear();
    _pin2.clear();
    if (_canBio) await _toggleBio(true);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _unlockPin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SecureVault.instance.unlockWithPin(_pin.text);
    if (!mounted) return;
    _pin.clear();
    setState(() {
      _busy = false;
      if (!ok) _error = context.t('vault.wrong_pin');
    });
  }

  Future<void> _unlockBio() async {
    final ok = await NativeExtras.authenticate(
      title: context.t('vault.title'),
      subtitle: context.t('vault.bio_prompt'),
      cancel: context.t('vault.use_pin'),
    );
    if (!ok || !mounted) return;
    final opened = await SecureVault.instance.unlockWithBiometricKey();
    if (!opened && mounted) setState(() => _error = context.t('vault.bio_failed'));
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      final ok = await SecureVault.instance.enableBiometric();
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
              leading: Icon(Icons.delete_forever_rounded,
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
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.t('vault.delete')),
            content: Text(ctx.t('vault.delete_body', {'name': item.name})),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.t('common.cancel'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.t('vault.delete'))),
            ],
          ),
        );
        if (ok == true) await SecureVault.instance.delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Icon(Icons.shield_rounded,
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
            icon: const Icon(Icons.shield_rounded),
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
              icon: const Icon(Icons.fingerprint_rounded),
              label: Text(context.t('vault.unlock_bio')),
            ),
          ],
        ],
      );

  Widget _content(BuildContext context) {
    final all = SecureVault.instance.items;
    final items = _types.isEmpty
        ? all
        : [
            for (final i in all)
              if (_types.contains(FmType.ofName(i.name))) i,
          ];
    final theme = Theme.of(context);
    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 96)),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(AppIcons.vault),
                title: Text(context.t('vault.summary', {'n': all.length})),
                subtitle: Text(context.t('vault.encrypted_note')),
              ),
              if (_canBio)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: Text(context.t('vault.bio_toggle')),
                  value: _bioOn,
                  onChanged: _toggleBio,
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
        const SizedBox(height: Gap.sm),
        FmFilterBar(
          children: FmTypeChips.build(
            context,
            counts: fmTypeCounts(all.map((i) => FmType.ofName(i.name))),
            selected: _types,
            onChanged: (t) => setState(() => _types = t),
          ),
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Text(context.t('vault.empty'),
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
        for (final item in items)
          FmEntryRow(
            // Küçük resim ÇIKARILMAZ (düz içerik yok) — türün simgesi.
            entry: FsEntry(
              path: item.name,
              name: item.name,
              isDir: false,
              sizeBytes: item.size,
              modifiedMs: item.addedMs,
            ),
            thumbnails: false,
            selected: false,
            selecting: false,
            subtitle: '${FsPaths.humanSize(item.size)} · '
                '${FsPaths.humanDate(item.addedMs)}',
            onTap: () => _open(item),
            onMore: () => _itemMenu(item),
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
