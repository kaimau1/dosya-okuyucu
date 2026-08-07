import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/l10n/app_language.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../services/gemini_service.dart';
import 'fm/fm_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKey;
  bool _obscure = true;

  /// Ayar araması (bölüm düzeyinde süzme).
  bool _searching = false;
  String _query = '';

  /// Anahtar geçersiz/ağ hatası/henüz çekilmediyse gösterilen yedek liste.
  static const _fallbackModels = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  /// API'den çekilen modeller (anahtara özgü — plan/bölgeye göre değişebilir).
  List<String>? _fetchedModels;
  bool _loadingModels = false;
  String? _modelsError;

  /// Anahtar geçerli ama hiç model dönmedi (hata metninden ayrı tutulur —
  /// çevirisi build'de yapılıyor, bkz. `build`).
  bool _noModels = false;
  Timer? _debounce;

  /// Son çekilen anahtar — aynı anahtar için gereksiz tekrar çekmeyi önler.
  String? _fetchedForKey;

  @override
  void initState() {
    super.initState();
    final key = context.read<AppState>().apiKey;
    _apiKey = TextEditingController(text: key);
    if (key.trim().isNotEmpty) _fetchModels(key);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onApiKeyChanged(String value) {
    context.read<AppState>().setApiKey(value);
    // Kullanıcı yazarken her tuşta ağ isteği atmamak için 600ms debounce.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) _fetchModels(value);
    });
  }

  /// Bu anahtarla kullanılabilir modelleri Gemini'den çeker. Anahtar
  /// geçersizse veya ağ hatası olursa yedek statik listeye sessizce düşülür
  /// (kullanıcı yine de bir model seçip devam edebilsin).
  Future<void> _fetchModels(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty || key == _fetchedForKey) return;
    setState(() {
      _loadingModels = true;
      _modelsError = null;
      _noModels = false;
    });
    try {
      final models = await GeminiService.listModels(key);
      if (!mounted) return;
      setState(() {
        _fetchedModels = models.isEmpty ? null : models;
        _fetchedForKey = key;
        _loadingModels = false;
        _noModels = models.isEmpty;
      });
      // Kaydedilmiş model bu anahtarda mevcut değilse (ör. ilk kurulum,
      // ya da eski seçim artık desteklenmiyor) listenin en iyisine geç.
      if (models.isNotEmpty && !models.contains(context.read<AppState>().model)) {
        context.read<AppState>().setModel(models.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _modelsError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Hata metni build'de çevriliyor: `setState` içinde üretilseydi dil
    // değişince ekranda ESKİ dilde asılı kalırdı.
    final modelsError = _noModels
        ? context.t('settings.model_none')
        : _modelsError;
    final models = _fetchedModels ?? _fallbackModels;
    final model = models.contains(appState.model) ? appState.model : models.first;

    // Bölüm bazlı arama: 7 bölüm × ~20 satır, aramasız bulunmuyordu. Süzme
    // BÖLÜM düzeyinde — satır düzeyi her satıra ayrı anahtar kelime listesi
    // yazmayı gerektirirdi ve bakımı ilk eklenen ayarda bozulurdu.
    final q = _query.trim().toLowerCase();
    bool shows(String titleKey) =>
        q.isEmpty || context.t(titleKey).toLowerCase().contains(q);

    // Sıra MANTIKLI (2026-08-07 kullanıcı: *"ayarlar kısmı eskidi, görsel ve
    // mantıksal olarak düzenlenmeli"*): önce "kimim" (hesap), sonra her açılışta
    // görünen şeyler (arayüz: tema + dil), sonra yeteneği açan ayar (yapay
    // zekâ) ve onun eki (hafıza), sonra dosya yöneticisi, en sonda hakkında.
    // Eskiden yapay zekâ ile dil arasında bir bağ yokken yan yanaydı ve dil,
    // temadan ayrı bir bölümdeydi.
    final sections = <Widget>[
      if (shows('settings.account')) const _AccountSection(),
      if (shows('settings.appearance') || shows('settings.language'))
        _interfaceSection(appState),
      if (shows('settings.ai_section'))
        _aiSection(appState, models, model, modelsError),
      if (shows('settings.memory')) _memorySection(appState),
      if (shows('settings.fm_section')) const _FileManagerSection(),
      if (shows('settings.about')) const _AboutSection(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings.title')),
        actions: [
          IconButton(
            tooltip: context.t('set.search_hint'),
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
        ],
        bottom: !_searching
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: context.t('set.search_hint'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
              ),
      ),
      body: sections.isEmpty
          ? Center(child: Text(context.t('set.no_match')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: sections,
            ),
    );
  }

  /// Arayüz: tema + dil TEK grupta.
  ///
  /// İkisi de "uygulama bana nasıl görünsün" sorusunun cevabı; ayrı iki bölüm
  /// olmaları kullanıcıyı dili ararken tema başlığının altına baktırıyordu.
  Widget _interfaceSection(AppState appState) => SettingsGroup(
        icon: Icons.palette_outlined,
        title: context.t('settings.appearance'),
        subtitle: context.t('settings.appearance_sub'),
        children: [
          _fieldLabel(context.t('settings.theme')),
          const SizedBox(height: Gap.sm),
          // Yatayda kaydırılabilir: üç etiket dar ekranda/büyük yazı tipinde
          // taşıyordu.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(context.t('settings.theme_system'))),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(context.t('settings.theme_light'))),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(context.t('settings.theme_dark'))),
              ],
              selected: {appState.themeMode},
              onSelectionChanged: (s) => appState.setThemeMode(s.first),
            ),
          ),
          const Divider(height: Gap.lg * 1.5),
          _fieldLabel(context.t('settings.language')),
          const SizedBox(height: Gap.sm),
          const _LanguageSection(),
        ],
      );

  /// Grup içi alan etiketi ("Tema", "Dil"): başlık değil, alanın adı.
  Widget _fieldLabel(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _memorySection(AppState appState) => SettingsGroup(
        icon: Icons.bookmark_outline,
        title: context.t('settings.memory'),
        subtitle: context.t('settings.memory_sub'),
        count: appState.memory.isEmpty ? null : '${appState.memory.length}',
        children: [
          if (appState.memory.isEmpty)
            Text(context.t('settings.memory_empty'),
                style: Theme.of(context).textTheme.bodySmall)
          else
            // Grup zaten bir kart: iç içe kart "kutu içinde kutu" oluyordu.
            // Notlar ince ayraçlı düz satırlar.
            ...appState.memory.asMap().entries.map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: context.t('common.delete'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => appState.removeMemory(e.key),
                    ),
                  ),
                ),
        ],
      );

  Widget _aiSection(
    AppState appState,
    List<String> models,
    String model,
    String? modelsError,
  ) {
    return SettingsGroup(
      icon: Icons.auto_awesome_outlined,
      title: context.t('settings.ai_section'),
      subtitle: context.t('settings.ai_sub'),
      children: [
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: context.t('settings.api_key'),
              hintText: 'AIza...',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: _onApiKeyChanged,
          ),
          const SizedBox(height: 6),
          Text(
            context.t('settings.api_key_note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // **Doğrulama satırı**: bilgi zaten `_fetchModels`ta vardı ama
          // aşağıda model listesinin altına gömülüydü — "anahtarım çalışıyor
          // mu" sorusu anahtarın hemen altında cevaplanmalı.
          if (appState.hasApiKey) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _fetchedModels != null
                      ? Icons.check_circle_outline
                      : (modelsError != null
                          ? Icons.error_outline
                          : Icons.hourglass_empty),
                  size: 16,
                  color: _fetchedModels != null
                      ? Paper.success(context)
                      : (modelsError != null
                          ? Theme.of(context).colorScheme.error
                          : Paper.faint(context)),
                ),
                const SizedBox(width: Gap.xs),
                Flexible(
                  child: Text(
                    _fetchedModels != null
                        ? context.t('set.key_valid',
                            {'n': _fetchedModels!.length})
                        : (modelsError != null
                            ? context.t('set.key_invalid')
                            : context.t('settings.model_refresh')),
                    style: TextStyle(fontSize: 12, color: Paper.faint(context)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: model,
                  decoration: InputDecoration(
                    labelText: context.t(_fetchedModels != null
                        ? 'settings.model_fetched'
                        : 'settings.model_default'),
                  ),
                  items: models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => v == null ? null : appState.setModel(v),
                ),
              ),
              const SizedBox(width: 4),
              if (_loadingModels)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: context.t('settings.model_refresh'),
                  icon: const Icon(Icons.refresh),
                  onPressed: appState.hasApiKey
                      ? () {
                          _fetchedForKey = null; // zorla yeniden çek
                          _fetchModels(appState.apiKey);
                        }
                      : null,
                ),
            ],
          ),
          if (modelsError != null) ...[
            const SizedBox(height: 4),
            Text(
              context.t('settings.model_error', {'error': modelsError}),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ],
      ],
    );
  }
}

/// Arayüz dili seçimi.
///
/// Diller **kendi dillerinde** yazılır (Türkçe / English / العربية): dilini
/// bulmaya çalışan kullanıcı, o an anlamadığı bir dilde yazılmış listeyi
/// okuyamaz. "Sistem" seçeneği ise seçili dilde yazılır — o, dilin adı değil
/// bir davranış.
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dikey dört radyo ekranın yarısını yiyordu → tek satır segment.
        // Yatayda kaydırılabilir: Arapça etiket + "Sistem" dar ekranda taşar.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<AppLanguage>(
            showSelectedIcon: false,
            segments: [
              for (final lang in AppLanguage.values)
                ButtonSegment(
                  value: lang,
                  label: Text(lang == AppLanguage.system
                      ? context.t('settings.language_system')
                      : lang.nativeLabel),
                ),
            ],
            selected: {appState.language},
            onSelectionChanged: (s) => appState.setLanguage(s.first),
          ),
        ),
        const SizedBox(height: 4),
        Text(context.t('settings.language_note'),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection();
  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await action();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.firebaseAvailable) {
      return SettingsGroup(
        icon: Icons.phone_android_outlined,
        title: context.t('settings.account'),
        subtitle: context.t('settings.account_sub'),
        children: [
          Text(context.t('settings.account_local')),
          const SizedBox(height: 6),
          Text(
            context.t('settings.account_local_note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    if (appState.signedIn) {
      return SettingsGroup(
        icon: Icons.cloud_done_outlined,
        title: context.t('settings.account'),
        subtitle: context.t('settings.sync_active'),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
                appState.userEmail ?? context.t('settings.signed_in')),
            subtitle: Text(context.t('settings.sync_active')),
            trailing: TextButton(
              onPressed: _busy ? null : () => _run(() async {
                await appState.signOut();
                return null;
              }),
              child: Text(context.t('settings.sign_out')),
            ),
          ),
        ],
      );
    }

    return SettingsGroup(
      icon: Icons.account_circle_outlined,
      title: context.t('settings.account'),
      subtitle: context.t('settings.account_sub'),
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration:
              InputDecoration(labelText: context.t('settings.email')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: true,
          decoration:
              InputDecoration(labelText: context.t('settings.password')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() =>
                        appState.signInWithEmail(_email.text, _password.text)),
                child: Text(context.t('settings.sign_in')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => appState.registerWithEmail(
                        _email.text, _password.text)),
                child: Text(context.t('settings.register')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              _busy ? null : () => _run(() => appState.signInWithGoogle()),
          icon: const Icon(Icons.login),
          label: Text(context.t('settings.google_sign_in')),
        ),
      ],
    );
  }
}

/// Dosya yöneticisi ayarlarına köprü.
///
/// O ekran yalnız gezgin panosundan açılabiliyordu; "ayarlar" diye buraya
/// gelen kullanıcı küçük resim/gizli dosya/çöp ayarlarını hiç bulamıyordu.
class _FileManagerSection extends StatelessWidget {
  const _FileManagerSection();

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      icon: Icons.folder_outlined,
      title: context.t('settings.fm_section'),
      subtitle: context.t('settings.fm_sub'),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('settings.fm_open')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FmSettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      icon: Icons.info_outline,
      title: context.t('settings.about'),
      subtitle: context.t('settings.about_sub'),
      children: [
        Text(context.t('settings.about_body'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // LGPL v3 ATIF YÜKÜMLÜLÜĞÜ: uygulama FFmpeg kütüphanelerini
        // dağıtıyor; lisans atfın kullanıcıya erişilebilir olmasını istiyor.
        // Ayrıntı ve kaynak bağlantıları depo kökündeki LICENSES.md'de.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.balance_outlined),
          title: Text(context.t('settings.oss')),
          subtitle: Text(context.t('settings.oss_sub')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showOpenSourceLicenses(context),
        ),
      ],
    );
  }
}

/// Ayarlar grubunun kabı: **simge + başlık + tek satır açıklama** taşıyan bir
/// kart.
///
/// KÖK NEDEN (2026-08-07 kullanıcı: *"ayarlar kısmı eskidi, görsel ve mantıksal
/// olarak düzenlenmeli"*): bölümler sayfa zemininde başlıksız-kutusuz duran
/// gevşek bileşen yığınlarıydı; nerede bittiği, hangi ayarın hangi başlığa ait
/// olduğu ancak boşluktan tahmin ediliyordu. Simge tanımayı hızlandırır,
/// açıklama da "bu bölüm ne işe yarar" sorusunu başlıkta cevaplar.
class SettingsGroup extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Başlığın altındaki tek satırlık "bu bölüm ne yapar" açıklaması.
  final String? subtitle;

  /// Başlığın sağındaki sayaç (ör. hafıza notu sayısı).
  final String? count;

  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                              fontSize: 12, color: Paper.faint(context)),
                        ),
                    ],
                  ),
                ),
                if (count != null)
                  Text(count!,
                      style: TextStyle(
                          fontSize: 12, color: Paper.faint(context))),
              ],
            ),
            const Divider(height: Gap.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Açık kaynak bileşen ve lisans bilgisi.
///
/// **Niye bir ekran gerekiyor:** uygulama FFmpeg kütüphanelerini (LGPL v3)
/// dağıtıyor ve lisans, atfın ve kaynak kodun nereden alınacağının kullanıcıya
/// ulaşmasını gerektiriyor. Depodaki `LICENSES.md` tek başına yetmez — uygulamayı
/// mağazadan kuran kullanıcı depoyu görmez.
///
/// GPL'li kodlayıcıların (x264/x265) bilinçli olarak DAĞITILMADIĞI da burada
/// yazılı: "neden bazı videolar mpeg4 çıkıyor" sorusunun dürüst cevabı bu.
Future<void> showOpenSourceLicenses(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('settings.oss')),
        content: const SingleChildScrollView(
          child: Text(
            'FFmpeg 8.1.2 — GNU Lesser General Public License v3.0 (LGPL v3)\n'
            'Video boyut düşürme, çözünürlük ve kare sayısı değiştirme '
            'işlemlerinde kullanılır.\n\n'
            'Kaynak kodu:\n'
            '• https://ffmpeg.org/download.html\n'
            '• https://github.com/arthenica/ffmpeg-kit\n\n'
            'Kütüphane değiştirilmeden, dinamik bağlı paylaşımlı kütüphane '
            '(.so) olarak dağıtılır; APK içinden çıkarılıp uyumlu başka bir '
            'sürümle değiştirilebilir.\n\n'
            'GPL lisanslı kodlayıcılar (x264, x265, xvidcore) bilinçli olarak '
            'DAĞITILMIYOR. Bu yüzden H.264 çıktısı cihazın donanım '
            'kodlayıcısıyla üretilir; donanım kodlayıcısı olmayan cihazlarda '
            'FFmpeg’in mpeg4 kodlayıcısına düşülür.\n\n'
            'Diğer bileşenler (Flutter, PDFium/pdfrx, Syncfusion Flutter PDF, '
            'Google ML Kit, Firebase, excel, archive, koni_archive, image, '
            'video_player, audioplayers, video_compress, '
            'flutter_local_notifications …) izin verici (BSD/MIT/Apache 2.0) '
            'ya da ticari kullanıma açık lisanslarla dağıtılır. Tam liste: '
            'depodaki LICENSES.md ve pubspec.yaml.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('common.close')),
          ),
        ],
      ),
    );
