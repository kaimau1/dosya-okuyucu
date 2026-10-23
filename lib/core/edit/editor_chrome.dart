/// Düzenleme kipinin ortak kabuk parçaları (Faz 20 / ED4, §5 madde 2–3).
///
/// * [KeyboardAccessoryBar] — klavye açıkken klavyenin **hemen üstünde** tek
///   satır (44 dp, yatay kayan) hızlı çubuk; öğeleri editör verir, sağda
///   **Aa** ve **⌄** sabit. Eskiden Word ve Excel'in şeridi tepedeydi, alt
///   çubuk klavyenin arkasında kalıyordu.
/// * [FormatPanelHost] — **Aa**'ya basınca klavye iner ve **son klavye
///   yüksekliğinde** biçim paneli açılır (mesajlaşma uygulamalarının emoji
///   paneli); belge zıplamaz. ⌨ ile klavyeye dönülür.
/// * [EditorChrome] — ikisini belgenin altına yerleştiren sarmalayıcı:
///   klavye kapalıyken editörün tam şeridi, açıkken hızlı çubuk.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_icons.dart';
import '../l10n/app_strings.dart';

/// Hızlı çubuktaki tek düğme.
class AccessoryItem {
  final IconData? icon;
  final String? text;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Açık/kapalı düğme (Kalın …): TalkBack "Kalın, açık" der.
  final bool? selected;
  final Key? key;

  const AccessoryItem({
    this.icon,
    this.text,
    required this.tooltip,
    this.onPressed,
    this.selected,
    this.key,
  }) : assert(icon != null || text != null);
}

/// Klavyenin hemen üstündeki tek satır hızlı çubuk.
class KeyboardAccessoryBar extends StatelessWidget {
  static const double height = 44;

  final List<AccessoryItem> items;

  /// **Aa** — biçim panelini açar (null ise düğme yok).
  final VoidCallback? onFormat;

  /// **⌄** — klavyeyi gizler.
  final VoidCallback? onHideKeyboard;

  const KeyboardAccessoryBar({
    super.key,
    required this.items,
    this.onFormat,
    this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('keyboard-accessory'),
      color: scheme.surfaceContainerHigh,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [for (final it in items) _button(context, it)],
              ),
            ),
            if (onFormat != null || onHideKeyboard != null)
              VerticalDivider(width: 1, color: scheme.outlineVariant),
            if (onFormat != null)
              _button(
                  context,
                  AccessoryItem(
                      key: const ValueKey('accessory-format'),
                      text: 'Aa',
                      tooltip: context.t('edit.format_panel'),
                      onPressed: onFormat)),
            if (onHideKeyboard != null)
              _button(
                  context,
                  AccessoryItem(
                      key: const ValueKey('accessory-hide'),
                      icon: AppIcons.keyboardArrowDown,
                      tooltip: context.t('edit.hide_keyboard'),
                      onPressed: onHideKeyboard)),
          ],
        ),
      ),
    );
  }

  static Widget _button(BuildContext context, AccessoryItem it) {
    final scheme = Theme.of(context).colorScheme;
    final on = it.selected == true;
    final fg = on ? scheme.onSecondaryContainer : scheme.onSurface;
    final child = it.icon != null
        ? Icon(it.icon, size: 22, color: fg)
        : Text(it.text!,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: fg));
    return Semantics(
      button: true,
      toggled: it.selected,
      label: it.tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: it.tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Material(
            color: on ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: it.key,
              borderRadius: BorderRadius.circular(8),
              onTap: it.onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Biçim panelinin bir sekmesi.
class FormatPanelTab {
  final String label;
  final WidgetBuilder builder;
  const FormatPanelTab({required this.label, required this.builder});
}

/// Klavye ↔ biçim paneli geçişinin durumu.
///
/// Son görülen klavye yüksekliği hatırlanır; panel o yükseklikte açılır, böylece
/// klavye inip panel çıkarken belge alanının yüksekliği DEĞİŞMEZ (imleç satırı
/// yerinde kalır).
class FormatPanelController extends ChangeNotifier {
  /// Klavye hiç görülmediyse panelin varsayılan yüksekliği.
  static const double fallbackHeight = 280;

  bool _open = false;
  double _lastKeyboard = 0;

  bool get isOpen => _open;
  double get panelHeight =>
      _lastKeyboard > 120 ? _lastKeyboard : fallbackHeight;

  /// [EditorChrome] her yerleşimde klavye payını bildirir.
  void reportKeyboard(double inset) {
    if (inset > 120) _lastKeyboard = inset;
  }

  /// Paneli açar ve klavyeyi indirir.
  void open() {
    if (_open) return;
    _open = true;
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    notifyListeners();
  }

  /// Paneli kapatır; [showKeyboard] ise klavyeyi geri çağırır.
  void close({bool showKeyboard = false}) {
    if (!_open) return;
    _open = false;
    if (showKeyboard) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
    notifyListeners();
  }
}

/// Klavye yüksekliğinde açılan, sekmeli biçim paneli.
class FormatPanelHost extends StatefulWidget {
  final FormatPanelController controller;
  final List<FormatPanelTab> tabs;

  const FormatPanelHost(
      {super.key, required this.controller, required this.tabs});

  @override
  State<FormatPanelHost> createState() => _FormatPanelHostState();
}

class _FormatPanelHostState extends State<FormatPanelHost> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = widget.tabs;
    final index = tabs.isEmpty ? 0 : _tab.clamp(0, tabs.length - 1);
    return Material(
      key: const ValueKey('format-panel'),
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: widget.controller.panelHeight,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            child: ChoiceChip(
                              label: Text(tabs[i].label),
                              selected: i == index,
                              onSelected: (_) => setState(() => _tab = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('format-panel-keyboard'),
                    tooltip: context.t('edit.show_keyboard'),
                    icon: const Icon(AppIcons.keyboard),
                    onPressed: () =>
                        widget.controller.close(showKeyboard: true),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: tabs.isEmpty
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: tabs[index].builder(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Belgenin altına hızlı çubuk / biçim paneli / tam şerit yerleştirir.
///
/// * Klavye açık → belge + [accessory] (klavyenin hemen üstünde).
/// * Panel açık → belge + [accessory] + panel (klavye yüksekliğinde).
/// * İkisi de kapalı → belge + [ribbon] (editörün tam şeridi, varsa).
///
/// `Scaffold(resizeToAvoidBottomInset: true)` içinde kullanılır: klavye payı
/// zaten gövdeden düşülmüş olur, çubuk gövdenin en altına (= klavyenin
/// üstüne) oturur.
class EditorChrome extends StatefulWidget {
  final Widget body;
  final Widget? accessory;
  final Widget? ribbon;
  final FormatPanelController? panel;
  final List<FormatPanelTab> panelTabs;

  /// Düzenleme kipinde mi (değilse yalnız [body]).
  final bool editing;

  /// Testte klavye payı benzetimi (null → pencerenin gerçek klavye payı).
  final double? keyboardInsetOverride;

  const EditorChrome({
    super.key,
    required this.body,
    this.accessory,
    this.ribbon,
    this.panel,
    this.panelTabs = const [],
    this.editing = true,
    this.keyboardInsetOverride,
  });

  @override
  State<EditorChrome> createState() => _EditorChromeState();
}

/// Klavye payı `Scaffold` gövdesinin `MediaQuery`sinden OKUNAMAZ: gövde
/// küçültülürken `viewInsets` oradan silinir (ve yalnız o değiştiği için
/// bağımlılar uyarılmaz). Bu yüzden pencere ölçüsü değişimini doğrudan
/// dinleriz (`didChangeMetrics` — klavye animasyonu boyunca kare kare gelir).
class _EditorChromeState extends State<EditorChrome>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  double _inset(BuildContext context) {
    final o = widget.keyboardInsetOverride;
    if (o != null) return o;
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final inset = _inset(context);
    final p = widget.panel;
    p?.reportKeyboard(inset);
    if (!widget.editing) return widget.body;
    Widget build(bool panelOpen) {
      final keyboardUp = inset > 0;
      final accessory = widget.accessory;
      final ribbon = widget.ribbon;
      return Column(
        children: [
          Expanded(child: widget.body),
          if ((keyboardUp || panelOpen) && accessory != null) accessory,
          if (panelOpen && !keyboardUp)
            FormatPanelHost(controller: p!, tabs: widget.panelTabs),
          if (!keyboardUp && !panelOpen && ribbon != null) ribbon,
        ],
      );
    }

    if (p == null) return build(false);
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => build(p.isOpen),
    );
  }
}
