import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/markdown.dart';

/// [parseMarkdown] bloklarını Flutter zengin metnine çizer.
///
/// AI sohbet balonlarında ham `**` / `#` / `-` işaretleri yerine gerçek
/// biçim (kalın, italik, başlık, madde, tablo…) gösterir. Metin seçilebilir
/// kalır (SelectableText.rich) — kullanıcı yanıtı kopyalayabilir.
class MarkdownText extends StatelessWidget {
  final String data;

  /// Gövde metni için temel stil (renk/boyut balondan gelir).
  final TextStyle? baseStyle;

  const MarkdownText(this.data, {super.key, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = (baseStyle ?? theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(height: 1.35);
    final blocks = parseMarkdown(data);

    final children = <Widget>[];
    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      if (b > 0) children.add(const SizedBox(height: 6));
      children.add(_buildBlock(context, block, base));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildBlock(BuildContext context, MdBlock block, TextStyle base) {
    final theme = Theme.of(context);
    switch (block.type) {
      case MdBlockType.heading:
        final sizes = [1.5, 1.35, 1.2, 1.1, 1.05, 1.0];
        final scale = sizes[(block.level - 1).clamp(0, 5)];
        return SelectableText.rich(
          _spansToTextSpan(
            context,
            block.spans,
            base.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: (base.fontSize ?? 14) * scale,
            ),
          ),
        );

      case MdBlockType.paragraph:
        return SelectableText.rich(_spansToTextSpan(context, block.spans, base));

      case MdBlockType.quote:
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.5),
                width: 3,
              ),
            ),
          ),
          child: SelectableText.rich(
            _spansToTextSpan(
              context,
              block.spans,
              base.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        );

      case MdBlockType.bullet:
        return _list(context, base, block.items, ordered: false);

      case MdBlockType.numbered:
        return _list(context, base, block.items,
            ordered: true, start: block.start);

      case MdBlockType.rule:
        return Divider(height: 12, color: theme.dividerColor);

      case MdBlockType.code:
        // Başlık şeridi: dil etiketi + kopyala; gövde yatay kaydırılabilir
        // monospace (uzun satırlar sarmasın, taşarsa kaydırılır).
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      block.codeLang.isEmpty ? 'kod' : block.codeLang,
                      style: base.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kopyala',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: block.rawCode)),
                  ),
                ],
              ),
              Divider(height: 1, color: theme.dividerColor),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                child: SelectableText(
                  block.rawCode,
                  style: base.copyWith(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ),
        );

      case MdBlockType.table:
        return _table(context, block.rows, block.aligns, base);
    }
  }

  Widget _list(
    BuildContext context,
    TextStyle base,
    List<List<MdSpan>> items, {
    required bool ordered,
    int start = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 26 : 18,
                  child: Text(
                    ordered ? '${start + i}.' : '•',
                    style: base.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: SelectableText.rich(
                      _spansToTextSpan(context, items[i], base)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _table(BuildContext context, List<List<List<MdSpan>>> rows,
      List<int> aligns, TextStyle base) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final border = TableBorder.all(color: theme.dividerColor, width: 1);
    // Flutter'ın Table'ı her satırda EŞİT hücre sayısı ister; AI'nın düzensiz
    // tablosunda satırlar boş hücreyle doldurulur (aksi halde çöker).
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    List<List<MdSpan>> pad(List<List<MdSpan>> row) => [
          for (var c = 0; c < cols; c++)
            c < row.length ? row[c] : const [MdSpan('')],
        ];
    // Sütun hizası (ayraç satırındaki `:`): 0=sol,1=orta,2=sağ.
    TextAlign alignOf(int c) {
      final a = c < aligns.length ? aligns[c] : 0;
      return a == 1
          ? TextAlign.center
          : a == 2
              ? TextAlign.right
              : TextAlign.left;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: border,
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5))
                  : null,
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: SelectableText.rich(
                      _spansToTextSpan(
                        context,
                        pad(rows[r])[c],
                        r == 0
                            ? base.copyWith(fontWeight: FontWeight.w700)
                            : base,
                      ),
                      textAlign: alignOf(c),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  TextSpan _spansToTextSpan(
      BuildContext context, List<MdSpan> spans, TextStyle base) {
    final codeBg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withOpacity(0.5);
    return TextSpan(
      children: [
        for (final s in spans)
          TextSpan(
            text: s.text,
            style: base.copyWith(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              decoration: s.strike ? TextDecoration.lineThrough : null,
              fontFamily: s.code ? 'monospace' : null,
              backgroundColor: s.code ? codeBg : null,
            ),
          ),
      ],
    );
  }
}
