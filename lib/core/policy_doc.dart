/// **Gizlilik politikası metnini ekrana çizilebilir bloklara çevirir.**
///
/// Politika `assets/privacy/<dil>.md` altında Markdown olarak duruyor; aynı
/// dosya hem uygulamada gösteriliyor hem de depoda (GitHub'da) okunabiliyor —
/// mağaza başvurusunun isteyeceği "privacy policy URL" da o adres olacak. Tek
/// kaynak tutmanın bedeli, uygulamanın bu metni çizebilmesi.
///
/// **Niçin `flutter_markdown` paketi değil:** pubspec'teki sürüm duvarı
/// (Flutter 3.29.3) yüzünden her yeni bağımlılık bir çözümleme riski; tek bir
/// belgeyi göstermek için buna girmeye değmez. Burada desteklenen alt küme
/// belgenin gerçekten kullandığı kadarıdır: başlık, paragraf, madde, tablo.
/// Desteklenmeyen bir işaretleme metni KAYBETMEZ, düz paragraf olarak çizilir.
library;

enum PolicyBlockKind { heading, paragraph, bullet, tableRow, divider }

class PolicyBlock {
  final PolicyBlockKind kind;

  /// Başlık düzeyi (1-3); diğer türlerde 0.
  final int level;

  /// Tek parçalı bloklarda tüm metin; tablo satırında **hücreler**.
  final List<String> cells;

  const PolicyBlock(this.kind, this.cells, {this.level = 0});

  String get text => cells.isEmpty ? '' : cells.first;
}

abstract final class PolicyDoc {
  static List<PolicyBlock> parse(String markdown) {
    final blocks = <PolicyBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(PolicyBlock(
          PolicyBlockKind.paragraph, [inline(paragraph.join(' '))]));
      paragraph.clear();
    }

    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      // Tablo ayracı (|---|---|) çizilmez ve **kendinden önceki başlık
      // satırını da düşürür**: tablo telefonda sütun sütun değil, satır
      // başına bir kart olarak çiziliyor (bkz. privacy_policy_screen);
      // orada "İşlem | Nereye gider" başlığı bağlamsız bir kart olurdu.
      if (_isTableDivider(trimmed)) {
        flushParagraph();
        if (blocks.isNotEmpty && blocks.last.kind == PolicyBlockKind.tableRow) {
          blocks.removeLast();
        }
        continue;
      }
      if (trimmed.startsWith('|')) {
        flushParagraph();
        blocks.add(PolicyBlock(PolicyBlockKind.tableRow, _cells(trimmed)));
        continue;
      }
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(PolicyBlock(
          PolicyBlockKind.heading,
          [inline(heading.group(2)!)],
          level: heading.group(1)!.length,
        ));
        continue;
      }
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(
            PolicyBlock(PolicyBlockKind.bullet, [inline(trimmed.substring(2))]));
        continue;
      }
      if (trimmed == '---') {
        flushParagraph();
        blocks.add(const PolicyBlock(PolicyBlockKind.divider, []));
        continue;
      }
      // Alıntı (`> `) ve düz satır: paragrafa katılır. Satır sonundaki tek
      // satır sonu Markdown'da boşluktur — bu yüzden birleştiriliyor.
      paragraph.add(trimmed.startsWith('> ') ? trimmed.substring(2) : trimmed);
    }
    flushParagraph();
    return blocks;
  }

  /// Satır içi işaretlemeyi düz metne indirger: `**kalın**`, `` `kod` ``,
  /// `[ad](adres)` → `ad (adres)`, `<adres>` → `adres`.
  static String inline(String text) {
    var out = text;
    out = out.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => '${m[1]} (${m[2]})');
    out = out.replaceAll('**', '').replaceAll('`', '');
    out = out.replaceAllMapped(RegExp(r'<(https?://[^>]+)>'), (m) => m[1]!);
    return out.trim();
  }

  static bool _isTableDivider(String line) =>
      RegExp(r'^\|[\s:\-|]+\|$').hasMatch(line);

  static List<String> _cells(String line) {
    final body = line.substring(1, line.endsWith('|') ? line.length - 1 : null);
    return body.split('|').map((c) => inline(c.trim())).toList();
  }
}
