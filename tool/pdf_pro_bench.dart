/// **PDF Pro ölçüm tezgâhı** (Faz 51 · PK8 "her şey ölçülür").
///
/// Bir düzenleme motorunu ([BenchEngine]) külliyatın her sayfasında koşturur
/// ve motordan BAĞIMSIZ ölçer: metin ve pikseller PDFium'dan (pdfrx) okunur,
/// yani iki motor (Faz 52 karar kapısı) aynı cetvelle karşılaştırılır.
///
/// Ölçülenler (sayfa/blok başına, sonra toplanır):
/// * **kapsama** — PDFium'un gördüğü (boşluksuz) karakterlerin yüzde kaçı
///   motorun düzenlenebilir bir bloğunda (çoklu küme kesişimi).
/// * **başarı** — iki düzenleme türü: `ayni` (aynı harflerle: ilk/son sözcük
///   yer değiştirir) ve `turkce` (ilk sözcük → "Işığı"). Başarı = motor
///   reddetmedi + yeni metin PDFium'un sayfa metninde (aranabilir) var.
/// * **piksel farkı** — PDFium çizimi (144 dpi), eski ve yeni bloğun kutusu
///   + 2 pt DIŞINDA değişen piksel sayısı (hedef 0). Döndürülmüş sayfada yok.
/// * **yazı tipi** — `turkce` düzenlemesinin eksik glif yüzünden reddi/yedeği
///   ve motorun bildirdiği `.notdef` karakteri.
/// * **büyüme** (bayt) ve **gecikme** (ms, motorun düzenleme çağrısı).
/// * isteğe bağlı: `qpdf --check` + `mutool draw` (araç PATH'teyse).
///
/// Koşum: `flutter test test/pdf_pro/bench_test.dart` (rapor JSON'u
/// `build/pdf_pro_bench/<motor>.json`, özet satırları stdout'a).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Motorun düzenlenebilir gördüğü blok (paragraf). Kutu PDF sayfa
/// uzayında (y yukarı).
class BenchBlock {
  final String text;
  final double left, bottom, right, top;
  const BenchBlock(this.text, this.left, this.bottom, this.right, this.top);
}

class BenchEditResult {
  final Uint8List bytes;

  /// Motorun bildirdiği `.notdef` (tofu) karakter sayısı; bilinmiyorsa null.
  final int? notdefChars;

  /// Yedek fonta düşen karakter sayısı (glif bazlı yedek); bilinmiyorsa null.
  final int? fallbackChars;

  const BenchEditResult(this.bytes, {this.notdefChars, this.fallbackChars});
}

/// Motor bir düzenlemeyi reddetti. [glyph] = neden eksik glif.
class BenchRefused implements Exception {
  final String reason;
  final bool glyph;
  const BenchRefused(this.reason, {this.glyph = false});
  @override
  String toString() => reason;
}

abstract class BenchEngine {
  String get name;

  /// Belge açılmadan önce (ör. sahip parolalı belgede kilit açma) — motorun
  /// gerçek akışında ne yapılıyorsa.
  Future<Uint8List> prepare(Uint8List pdf) async => pdf;
  Future<List<BenchBlock>> blocks(Uint8List pdf, int page);
  Future<BenchEditResult> edit(
      Uint8List pdf, int page, int block, String newText);
}

class CorpusFile {
  final String file;
  final String producer;
  final List<String> features;
  final int expectedParagraphs;
  final String path;
  final bool local;
  const CorpusFile(this.file, this.producer, this.features,
      this.expectedParagraphs, this.path,
      {this.local = false});
}

/// `test/fixtures/pdf_corpus/` (+ varsa `.gitignore`'daki yerel klasör).
List<CorpusFile> loadCorpus({String root = 'test/fixtures/pdf_corpus'}) {
  final out = <CorpusFile>[];
  for (final name in ['corpus.json', 'corpus_dart.json']) {
    final f = File('$root/$name');
    if (!f.existsSync()) continue;
    for (final m in (jsonDecode(f.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()) {
      out.add(CorpusFile(
          m['file'] as String,
          m['producer'] as String,
          (m['features'] as List).cast<String>(),
          m['expected_paragraphs'] as int,
          '$root/${m['file']}'));
    }
  }
  final local = Directory('${root}_local');
  if (local.existsSync()) {
    for (final f in local.listSync().whereType<File>()) {
      if (!f.path.toLowerCase().endsWith('.pdf')) continue;
      // KVKK: yerel belgenin adı rapora yazılmaz, yalnız sıra no.
      out.add(CorpusFile('yerel_${out.length}.pdf', 'yerel', const ['yerel'],
          -1, f.path,
          local: true));
    }
  }
  out.sort((a, b) => a.file.compareTo(b.file));
  return out;
}

/// Bir düzenlemenin kaydı.
class EditRecord {
  final String file, producer, kind;
  final int page, block;
  final bool ok, glyphRefused;
  final String? reason;
  final double? ms;
  final int? growth, pixelDiff, notdef, fallback;
  final bool? qpdfOk, mutoolOk;
  EditRecord({
    required this.file,
    required this.producer,
    required this.kind,
    required this.page,
    required this.block,
    required this.ok,
    this.glyphRefused = false,
    this.reason,
    this.ms,
    this.growth,
    this.pixelDiff,
    this.notdef,
    this.fallback,
    this.qpdfOk,
    this.mutoolOk,
  });
  Map<String, Object?> toJson() => {
        'file': file,
        'producer': producer,
        'kind': kind,
        'page': page,
        'block': block,
        'ok': ok,
        'glyphRefused': glyphRefused,
        'reason': reason,
        'ms': ms,
        'growth': growth,
        'pixelDiff': pixelDiff,
        'notdef': notdef,
        'fallback': fallback,
        'qpdfOk': qpdfOk,
        'mutoolOk': mutoolOk,
      };
}

class PageRecord {
  final String file, producer;
  final int page, pdfiumChars, coveredChars, blocks, expected;
  final bool local;
  final String? error;
  PageRecord(this.file, this.producer, this.page, this.pdfiumChars,
      this.coveredChars, this.blocks, this.expected,
      {this.local = false, this.error});
  Map<String, Object?> toJson() => {
        'file': file,
        'producer': producer,
        'page': page,
        'pdfiumChars': pdfiumChars,
        'coveredChars': coveredChars,
        'blocks': blocks,
        'expected': expected,
        'error': error,
      };
}

class BenchReport {
  final String engine;
  final List<PageRecord> pages;
  final List<EditRecord> edits;
  final bool qpdfAvailable, mutoolAvailable;
  BenchReport(this.engine, this.pages, this.edits, this.qpdfAvailable,
      this.mutoolAvailable);

  /// Özet sayılar — rapor tablosu ve taban karşılaştırması bunlardan.
  Map<String, Object?> summary({bool includeLocal = false}) {
    final pg = pages.where((p) => includeLocal || !p.local).toList();
    final ed = edits.where((e) => includeLocal || !e.file.startsWith('yerel_'))
        .toList();
    final natural = pg.where((p) => p.pdfiumChars > 0);
    final chars = natural.fold<int>(0, (s, p) => s + p.pdfiumChars);
    final covered = natural.fold<int>(0, (s, p) => s + p.coveredChars);
    Map<String, Object?> kind(String k) {
      final e = ed.where((x) => x.kind == k).toList();
      final ok = e.where((x) => x.ok).toList();
      final ms = ok.map((x) => x.ms!).toList()..sort();
      final growth = ok.map((x) => x.growth!).toList()..sort();
      final px = ok.where((x) => x.pixelDiff != null).toList();
      return {
        'attempts': e.length,
        'ok': ok.length,
        'successPct': _pct(ok.length, e.length),
        'glyphRefused': e.where((x) => x.glyphRefused).length,
        'pixelChecked': px.length,
        'pixelDirty': px.where((x) => x.pixelDiff! > 0).length,
        'pixelMax': px.isEmpty ? 0 : px.map((x) => x.pixelDiff!).reduce(math.max),
        'notdef': ok.fold<int>(0, (s, x) => s + (x.notdef ?? 0)),
        'notdefUnknown': ok.where((x) => x.notdef == null).length,
        'fallbackChars': ok.fold<int>(0, (s, x) => s + (x.fallback ?? 0)),
        'msP50': _q(ms, .5),
        'msP95': _q(ms, .95),
        'growthP50': _q(growth.map((g) => g.toDouble()).toList(), .5),
        'growthP95': _q(growth.map((g) => g.toDouble()).toList(), .95),
        'qpdfFail': ok.where((x) => x.qpdfOk == false).length,
        'mutoolFail': ok.where((x) => x.mutoolOk == false).length,
      };
    }

    final expected = pg.where((p) => p.expected >= 0);
    return {
      'engine': engine,
      'files': pg.map((p) => p.file).toSet().length,
      'pages': pg.length,
      'pageErrors': pg.where((p) => p.error != null).length,
      'coveragePct': _pct(covered, chars),
      'blocks': pg.fold<int>(0, (s, p) => s + p.blocks),
      'expectedBlocks': expected.fold<int>(0, (s, p) => s + p.expected),
      'zeroBlockNaturalPages':
          natural.where((p) => p.blocks == 0).map((p) => p.file).toList(),
      'same': kind('ayni'),
      'turkish': kind('turkce'),
      'qpdf': qpdfAvailable,
      'mutool': mutoolAvailable,
    };
  }

  /// Üretici başına kapsama ve başarı (rapor tablosu).
  Map<String, Map<String, Object?>> byProducer() {
    final out = <String, Map<String, Object?>>{};
    for (final prod in pages.where((p) => !p.local).map((p) => p.producer).toSet()) {
      final pg = pages.where((p) => p.producer == prod && p.pdfiumChars > 0);
      final chars = pg.fold<int>(0, (s, p) => s + p.pdfiumChars);
      final cov = pg.fold<int>(0, (s, p) => s + p.coveredChars);
      final ed = edits.where((e) => e.producer == prod).toList();
      out[prod] = {
        'coveragePct': _pct(cov, chars),
        'edits': ed.length,
        'successPct': _pct(ed.where((e) => e.ok).length, ed.length),
        'pixelDirty': ed.where((e) => (e.pixelDiff ?? 0) > 0).length,
      };
    }
    return out;
  }

  Map<String, Object?> toJson() => {
        'summary': summary(),
        'summaryWithLocal': summary(includeLocal: true),
        'byProducer': byProducer(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'edits': edits.map((e) => e.toJson()).toList(),
      };
}

double _pct(int a, int b) => b == 0 ? 0 : (a * 1000 / b).round() / 10;
double _q(List<double> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * q).round();
  return (sorted[i] * 10).round() / 10;
}

/// Boşlukları tek boşluğa indirir; karakterin özgün dizideki yerini tutar.
({String text, List<int> index}) normalizeWithIndex(String s) {
  final b = StringBuffer();
  final idx = <int>[];
  var space = true; // baştaki boşlukları at
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final ws = c.trim().isEmpty || c == ' ' || c == '￾';
    if (ws) {
      if (!space) {
        b.write(' ');
        idx.add(i);
      }
      space = true;
      continue;
    }
    // pdfium satır sonu tirelemesini (U+0002) atla
    if (c == '\u0002') continue;
    b.write(c);
    idx.add(i);
    space = false;
  }
  return (text: b.toString(), index: idx);
}

String normalize(String s) => normalizeWithIndex(s).text.trim();

/// Boşluksuz karakter çoklu kümesi kesişimi.
int multisetOverlap(String a, String b) {
  final m = <int, int>{};
  for (final r in a.runes) {
    if (String.fromCharCode(r).trim().isEmpty) continue;
    m[r] = (m[r] ?? 0) + 1;
  }
  var n = 0;
  for (final r in b.runes) {
    final c = m[r];
    if (c != null && c > 0) {
      m[r] = c - 1;
      n++;
    }
  }
  return n;
}

int nonSpaceCount(String s) =>
    s.runes.where((r) => String.fromCharCode(r).trim().isNotEmpty).length;

/// Ölçüm düzenlemesi: aynı harflerle (ilk ↔ son sözcük; tek sözcükse ters).
String? sameGlyphEdit(String text) {
  final t = normalize(text);
  final w = t.split(' ');
  if (w.length >= 2) {
    if (w.first == w.last) return null;
    final s = [w.last, ...w.sublist(1, w.length - 1), w.first].join(' ');
    return s == t ? null : s;
  }
  if (t.length < 2) return null;
  final r = String.fromCharCodes(t.runes.toList().reversed);
  return r == t ? null : r;
}

/// Ölçüm düzenlemesi: Türkçe harfler (ilk sözcük → "Işığı").
String? turkishEdit(String text) {
  final t = normalize(text);
  if (t.isEmpty) return null;
  final w = t.split(' ');
  w[0] = 'Işığı';
  final s = w.join(' ');
  return s == t ? null : s;
}

class _Rendered {
  final int w, h;
  final Uint8List px;
  _Rendered(this.w, this.h, this.px);
}

const _scale = 2.0; // 144 dpi
const _margin = 2.0; // pt

Future<_Rendered?> _render(PdfPage p) async {
  final w = (p.width * _scale).round();
  final h = (p.height * _scale).round();
  final img = await p.render(
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      width: w,
      height: h,
      backgroundColor: 0xffffffff);
  if (img == null) return null;
  final r = _Rendered(img.width, img.height, Uint8List.fromList(img.pixels));
  img.dispose();
  return r;
}

/// Metnin PDFium karakter kutularından birleşik kutusu (bulunamazsa null).
PdfRect? _textRect(PdfPageRawText t, String needle) {
  final n = normalizeWithIndex(t.fullText);
  final at = n.text.indexOf(needle);
  if (at < 0) return null;
  PdfRect? r;
  for (var i = at; i < at + needle.length; i++) {
    final src = n.index[i];
    if (src >= t.charRects.length) continue;
    final c = t.charRects[src];
    if (c.width <= 0 && c.height <= 0) continue;
    r = r == null ? c : r.merge(c);
  }
  return r;
}

/// [a]/[b] çizimleri arasında, [keep] kutuları (+ kenar payı) dışındaki
/// farklı piksel sayısı.
int _diffOutside(
    _Rendered a, _Rendered b, List<PdfRect> keep, double pageHeight) {
  if (a.w != b.w || a.h != b.h) return a.w * a.h;
  final boxes = [
    for (final k in keep)
      (
        ((k.left - _margin) * _scale).floor(),
        ((pageHeight - k.top - _margin) * _scale).floor(),
        ((k.right + _margin) * _scale).ceil(),
        ((pageHeight - k.bottom + _margin) * _scale).ceil(),
      )
  ];
  var n = 0;
  for (var y = 0; y < a.h; y++) {
    final row = y * a.w * 4;
    for (var x = 0; x < a.w; x++) {
      final o = row + x * 4;
      if (a.px[o] == b.px[o] &&
          a.px[o + 1] == b.px[o + 1] &&
          a.px[o + 2] == b.px[o + 2]) {
        continue;
      }
      var inside = false;
      for (final k in boxes) {
        if (x >= k.$1 && x <= k.$3 && y >= k.$2 && y <= k.$4) {
          inside = true;
          break;
        }
      }
      if (!inside) n++;
    }
  }
  return n;
}

/// Araç PATH'te mi? (Çıkış kodu önemsiz: `mutool` argümansız 1 döner.)
Future<bool> _toolAvailable(String exe) async {
  try {
    await Process.run(exe, const []);
    return true;
  } on ProcessException {
    return false;
  }
}

/// Tezgâhı koşturur. [maxBlocksPerPage]/[maxPages] süreyi sınırlar
/// (CI'da birkaç dakika).
Future<BenchReport> runBench(
  BenchEngine engine,
  List<CorpusFile> corpus, {
  int maxPages = 2,
  int maxBlocksPerPage = 6,
  void Function(String)? log,
}) async {
  final qpdf = await _toolAvailable('qpdf');
  final mutool = await _toolAvailable('mutool');
  final tmp = await Directory.systemTemp.createTemp('pdfbench_');
  final pages = <PageRecord>[];
  final edits = <EditRecord>[];

  for (final cf in corpus) {
    Uint8List src;
    try {
      src = await engine.prepare(File(cf.path).readAsBytesSync());
    } catch (e) {
      pages.add(PageRecord(cf.file, cf.producer, 0, 0, 0, 0, cf.expectedParagraphs,
          local: cf.local, error: 'prepare: $e'));
      continue;
    }
    PdfDocument doc;
    try {
      doc = await PdfDocument.openData(src);
    } catch (e) {
      pages.add(PageRecord(cf.file, cf.producer, 0, 0, 0, 0, cf.expectedParagraphs,
          local: cf.local, error: 'pdfium: $e'));
      continue;
    }
    var expectedLeft = cf.expectedParagraphs;
    final n = math.min(doc.pages.length, maxPages);
    for (var pi = 0; pi < n; pi++) {
      final page = doc.pages[pi];
      final text = await page.loadText();
      final full = text?.fullText ?? '';
      List<BenchBlock> blocks;
      String? err;
      try {
        blocks = await engine.blocks(src, pi);
      } catch (e) {
        blocks = const [];
        err = '$e';
      }
      final covered =
          multisetOverlap(full, blocks.map((b) => b.text).join(' '));
      // Beklenen paragraf belge geneli; çok sayfalıda ilk sayfaya yazılır.
      final exp = pi == 0 ? expectedLeft : 0;
      if (pi == 0) expectedLeft = 0;
      pages.add(PageRecord(cf.file, cf.producer, pi, nonSpaceCount(full),
          math.min(covered, nonSpaceCount(full)), blocks.length,
          cf.local ? -1 : exp,
          local: cf.local, error: err));
      if (blocks.isEmpty || text == null) continue;

      final rotated = page.rotation != PdfPageRotation.none;
      final before = rotated ? null : await _render(page);
      final step = math.max(1, (blocks.length / maxBlocksPerPage).ceil());
      for (var bi = 0; bi < blocks.length; bi += step) {
        final blk = blocks[bi];
        for (final kind in const ['ayni', 'turkce']) {
          final newText =
              kind == 'ayni' ? sameGlyphEdit(blk.text) : turkishEdit(blk.text);
          if (newText == null) continue;
          final sw = Stopwatch()..start();
          BenchEditResult res;
          try {
            res = await engine.edit(src, pi, bi, newText);
          } on BenchRefused catch (r) {
            edits.add(EditRecord(
                file: cf.file,
                producer: cf.producer,
                kind: kind,
                page: pi,
                block: bi,
                ok: false,
                glyphRefused: r.glyph,
                reason: _short(r.reason)));
            continue;
          } catch (e) {
            edits.add(EditRecord(
                file: cf.file,
                producer: cf.producer,
                kind: kind,
                page: pi,
                block: bi,
                ok: false,
                reason: _short('HATA: $e')));
            continue;
          }
          final ms = sw.elapsedMicroseconds / 1000;
          // Yeniden çıkar: PDFium sayfa metninde yeni metin var mı?
          var ok = false;
          int? pixel;
          String? reason;
          bool? qpdfOk, mutoolOk;
          PdfDocument? out;
          try {
            out = await PdfDocument.openData(res.bytes);
            final op = out.pages[pi];
            final ot = await op.loadText();
            final needle = normalize(newText);
            ok = ot != null && normalizeWithIndex(ot.fullText).text.contains(needle);
            if (!ok) reason = 'yeni metin PDFium metninde yok';
            if (ok && before != null) {
              final after = await _render(op);
              final keep = <PdfRect>[
                PdfRect(blk.left, blk.top, blk.right, blk.bottom),
                ?_textRect(text, normalize(blk.text)),
                ?_textRect(ot, needle),
              ];
              if (after != null) {
                pixel = _diffOutside(before, after, keep, page.height);
              }
            }
          } catch (e) {
            ok = false;
            reason = _short('yeniden açılamadı: $e');
          } finally {
            await out?.dispose();
          }
          if (ok && (qpdf || mutool)) {
            final f = File('${tmp.path}/e${edits.length}.pdf')
              ..writeAsBytesSync(res.bytes);
            if (qpdf) {
              final r = await Process.run('qpdf', ['--check', f.path]);
              qpdfOk = r.exitCode == 0 || r.exitCode == 3; // 3 = yalnız uyarı
            }
            if (mutool) {
              final r = await Process.run('mutool',
                  ['draw', '-q', '-o', '${f.path}.png', f.path, '${pi + 1}']);
              mutoolOk = r.exitCode == 0 &&
                  !(r.stderr as String).toLowerCase().contains('error');
            }
          }
          edits.add(EditRecord(
              file: cf.file,
              producer: cf.producer,
              kind: kind,
              page: pi,
              block: bi,
              ok: ok,
              reason: reason,
              ms: ms,
              growth: res.bytes.length - src.length,
              pixelDiff: pixel,
              notdef: res.notdefChars,
              fallback: res.fallbackChars,
              qpdfOk: qpdfOk,
              mutoolOk: mutoolOk));
        }
      }
    }
    await doc.dispose();
    log?.call('${cf.file}: ${pages.where((p) => p.file == cf.file).map((p) => p.blocks).join('+')} blok');
  }
  await tmp.delete(recursive: true);
  return BenchReport(engine.name, pages, edits, qpdf, mutool);
}

String _short(String s) => s.length > 140 ? '${s.substring(0, 140)}…' : s;

/// Özeti okunur satırlara döker (CI logu ve rapor için).
String formatSummary(BenchReport r) {
  final s = r.summary();
  final b = StringBuffer()
    ..writeln('PDFPRO_BENCH ${jsonEncode(s)}')
    ..writeln('PDFPRO_BYPRODUCER ${jsonEncode(r.byProducer())}');
  return b.toString();
}
