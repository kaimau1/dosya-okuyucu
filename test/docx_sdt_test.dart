import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_insert_pro.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/docx_synth.dart';

/// B9 m.1 — İçerik denetimleri (`w:sdt`). Kanıt: blok denetim (kapak,
/// İçindekiler, form bölümü) TEK opak paragrafa düzleşiyordu — paragraflar
/// birleşir, biçim gider, düzenlenemez. Şimdi içindekiler kendi kabında
/// okunur, kayıtta yerinde yazılır; satır içi form denetimleri doldurulur,
/// XML farkı yalnız değer.

const _cover = '<w:sdt><w:sdtPr><w:alias w:val="Kapak"/><w:tag w:val="kapak"/>'
    '<w:id w:val="101"/></w:sdtPr><w:sdtContent>'
    '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Birinci kapak satırı</w:t></w:r></w:p>'
    '<w:p><w:r><w:t>İkinci kapak satırı</w:t></w:r></w:p>'
    '<w:p><w:r><w:t>Üçüncü kapak satırı</w:t></w:r></w:p>'
    '</w:sdtContent></w:sdt>';

String _doc(List<int> b) => synthPart(b, 'word/document.xml');

XmlElement _body(List<int> b) =>
    XmlDocument.parse(_doc(b)).findAllElements('w:body').first;

List<String> _paraXml(List<int> b) => [
      for (final p in XmlDocument.parse(_doc(b)).findAllElements('w:p'))
        p.toXmlString(),
    ];

int _find(DocxDocument d, String start) =>
    d.paras.indexWhere((p) => p.text.startsWith(start));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('blok içerik denetimi', () {
    final bytes = synthDocx(synthP('Önce') + _cover + synthP('Sonra'));

    test('3 paragraflı denetim 3 düzenlenebilir paragraf, biçim korunur', () {
      final d = DocxDocument.parse(bytes);
      expect(d.paras.map((p) => p.text), [
        'Önce',
        'Birinci kapak satırı',
        'İkinci kapak satırı',
        'Üçüncü kapak satırı',
        'Sonra',
      ]);
      expect(d.paras.any((p) => p.opaque), isFalse);
      expect(d.paras[1].styles.first.look.bold, isTrue);
      expect(d.paras[2].styles.first.look.bold, isFalse);
      expect(d.paras[1].container.name.local, 'sdtContent');
    });

    test('el değmemiş kayıt baytı baytına aynı', () {
      final d = DocxDocument.parse(bytes);
      expect(_doc(d.save()), _doc(bytes));
      expect(d.xmlDirty, isFalse);
    });

    test('denetimdeki paragraf düzenlenince yalnız o w:p değişir, kap kalır', () {
      final d = DocxDocument.parse(bytes);
      final i = _find(d, 'İkinci');
      final p = d.paras[i];
      d.paras[i] = p.replace(0, 6, 'Değişen', p.typingStyleAt(0));
      final out = d.save();
      final before = _paraXml(bytes), after = _paraXml(out);
      expect(after, hasLength(before.length));
      var diff = 0;
      for (var k = 0; k < before.length; k++) {
        if (before[k] != after[k]) diff++;
      }
      expect(diff, 1);
      final sdt = _body(out).findElements('w:sdt').single;
      expect(sdt.findAllElements('w:alias').single.getAttribute('w:val'), 'Kapak');
      expect(sdt.findAllElements('w:p'), hasLength(3));
      final back = DocxDocument.parse(out);
      expect(back.paras[i].text, 'Değişen kapak satırı');
      expect(back.paras[i].container.name.local, 'sdtContent');
    });

    test('Enter denetimin İÇİNDE yeni paragraf açar; birleştirme de içeride', () {
      final d = DocxDocument.parse(bytes);
      final i = _find(d, 'İkinci');
      final (l, r) = d.paras[i].split(d.paras[i].length);
      d.paras
        ..[i] = l
        ..insert(i + 1, r.replace(0, 0, 'Yeni satır', r.mark));
      var out = d.save();
      var body = _body(out);
      expect(body.findElements('w:p'), hasLength(2)); // Önce, Sonra
      final content = body.findAllElements('w:sdtContent').single;
      expect(content.findElements('w:p').map((p) => p.innerText),
          ['Birinci kapak satırı', 'İkinci kapak satırı', 'Yeni satır',
           'Üçüncü kapak satırı']);

      final e = DocxDocument.parse(out);
      final j = _find(e, 'Yeni satır');
      e.paras[j - 1] = e.paras[j - 1].join(e.paras[j]);
      e.paras.removeAt(j);
      out = e.save();
      body = _body(out);
      expect(body.findAllElements('w:sdtContent').single.findElements('w:p'),
          hasLength(3));
      expect(DocxDocument.parse(out).paras.map((p) => p.text),
          contains('İkinci kapak satırıYeni satır'));
    });

    test('denetimdeyken eklenen tablo denetimin ARDINA gelir', () {
      final d = DocxDocument.parse(bytes);
      final at = d.insertTable(_find(d, 'İkinci'), 1, 1);
      expect(at, _find(d, 'Üçüncü') + 1);
      final out = d.save();
      expect(
          _body(out).childElements.map((e) => e.name.local),
          ['p', 'sdt', 'tbl', 'p', 'p', 'sectPr']);
    });
  });

  test('kilitli ya da veri bağlı denetim satır satır okunur ama düzenlenmez', () {
    String locked(String pr, String text) =>
        '<w:sdt><w:sdtPr>$pr</w:sdtPr><w:sdtContent>${synthP('$text 1')}'
        '${synthP('$text 2')}</w:sdtContent></w:sdt>';
    final bytes = synthDocx(
        locked('<w:lock w:val="sdtContentLocked"/>', 'Kilitli') +
            locked('<w:dataBinding w:xpath="/a/b" w:storeItemID="{1}"/>', 'Bağlı'));
    final d = DocxDocument.parse(bytes);
    expect(d.paras.map((p) => p.text),
        ['Kilitli 1', 'Kilitli 2', 'Bağlı 1', 'Bağlı 2']);
    expect(d.paras.every((p) => p.opaque), isTrue);
    expect(_doc(d.save()), _doc(bytes));
  });

  test('tablo içeren denetim ve hücre içindeki denetim okunur', () {
    const grid = '<w:tblGrid><w:gridCol w:w="3000"/></w:tblGrid>';
    final bytes = synthDocx(
        '<w:sdt><w:sdtPr><w:id w:val="5"/></w:sdtPr><w:sdtContent>'
        '<w:tbl>$grid<w:tr><w:tc>${synthP('Hücre A')}</w:tc></w:tr></w:tbl>'
        '</w:sdtContent></w:sdt>'
        '<w:tbl>$grid<w:tr><w:tc><w:sdt><w:sdtPr><w:id w:val="6"/></w:sdtPr>'
        '<w:sdtContent>${synthP('Hücre B')}</w:sdtContent></w:sdt></w:tc></w:tr></w:tbl>'
        '${synthP('Son')}');
    final d = DocxDocument.parse(bytes);
    final a = d.paras[_find(d, 'Hücre A')], b = d.paras[_find(d, 'Hücre B')];
    expect(a.cell, isNotNull);
    expect(b.cell, isNotNull);
    expect(a.opaque || b.opaque, isFalse);
    final i = _find(d, 'Hücre B');
    d.paras[i] = b.replace(6, 7, 'C', b.typingStyleAt(6));
    final out = d.save();
    final cell = _body(out).findElements('w:tbl').single;
    expect(cell.findAllElements('w:sdt').single.innerText, 'Hücre C');
  });

  group('satır içi form denetimleri', () {
    const text = '<w:p><w:r><w:t xml:space="preserve">Ad: </w:t></w:r>'
        '<w:sdt><w:sdtPr><w:alias w:val="Ad Soyad"/><w:tag w:val="ad"/>'
        '<w:id w:val="201"/><w:showingPlcHdr/><w:text/></w:sdtPr><w:sdtContent>'
        '<w:r><w:rPr><w:rStyle w:val="PlaceholderText"/></w:rPr>'
        '<w:t>Metin girin</w:t></w:r></w:sdtContent></w:sdt></w:p>';
    const box = '<w:p><w:sdt><w:sdtPr><w:id w:val="202"/><w14:checkbox>'
        '<w14:checked w14:val="0"/>'
        '<w14:checkedState w14:val="2612" w14:font="MS Gothic"/>'
        '<w14:uncheckedState w14:val="2610" w14:font="MS Gothic"/>'
        '</w14:checkbox></w:sdtPr><w:sdtContent><w:r><w:rPr>'
        '<w:rFonts w:ascii="MS Gothic" w:hAnsi="MS Gothic"/></w:rPr>'
        '<w:t>☐</w:t></w:r></w:sdtContent></w:sdt>'
        '<w:r><w:t xml:space="preserve"> Onaylıyorum</w:t></w:r></w:p>';
    const list = '<w:p><w:sdt><w:sdtPr><w:id w:val="203"/>'
        '<w:dropDownList w:lastValue="b"><w:listItem w:displayText="Seçin" w:value=""/>'
        '<w:listItem w:displayText="Elma" w:value="a"/>'
        '<w:listItem w:displayText="Armut" w:value="b"/></w:dropDownList>'
        '</w:sdtPr><w:sdtContent><w:r><w:t>Armut</w:t></w:r></w:sdtContent>'
        '</w:sdt></w:p>';
    const date = '<w:p><w:sdt><w:sdtPr><w:id w:val="204"/><w:showingPlcHdr/>'
        '<w:date><w:dateFormat w:val="dd.MM.yyyy"/><w:lid w:val="tr-TR"/>'
        '<w:storeMappedDataAs w:val="dateTime"/><w:calendar w:val="gregorian"/>'
        '</w:date></w:sdtPr><w:sdtContent><w:r><w:rPr>'
        '<w:rStyle w:val="PlaceholderText"/></w:rPr><w:t>Tarih seçin</w:t></w:r>'
        '</w:sdtContent></w:sdt></w:p>';
    const pic = '<w:p><w:sdt><w:sdtPr><w:id w:val="205"/><w:docPartObj>'
        '<w:docPartGallery w:val="Page Numbers (Top of Page)"/></w:docPartObj>'
        '</w:sdtPr><w:sdtContent><w:r><w:t>Sayfa</w:t></w:r></w:sdtContent>'
        '</w:sdt></w:p>';
    final bytes = synthDocx(text + box + list + date + pic);

    (int, int) at(DocxDocument d, int para) {
      final p = d.paras[para];
      return (para, p.atoms.indexWhere((a) => a?.kind == DocxAtomKind.control));
    }

    test('türler okunur; galeri denetimi doldurulmaz', () {
      final d = DocxDocument.parse(bytes);
      DocxControl c(int i) {
        final (p, k) = at(d, i);
        return d.controlOf(d.paras[p].atoms[k])!;
      }

      expect(c(0).type, DocxControlType.text);
      expect(c(0).title, 'Ad Soyad');
      expect(c(0).value, '');
      expect(c(0).placeholder, 'Metin girin');
      expect(c(1).type, DocxControlType.checkbox);
      expect(c(1).checked, isFalse);
      expect(c(2).type, DocxControlType.dropdown);
      expect(c(2).value, 'Armut');
      expect(c(2).items.map((x) => x.$1), ['Seçin', 'Elma', 'Armut']);
      expect(c(3).type, DocxControlType.date);
      expect(c(3).date, isNull);
      expect(at(d, 4).$2, -1);
      expect(d.paras[4].atoms.whereType<DocxAtom>().single.kind,
          DocxAtomKind.inline);
      expect(_doc(d.save()), _doc(bytes));
    });

    test('onay kutusu: XML farkı yalnız işaret ve simge', () {
      final d = DocxDocument.parse(bytes);
      final (i, k) = at(d, 1);
      d.paras[i] = d.fillControl(d.paras[i], k, checked: true);
      final out = d.save();
      final before = _paraXml(bytes), after = _paraXml(out);
      for (var n = 0; n < before.length; n++) {
        if (n == 1) continue;
        expect(after[n], before[n]);
      }
      expect(after[1],
          before[1].replaceFirst('w14:val="0"', 'w14:val="1"').replaceFirst('☐', '☒'));
      final back = DocxDocument.parse(out);
      final (bi, bk) = at(back, 1);
      expect(back.controlOf(back.paras[bi].atoms[bk])!.checked, isTrue);
    });

    test('metin, liste, tarih doldurulur; kap (kimlik, etiket) korunur', () {
      final d = DocxDocument.parse(bytes);
      var (i, k) = at(d, 0);
      d.paras[i] = d.fillControl(d.paras[i], k, text: 'Ayşe Yılmaz');
      (i, k) = at(d, 2);
      d.paras[i] = d.fillControl(d.paras[i], k, text: 'Elma');
      (i, k) = at(d, 3);
      d.paras[i] = d.fillControl(d.paras[i], k, date: DateTime(2026, 11, 19));
      final out = d.save();
      final xml = XmlDocument.parse(_doc(out));
      final sdts = xml.findAllElements('w:sdt').toList();
      expect(sdts[0].findAllElements('w:tag').single.getAttribute('w:val'), 'ad');
      expect(sdts[0].findAllElements('w:id').single.getAttribute('w:val'), '201');
      expect(sdts[0].findAllElements('w:showingPlcHdr'), isEmpty);
      expect(sdts[0].findAllElements('w:rStyle'), isEmpty);
      expect(sdts[2].findAllElements('w:dropDownList').single.getAttribute('w:lastValue'), 'a');
      expect(sdts[3].findAllElements('w:date').single.getAttribute('w:fullDate'),
          '2026-11-19T00:00:00Z');

      final back = DocxDocument.parse(out);
      DocxControl c(int n) {
        final (p, q) = at(back, n);
        return back.controlOf(back.paras[p].atoms[q])!;
      }

      expect(c(0).value, 'Ayşe Yılmaz');
      expect(c(2).value, 'Elma');
      expect(c(3).value, '19.11.2026');
      expect(c(3).date, DateTime.utc(2026, 11, 19));
      expect(back.plainText(), contains('Ad: Ayşe Yılmaz'));
    });

    test('düzenleyici: doldur → geri al tek adım', () {
      final d = DocxDocument.parse(bytes);
      final c = DocxEditController(d);
      final (i, k) = at(d, 0);
      c.fillControlAt(i, k, text: 'Deneme');
      expect(c.controlAt(i, k)!.value, 'Deneme');
      c.undo();
      expect(c.controlAt(i, k)!.value, '');
      expect(c.controlAt(i, k)!.placeholder, 'Metin girin');
    });
  });

  test('Word tarih biçimi', () {
    final d = DateTime(2026, 3, 5);
    expect(docxFormatDate(d, 'd.M.yy'), '5.3.26');
    expect(docxFormatDate(d, 'd MMMM yyyy dddd'), '5 Mart 2026 Perşembe');
    expect(docxFormatDate(d, 'MMMM d, yyyy', lang: 'en-US'), 'March 5, 2026');
    expect(docxFormatDate(d, "dd'.'MM"), '05.03');
  });

  group('paket işlemleri denetimli belgede', () {
    // Kök: modelParagraphs blok sdt'yi tek öğe sayıyordu; editör (m.1'den
    // beri) içindeki paragrafları ayrı okuyor → Araçlar işlemleri (kenarlık,
    // çapraz başvuru, İçindekiler) sdt'den sonraki paragrafta kayıyordu.
    const cellSdt = '<w:tbl><w:tr><w:tc><w:sdt><w:sdtContent>'
        '<w:p><w:r><w:t>Hücre bir</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Hücre iki</w:t></w:r></w:p>'
        '</w:sdtContent></w:sdt></w:tc><w:tc><w:p/></w:tc></w:tr></w:tbl>';
    final bytes = synthDocx(synthP('Önce') + _cover + cellSdt + synthP('Sonra'));

    test('model paragrafları editör paragraflarıyla bire bir', () {
      final d = DocxDocument.parse(bytes);
      final m = DocxPackage.open(bytes).modelParagraphs();
      expect(m.length, d.paras.length);
      for (var i = 0; i < m.length; i++) {
        expect(m[i].innerText, d.paras[i].text, reason: 'paragraf $i');
      }
    });

    test('denetimden sonraki paragrafa kenarlık doğru yere', () {
      final d = DocxDocument.parse(bytes);
      final i = _find(d, 'Sonra');
      final pkg = DocxPackage.open(bytes);
      DocxInsertPro.paraBorder(i, 'box')(pkg);
      final out = DocxDocument.parse(pkg.save());
      final p = out.paras[_find(out, 'Sonra')];
      expect(p.pPr?.findAllElements('w:pBdr'), isNotEmpty);
      expect(out.paras[_find(out, 'Üçüncü')].pPr?.findAllElements('w:pBdr') ?? const [], isEmpty);
    });
  });
}
