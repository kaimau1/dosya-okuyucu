"""Symbol/Wingdings madde imli örnek belge: test/fixtures/office/madde_imleri.docx

Word madde imlerini özel kod noktalarıyla yazar (Symbol U+F0B7 •, Wingdings
U+F0A7 ▪ / U+F0D8 ➢ / U+F0FC ✓) ve metin içi simgeyi w:sym ile. Görüntüleyici
bunları Unicode'a çevirmeli (assets/word/viewer.html fixSymbolFonts;
denetim: tool/check_word_bridge.js).
    python3 tool/make_symbol_bullets_docx.py
"""
import zipfile
from pathlib import Path

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'


def lvl(ilvl, char, font):
    return (f'<w:lvl w:ilvl="{ilvl}"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
            f'<w:lvlText w:val="{char}"/><w:lvlJc w:val="left"/>'
            f'<w:pPr><w:ind w:left="{720 * (ilvl + 1)}" w:hanging="360"/></w:pPr>'
            f'<w:rPr><w:rFonts w:ascii="{font}" w:hAnsi="{font}" w:hint="default"/></w:rPr></w:lvl>')


numbering = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
             f'<w:numbering xmlns:w="{W}">'
             f'<w:abstractNum w:abstractNumId="0">{lvl(0, "", "Symbol")}{lvl(1, "", "Wingdings")}</w:abstractNum>'
             f'<w:abstractNum w:abstractNumId="1">{lvl(0, "", "Wingdings")}</w:abstractNum>'
             f'<w:abstractNum w:abstractNumId="2">{lvl(0, "", "Wingdings")}</w:abstractNum>'
             f'<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
             f'<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>'
             f'<w:num w:numId="3"><w:abstractNumId w:val="2"/></w:num>'
             f'</w:numbering>')


def item(text, num, ilvl=0):
    return (f'<w:p><w:pPr><w:numPr><w:ilvl w:val="{ilvl}"/><w:numId w:val="{num}"/></w:numPr></w:pPr>'
            f'<w:r><w:t>{text}</w:t></w:r></w:p>')


body = ''.join([
    '<w:p><w:r><w:t>Evde bir parkur hazırlayın:</w:t></w:r></w:p>',
    item('Yastıkların üzerinden atlama', 1),
    item('Sandalyenin altından sürünme', 1),
    item('Alt madde', 1, 1),
    item('Ok imli madde', 2),
    item('Onay imli madde', 3),
    '<w:p><w:r><w:t xml:space="preserve">Simge: </w:t></w:r>'
    '<w:r><w:sym w:font="Wingdings" w:char="F0E0"/></w:r>'
    '<w:r><w:t xml:space="preserve"> ve </w:t></w:r>'
    '<w:r><w:sym w:font="Symbol" w:char="F061"/></w:r></w:p>',
])
document = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<w:document xmlns:w="{W}" xmlns:r="{R}"><w:body>{body}'
            f'<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body></w:document>')
content_types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                 '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                 '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                 '<Default Extension="xml" ContentType="application/xml"/>'
                 '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
                 '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
                 '</Types>')
rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>')
doc_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
            '</Relationships>')

out = Path(__file__).resolve().parent.parent / 'test/fixtures/office/madde_imleri.docx'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', content_types)
    z.writestr('_rels/.rels', rels)
    z.writestr('word/document.xml', document)
    z.writestr('word/numbering.xml', numbering)
    z.writestr('word/_rels/document.xml.rels', doc_rels)
print(out)
