/// **Faz 37 madde 4 — Word şablonları** (CV, mektup, rapor, fatura,
/// tutanak). Her biri geçerli, Word/LibreOffice'te onarımsız açılan tam bir
/// OOXML paketi: stiller (Normal, Konu Başlığı, Başlık 1–3, Alıntı, Liste
/// Paragrafı, Tablo Kılavuzu), madde imi numaralandırması, A4 bölüm.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const kDocxTemplateIds = ['cv', 'letter', 'report', 'invoice', 'minutes'];

abstract final class DocxTemplates {
  static Uint8List build(String id, {bool turkish = true, DateTime? now}) {
    final d = now ?? DateTime.now();
    final date =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final t = turkish ? _tr : _en;
    final body = switch (id) {
      'cv' => _cv(t),
      'letter' => _letter(t, date),
      'report' => _report(t, date),
      'invoice' => _invoice(t, date),
      'minutes' => _minutes(t, date),
      _ => throw ArgumentError('şablon: $id'),
    };
    return _package(body);
  }

  // ── içerik ──────────────────────────────────────────────────────────────

  static String _cv(Map<String, String> t) => [
        _p(t['cv_name']!, style: 'Title'),
        _p(t['cv_contact']!, align: 'left'),
        _p(t['cv_profile_h']!, style: 'Heading1'),
        _p(t['cv_profile']!),
        _p(t['cv_exp_h']!, style: 'Heading1'),
        _p(t['cv_job1']!, style: 'Heading2'),
        _bullet(t['cv_job1_a']!),
        _bullet(t['cv_job1_b']!),
        _p(t['cv_job2']!, style: 'Heading2'),
        _bullet(t['cv_job2_a']!),
        _p(t['cv_edu_h']!, style: 'Heading1'),
        _p(t['cv_edu']!),
        _p(t['cv_skills_h']!, style: 'Heading1'),
        _bullet(t['cv_skill1']!),
        _bullet(t['cv_skill2']!),
        _bullet(t['cv_skill3']!),
        _p(t['cv_lang_h']!, style: 'Heading1'),
        _p(t['cv_lang']!),
      ].join();

  static String _letter(Map<String, String> t, String date) => [
        _p(t['lt_sender']!, align: 'right'),
        _p(date, align: 'right'),
        _p(''),
        _p(t['lt_to']!),
        _p(''),
        _p(t['lt_subject']!, bold: true),
        _p(t['lt_greeting']!),
        _p(t['lt_body1']!, align: 'both'),
        _p(t['lt_body2']!, align: 'both'),
        _p(t['lt_close']!),
        _p(''),
        _p(t['lt_sign']!, align: 'right'),
      ].join();

  static String _report(Map<String, String> t, String date) => [
        _p(t['rp_title']!, style: 'Title'),
        _p('${t['rp_author']!} · $date', style: 'Subtitle'),
        _p(t['rp_summary_h']!, style: 'Heading1'),
        _p(t['rp_summary']!, align: 'both'),
        _p(t['rp_intro_h']!, style: 'Heading1'),
        _p(t['rp_intro']!, align: 'both'),
        _p(t['rp_method_h']!, style: 'Heading1'),
        _p(t['rp_method']!, align: 'both'),
        _p(t['rp_find_h']!, style: 'Heading1'),
        _p(t['rp_find_sub']!, style: 'Heading2'),
        _bullet(t['rp_find1']!),
        _bullet(t['rp_find2']!),
        _table([
          [t['rp_col1']!, t['rp_col2']!, t['rp_col3']!],
          ['A', '120', '%40'],
          ['B', '180', '%60'],
        ]),
        _p(t['rp_quote']!, style: 'Quote'),
        _p(t['rp_result_h']!, style: 'Heading1'),
        _p(t['rp_result']!, align: 'both'),
      ].join();

  static String _invoice(Map<String, String> t, String date) => [
        _p(t['iv_title']!, style: 'Title'),
        _table([
          [t['iv_seller']!, t['iv_buyer']!],
          [t['iv_seller_info']!, t['iv_buyer_info']!],
        ], header: false, borders: false),
        _p('${t['iv_no']!}: 2026-001   ${t['iv_date']!}: $date'),
        _table([
          [t['iv_item']!, t['iv_qty']!, t['iv_price']!, t['iv_total']!],
          [t['iv_item1']!, '2', '500,00', '1.000,00'],
          [t['iv_item2']!, '1', '750,00', '750,00'],
          ['', '', t['iv_sub']!, '1.750,00'],
          ['', '', t['iv_vat']!, '350,00'],
          ['', '', t['iv_grand']!, '2.100,00'],
        ]),
        _p(t['iv_note']!, style: 'Quote'),
      ].join();

  static String _minutes(Map<String, String> t, String date) => [
        _p(t['mn_title']!, style: 'Title'),
        _table([
          [t['mn_date']!, date],
          [t['mn_place']!, '…'],
          [t['mn_chair']!, '…'],
          [t['mn_attend']!, '…'],
        ], header: false),
        _p(t['mn_agenda_h']!, style: 'Heading1'),
        _numbered(t['mn_agenda1']!),
        _numbered(t['mn_agenda2']!),
        _numbered(t['mn_agenda3']!),
        _p(t['mn_talks_h']!, style: 'Heading1'),
        _p(t['mn_talks']!, align: 'both'),
        _p(t['mn_dec_h']!, style: 'Heading1'),
        _table([
          [t['mn_dec']!, t['mn_owner']!, t['mn_due']!],
          ['…', '…', '…'],
          ['…', '…', '…'],
        ]),
        _p(''),
        _table([
          [t['mn_sign']!, t['mn_sign']!, t['mn_sign']!],
          ['', '', ''],
        ], header: false, borders: false),
      ].join();

  // ── yapı taşları ─────────────────────────────────────────────────────────

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _runs(String text, {bool bold = false}) {
    final lines = text.split('\n');
    final rPr = bold ? '<w:rPr><w:b/></w:rPr>' : '';
    return [
      for (var i = 0; i < lines.length; i++)
        '${i > 0 ? '<w:r><w:br/></w:r>' : ''}<w:r>$rPr<w:t xml:space="preserve">${_esc(lines[i])}</w:t></w:r>',
    ].join();
  }

  static String _p(String text,
      {String? style, String? align, bool bold = false, String extraPPr = ''}) {
    final pPr = [
      if (style != null) '<w:pStyle w:val="$style"/>',
      extraPPr,
      if (align != null) '<w:jc w:val="$align"/>',
    ].join();
    return '<w:p>${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}'
        '${text.isEmpty ? '' : _runs(text, bold: bold)}</w:p>';
  }

  static String _bullet(String text) => _p(text,
      style: 'ListParagraph',
      extraPPr: '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>');

  static String _numbered(String text) => _p(text,
      style: 'ListParagraph',
      extraPPr: '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr>');

  static String _table(List<List<String>> rows,
      {bool header = true, bool borders = true}) {
    final cols = rows.first.length;
    final each = (9026 / cols).floor();
    final b = borders
        ? '<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
            '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
            '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
            '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
            '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
            '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders>'
        : '';
    final sb = StringBuffer('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="5000" w:type="pct"/>$b<w:tblLook w:val="04A0" w:firstRow="1" '
        'w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>'
        '</w:tblPr><w:tblGrid>');
    for (var c = 0; c < cols; c++) {
      sb.write('<w:gridCol w:w="$each"/>');
    }
    sb.write('</w:tblGrid>');
    for (var r = 0; r < rows.length; r++) {
      final head = header && r == 0;
      sb.write('<w:tr>${head ? '<w:trPr><w:tblHeader/></w:trPr>' : ''}');
      for (final cell in rows[r]) {
        sb.write('<w:tc><w:tcPr><w:tcW w:w="$each" w:type="dxa"/>'
            '${head ? '<w:shd w:val="clear" w:color="auto" w:fill="D9E2F3"/>' : ''}'
            '</w:tcPr>${_p(cell, bold: head)}</w:tc>');
      }
      sb.write('</w:tr>');
    }
    sb.write('</w:tbl>');
    return sb.toString();
  }

  static Uint8List _package(String body) {
    const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
    const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
    final files = <String, String>{
      '[Content_Types].xml': '$head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
          '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
          '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
          '</Types>',
      '_rels/.rels': '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
          '</Relationships>',
      'word/_rels/document.xml.rels': '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
          '</Relationships>',
      'word/document.xml': '$head<w:document $ns><w:body>$body'
          '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>'
          '<w:cols w:space="708"/></w:sectPr></w:body></w:document>',
      'word/styles.xml': '$head<w:styles $ns>$_styles</w:styles>',
      'word/numbering.xml': '$head<w:numbering $ns>$_numbering</w:numbering>',
    };
    final a = Archive();
    for (final MapEntry(:key, :value) in files.entries) {
      final b = utf8.encode(value);
      a.addFile(ArchiveFile(key, b.length, b));
    }
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  static String _pStyle(String id, String name, String pPr, String rPr,
          {bool heading = false}) =>
      '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/>'
      '<w:basedOn w:val="Normal"/><w:next w:val="Normal"/>'
      '${heading ? '<w:uiPriority w:val="9"/>' : ''}<w:qFormat/>'
      '<w:pPr>$pPr</w:pPr><w:rPr>$rPr</w:rPr></w:style>';

  static final _styles = [
    '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri" w:eastAsia="Calibri"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="tr-TR"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="259" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>',
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>',
    _pStyle('Title', 'Title', '<w:spacing w:after="80"/><w:contextualSpacing/>',
        '<w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/><w:spacing w:val="-10"/><w:kern w:val="28"/><w:sz w:val="56"/><w:szCs w:val="56"/>'),
    _pStyle('Subtitle', 'Subtitle', '<w:spacing w:after="160"/>',
        '<w:color w:val="595959"/><w:spacing w:val="15"/><w:sz w:val="28"/><w:szCs w:val="28"/>'),
    _pStyle('Heading1', 'heading 1',
        '<w:keepNext/><w:keepLines/><w:spacing w:before="360" w:after="80"/><w:outlineLvl w:val="0"/>',
        '<w:color w:val="2F5496"/><w:sz w:val="32"/><w:szCs w:val="32"/>', heading: true),
    _pStyle('Heading2', 'heading 2',
        '<w:keepNext/><w:keepLines/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="1"/>',
        '<w:color w:val="2F5496"/><w:sz w:val="26"/><w:szCs w:val="26"/>', heading: true),
    _pStyle('Heading3', 'heading 3',
        '<w:keepNext/><w:keepLines/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="2"/>',
        '<w:color w:val="1F3763"/><w:sz w:val="24"/><w:szCs w:val="24"/>', heading: true),
    _pStyle('Quote', 'Quote', '<w:spacing w:before="200" w:after="160"/><w:ind w:left="864" w:right="864"/><w:jc w:val="center"/>',
        '<w:i/><w:iCs/><w:color w:val="404040"/>'),
    _pStyle('ListParagraph', 'List Paragraph', '<w:ind w:left="720"/><w:contextualSpacing/>', ''),
    '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/>'
        '<w:tblPr><w:tblCellMar><w:left w:w="108" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>',
  ].join();

  static const _numbering =
      '<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>'
      '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/>'
      '<w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>'
      '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>'
      '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/>'
      '<w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>'
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
      '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>';

  // ── metinler (belge İÇERİĞİ — arayüz dili Türkçe değilse İngilizce) ──────

  static const _tr = <String, String>{
    'cv_name': 'Ad Soyad',
    'cv_contact': 'Şehir · 0 (5xx) xxx xx xx · ad.soyad@ornek.com · linkedin.com/in/adsoyad',
    'cv_profile_h': 'Profil',
    'cv_profile': 'Alanında deneyimli, sonuç odaklı, ekip çalışmasına yatkın bir profesyonel. Kendinizi iki üç cümleyle burada anlatın.',
    'cv_exp_h': 'Deneyim',
    'cv_job1': 'Pozisyon — Şirket (2022 – Bugün)',
    'cv_job1_a': 'Üstlendiğiniz en önemli sorumluluk ve ölçülebilir sonucu',
    'cv_job1_b': 'Yönettiğiniz proje ya da elde ettiğiniz başarı',
    'cv_job2': 'Pozisyon — Şirket (2018 – 2022)',
    'cv_job2_a': 'Görev ve katkılarınız',
    'cv_edu_h': 'Eğitim',
    'cv_edu': 'Bölüm, Üniversite (2014 – 2018)',
    'cv_skills_h': 'Yetenekler',
    'cv_skill1': 'Yetenek 1',
    'cv_skill2': 'Yetenek 2',
    'cv_skill3': 'Yetenek 3',
    'cv_lang_h': 'Diller',
    'cv_lang': 'Türkçe (ana dil) · İngilizce (ileri)',
    'lt_sender': 'Ad Soyad\nAdres\nTelefon · E-posta',
    'lt_to': 'Sayın Alıcı Adı\nKurum\nAdres',
    'lt_subject': 'Konu: Mektubun konusu',
    'lt_greeting': 'Sayın Alıcı,',
    'lt_body1': 'Mektubun ilk paragrafında yazma amacınızı kısaca belirtin.',
    'lt_body2': 'İkinci paragrafta ayrıntıları, talebinizi ya da önerinizi açıklayın.',
    'lt_close': 'Gereğini bilgilerinize arz ederim.\nSaygılarımla,',
    'lt_sign': 'Ad Soyad\nİmza',
    'rp_title': 'Rapor Başlığı',
    'rp_author': 'Hazırlayan',
    'rp_summary_h': 'Özet',
    'rp_summary': 'Raporun amacı, yöntemi ve ana bulguları tek paragrafta.',
    'rp_intro_h': 'Giriş',
    'rp_intro': 'Konunun arka planı ve raporun kapsamı.',
    'rp_method_h': 'Yöntem',
    'rp_method': 'Verinin nasıl toplandığı ve incelendiği.',
    'rp_find_h': 'Bulgular',
    'rp_find_sub': 'Ana bulgular',
    'rp_find1': 'Birinci bulgu',
    'rp_find2': 'İkinci bulgu',
    'rp_col1': 'Kalem',
    'rp_col2': 'Değer',
    'rp_col3': 'Pay',
    'rp_quote': 'Öne çıkan bir alıntı ya da önemli not.',
    'rp_result_h': 'Sonuç ve Öneriler',
    'rp_result': 'Bulgulardan çıkan sonuçlar ve önerilen adımlar.',
    'iv_title': 'FATURA',
    'iv_seller': 'Satıcı',
    'iv_buyer': 'Alıcı',
    'iv_seller_info': 'Firma Adı\nAdres\nVergi Dairesi / No',
    'iv_buyer_info': 'Müşteri Adı\nAdres\nVergi Dairesi / No',
    'iv_no': 'Fatura No',
    'iv_date': 'Tarih',
    'iv_item': 'Açıklama',
    'iv_qty': 'Miktar',
    'iv_price': 'Birim Fiyat (₺)',
    'iv_total': 'Tutar (₺)',
    'iv_item1': 'Ürün / Hizmet 1',
    'iv_item2': 'Ürün / Hizmet 2',
    'iv_sub': 'Ara Toplam',
    'iv_vat': 'KDV (%20)',
    'iv_grand': 'Genel Toplam',
    'iv_note': 'Ödeme: 30 gün içinde · IBAN: TR00 0000 0000 0000 0000 0000 00',
    'mn_title': 'TOPLANTI TUTANAĞI',
    'mn_date': 'Tarih',
    'mn_place': 'Yer',
    'mn_chair': 'Başkan',
    'mn_attend': 'Katılımcılar',
    'mn_agenda_h': 'Gündem',
    'mn_agenda1': 'Açılış ve yoklama',
    'mn_agenda2': 'Gündem maddesi',
    'mn_agenda3': 'Dilek ve temenniler',
    'mn_talks_h': 'Görüşmeler',
    'mn_talks': 'Görüşülen konuların özeti.',
    'mn_dec_h': 'Alınan Kararlar',
    'mn_dec': 'Karar',
    'mn_owner': 'Sorumlu',
    'mn_due': 'Termin',
    'mn_sign': 'Ad Soyad / İmza',
  };

  static const _en = <String, String>{
    'cv_name': 'Your Name',
    'cv_contact': 'City · +00 000 000 0000 · your.name@example.com · linkedin.com/in/yourname',
    'cv_profile_h': 'Profile',
    'cv_profile': 'Experienced, results-driven professional and team player. Describe yourself here in two or three sentences.',
    'cv_exp_h': 'Experience',
    'cv_job1': 'Position — Company (2022 – Present)',
    'cv_job1_a': 'Your key responsibility and a measurable result',
    'cv_job1_b': 'A project you led or an achievement',
    'cv_job2': 'Position — Company (2018 – 2022)',
    'cv_job2_a': 'Duties and contributions',
    'cv_edu_h': 'Education',
    'cv_edu': 'Degree, University (2014 – 2018)',
    'cv_skills_h': 'Skills',
    'cv_skill1': 'Skill 1',
    'cv_skill2': 'Skill 2',
    'cv_skill3': 'Skill 3',
    'cv_lang_h': 'Languages',
    'cv_lang': 'English (native) · Turkish (intermediate)',
    'lt_sender': 'Your Name\nAddress\nPhone · Email',
    'lt_to': 'Recipient Name\nOrganisation\nAddress',
    'lt_subject': 'Subject: Letter subject',
    'lt_greeting': 'Dear Recipient,',
    'lt_body1': 'State the purpose of your letter briefly in the first paragraph.',
    'lt_body2': 'Explain the details, your request or proposal in the second paragraph.',
    'lt_close': 'Thank you for your consideration.\nSincerely,',
    'lt_sign': 'Your Name\nSignature',
    'rp_title': 'Report Title',
    'rp_author': 'Prepared by',
    'rp_summary_h': 'Summary',
    'rp_summary': 'The purpose, method and key findings in one paragraph.',
    'rp_intro_h': 'Introduction',
    'rp_intro': 'Background and scope of the report.',
    'rp_method_h': 'Method',
    'rp_method': 'How the data was collected and analysed.',
    'rp_find_h': 'Findings',
    'rp_find_sub': 'Key findings',
    'rp_find1': 'First finding',
    'rp_find2': 'Second finding',
    'rp_col1': 'Item',
    'rp_col2': 'Value',
    'rp_col3': 'Share',
    'rp_quote': 'A highlighted quote or important note.',
    'rp_result_h': 'Conclusions and Recommendations',
    'rp_result': 'Conclusions drawn from the findings and recommended next steps.',
    'iv_title': 'INVOICE',
    'iv_seller': 'Seller',
    'iv_buyer': 'Bill to',
    'iv_seller_info': 'Company Name\nAddress\nTax ID',
    'iv_buyer_info': 'Customer Name\nAddress\nTax ID',
    'iv_no': 'Invoice No',
    'iv_date': 'Date',
    'iv_item': 'Description',
    'iv_qty': 'Qty',
    'iv_price': 'Unit Price',
    'iv_total': 'Amount',
    'iv_item1': 'Product / Service 1',
    'iv_item2': 'Product / Service 2',
    'iv_sub': 'Subtotal',
    'iv_vat': 'VAT (20%)',
    'iv_grand': 'Total',
    'iv_note': 'Payment due within 30 days · IBAN: 00 0000 0000 0000 0000',
    'mn_title': 'MEETING MINUTES',
    'mn_date': 'Date',
    'mn_place': 'Location',
    'mn_chair': 'Chair',
    'mn_attend': 'Attendees',
    'mn_agenda_h': 'Agenda',
    'mn_agenda1': 'Opening and roll call',
    'mn_agenda2': 'Agenda item',
    'mn_agenda3': 'Any other business',
    'mn_talks_h': 'Discussion',
    'mn_talks': 'Summary of the topics discussed.',
    'mn_dec_h': 'Decisions',
    'mn_dec': 'Decision',
    'mn_owner': 'Owner',
    'mn_due': 'Due',
    'mn_sign': 'Name / Signature',
  };
}
