import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/snack.dart';
import '../../services/file_service.dart' show FileService;
import '../../services/fm/entry_opener.dart';
import '../../services/sample_docs.dart';
import '../../widgets/permission_gate.dart';

/// **İlk açılış rehberi** (Faz 11a / N1, 2026-10-22).
///
/// **Faz 40 / 4 (2026-11-05):** üç sayfa artık uygulamanın üç işi —
/// okuyucu · düzenleyici · tara — ve son sayfada "örnek belgeler". Aşağıdaki
/// ilkeler aynen geçerli (izin satırları ilgili işin sayfasında).
///
/// Eski düzen: (1) uygulama ne yapar, (2) izinler — her biri NEDEN istenir,
/// vermezse ne olur (izin burada İSTENMEZ; yalnız durumu ve "aç" yolu
/// gösterilir, asıl istek ilgili özelliğe ilk dokunuşta), (3) gizlilik ve
/// AI veri açıklaması. Bir kez gösterilir (`onboarding_done`); seçici
/// kipinde hiç gösterilmez (başka uygulama bizden dosya isterken araya
/// rehber sokmak o akışı keser).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const prefKey = 'onboarding_done';

  /// Bunlardan biri kayıtlıysa uygulama daha önce KULLANILMIŞTIR.
  static const existingUserKeys = [
    'recent_files',
    'fm_bookmarks',
    'fm_recent_destinations',
    'gemini_api_key',
    'gemini_api_keys',
    'theme_mode',
    'app_skin',
    'fm_layout',
    'fm_sort',
    'dash_sections',
    'nav_tabs',
  ];

  /// Rehber daha önce bitirildi mi? (Okunamazsa "evet" — rehber yüzünden
  /// uygulama açılmaz hâle gelmesin.)
  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool(prefKey);
      if (done != null) return done;
      // **Güncelleyen kullanıcı** rehberi görmez: daha önce dosya açmış,
      // ayar değiştirmiş ya da anahtar girmiş biri yeni değil (göç).
      final existing = existingUserKeys.any(prefs.containsKey);
      if (existing) await prefs.setBool(prefKey, true);
      return existing;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
    } catch (_) {
      // Yazılamadı: rehber bir sonraki açılışta yeniden görünür (zararsız).
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  GateStatus? _allFiles;

  @override
  void initState() {
    super.initState();
    PermissionGate.probe.status(AppPermission.allFiles).then((s) {
      if (mounted) setState(() => _allFiles = s);
    });
  }

  /// "Bir dosya aç": sistem seçicisi (izin yok); seçilirse rehber biter ve
  /// dosya açılır.
  Future<void> _openFile() async {
    final nav = Navigator.of(context);
    final path = await FileService().pickFilePath();
    if (path == null || !mounted) return;
    await OnboardingScreen.markDone();
    nav.pop();
    if (nav.mounted) await EntryOpener.open(nav.context, path);
  }

  /// "Tüm dosyaları yönet": tek sistem penceresi; ret → izinsiz yol önerisi.
  Future<void> _manageAll() async {
    final s = await PermissionGate.probe.request(AppPermission.allFiles);
    if (!mounted) return;
    setState(() => _allFiles = s);
    if (s == GateStatus.granted) {
      _next();
    } else {
      showStorageDeniedHint(context, _openFile);
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_index >= _count - 1) {
      _finish();
    } else {
      Motion.toPage(context, _pages, _index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // Geri tuşu rehberi bitirmiş sayılır (bir daha gösterilmez).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('onboarding-skip'),
                  onPressed: _finish,
                  child: Text(context.t('onb.skip')),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  // Faz 40 / 4: üç ekran = uygulamanın üç işi — okuyucu ·
                  // düzenleyici · tara. İzin satırları ilgili işin yanında,
                  // gizlilik notu son sayfada (Faz 11a açıklaması korunur).
                  children: [
                    _Page(
                      icon: AppIcons.menuBook,
                      title: context.t('onb.reader_title'),
                      body: context.t('onb.reader_body'),
                      // Play yorum çalışması (2026-11-08): okumak için
                      // gelen kullanıcı hiç izin görmez — iki yol, izin
                      // yalnız ikincisinde ve gerekçesiyle.
                      extra: [
                        _Choice(
                          key: const ValueKey('onb-open-file'),
                          icon: AppIcons.insertDriveFile,
                          title: context.t('onb.choice_open'),
                          body: context.t('onb.choice_open_sub'),
                          onTap: _openFile,
                        ),
                        const SizedBox(height: Gap.sm),
                        _Choice(
                          key: const ValueKey('onb-manage-all'),
                          icon: AppIcons.folderSpecial,
                          title: context.t('onb.choice_manage'),
                          body: _allFiles == GateStatus.granted
                              ? context.t('perm.granted')
                              : context.t('fm.permission_body'),
                          onTap: _manageAll,
                        ),
                      ],
                    ),
                    _Page(
                      icon: AppIcons.edit,
                      title: context.t('onb.editor_title'),
                      body: context.t('onb.editor_body'),
                      extra: const [
                        PermissionStatusRow(
                            permission: AppPermission.notifications),
                      ],
                    ),
                    _Page(
                      icon: AppIcons.scanHere,
                      title: context.t('onb.scan_title'),
                      body: context.t('onb.scan_body'),
                      extra: [
                        const PermissionStatusRow(
                            permission: AppPermission.camera),
                        const SizedBox(height: Gap.md),
                        _SamplesButton(),
                        const SizedBox(height: Gap.md),
                        Text(
                          context.t('onb.privacy_note'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: Motion.of(context, Motion.short),
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        width: i == _index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('onboarding-next'),
                      onPressed: _next,
                      child: Text(context.t(
                          _index == _count - 1 ? 'onb.start' : 'onb.next')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Örnek belgeleri ekle" — yalnız basılınca dört küçük dosya yazar
/// ([SampleDocs]); bitince onay simgesi ve klasör adı.
class _SamplesButton extends StatefulWidget {
  @override
  State<_SamplesButton> createState() => _SamplesButtonState();
}

class _SamplesButtonState extends State<_SamplesButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    final strings = AppStrings.of(context);
    var ok = true;
    try {
      await SampleDocs.create(strings);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    if (!ok) showSnack(context, context.t('onb.samples_failed'));
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('onboarding-samples'),
      onPressed: _busy || _done ? null : _add,
      icon: Icon(_done ? AppIcons.checkCircle : AppIcons.addFile),
      label: Text(_done
          ? context.t('onb.samples_done',
              {'folder': context.t(SampleDocs.folderKey)})
          : context.t('onb.samples')),
    );
  }
}

/// İlk sayfadaki iki büyük seçenekten biri.
class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: Gap.xs),
                    Text(body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> extra;

  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Gap.lg),
          Icon(icon, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: Gap.lg),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: Gap.md),
          Text(body,
              textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            ...extra,
          ],
        ],
      ),
    );
  }
}

/// Ana ekranı sarar: rehber bitirilmediyse ilk karede üstüne açar.
class OnboardingGate extends StatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (await OnboardingScreen.isDone() || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const OnboardingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
