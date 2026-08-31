import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/fm/remote/ftp_service.dart';
import '../../../services/fm/remote/ftp_tree.dart';
import '../../../services/fm/remote/share_scope.dart';
import 'share_folders_screen.dart';
import '../../../core/snack.dart';

/// **Ağdan erişim** — telefondaki dosyalara ağdaki bilgisayardan ulaşma.
///
/// ## Ekranın tamamı iki karttan ibaret (kullanıcı isteği 2026-08-29)
/// *"Ağdan erişim örnekteki gibi çok basit olmalı … kullanıcı bir şey
/// yapmıyor, sadece başlatıyor."*
///
/// Eski ekran kullanıcıdan **kullanıcı adı ve parola YAZMASINI** istiyordu ve
/// yazma iznini kapalı bırakıyordu; yani "başlat"a basmadan önce üç karar
/// vermek gerekiyordu. Şimdi:
/// - **kapalıyken:** iki onay kutusu (rastgele şifre / gizli dosyalar) ve tek
///   bir BAŞLAT düğmesi — hiçbirine dokunmadan başlatılabilir,
/// - **açıkken:** adres, kullanıcı adı, parola ve HİZMETİ DURDUR.
///
/// Elle kullanıcı adı/parola isteyen (nadir) kullanıcı için *Gelişmiş*
/// katlanır bölümü duruyor: seçenek kaldırılmadı, **yoldan çekildi**.
///
/// Sunucunun kendisi bu ekranda YAŞAMIYOR ([FtpService] tutuyor): ekrandan
/// çıkmak, hatta uygulamayı arka plana almak paylaşımı kesmez. Gerekçe ve
/// "unutma" sorusunun karşılığı servisin başındaki notta.
class FtpServerScreen extends StatefulWidget {
  const FtpServerScreen({super.key});

  @override
  State<FtpServerScreen> createState() => _FtpServerScreenState();
}

class _FtpServerScreenState extends State<FtpServerScreen> {
  final _service = FtpService.instance;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _service.load();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    // **Sunucu BURADA DURDURULMAZ** (2026-08-29). Eski ekran `dispose`ta
    // `stop()` çağırıyordu; "arka planda da çalışmalı" isteğinin kök nedeni
    // tam olarak o satırdı.
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_service.running) {
      await _service.stop();
    } else {
      // Kilitli klasörler PC'deki kategori kutularında GÖRÜNMEZ.
      await _service.start(
          lockedFolders: context.read<AppState>().fmLockedFolders.toList());
      final error = _service.error;
      if (error != null && mounted) {
        showSnack(context,
            context.t('ftpd.start_failed').replaceAll('{error}', error));
      }
    }
  }

  Future<void> _copy(String text) async {
    final copied = context.t('ftpd.copied');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showSnack(context, copied);
  }

  @override
  Widget build(BuildContext context) {
    final running = _service.running;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ftpd.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _card(context, running ? _runningBody(context) : _idleBody(context)),
          const SizedBox(height: Gap.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: Text(
              context.t('ftpd.description'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: Text(
              context.t('ftpd.folders_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
            child: Text(
              context.t('ftpd.notification_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartın çerçevesi — örnekteki gibi ince kenarlıklı, ortalanmış tek kutu.
  Widget _card(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, Gap.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.fmCardRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  /// **Paylaşılacak klasörler** satırı — hem kapalıyken hem açıkken görünür.
  /// Alt yazı kapsamı tek cümlede söylüyor; dokunmak seçim ekranını açıyor.
  Widget _foldersTile(BuildContext context) {
    final scope = _service.shareScope;
    final empty = scope.isEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_shared_outlined),
      title: Text(context.t('ftpd.folders_title')),
      subtitle: Text(
        _scopeSummary(context, scope),
        style: empty
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ShareFoldersScreen(),
      )),
    );
  }

  /// "Tümü paylaşılıyor" · "4 klasör paylaşılıyor" · "Yalnız Paylaşılan
  /// klasörü" · "Hiçbir klasör seçilmedi".
  static String _scopeSummary(BuildContext context, ShareScope scope) {
    if (scope.mode == ShareMode.sharedOnly) {
      return context.t('ftpd.mode_shared');
    }
    final boxes = scope.boxes;
    if (boxes == null || boxes.length == FtpTree.allBoxes.length) {
      return context.t('ftpd.folders_all');
    }
    if (boxes.isEmpty) return context.t('ftpd.folders_none');
    return context.t('ftpd.folders_count', {'n': boxes.length});
  }

  // ── kapalı ────────────────────────────────────────────────────────────────

  Widget _idleBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _foldersTile(context),
        Divider(height: Gap.lg, color: scheme.outlineVariant),
        // İki seçenek — hiçbirine dokunmadan başlatılabilir.
        _check(
          context,
          value: _service.randomPassword,
          label: context.t('ftpd.random_password'),
          onChanged: _service.setRandomPassword,
        ),
        _check(
          context,
          value: _service.showHidden,
          label: context.t('ftpd.show_hidden'),
          onChanged: _service.setShowHidden,
        ),
        _check(
          context,
          value: _service.allowWrite,
          label: context.t('ftpd.allow_write'),
          onChanged: _service.setAllowWrite,
        ),
        // Yazma açıkken ne demek olduğu tek satırla yazılı: kutu varsayılan
        // olarak AÇIK, sessizce açık bırakmak dürüst olmazdı.
        if (_service.allowWrite)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: Text(
              context.t('ftpd.allow_write_note'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        _advancedSection(context),
        Divider(height: Gap.lg, color: scheme.outlineVariant),
        Text(
          context.t('ftpd.intro'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Gap.md),
        FilledButton(
          onPressed: _service.busy ? null : _toggle,
          child: Text(context.t('ftpd.start')),
        ),
      ],
    );
  }

  Widget _check(
    BuildContext context, {
    required bool value,
    required String label,
    required Future<void> Function(bool) onChanged,
  }) =>
      CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(label),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      );

  /// Elle kullanıcı adı/parola. Katlanmış duruyor: örnekteki sadeliği bozmadan
  /// seçeneği koruyor.
  Widget _advancedSection(BuildContext context) {
    if (_service.randomPassword) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      initiallyExpanded: _advanced,
      onExpansionChanged: (v) => setState(() => _advanced = v),
      title: Text(context.t('ftpd.advanced')),
      children: [
        TextFormField(
          initialValue: _service.username,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.t('nas.user')),
          onChanged: (v) => _service.setCredentials(user: v),
        ),
        const SizedBox(height: Gap.sm),
        TextFormField(
          initialValue: _service.password,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.t('nas.password')),
          onChanged: (v) => _service.setCredentials(password: v),
        ),
        const SizedBox(height: Gap.sm),
      ],
    );
  }

  // ── açık ──────────────────────────────────────────────────────────────────

  Widget _runningBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Paper.success(context);
    final addresses = _service.addresses;
    final webAddresses = _service.webAddresses;
    return Column(
      children: [
        if (addresses.isEmpty && webAddresses.isEmpty)
          Text(
            context.t('ftpd.no_address'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.error),
          )
        else ...[
          // **Tarayıcı adresi ÖNCE ve en büyük.** Kullanıcı hatası
          // 2026-08-29: FTP adresini PC'ye yazınca Gezgin listeliyor ama
          // dosyaya çift tıklayınca adresi tarayıcıya devrediyor ve Chromium
          // tabanlı tarayıcılar FTP'yi 2021'de kaldırdığı için hiçbir şey
          // olmuyordu. `http://` adresi her tarayıcıda çalışıyor ve dosyayı
          // ya sekmede açıyor ya indiriyor (bkz. HttpShareServer).
          if (webAddresses.isNotEmpty) ...[
            _addressBlock(
              context,
              label: context.t('ftpd.web_label'),
              hint: context.t('ftpd.web_hint'),
              addresses: webAddresses,
              color: accent,
              primary: true,
            ),
            const SizedBox(height: Gap.md),
          ],
          if (addresses.isNotEmpty)
            _addressBlock(
              context,
              label: context.t('ftpd.ftp_label'),
              hint: context.t('ftpd.ftp_hint'),
              addresses: addresses,
              color: scheme.onSurfaceVariant,
              primary: false,
            ),
        ],
        const SizedBox(height: Gap.md),
        _field(context, context.t('nas.user'), _service.username, accent),
        const SizedBox(height: Gap.sm),
        _field(context, context.t('nas.password'), _service.password, accent),
        if (_service.clients > 0) ...[
          const SizedBox(height: Gap.sm),
          Text(
            context.t('ftpd.clients', {'n': _service.clients}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        Divider(height: Gap.lg, color: scheme.outlineVariant),
        // Genel "adresi gezginine yaz" cümlesi KALKTI: artık her adresin
        // kendi ipucu var ve hangisinin ne işe yaradığı orada yazıyor.
        //
        // Kökün yolu (`/storage/emulated/0`) yerine **kapsam** yazıyor:
        // paylaşımın tamamı artık seçilebilir olduğu için kullanıcının
        // görmesi gereken şey "neresi paylaşılıyor" (2026-08-31). Açıkken de
        // değiştirilebilir — kapsam sunucuya anında geçiyor.
        _foldersTile(context),
        const SizedBox(height: Gap.md),
        FilledButton.tonal(
          onPressed: _service.busy ? null : _toggle,
          child: Text(context.t('ftpd.stop')),
        ),
      ],
    );
  }

  /// Bir adres bloğu: küçük başlık, adres(ler) ve ne işe yaradığı.
  ///
  /// [primary] olan (tarayıcı) büyük ve renkli; ikincil (FTP) daha sakin —
  /// ikisi aynı ağırlıkta olsaydı kullanıcı yine yanlış olanı seçerdi.
  Widget _addressBlock(
    BuildContext context, {
    required String label,
    required String hint,
    required List<String> addresses,
    required Color color,
    required bool primary,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            )),
        for (final address in addresses)
          InkWell(
            // Dokununca panoya kopyalanır: kullanıcı adresi PC'ye elle
            // yazmak zorunda kalmasın.
            onTap: () => _copy(address),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              child: Text(
                address,
                textAlign: TextAlign.center,
                style: (primary
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _field(
      BuildContext context, String label, String value, Color accent) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        InkWell(
          onTap: value.isEmpty ? null : () => _copy(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SelectableText(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: accent),
            ),
          ),
        ),
      ],
    );
  }
}
