import 'package:flutter/material.dart';

import '../core/theme.dart';

/// **Üç Office editörünün ortak simge dili.**
///
/// (2026-08-07 kullanıcı isteği: *"3 uygulama simge dilini eşitleme"*.) Aynı
/// iş Word'de, Excel'de ve Slayt'ta AYNI simgeyle görünsün: kullanıcı bir kez
/// öğrenir, üçünde de bulur. Ekranlar `Icons.` sabitini doğrudan yazmaz,
/// buradan alır — yeni bir ekran eklendiğinde de dil kendiliğinden tutar.
abstract final class OfficeIcons {
  // Yazı biçimi
  static const bold = Icons.format_bold;
  static const italic = Icons.format_italic;
  static const underline = Icons.format_underlined;
  static const strike = Icons.strikethrough_s;
  static const fontFamily = Icons.text_fields;
  static const fontSize = Icons.format_size;
  static const fontGrow = Icons.text_increase;
  static const fontShrink = Icons.text_decrease;
  static const textColor = Icons.format_color_text;
  static const fillColor = Icons.format_color_fill;
  static const highlight = Icons.border_color_outlined;
  static const clearFormat = Icons.format_clear;

  // Hizalama ve akış
  static const alignLeft = Icons.format_align_left;
  static const alignCenter = Icons.format_align_center;
  static const alignRight = Icons.format_align_right;
  static const alignJustify = Icons.format_align_justify;
  static const wrapText = Icons.wrap_text;
  static const bullets = Icons.format_list_bulleted;
  static const numbering = Icons.format_list_numbered;

  // Tablo / hücre
  static const borders = Icons.border_all;
  static const merge = Icons.merge_type;
  static const numberFormat = Icons.tag;
  static const autoSum = Icons.functions;
  static const condFormat = Icons.rule;
  static const insertRow = Icons.table_rows_outlined;
  static const insertColumn = Icons.view_column_outlined;
  static const deleteCells = Icons.delete_outline;
  static const rowHeight = Icons.height;
  static const columnWidth = Icons.straighten;
  static const sortAsc = Icons.arrow_upward;
  static const sortDesc = Icons.arrow_downward;
  static const filter = Icons.filter_alt_outlined;
  static const freeze = Icons.push_pin_outlined;
  static const gridlines = Icons.grid_on;
  static const sheetAdd = Icons.post_add;

  // Pano
  static const cut = Icons.content_cut;
  static const copy = Icons.content_copy;
  static const paste = Icons.content_paste;
  static const clearContents = Icons.backspace_outlined;

  // Genel
  static const undo = Icons.undo;
  static const redo = Icons.redo;
  static const search = Icons.search;
  static const save = Icons.save_outlined;
  static const share = Icons.share_outlined;
  static const translate = Icons.translate;
  static const ai = Icons.smart_toy_outlined;
  static const zoomIn = Icons.zoom_in;
  static const zoomOut = Icons.zoom_out;
  static const goTo = Icons.my_location;
  static const more = Icons.more_horiz;
  static const done = Icons.check;
}

/// Şeritteki tek bir sekme: adı ve içindeki öğeler.
class RibbonTab {
  final String label;
  final List<Widget> items;
  const RibbonTab(this.label, this.items);
}

/// Office şeridi: üstte (birden çoksa) sekmeler, altında yatay kayan simge
/// sırası, sağda sabit kalan [trailing].
///
/// [onBrand] Word'ün üst çubuğundaki gibi **renkli zeminde** çizim demek:
/// simgeler beyaz, etkin durum beyaz örtüyle gösterilir.
class OfficeRibbon extends StatefulWidget {
  final List<RibbonTab> tabs;
  final Widget? trailing;
  final bool onBrand;

  /// Şerit yüksekliği — `PreferredSize` kullanan ekranlar için hesaplanır.
  static double heightFor(int tabCount) => tabCount > 1 ? 84 : 48;

  const OfficeRibbon({
    super.key,
    required this.tabs,
    this.trailing,
    this.onBrand = false,
  });

  @override
  State<OfficeRibbon> createState() => _OfficeRibbonState();
}

class _OfficeRibbonState extends State<OfficeRibbon> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = widget.tabs.isEmpty ? const [RibbonTab('', [])] : widget.tabs;
    final index = _tab < tabs.length ? _tab : 0;
    final fg = widget.onBrand ? Colors.white : scheme.onSurface;

    return RibbonStyle(
      onBrand: widget.onBrand,
      child: Container(
        color: widget.onBrand ? Colors.transparent : scheme.surfaceContainerHigh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tabs.length > 1)
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: tabs.length,
                  itemBuilder: (_, i) {
                    final active = i == index;
                    return InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2,
                              color: active
                                  ? (widget.onBrand ? Colors.white : scheme.primary)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? fg
                                : fg.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: tabs[index].items,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Şeridin çizim kipini (renkli zemin mi?) alt öğelere taşır — her düğmeye
/// tek tek bayrak geçirmek yerine.
class RibbonStyle extends InheritedWidget {
  final bool onBrand;
  const RibbonStyle({super.key, required this.onBrand, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RibbonStyle>()?.onBrand ??
      false;

  @override
  bool updateShouldNotify(RibbonStyle oldWidget) => oldWidget.onBrand != onBrand;
}

/// Şerit düğmesi (simge + isteğe bağlı etkin durum).
class RibbonButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  const RibbonButton(
    this.icon,
    this.tooltip, {
    super.key,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onBrand = RibbonStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: active
          ? BoxDecoration(
              color: onBrand ? Colors.white24 : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            )
          : null,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        color: onBrand ? Colors.white : null,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}

/// Şerit menüsü (hizalama, sayı biçimi, renk…). Seçenekler `itemBuilder`dan.
class RibbonMenu<T> extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ValueChanged<T> onSelected;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;

  const RibbonMenu({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final onBrand = RibbonStyle.of(context);
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: onBrand ? Colors.white : null),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
    );
  }
}

/// Metin taşıyan şerit öğesi — yazı tipi adı ve punto için (Word'de zaten
/// böyleydi; Excel ve Slayt da aynı görünümü kullanıyor).
class RibbonChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  const RibbonChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onBrand = RibbonStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fg = onBrand ? Colors.white : scheme.onSurface;
    // [onTap] null ise HİÇ jest kurulmaz: bu çip çoğu zaman bir
    // `PopupMenuButton`ın çocuğudur ve araya giren bir `InkWell` dokunuşu
    // yutup menüyü açtırmazdı (Word'ün yazı tipi/punto menüleri).
    Widget wrap(Widget child) => onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: child,
          );
    return Tooltip(
      message: tooltip,
      child: wrap(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: onBrand ? Colors.white24 : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          constraints: const BoxConstraints(maxWidth: 150),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şerit grupları arasındaki ince ayraç.
class RibbonSep extends StatelessWidget {
  const RibbonSep({super.key});

  @override
  Widget build(BuildContext context) {
    final onBrand = RibbonStyle.of(context);
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: onBrand
          ? Colors.white38
          : Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
