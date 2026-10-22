import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../widgets/permission_gate.dart';

/// **İlk açılış rehberi** (Faz 11a / N1, 2026-10-22).
///
/// Üç sayfa: (1) uygulama ne yapar, (2) izinler — her biri NEDEN istenir,
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
                  children: [
                    _Page(
                      icon: AppIcons.folder,
                      title: context.t('onb.p1_title'),
                      body: context.t('onb.p1_body'),
                    ),
                    _Page(
                      icon: AppIcons.lock,
                      title: context.t('onb.p2_title'),
                      body: context.t('onb.p2_body'),
                      extra: [
                        for (final p in const [
                          AppPermission.allFiles,
                          AppPermission.notifications,
                          AppPermission.camera,
                        ])
                          PermissionStatusRow(permission: p),
                      ],
                    ),
                    _Page(
                      icon: AppIcons.ai,
                      title: context.t('onb.p3_title'),
                      body: context.t('onb.p3_body'),
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
