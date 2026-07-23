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

  /// Kod bloğunun dil etiketi (```dart → "dart"); yoksa boş.
  final String codeLang;

  /// Tablo satırları (ilk satır başlık); yalnız [MdBlockType.table].
  final List<List<List<MdSpan>>> rows;

  /// Tablo sütun hizaları: 0=sol, 1=orta, 2=sağ (ayraç satırındaki `:`).
  /// Boşsa hepsi sol. Yalnız [MdBlockType.table].
  final List<int> aligns;

  const MdBlock({
    required this.type,
    this.spans = const [],
    this.level = 0,
    this.items = const [],
    this.start = 1,
    this.rawCode = '',
    this.codeLang = '',
    this.rows = const [],
    this.aligns = const [],
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

    // Kod bloğu (```): kapanış işaretine kadar ham topla. `​```dart` → dil etiketi.
    final fence = _fenceRe.firstMatch(line);
    if (fence != null) {
      final marker = fence.group(1)![0];
      final lang = fence.group(2)!.trim().split(RegExp(r'\s')).first;
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
      blocks.add(MdBlock(
        type: MdBlockType.code,
        rawCode: buf.join('\n'),
        codeLang: lang,
      ));
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
      // ATX kapanış diyezleri: `## Başlık ##` → sondaki `#`'ler atılır.
      final content =
          heading.group(2)!.replaceFirst(RegExp(r'\s+#+\s*$'), '').trim();
      blocks.add(MdBlock(
        type: MdBlockType.heading,
        level: heading.group(1)!.length,
        spans: _parseInline(content),
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
      final aligns = _parseAligns(lines[i + 1]);
      i += 2; // başlık + ayraç
      while (i < lines.length &&
          lines[i].contains('|') &&
          lines[i].trim().isNotEmpty) {
        rows.add(_splitTableRow(lines[i]));
        i++;
      }
      blocks.add(MdBlock(type: MdBlockType.table, rows: rows, aligns: aligns));
      continue;
    }

    // Madde işaretli liste (ardışık maddeleri topla). GFM görev listesi
    // `- [ ]` / `- [x]` onay kutusu simgesine çevrilir.
    if (_bulletRe.hasMatch(line)) {
      final items = <List<MdSpan>>[];
      while (i < lines.length) {
        final m = _bulletRe.firstMatch(lines[i]);
        if (m == null) break;
        items.add(_parseBulletItem(m.group(1)!.trim()));
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
    // Sert satır sonu (satır sonunda 2+ boşluk veya `\`) korunur → `\n`.
    final sb = StringBuffer();
    var firstLine = true;
    var pendingHard = false;
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
      if (!firstLine) sb.write(pendingHard ? '\n' : ' ');
      var content = l.trim();
      final hardBackslash = content.endsWith(r'\');
      pendingHard = RegExp(r'  +$').hasMatch(l) || hardBackslash;
      if (hardBackslash) content = content.substring(0, content.length - 1);
      sb.write(content);
      firstLine = false;
      i++;
    }
    blocks.add(MdBlock(
      type: MdBlockType.paragraph,
      spans: _parseInline(sb.toString()),
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

/// Tablo ayraç satırından sütun hizalarını çözer: `:--`→sol, `:-:`→orta,
/// `--:`→sağ. 0=sol, 1=orta, 2=sağ.
List<int> _parseAligns(String sep) {
  var s = sep.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) {
    final t = c.trim();
    final left = t.startsWith(':');
    final right = t.endsWith(':');
    if (left && right) return 1;
    if (right) return 2;
    return 0;
  }).toList();
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

    // Ters bölü kaçışı: `\*` → düz `*` (işaret olarak yorumlanmaz).
    if (c == r'\' && i + 1 < n && _isEscapable(text[i + 1])) {
      buf.write(text[i + 1]);
      i += 2;
      continue;
    }

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

    // Görsel: ![alt](url) → yalnız alt metni göster (mobilde görsel çizilmez).
    if (c == '!' && i + 1 < n && text[i + 1] == '[') {
      final close = text.indexOf(']', i + 2);
      if (close > i && close + 1 < n && text[close + 1] == '(') {
        final paren = text.indexOf(')', close + 2);
        if (paren > close) {
          flush();
          spans.addAll(_parseInline(text.substring(i + 2, close)));
          i = paren + 1;
          continue;
        }
      }
    }

    // Otomatik bağlantı: <https://...> veya <a@b.com> → içeriği göster.
    if (c == '<') {
      final end = text.indexOf('>', i + 1);
      if (end > i) {
        final inner = text.substring(i + 1, end);
        if (RegExp(r'^(https?://|mailto:|[^\s@]+@[^\s@]+\.)').hasMatch(inner)) {
          flush();
          spans.add(MdSpan(inner));
          i = end + 1;
          continue;
        }
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

    // Kalın+italik: ***...*** (flanking: boşlukla çevrili `*` işaret değildir).
    if (text.startsWith('***', i) && _canToggle(text, i, 3, bold && italic)) {
      flush();
      bold = !bold;
      italic = !italic;
      i += 3;
      continue;
    }

    // Kalın: ** (flanking) — `5 ** 2` gibi boşluklu `*` düz metin kalır.
    if (text.startsWith('**', i) && _canToggle(text, i, 2, bold)) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }

    // Kalın: __ (kelime sınırı — `a__b` düz kalır).
    if (text.startsWith('__', i) && _isUnderscoreEmphasis(text, i)) {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }

    // Üstü çizili: ~~ (flanking).
    if (text.startsWith('~~', i) && _canToggle(text, i, 2, strike)) {
      flush();
      strike = !strike;
      i += 2;
      continue;
    }

    // İtalik: tek * (flanking — `2 * 3` italik olmaz).
    if (c == '*' && _canToggle(text, i, 1, italic)) {
      flush();
      italic = !italic;
      i += 1;
      continue;
    }

    // İtalik: tek _ (kelime içinde italik sayılmaz: snake_case).
    if (c == '_' && _isUnderscoreEmphasis(text, i)) {
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

/// Ters bölü ile kaçırılabilen noktalama (CommonMark). Harf/rakam kaçmaz
/// (ör. `\n` metinde ters bölü + n kalır, satır sonu değil).
bool _isEscapable(String ch) => r'\`*_{}[]()#+-.!>~|'.contains(ch);

bool _isSpaceCh(String ch) => ch == ' ' || ch == '\t' || ch == '\n';

/// CommonMark flanking (sadeleştirilmiş): bir vurgu işareti ancak açılışta
/// KENDİSİNDEN SONRA, kapanışta KENDİSİNDEN ÖNCE boşluk yoksa geçerlidir.
/// Böylece `2 * 3 = 6` gibi boşlukla çevrili `*` düz metin kalır ama
/// `**kalın**` çalışır. [currentlyOn] o biçimin şu an açık olup olmadığı.
bool _canToggle(String text, int i, int len, bool currentlyOn) {
  final before = i > 0 ? text[i - 1] : ' ';
  final after = i + len < text.length ? text[i + len] : ' ';
  return currentlyOn ? !_isSpaceCh(before) : !_isSpaceCh(after);
}

/// Madde içeriğini biçimler; GFM görev listesi işaretini (`[ ]`/`[x]`)
/// onay kutusu simgesine (☐/☑) çevirir.
List<MdSpan> _parseBulletItem(String content) {
  final task = RegExp(r'^\[([ xX])\]\s+(.*)$').firstMatch(content);
  if (task != null) {
    final checked = task.group(1) != ' ';
    return [
      MdSpan(checked ? '☑ ' : '☐ '),
      ..._parseInline(task.group(2)!.trim()),
    ];
  }
  return _parseInline(content);
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
