import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/theme.dart';
import '../core/app_colors.dart';

/// **Üç Office editörünün ortak simge dili.**
///
/// (2026-08-07 kullanıcı isteği: *"3 uygulama simge dilini eşitleme"*.) Aynı
/// iş Word'de, Excel'de ve Slayt'ta AYNI simgeyle görünsün: kullanıcı bir kez
/// öğrenir, üçünde de bulur. Ekranlar `Icons.` sabitini doğrudan yazmaz,
/// buradan alır — yeni bir ekran eklendiğinde de dil kendiliğinden tutar.
abstract final class OfficeIcons {
  // Yazı biçimi
  static const bold = AppIcons.formatBold;
  static const italic = AppIcons.formatItalic;
  static const underline = AppIcons.formatUnderlined;
  static const strike = AppIcons.strikethroughS;
  static const fontFamily = AppIcons.textFields;
  static const fontSize = AppIcons.formatSize;
  static const fontGrow = AppIcons.textIncrease;
  static const fontShrink = AppIcons.textDecrease;
  static const textColor = AppIcons.formatColorText;
  static const fillColor = AppIcons.formatColorFill;
  static const highlight = AppIcons.borderColor;
  static const superscript = AppIcons.superscript;
  static const subscript = AppIcons.subscript;
  static const clearFormat = AppIcons.formatClear;
  static const formatPainter = AppIcons.formatPaint;

  // Hizalama ve akış
  static const alignLeft = AppIcons.formatAlignLeft;
  static const alignCenter = AppIcons.formatAlignCenter;
  static const alignRight = AppIcons.formatAlignRight;
  static const alignJustify = AppIcons.formatAlignJustify;
  static const wrapText = AppIcons.wrapText;
  static const bullets = AppIcons.formatListBulleted;
  static const numbering = AppIcons.formatListNumbered;
  static const multilevel = AppIcons.accountTree;
  static const indentLess = AppIcons.formatIndentDecrease;
  static const indentMore = AppIcons.formatIndentIncrease;
  static const lineSpacing = AppIcons.formatLineSpacing;
  static const rtl = AppIcons.formatTextdirectionRToL;
  static const styles = AppIcons.title;
  static const navigation = AppIcons.toc;
  static const wordCount = AppIcons.numbers;

  // Tablo / hücre
  static const borders = AppIcons.borderAll;
  static const merge = AppIcons.mergeType;
  static const numberFormat = AppIcons.hashtag;
  static const autoSum = AppIcons.functions;
  static const condFormat = AppIcons.rule;
  static const insertRow = AppIcons.tableRows;
  static const insertColumn = AppIcons.viewColumn;
  static const deleteCells = AppIcons.delete;
  static const rowHeight = AppIcons.height;
  static const columnWidth = AppIcons.straighten;
  static const sortAsc = AppIcons.arrowUp;
  static const sortDesc = AppIcons.arrowDown;
  static const filter = AppIcons.filterAlt;
  static const freeze = AppIcons.pushPin;
  static const sheetAdd = AppIcons.postAdd;

  // Pano
  static const cut = AppIcons.cut;
  static const copy = AppIcons.clipCopy;
  static const paste = AppIcons.paste;
  static const clearContents = AppIcons.backspace;

  // Genel
  static const undo = AppIcons.undo;
  static const redo = AppIcons.redo;
  static const search = AppIcons.search;
  static const save = AppIcons.save;
  static const share = AppIcons.share;
  static const translate = AppIcons.translate;
  static const ai = AppIcons.ai;
  static const zoomIn = AppIcons.zoomIn;
  static const zoomOut = AppIcons.zoomOut;
  static const goTo = AppIcons.reveal;
  static const more = AppIcons.moreHoriz;
  static const done = AppIcons.check;
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

  /// **Sıkışık kip** — sekme şeridi ve simge sırası bir kademe kısalır
  /// (84 → 68 dp). Kullanıcı 2026-08-17: *"excelde üst bilgi alanı çok
  /// kalabalık ve prime alanı kaplıyor kompactlaşmalı"*. Telefonda ızgaraya
  /// kalan yükseklik değerlidir; simgeler 20 dp kalır, yalnız çevrelerindeki
  /// boşluk kısılır — dokunma hedefi 40 dp'nin altına DÜŞMEZ.
  final bool compact;

  /// Şerit yüksekliği — `PreferredSize` kullanan ekranlar için hesaplanır.
  static double heightFor(int tabCount, {bool compact = false}) {
    final rows = compact ? 40.0 : 48.0;
    return tabCount > 1 ? rows + (compact ? 28 : 36) : rows;
  }

  const OfficeRibbon({
    super.key,
    required this.tabs,
    this.trailing,
    this.onBrand = false,
    this.compact = false,
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
    final fg = widget.onBrand ? AppColors.onBrand : scheme.onSurface;

    // 2026-09-23 tasarım turu: sekmeler alt çizgili düz metin değil, HAP
    // (M3 "segmented" dili): etkin sekme vurgu dolgusuyla okunur, parmakla
    // hedeflemesi kolay. Şerit zemini kabukla aynı yüzeyde + alt cetvel.
    return RibbonStyle(
      onBrand: widget.onBrand,
      child: Container(
        color: widget.onBrand ? Colors.transparent : scheme.surface,
        // Cetvel ÖN süslemede: `decoration` kenarlığı yüksekliğe 1 px ekler
        // ve `heightFor` sözleşmesini (PreferredSize) bozardı.
        foregroundDecoration: widget.onBrand
            ? null
            : BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tabs.length > 1)
              SizedBox(
                height: widget.compact ? 28 : 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(8, widget.compact ? 2 : 4, 8, 0),
                  itemCount: tabs.length,
                  itemBuilder: (_, i) {
                    final active = i == index;
                    final activeBg = widget.onBrand
                        ? AppColors.onBrandWell
                        : scheme.primaryContainer;
                    final activeFg = widget.onBrand
                        ? AppColors.onBrand
                        : scheme.onPrimaryContainer;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Material(
                        color: active ? activeBg : Colors.transparent,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            child: Text(
                              tabs[i].label,
                              style: TextStyle(
                                fontSize: widget.compact ? 12 : 13,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w600,
                                color: active
                                    ? activeFg
                                    : fg.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(
              height: widget.compact ? 40 : 48,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: tabs[index].items,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    // Kayan simgelerle sabit düğme arasına ince ayraç: "Bitti"
                    // simge sırasının bir parçası sanılmasın.
                    Container(
                      width: 1,
                      height: 24,
                      color: widget.onBrand
                          ? AppColors.onBrandMuted
                          : scheme.outlineVariant,
                    ),
                    widget.trailing!,
                  ],
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
  bool updateShouldNotify(RibbonStyle oldWidget) =>
      oldWidget.onBrand != onBrand;
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
              color: onBrand ? AppColors.onBrandWell : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        color: onBrand
            ? AppColors.onBrand
            : (active ? scheme.onPrimaryContainer : scheme.onSurface),
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
      icon: Icon(icon, size: 20, color: onBrand ? AppColors.onBrand : null),
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
    final fg = onBrand ? AppColors.onBrand : scheme.onSurface;
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
            color: onBrand ? AppColors.onBrandWell : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: onBrand ? null : Border.all(color: scheme.outlineVariant),
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
                  style: context.type.compact.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
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
          ? AppColors.onBrandMuted
          : Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
