import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/menu_look.dart';
import '../core/state/appearance_state.dart';
import '../core/theme.dart';

export '../core/menu_look.dart';

/// **Ortak menü dili** (2026-10-29, kullanıcı: *"görsel birlik üzerine çalış —
/// bazı menüler farklı görünüyor: dosya içi farklı, ayarlar farklı, klasör
/// menüsü farklı; hepsi görsel birlikte olmalı"*).
///
/// Bugüne dek dört ayrı menü dili vardı: dosya içindeki "Daha fazla" ızgarası
/// ([DocMoreSheet]), uzun basma menüsü (büyük daire düğmeler + çerçeveli
/// hücreler + BÜYÜK HARF başlık), seçimdeki eylem levhası (çıplak liste +
/// mavi başlık) ve klasörün ⋮ açılır menüsü. Hepsi aynı üç parçaya indi:
///
/// * [MenuGroupTitle] — grup başlığı (tek yazı stili, büyük harf yok);
/// * [MenuGroupCard] — grubun kartı (aynı zemin, aynı köşe);
/// * [MenuIconWell] — simge kutusu (aynı boy, aynı köşe; nötr / vurgu /
///   tehlike / kapalı tonları).
///
/// Ekran bu parçaları dizer; renk ve köşe tek yerden gelir.
abstract final class MenuKit {
  /// Grup kartının köşesi.
  static const double cardRadius = 20;

  /// Simge kutusunun köşesi (kutu boyunun ~üçte biri).
  static const double wellRadius = 14;

  /// **Seçili menü görünümü** (Ayarlar › Görünüm › Menü görünümü).
  ///
  /// [MenuSections] kendisi okur; çağıranlar dallanmaz — görsel birlik bu
  /// yüzden tek yerde. Sağlayıcısız ağaçta (test, bağımsız levha) sekmeli.
  static MenuLook lookOf(BuildContext context, {bool listen = false}) =>
      Provider.of<AppearanceState?>(context, listen: listen)?.menuLook ??
      MenuLook.tabbed;

  /// **Türe özel düğmelerin rengi** (2026-11-15, kullanıcı: *"her türe özel
  /// butonlar ayrı bir renkte olsun, menü içinde ortak olanlar zaten kendi
  /// renginde; böylece ayrım kolaylaşır"*).
  ///
  /// Ortak dosya işleri (taşı, kopyala, sil …) vurgu renginde; PDF'in sayfa
  /// işleri, videonun oynatıcı işleri gibi TÜRE ÖZEL olanlar vurgunun renk
  /// çemberinde 120° ötesinde bir tonda — her temada vurgudan ayrışır. Kırmızı
  /// bölgeye düşerse kaydırılır: kırmızı yalnız "Sil"in.
  static double specialHue(ColorScheme scheme) {
    final base = HSLColor.fromColor(scheme.primary).hue;
    var hue = (base + 120) % 360;
    if (hue > 330 || hue < 30) hue = (hue + 60) % 360;
    return hue;
  }

  /// Türe özel simge kutusunun zemini.
  static Color specialWell(ColorScheme scheme) => HSLColor.fromAHSL(
          1,
          specialHue(scheme),
          0.55,
          scheme.brightness == Brightness.dark ? 0.27 : 0.89)
      .toColor();

  /// Türe özel simge ve başlık rengi (zemin üstünde WCAG ≥ 4,5).
  static Color specialInk(ColorScheme scheme) => HSLColor.fromAHSL(
          1,
          specialHue(scheme),
          0.6,
          scheme.brightness == Brightness.dark ? 0.84 : 0.30)
      .toColor();
}

/// Grup başlığı ("Düzenle", "Taşı / kopyala").
class MenuGroupTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  /// Türe özel grup: başlık [MenuKit.specialInk] renginde.
  final bool special;

  const MenuGroupTitle(
    this.text, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 6),
    this.special = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Büyük ve kalın (2026-11-15, kullanıcı: *"başlıklar büyüsün baya ve
    // bold olsun"*) — eskiden soluk, küçük etiket yazısıydı.
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.titleMedium
            ?.apply(fontSizeFactor: 1.12)
            .copyWith(
          height: 1.2,
          color: special ? MenuKit.specialInk(scheme) : scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Grubun kartı: hafif yükseltilmiş zemin, yuvarlak köşe.
class MenuGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Türe özel grup: kart [MenuKit.specialWell] tonuna çalar.
  final bool special;

  const MenuGroupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    this.special = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: special
            ? Color.lerp(scheme.surfaceContainerHigh,
                MenuKit.specialWell(scheme), 0.45)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(MenuKit.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Simge kutusunun tonu.
///
/// [special]: türe özel işlem (PDF'in sayfa işi, videonun oynatıcı işi …) —
/// ortak dosya işlerinden ayrı renkte, bkz. [MenuKit.specialWell].
enum MenuTone { neutral, accent, danger, disabled, selected, special }

/// Simge kutusu — bütün menülerde aynı şekil.
class MenuIconWell extends StatelessWidget {
  final IconData icon;
  final MenuTone tone;
  final double size;

  /// Yuvarlak kutu (sekmeli ızgara hücresi).
  final bool circle;

  const MenuIconWell(
    this.icon, {
    super.key,
    this.tone = MenuTone.neutral,
    this.size = 44,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, bool border) = switch (tone) {
      MenuTone.neutral => (scheme.surface, scheme.onSurface, true),
      MenuTone.accent => (scheme.primaryContainer, scheme.onPrimaryContainer, false),
      MenuTone.danger => (scheme.errorContainer, scheme.error, false),
      MenuTone.selected => (scheme.primary, scheme.onPrimary, false),
      MenuTone.special => (
          MenuKit.specialWell(scheme),
          MenuKit.specialInk(scheme),
          false
        ),
      MenuTone.disabled => (
          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          scheme.onSurface.withValues(alpha: 0.35),
          false
        ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : BorderRadius.circular(MenuKit.wellRadius * size / 48),
        border: border ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Icon(icon, size: size * 0.48, color: fg),
    );
  }
}

/// Kart içindeki satır: simge kutusu + etiket (+ ipucu).
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final MenuTone tone;
  final VoidCallback? onTap;
  final Widget? trailing;

  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
    this.tone = MenuTone.neutral,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = tone == MenuTone.danger;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              MenuIconWell(icon, tone: tone, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: danger ? scheme.error : null,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Izgara hücresi: simge kutusu + altında etiket (hızlı eylemler, "Daha
/// fazla" ızgarası).
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final MenuTone tone;
  final VoidCallback? onTap;

  /// Köşede onay işareti (açık/kapalı ayarlar).
  final Widget? badge;

  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.tone = MenuTone.neutral,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null && tone != MenuTone.disabled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MenuIconWell(icon, tone: enabled ? tone : MenuTone.disabled, size: 48),
                if (badge != null)
                  PositionedDirectional(end: -4, top: -4, child: badge!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? scheme.onSurface.withValues(alpha: 0.38)
                    : (tone == MenuTone.danger ? scheme.error : scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menü görünümleri (2026-11-15) ─────────────────────────────────────────
//
// Kullanıcı levhanın baştan tasarlanmasını istedi; iki görünümden birini
// Ayarlar'dan seçiyor (varsayılan sekmeli). MenuKit grubu kullanan HER levha
// (dosya işlemleri, görüntüleyici ⋮'ı, "Daha fazla", ortak eylem levhası)
// içeriğini [MenuSections]'a model olarak verir; görünümü kit seçer.

/// Levhadaki tek işlem (görünümden bağımsız model).
class MenuKitAction {
  final IconData icon;
  final String label;

  /// İkinci satır; sekmeli ızgarada görünmez, erişilebilirlik ipucunda ve
  /// uzun basınca ipucu balonunda kalır.
  final String? hint;
  final MenuTone tone;

  /// Aç/kapa ayarıysa durumu; null = düz işlem.
  final bool? checked;

  /// null = şu an yapılamaz (soluk).
  final VoidCallback? onTap;

  /// Hücrenin anahtarı (testler/ölçüm).
  final Key? key;

  const MenuKitAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.tone = MenuTone.accent,
    this.checked,
    this.key,
  });

  bool get enabled => onTap != null && tone != MenuTone.disabled;
  MenuTone get shownTone => enabled ? tone : MenuTone.disabled;
}

/// Başlıklı işlem grubu. [special]: türe özel grup (ayrı renk).
class MenuKitSection {
  final String? title;
  final bool special;
  final List<MenuKitAction> actions;
  const MenuKitSection({this.title, this.special = false, required this.actions});
}

class _MenuTab {
  final String title;
  final bool special;
  final List<MenuKitAction> actions;
  _MenuTab(this.title, this.special, this.actions);
}

/// **Ortak levha gövdesi** — seçili görünüme göre ([MenuKit.lookOf]) sekmeli
/// ya da Bento çizer. Çağıran yalnız modeli verir; kaydırmayı (levhanın
/// `SingleChildScrollView`ı) çağıran sağlar.
///
/// * [primary] — büyük "Aç" düğmesi; [mainActions] yanındaki simge düğmeleri
///   (Paylaş, Sil). [primary] yoksa (görüntüleyici) bunlar [quick]'in
///   sonuna iner.
/// * [quick] — en sık işler ("Sık kullanılan" sekmesi / Bento'da üst karolar).
/// * [sections] — başlıklı gruplar, sırasıyla; boş grup çizilmez.
/// * [preferSpecial] — sekmeli görünümde ilk türe özel grup seçili açılır
///   (görüntüleyici ⋮'ı).
class MenuSections extends StatefulWidget {
  final Widget? header;
  final MenuKitAction? primary;
  final List<MenuKitAction> mainActions;
  final String? quickTitle;
  final List<MenuKitAction> quick;
  final List<MenuKitSection> sections;
  final bool preferSpecial;

  /// Görünümü zorla (test); null = ayardan.
  final MenuLook? look;

  const MenuSections({
    super.key,
    this.header,
    this.primary,
    this.mainActions = const [],
    this.quickTitle,
    this.quick = const [],
    this.sections = const [],
    this.preferSpecial = false,
    this.look,
  });

  /// Sekme çiplerinin anahtarı (testler): `menu-tab-<sıra>`.
  static Key tabKey(int i) => ValueKey('menu-tab-$i');

  @override
  State<MenuSections> createState() => _MenuSectionsState();
}

class _MenuSectionsState extends State<MenuSections> {
  int? _tab;

  List<_MenuTab> _tabs(BuildContext context) {
    final out = <_MenuTab>[];
    final quick = [
      ...widget.quick,
      if (widget.primary == null) ...widget.mainActions,
    ];
    if (quick.isNotEmpty) {
      out.add(_MenuTab(
          widget.quickTitle ?? context.t('menu.tab_common'), false, quick));
    }
    _MenuTab? more;
    for (final s in widget.sections) {
      if (s.actions.isEmpty) continue;
      final title = s.title;
      if (title != null && title.isNotEmpty) {
        out.add(_MenuTab(title, s.special, s.actions));
      } else if (out.isEmpty) {
        out.add(_MenuTab(
            context.t('menu.tab_common'), s.special, [...s.actions]));
      } else if (more != null) {
        more.actions.addAll(s.actions);
      } else {
        more = _MenuTab(context.t('menu.tab_more'), s.special, [...s.actions]);
        out.add(more);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look ?? MenuKit.lookOf(context, listen: true);
    return look == MenuLook.bento ? _bento(context) : _tabbed(context);
  }

  // ── Sekmeli ──────────────────────────────────────────────────────────────

  Widget _tabbed(BuildContext context) {
    final tabs = _tabs(context);
    var selected = _tab;
    if (selected == null || selected >= tabs.length) {
      final special = widget.preferSpecial
          ? tabs.indexWhere((t) => t.special)
          : -1;
      selected = special < 0 ? 0 : special;
    }
    final primary = widget.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: widget.header,
          ),
        if (primary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: _MainRow(primary: primary, actions: widget.mainActions),
          ),
        if (tabs.length > 1)
          _TabStrip(
            tabs: tabs,
            selected: selected,
            onSelect: (i) => setState(() => _tab = i),
          )
        else
          const SizedBox(height: Gap.xs),
        if (tabs.isNotEmpty) _TabBody(tabs: tabs, selected: selected),
      ],
    );
  }

  // ── Bento ────────────────────────────────────────────────────────────────

  Widget _bento(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = widget.primary;
    final top = <(MenuKitAction, int, bool)>[
      if (primary != null) (primary, 2, true),
      for (final a in widget.mainActions)
        if (a.tone != MenuTone.danger) (a, 1, false),
      for (final a in widget.quick) (a, 1, false),
      for (final a in widget.mainActions)
        if (a.tone == MenuTone.danger) (a, 1, false),
    ];
    final children = <Widget>[
      if (widget.header != null)
        Container(
          margin: const EdgeInsets.only(bottom: Gap.sm),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(MenuKit.cardRadius),
          ),
          child: widget.header,
        ),
      if (top.isNotEmpty)
        _BentoGrid(items: [
          for (final (a, span, isPrimary) in top)
            (span, _BentoTile(action: a, primary: isPrimary)),
        ]),
    ];
    for (final s in widget.sections) {
      if (s.actions.isEmpty) continue;
      final title = s.title;
      children.add(title != null && title.isNotEmpty
          ? MenuGroupTitle(title,
              special: s.special,
              padding: const EdgeInsetsDirectional.fromSTEB(4, Gap.md, 4, 6))
          : const SizedBox(height: Gap.sm));
      children.add(_BentoGrid(items: [
        for (var i = 0; i < s.actions.length; i++)
          (
            // Türe özel: tam genişlik. Diğerleri iki sütun; tek kalan son
            // işlem tam genişlik.
            s.special || (i == s.actions.length - 1 && i.isEven) ? 4 : 2,
            _BentoRowTile(action: s.actions[i]),
          ),
      ]));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Sekmeli görünümün ana sırası: dolgulu "Aç" + simge düğmeleri.
class _MainRow extends StatelessWidget {
  final MenuKitAction primary;
  final List<MenuKitAction> actions;
  const _MainRow({required this.primary, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: primary.key,
            onPressed: primary.enabled ? primary.onTap : null,
            icon: Icon(primary.icon),
            label: Text(primary.label,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: shape,
              textStyle: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        for (final a in actions) ...[
          const SizedBox(width: Gap.sm),
          IconButton(
            key: a.key,
            onPressed: a.enabled ? a.onTap : null,
            tooltip: a.label,
            icon: Icon(a.icon),
            style: IconButton.styleFrom(
              fixedSize: const Size(48, 48),
              minimumSize: const Size(48, 48),
              shape: shape,
              backgroundColor: a.tone == MenuTone.danger
                  ? scheme.errorContainer
                  : scheme.primaryContainer,
              foregroundColor: a.tone == MenuTone.danger
                  ? scheme.error
                  : scheme.onPrimaryContainer,
            ),
          ),
        ],
      ],
    );
  }
}

/// Yana kayan sekme çipleri. Erişilebilirlikte gerçek sekme: seçili durum
/// bildirilir, dokunma hedefi 48 dp.
class _TabStrip extends StatelessWidget {
  final List<_MenuTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _TabStrip(
      {required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: EdgeInsetsDirectional.only(end: i == tabs.length - 1 ? 0 : 6),
              child: Builder(builder: (context) {
                final on = i == selected;
                final fill = !on
                    ? null
                    : (tabs[i].special
                        ? MenuKit.specialInk(scheme)
                        : scheme.onSurface);
                return Semantics(
                  container: true,
                  selected: on,
                  inMutuallyExclusiveGroup: true,
                  button: true,
                  child: InkWell(
                    key: MenuSections.tabKey(i),
                    onTap: () => onSelect(i),
                    customBorder: const StadiumBorder(),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: ShapeDecoration(
                            color: fill,
                            shape: StadiumBorder(
                              side: BorderSide(
                                  color: fill ?? scheme.outlineVariant),
                            ),
                          ),
                          child: Text(
                            tabs[i].title,
                            maxLines: 1,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: on
                                  ? scheme.surface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// Seçili sekmenin kartı: 4 sütunlu ızgara. Yükseklik EN UZUN sekmeye göre
/// sabit — sekme değişince levha zıplamaz (kasma-kontrol 6: boy animasyonu
/// yok, tek adım).
class _TabBody extends StatelessWidget {
  final List<_MenuTab> tabs;
  final int selected;
  const _TabBody({required this.tabs, required this.selected});

  static const _cols = 4;
  static const _well = 46.0;
  static const _rowGap = 8.0;

  static TextStyle? labelStyle(ThemeData theme) => theme.textTheme.labelMedium
      ?.copyWith(height: 1.2, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hücre boyu: simge + iki satır etiket, o anki yazı ölçeğiyle. Elle
    // ölçülüyor (GridView'in sabit oranı büyük yazıda taşardı).
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: labelStyle(theme)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    final cellH = 4 + _well + 6 + line * 2 + 4 + 2;
    var maxRows = 1;
    for (final t in tabs) {
      final rows = (t.actions.length + _cols - 1) ~/ _cols;
      if (rows > maxRows) maxRows = rows;
    }
    final tab = tabs[selected];
    final rows = (tab.actions.length + _cols - 1) ~/ _cols;
    return MenuGroupCard(
      special: tab.special,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: SizedBox(
        height: maxRows * cellH + (maxRows - 1) * _rowGap,
        child: KeyedSubtree(
          key: ValueKey(selected),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: _rowGap),
                SizedBox(
                  height: cellH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < _cols; c++)
                        Expanded(
                          child: r * _cols + c < tab.actions.length
                              ? _GridCell(action: tab.actions[r * _cols + c])
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Erişilebilirlik sarmalı: etiket + ipucu + aç/kapa durumu; ipucu uzun
/// basınca balonda.
Widget _semantic(MenuKitAction a, Widget child) {
  Widget out = Semantics(
    button: true,
    enabled: a.enabled,
    toggled: a.checked,
    label: a.label,
    hint: a.hint,
    onTap: a.enabled ? a.onTap : null,
    excludeSemantics: true,
    child: child,
  );
  if (a.hint != null) {
    out = Tooltip(message: a.hint!, excludeFromSemantics: true, child: out);
  }
  return KeyedSubtree(key: a.key, child: out);
}

/// Sekmeli ızgara hücresi: yuvarlak simge kutusu + altında etiket.
class _GridCell extends StatelessWidget {
  final MenuKitAction action;
  const _GridCell({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = action;
    final tone = a.shownTone;
    return _semantic(
      a,
      InkWell(
        onTap: a.enabled ? a.onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  MenuIconWell(a.icon,
                      tone: tone, size: _TabBody._well, circle: true),
                  if (a.checked == true)
                    PositionedDirectional(
                      end: -3,
                      top: -3,
                      child: _CheckBadge(special: tone == MenuTone.special),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  a.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: _TabBody.labelStyle(theme)?.copyWith(
                    color: tone == MenuTone.disabled
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : (tone == MenuTone.danger
                            ? scheme.error
                            : scheme.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  final bool special;
  const _CheckBadge({required this.special});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
      child: Icon(AppIcons.checkCircle,
          size: 18,
          color: special ? MenuKit.specialInk(scheme) : scheme.primary),
    );
  }
}

/// Bento renkleri: (zemin, simge, yazı).
(Color, Color, Color) _bentoColors(
    ColorScheme scheme, MenuTone tone, bool primary) {
  final faded = scheme.onSurface.withValues(alpha: 0.38);
  return switch (tone) {
    MenuTone.disabled => (scheme.surfaceContainerHigh, faded, faded),
    MenuTone.danger => (scheme.errorContainer, scheme.error, scheme.error),
    MenuTone.special => (
        MenuKit.specialWell(scheme),
        MenuKit.specialInk(scheme),
        MenuKit.specialInk(scheme)
      ),
    _ when primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.onPrimaryContainer
      ),
    _ => (scheme.surfaceContainerHigh, scheme.primary, scheme.onSurface),
  };
}

/// Bento ızgarası: 4 sütun, karo genişliği 1, 2 ya da 4 sütun. Satırdaki
/// karolar aynı boyda; sütunlar satırlar arasında hizalı.
class _BentoGrid extends StatelessWidget {
  final List<(int, Widget)> items;
  const _BentoGrid({required this.items});

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final unit = (box.maxWidth - 3 * _gap) / 4;
      final rows = <List<(int, Widget)>>[];
      var cur = <(int, Widget)>[];
      var used = 0;
      for (final it in items) {
        if (used + it.$1 > 4) {
          rows.add(cur);
          cur = [];
          used = 0;
        }
        cur.add(it);
        used += it.$1;
      }
      if (cur.isNotEmpty) rows.add(cur);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < rows.length; r++)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : _gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows[r].length; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      // Satırın son karosu kalan yeri alır (yuvarlama payı);
                      // eksik satırda boşluk sonda kalır.
                      if (i == rows[r].length - 1 &&
                          rows[r].fold<int>(0, (n, e) => n + e.$1) == 4)
                        Expanded(child: rows[r][i].$2)
                      else
                        SizedBox(
                          width: rows[r][i].$1 * unit +
                              (rows[r][i].$1 - 1) * _gap,
                          child: rows[r][i].$2,
                        ),
                    ],
                    if (rows[r].fold<int>(0, (n, e) => n + e.$1) < 4)
                      const Spacer(),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Bento kare karosu: simge üst başta, kalın etiket alt başta.
class _BentoTile extends StatelessWidget {
  final MenuKitAction action;
  final bool primary;
  const _BentoTile({required this.action, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = action;
    final (bg, fg, ink) = _bentoColors(theme.colorScheme, a.shownTone, primary);
    return _semantic(
      a,
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: a.enabled ? a.onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(a.icon, size: 22, color: fg),
                      const Spacer(),
                      if (a.checked == true)
                        Icon(AppIcons.checkCircle, size: 18, color: fg),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                        height: 1.2, fontWeight: FontWeight.w700, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bento satır karosu: simge başta, etiket + ipucu (iki sütunlu bölümler,
/// tam genişlik türe özel işler).
class _BentoRowTile extends StatelessWidget {
  final MenuKitAction action;
  const _BentoRowTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = action;
    final (bg, fg, ink) = _bentoColors(scheme, a.shownTone, false);
    return _semantic(
      a,
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: a.enabled ? a.onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(a.icon, size: 22, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: ink),
                        ),
                        if (a.hint != null)
                          Text(
                            a.hint!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: a.shownTone == MenuTone.special
                                    ? ink
                                    : scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (a.checked != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      a.checked!
                          ? AppIcons.checkCircle
                          : AppIcons.checkCircleOutline,
                      size: 22,
                      color: a.checked! ? fg : scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
