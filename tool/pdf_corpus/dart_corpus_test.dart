// Külliyatın Dart üreticileri (`pdf` paketi + Syncfusion) — Faz 51.
import 'dart:ui' show Rect;
// Koşum: flutter test tool/pdf_corpus/dart_corpus_test.dart
// (ardından: python tool/pdf_corpus/make_corpus.py --manifest)
// Metinler UYDURMA (KVKK).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pp;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _cumleler = [
  'Bu belge, düzenleme motorunu sınamak için Dart ile üretilmiş örnek bir metindir.',
  'Ağaçların gölgesinde çay içen öğrenciler sınav haftasını konuşuyordu.',
  'İstanbul\'un eski çarşılarında kuyumcular ve halıcılar yan yana dizilir.',
  'Şehir kütüphanesi bu yıl çocuklar için ücretsiz okuma atölyeleri açacak.',
  'Göl kıyısındaki yürüyüş yolu ilkbaharda çiğdemlerle kaplanıyor.',
  'Işıklı tabelalar gece boyunca yanık kalınca elektrik tüketimi artar.',
  'Ödünç alınan kitapların iade süresi yaz döneminde uzatılmıştır.',
  'Yağmur suyu toplama sistemi bahçe sulamasında şebeke suyunun yerini alıyor.',
];

String _p(int i, [int n = 2]) =>
    List.generate(n, (k) => _cumleler[(i + k * 3) % _cumleler.length]).join(' ');

final _out = Directory('test/fixtures/pdf_corpus');
final _kayit = <Map<String, Object>>[];

void _yaz(String ad, List<int> b, String ureten, List<String> oz, int beklenen,
    [int sayfa = 1]) {
  File('${_out.path}/$ad').writeAsBytesSync(b);
  _kayit.add({
    'file': ad,
    'producer': ureten,
    'features': oz,
    'expected_paragraphs': beklenen,
    'pages': sayfa,
  });
}

void main() {
  final car = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();
  final carB = File('assets/fonts/Carlito-Bold.ttf').readAsBytesSync();
  final tin = File('assets/fonts/Tinos-Regular.ttf').readAsBytesSync();

  test('pdf paketi', () async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(car.buffer.asByteData()),
      bold: pw.Font.ttf(carB.buffer.asByteData()),
    );
    Future<List<int>> doc(List<pw.Widget> Function() body) async {
      final d = pw.Document(theme: theme, creator: 'pdf (Dart)');
      d.addPage(pw.MultiPage(pageFormat: pp.PdfPageFormat.a4, build: (_) => body()));
      return d.save();
    }

    _yaz(
        'dp_paragraflar.pdf',
        await doc(() => [
              pw.Header(level: 0, text: 'Dart pdf paketi'),
              for (var i = 0; i < 5; i++) pw.Paragraph(text: _p(i, 3)),
            ]),
        'pdf (Dart)',
        ['ttf-alt-kume', 'carlito'],
        6);
    _yaz(
        'dp_iki_yana.pdf',
        await doc(() => [
              pw.Header(level: 0, text: 'İki yana yaslı'),
              for (var i = 0; i < 4; i++)
                pw.Paragraph(text: _p(i + 1, 4), textAlign: pw.TextAlign.justify),
            ]),
        'pdf (Dart)',
        ['iki-yana'],
        5);
    _yaz(
        'dp_tablo.pdf',
        await doc(() => [
              pw.Header(level: 0, text: 'Tablo'),
              pw.TableHelper.fromTextArray(data: [
                ['Ürün', 'Adet', 'Açıklama'],
                ['Çay', '12', 'Depoda'],
                ['Şeker', '4', 'Yolda'],
                ['Kâğıt', '30', 'Sipariş verildi'],
              ]),
            ]),
        'pdf (Dart)',
        ['tablo'],
        13);
    _yaz(
        'dp_liste.pdf',
        await doc(() => [
              pw.Header(level: 0, text: 'Madde listesi'),
              for (var i = 0; i < 5; i++) pw.Bullet(text: _cumleler[i]),
            ]),
        'pdf (Dart)',
        ['madde-listesi'],
        6);
  });

  test('Syncfusion', () {
    List<int> doc(void Function(sf.PdfDocument d, sf.PdfPage pg) f,
        {String? owner}) {
      final d = sf.PdfDocument();
      if (owner != null) {
        d.security.ownerPassword = owner;
        d.security.permissions.addAll([sf.PdfPermissionsFlags.print]);
      }
      final pg = d.pages.add();
      f(d, pg);
      final b = d.saveSync();
      d.dispose();
      return b;
    }

    void paragraflar(sf.PdfPage pg, sf.PdfFont f, int n, {sf.PdfTextAlignment? hiza}) {
      var y = 50.0;
      pg.graphics.drawString('Syncfusion örnek belgesi', sf.PdfTrueTypeFont(carB, 16),
          bounds: const Rect.fromLTWH(0, 0, 500, 30));
      for (var i = 0; i < n; i++) {
        final r = sf.PdfTextElement(
                text: _p(i, 3),
                font: f,
                format: hiza == null ? null : sf.PdfStringFormat(alignment: hiza))
            .draw(page: pg, bounds: Rect.fromLTWH(0, y, pg.getClientSize().width, 0))!;
        y = r.bounds.bottom + 10;
      }
    }

    _yaz('sf_paragraflar.pdf',
        doc((d, pg) => paragraflar(pg, sf.PdfTrueTypeFont(car, 11), 5)),
        'Syncfusion', ['ttf', 'carlito'], 6);
    _yaz(
        'sf_iki_yana.pdf',
        doc((d, pg) => paragraflar(pg, sf.PdfTrueTypeFont(tin, 11), 4,
            hiza: sf.PdfTextAlignment.justify)),
        'Syncfusion',
        ['iki-yana', 'tinos'],
        5);
    _yaz(
        'sf_tablo.pdf',
        doc((d, pg) {
          final g = sf.PdfGrid();
          g.style.font = sf.PdfTrueTypeFont(car, 10);
          g.columns.add(count: 3);
          for (final r in [
            ['Ürün', 'Adet', 'Açıklama'],
            ['Gözlük', '2', 'Teslim alındı'],
            ['İp', '9', 'Depoda'],
            ['Üzüm', '5', 'Yolda'],
          ]) {
            final row = g.rows.add();
            for (var j = 0; j < 3; j++) {
              row.cells[j].value = r[j];
            }
          }
          g.draw(page: pg, bounds: const Rect.fromLTWH(0, 0, 0, 0));
        }),
        'Syncfusion',
        ['tablo'],
        12);
    _yaz(
        'sf_form.pdf',
        doc((d, pg) {
          final f = sf.PdfTrueTypeFont(car, 11);
          for (var i = 0; i < 3; i++) {
            pg.graphics.drawString(['Adı:', 'Şehir:', 'Not:'][i], f,
                bounds: Rect.fromLTWH(0, 20.0 + i * 40, 80, 20));
            d.form.fields.add(sf.PdfTextBoxField(
                pg, 'alan$i', Rect.fromLTWH(90, 18.0 + i * 40, 300, 22),
                text: i == 1 ? 'Örnek değer' : '', font: f));
          }
        }),
        'Syncfusion',
        ['acroform'],
        3);
    _yaz('sf_sifreli.pdf',
        doc((d, pg) => paragraflar(pg, sf.PdfTrueTypeFont(car, 11), 3), owner: 'sahip'),
        'Syncfusion', ['sifreli-sahip-parolasi'], 4);
  });

  tearDownAll(() {
    File('${_out.path}/corpus_dart.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_kayit));
  });
}
