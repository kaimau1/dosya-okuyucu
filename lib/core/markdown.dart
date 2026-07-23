/// Hafif, bağımlılıksız Markdown ayrıştırıcı.
///
/// *Niye:* Gemini yanıtları çoğu zaman `**kalın**`, `# başlık`, `- madde`,
/// `| tablo |` gibi Markdown içerir; ham gösterilince `**` gibi işaretler
/// ekranda çirkin durur (kullanıcı şikayeti). Burada Markdown ya biçimli
/// zengin metne çevrilir ([parseMarkdown]) ya da düz metne indirgenir
/// ([stripMarkdown]) — işaretler ekranda ASLA ham kalmaz.
///
/// Kapsam bilinçli olarak sade: başlık, madde/numaralı liste, alıntı, kod
/// bloğu, yatay çizgi, tablo ve satır-içi kalın/italik/kod/üstü-çizili/bağlantı.
/// `markdown` paketine bağımlılık eklenMEdi (APK şişkinliği + CI sürüm
/// hassasiyeti; bkz. HAFIZA "düz REST / bağımlılık şişkinliği istenmedi").
library;

/// Satır-içi metin parçası — biçim bayraklarıyla.
class MdSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool strike;

  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.strike = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, strike);

  @override
  String toString() =>
      'MdSpan("$text"${bold ? " b" : ""}${italic ? " i" : ""}'
      '${code ? " c" : ""}${strike ? " s" : ""})';
}

enum MdBlockType { paragraph, heading, bullet, numbered, quote, code, rule, table }

/// Belge bloğu. [spans] satır-içi biçimli metni tutar; liste maddelerinde her
/// madde bir `List<MdSpan>` satırıdır. Tabloda [rows] her hücreyi span listesi
/// olarak taşır ([rows]`[0]` başlık satırıdır).
class MdBlock {
  final MdBlockType type;
  final List<MdSpan> spans;

  /// Başlık düzeyi (1–6); yalnız [MdBlockType.heading].
  final int level;

  /// Liste maddeleri; yalnız [MdBlockType.bullet]/[MdBlockType.numbered].
  final List<List<MdSpan>> items;

  /// Numaralı listede ilk maddenin başlangıç numarası.
  final int start;

  /// Kod bloğunun ham içeriği; yalnız [MdBlockType.code].
  final String rawCode;

  /// Tablo satırları (ilk satır başlık); yalnız [MdBlockType.table].
  final List<List<List<MdSpan>>> rows;

  const MdBlock({
    required this.type,
    this.spans = const [],
    this.level = 0,
    this.items = const [],
    this.start = 1,
    this.rawCode = '',
    this.rows = const [],
  });
}

final _bulletRe = RegExp(r'^\s{0,3}[-*+]\s+(.*)$');
final _numberedRe = RegExp(r'^\s{0,3}(\d+)[.)]\s+(.*)$');
final _headingRe = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$');
final _quoteRe = RegExp(r'^\s{0,3}>\s?(.*)$');
final _ruleRe = RegExp(r'^\s{0,3}([-*_])(\s?\1){2,}\s*$');
final _fenceRe = RegExp(r'^\s{0,3}(`{3,}|~{3,})(.*)$');
final _tableSepRe = RegExp(r'^\s*\|?[\s:|-]+\|?\s*$');

/// Ham Markdown metnini blok listesine çözer.
List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final blocks = <MdBlock>[];

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    // Boş satır → paragraf ayırıcı, atla.
    if (line.trim().isEmpty) {
      i++;
      continue;
    }

    // Kod bloğu (```): kapanış işaretine kadar ham topla.
    final fence = _fenceRe.firstMatch(line);
    if (fence != null) {
      final marker = fence.group(1)![0];
      final buf = <String>[];
      i++;
      while (i < lines.length) {
        final l = lines[i];
        if (l.trimLeft().startsWith(marker * 3)) {
          i++;
          break;
        }
        buf.add(l);
        i++;
      }
      blocks.add(MdBlock(type: MdBlockType.code, rawCode: buf.join('\n')));
      continue;
    }

    // Yatay çizgi.
    if (_ruleRe.hasMatch(line)) {
      blocks.add(const MdBlock(type: MdBlockType.rule));
      i++;
      continue;
    }

    // Başlık.
    final heading = _headingRe.firstMatch(line);
    if (heading != null) {
      blocks.add(MdBlock(
        type: MdBlockType.heading,
        level: heading.group(1)!.length,
        spans: _parseInline(heading.group(2)!.trim()),
      ));
      i++;
      continue;
    }

    // Tablo: bu satır `|` içeriyor ve sonraki satır ayraç (---|---) ise.
    if (line.contains('|') &&
        i + 1 < lines.length &&
        _tableSepRe.hasMatch(lines[i + 1]) &&
        lines[i + 1].contains('-')) {
      final rows = <List<List<MdSpan>>>[];
      rows.add(_splitTableRow(line));
      i += 2; // başlık + ayraç
      while (i < lines.length &&
          lines[i].contains('|') &&
          lines[i].trim().isNotEmpty) {
        rows.add(_splitTableRow(lines[i]));
        i++;
      }
      blocks.add(MdBlock(type: MdBlockType.table, rows: rows));
      continue;
    }

    // Madde işaretli liste (ardışık maddeleri topla).
    if (_bulletRe.hasMatch(line)) {
      final items = <List<MdSpan>>[];
      while (i < lines.length) {
        final m = _bulletRe.firstMatch(lines[i]);
        if (m == null) break;
        items.add(_parseInline(m.group(1)!.trim()));
        i++;
      }
      blocks.add(MdBlock(type: MdBlockType.bullet, items: items));
      continue;
    }

    // Numaralı liste.
    if (_numberedRe.hasMatch(line)) {
      final items = <List<MdSpan>>[];
      var start = 1;
      var first = true;
      while (i < lines.length) {
        final m = _numberedRe.firstMatch(lines[i]);
        if (m == null) break;
        if (first) {
          start = int.tryParse(m.group(1)!) ?? 1;
          first = false;
        }
        items.add(_parseInline(m.group(2)!.trim()));
        i++;
      }
      blocks.add(MdBlock(type: MdBlockType.numbered, items: items, start: start));
      continue;
    }

    // Alıntı (ardışık satırları birleştir).
    if (_quoteRe.hasMatch(line)) {
      final buf = <String>[];
      while (i < lines.length) {
        final m = _quoteRe.firstMatch(lines[i]);
        if (m == null) break;
        buf.add(m.group(1)!);
        i++;
      }
      blocks.add(MdBlock(
        type: MdBlockType.quote,
        spans: _parseInline(buf.join(' ').trim()),
      ));
      continue;
    }

    // Paragraf: boş satıra / özel bloğa kadar birleştir (yumuşak sarma).
    final buf = <String>[];
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty ||
          _bulletRe.hasMatch(l) ||
          _numberedRe.hasMatch(l) ||
          _headingRe.hasMatch(l) ||
          _quoteRe.hasMatch(l) ||
          _ruleRe.hasMatch(l) ||
          _fenceRe.hasMatch(l)) {
        break;
      }
      buf.add(l.trim());
      i++;
    }
    blocks.add(MdBlock(
      type: MdBlockType.paragraph,
      spans: _parseInline(buf.join(' ')),
    ));
  }

  return blocks;
}

List<List<MdSpan>> _splitTableRow(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) => _parseInline(c.trim())).toList();
}

/// Satır-içi biçim ayrıştırma: `**kalın**`, `*italik*`, `` `kod` ``,
/// `~~üstü çizili~~`, `[metin](url)`. Ham işaretler çıktıya konmaz.
List<MdSpan> _parseInline(String text) {
  final spans = <MdSpan>[];
  final buf = StringBuffer();
  var bold = false;
  var italic = false;
  var strike = false;

  void flush() {
    if (buf.isNotEmpty) {
      spans.add(MdSpan(buf.toString(), bold: bold, italic: italic, strike: strike));
      buf.clear();
    }
  }

  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text[i];

    // Satır-içi kod: `...`
    if (c == '`') {
      final end = text.indexOf('`', i + 1);
      if (end > i) {
        flush();
        spans.add(MdSpan(text.substring(i + 1, end), code: true));
        i = end + 1;
        continue;
      }
    }

    // Bağlantı: [metin](url) → yalnız metni göster.
    if (c == '[') {
      final close = text.indexOf(']', i + 1);
      if (close > i && close + 1 < n && text[close + 1] == '(') {
        final paren = text.indexOf(')', close + 2);
        if (paren > close) {
          flush();
          final label = text.substring(i + 1, close);
          spans.addAll(_parseInline(label));
          i = paren + 1;
          continue;
        }
      }
    }

    // Kalın+italik: ***...***
    if (text.startsWith('***', i)) {
      flush();
      bold = !bold;
      italic = !italic;
      i += 3;
      continue;
    }

    // Kalın: ** veya __
    if (text.startsWith('**', i) || text.startsWith('__', i)) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }

    // Üstü çizili: ~~
    if (text.startsWith('~~', i)) {
      flush();
      strike = !strike;
      i += 2;
      continue;
    }

    // İtalik: tek * veya _ (kelime içinde _ italik sayılmaz: snake_case).
    if (c == '*' || (c == '_' && _isUnderscoreEmphasis(text, i))) {
      flush();
      italic = !italic;
      i += 1;
      continue;
    }

    buf.write(c);
    i++;
  }
  flush();

  // Hiç metin yoksa (ör. yalnız işaretlerden oluşan satır) boş span döndür.
  return spans.isEmpty ? const [MdSpan('')] : spans;
}

/// `_` yalnızca kelime sınırındaysa italik başlatır/bitirir; `snake_case`
/// içindeki alt çizgiler düz metin kalır.
bool _isUnderscoreEmphasis(String text, int i) {
  final prev = i > 0 ? text[i - 1] : ' ';
  final next = i + 1 < text.length ? text[i + 1] : ' ';
  final prevWord = RegExp(r'\w').hasMatch(prev);
  final nextWord = RegExp(r'\w').hasMatch(next);
  // Açılış: öncesi kelime değil, sonrası kelime. Kapanış: tersi.
  return (!prevWord && nextWord) || (prevWord && !nextWord);
}

/// Markdown'ı düz metne indirger (işaretler kaldırılır). Kalıcı hafızaya
/// kaydetme, önizleme ve panoya kopyalama gibi biçimsiz bağlamlar için.
String stripMarkdown(String source) {
  final out = StringBuffer();
  for (final block in parseMarkdown(source)) {
    switch (block.type) {
      case MdBlockType.rule:
        out.writeln('———');
        break;
      case MdBlockType.code:
        out.writeln(block.rawCode);
        break;
      case MdBlockType.heading:
      case MdBlockType.paragraph:
      case MdBlockType.quote:
        out.writeln(_spansText(block.spans));
        break;
      case MdBlockType.bullet:
        for (final it in block.items) {
          out.writeln('• ${_spansText(it)}');
        }
        break;
      case MdBlockType.numbered:
        var n = block.start;
        for (final it in block.items) {
          out.writeln('${n++}. ${_spansText(it)}');
        }
        break;
      case MdBlockType.table:
        for (final row in block.rows) {
          out.writeln(row.map(_spansText).join('  |  '));
        }
        break;
    }
  }
  return out.toString().trim();
}

String _spansText(List<MdSpan> spans) => spans.map((s) => s.text).join();

/// Tek satırdaki satır-içi Markdown işaretlerini (kalın/italik/kod/üstü
/// çizili/bağlantı) ve baştaki liste/başlık işaretini kaldırıp düz metin
/// döndürür. Slayt başlığı/maddesi, PDF satırı gibi tek satırlık bağlamlar
/// için ([stripMarkdown] tüm belge içindir).
String stripInlineMarkdown(String line) {
  final s = line.trim().replaceFirst(
        RegExp(r'^\s{0,3}([-*+]|\d+[.)]|#{1,6})\s+'),
        '',
      );
  return _spansText(_parseInline(s));
}
