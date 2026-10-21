part of '../viewer_screen.dart';


class _TextEditor extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editable;
  final double fontSize;

  /// `null` = temanın gövde yazı tipi.
  final String? fontFamily;

  /// Solda satır numarası şeridi (2026-09-06 denetim turu): kayıt ve kod
  /// dosyalarında "347. satırda hata" diyen bir mesajı takip edebilmek için.
  final bool lineNumbers;

  /// Satırlar sarılsın mı? Kapalıyken uzun satır yatay kaydırılıyor —
  /// kayıt dosyalarında sütun hizası bozulmadan okunuyor.
  final bool wrapLines;
  final VoidCallback onChanged;
  const _TextEditor({
    required this.controller,
    required this.focusNode,
    required this.editable,
    required this.fontSize,
    required this.onChanged,
    this.lineNumbers = false,
    this.wrapLines = true,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    if (!lineNumbers) return _field(context);
    // **Numaralar ve metin AYNI kaydırmayı paylaşır.** İki ayrı kaydırılabilir
    // alan yapılsaydı senkron tutmak gerekirdi (ve bir kaydırma denetleyicisi
    // iki `Scrollable`a bağlanamaz). Çözüm: tek bir kaydırma alanı, içinde
    // yan yana iki sütun — numaralar metinle birlikte, aynı satır
    // yüksekliğiyle kayıyor.
    return Container(
      color: Paper.docSurface(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final count = value.text.split('\n').length;
                // Numara şeridi metinden ince bir cetvelle ayrılır (kod
                // düzenleyicilerinin "gutter"ı).
                final scheme = Theme.of(context).colorScheme;
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.only(left: 12, right: 10),
                  decoration: BoxDecoration(
                    border:
                        Border(right: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 1; i <= count; i++)
                        Text(
                          '\$i',
                          style: TextStyle(
                            fontSize: fontSize,
                            height: 1.5,
                            // Tek aralıklı yazı tipi: numaralar sağa hizalı
                            // olsa bile orantılı yazıda basamaklar oynuyor.
                            fontFamily: 'monospace',
                            color: scheme.outline,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Expanded(child: _field(context, scrollable: false)),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext context, {bool scrollable = true}) {
    // **Kaydırma kapalı**: uzun satır sarılmıyor, yatay kaydırılıyor.
    // `TextField` tek başına yatay kaydırmayı satır SARMADAN yapamıyor
    // (`maxLines: null` sarmayı zorunlu kılar); çözüm alanı yatay bir
    // kaydırma kutusuna koyup ona geniş bir genişlik vermek.
    if (!wrapLines) {
      return Container(
        color: Paper.docSurface(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // Ekranın üç katı: en uzun kayıt satırları bile sığıyor, sonsuz
            // genişlik ise ölçülemez (Flutter yerleşimi patlar).
            width: MediaQuery.sizeOf(context).width * 3,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: !editable,
              onChanged: (_) => onChanged(),
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              style: TextStyle(
                fontSize: fontSize,
                height: 1.5,
                fontFamily: fontFamily,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Paper.inkDark
                    : Paper.ink,
              ),
            ),
          ),
        ),
      );
    }
    if (!scrollable) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: !editable,
        onChanged: (_) => onChanged(),
        maxLines: null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
        ),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.5,
          fontFamily: fontFamily,
          color: Theme.of(context).brightness == Brightness.dark
              ? Paper.inkDark
              : Paper.ink,
        ),
      );
    }
    return Container(
      // Metin sayfası BEYAZ: kağıt teması uygulamanın kabuğuna ait, belgenin
      // içine değil (2026-08-07 kullanıcı isteği — "txt de öyle").
      //
      // 2026-09-23: kenar boşluğu 12 → 20 (okuma uygulamalarının rahat
      // sütunu) ve geniş ekranda satır uzunluğu ~80 karakterde sınırlı —
      // tablette ekran boyu uzanan satırı göz takip edemiyordu.
      color: Paper.docSurface(context),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: !editable,
          onChanged: (_) => onChanged(),
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: editable ? context.t('vw.doc_content') : null,
            filled: false,
          ),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.5,
            fontFamily: fontFamily,
            color: Theme.of(context).brightness == Brightness.dark
                ? Paper.inkDark
                : Paper.ink,
          ),
        ),
      ),
    );
  }
}

/// Salt-okunur Excel ızgarası (eski .xls görüntüleme). A/B/C sütun başlıkları,
/// satır numaraları; iki parmakla yakınlaştırılabilir.
class _SpreadsheetView extends StatelessWidget {
  final List<List<String>> table;
  const _SpreadsheetView({required this.table});

  static String _colLabel(int i) {
    var n = i;
    final sb = StringBuffer();
    do {
      sb.write(String.fromCharCode(65 + (n % 26)));
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return String.fromCharCodes(sb.toString().codeUnits.reversed);
  }

  @override
  Widget build(BuildContext context) {
    if (table.isEmpty) {
      return Center(child: Text(context.t('vw.table_empty')));
    }
    final scheme = Theme.of(context).colorScheme;
    final divider = Theme.of(context).dividerColor;
    final maxCols = table
        .fold<int>(0, (m, row) => row.length > m ? row.length : m)
        .clamp(1, 64);
    const rowHeaderW = 46.0;
    const colW = 120.0;
    const cellH = 34.0;

    Widget headerCell(String text, double w) => Container(
          width: w,
          height: cellH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: divider, width: 0.5),
          ),
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        );

    Widget dataCell(String text, double w) => Container(
          width: w,
          height: cellH,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration:
              BoxDecoration(border: Border.all(color: divider, width: 0.5)),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );

    final rows = table.length > 2000 ? table.sublist(0, 2000) : table;

    return InteractiveViewer(
      panEnabled: false,
      minScale: 1,
      maxScale: 5,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: rowHeaderW + maxCols * colW,
          child: Column(
            children: [
              Row(children: [
                headerCell('', rowHeaderW),
                for (var c = 0; c < maxCols; c++)
                  headerCell(_colLabel(c), colW),
              ]),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, r) {
                    final row = rows[r];
                    return Row(children: [
                      headerCell('${r + 1}', rowHeaderW),
                      for (var c = 0; c < maxCols; c++)
                        dataCell(c < row.length ? row[c] : '', colW),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sayfa üzerinde açık olan yerinde düzenleme kutusunun durumu.
/// Ekranda bekleyen (henüz dosyaya yazılmamış) bir vurgu.
class _PendingMark {
  /// 1-tabanlı sayfa numarası.
  final int page;

  /// Satır kutuları (pdfium PDF koordinatı).
  final List<PdfRect> rects;

  int color;

  _PendingMark(this.page, this.rects, this.color);

  /// Dosyaya yazılacak biçim (isolate sınırından geçer).
  PdfHighlightSpec get spec => (
        pageIndex: page - 1,
        rects: [
          for (final r in rects) [r.left, r.top, r.right, r.bottom]
        ],
        color: color,
      );

  /// [other] kutularından biri bu vurgunun bir kutusuna değiyor mu?
  bool touches(List<PdfRect> other) {
    for (final a in rects) {
      for (final b in other) {
        if (a.left < b.right &&
            b.left < a.right &&
            a.bottom < b.top &&
            b.bottom < a.top) {
          return true;
        }
      }
    }
    return false;
  }
}

class _InlineEdit {
  /// 1-tabanlı sayfa numarası.
  final int page;

  /// Düzenlenen metnin PDF-koordinat dikdörtgenleri.
  final List<PdfRect> rects;

  final String original;

  /// Seçimden önceki metin — aynı kelimenin doğru geçişini bulmak için.
  final String preceding;

  const _InlineEdit({
    required this.page,
    required this.rects,
    required this.original,
    required this.preceding,
  });
}
