#!/usr/bin/env python3
"""Düşük donanım ölçüm verisi üreticisi (FAZ_PLANI Ek D, Faz 4).

Üretir (hedef klasörün altına):
  klasor_5000/    5.000 küçük metin dosyası (gezgin kaydırma + seçim)
  galeri_2000/    2.000 PNG (galeri kaydırma, RSS)
  belge_100.pdf   100 sayfalık metinli PDF (açılış süresi)
  tablo_10k.csv   10.000 satırlık tablo (Excel ekranı CSV'yi de açar)
  tablo_100k.xlsx 100.000 satırlık xlsx (integration_test, Faz 42 / 6)
  word_300.docx   ~300 sayfa docx (Faz 37 perf + B3.3d kapanış/menü)
  slayt_300.pptx  300 slayt (Faz 38 perf; test/fixtures/office/sunum.pptx çoğaltılır)
  tablo_10k_x20.xlsx 10 bin × 20 xlsx (K23 / B3.3a açılış hedefi, P12)
  --buyuk ile ek olarak (Faz 42 / 2, büyük dosya tavanı):
  buyuk_100mb.xlsx ~100 MB xlsx (akış önizlemesi, bellek tavanı)
  buyuk_100mb.pdf  ~100 MB PDF (görüntüleyici akışla; araçlar bütçe uyarısı)

Kullanım:  python3 tool/make_test_tree.py <hedef> [--buyuk] ; sonra
           adb push <hedef> /sdcard/DosyaOkuyucuOlcum
Bağımlılık yok (yalnız standart kütüphane).
"""
import os
import random
import struct
import sys
import zipfile
import zlib


def png(w, h, rgb):
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def pdf(pages):
    objs = []
    kids = ' '.join(f'{3 + 2 * i} 0 R' for i in range(pages))
    objs.append('<< /Type /Catalog /Pages 2 0 R >>')
    objs.append(f'<< /Type /Pages /Kids [{kids}] /Count {pages} >>')
    font = 3 + 2 * pages
    for i in range(pages):
        objs.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
                    f'/Resources << /Font << /F1 {font} 0 R >> >> /Contents {4 + 2 * i} 0 R >>')
        lines = ''.join(f'BT /F1 11 Tf 50 {800 - 14 * k} Td (Sayfa {i + 1} satir {k + 1} - olcum metni) Tj ET\n'
                        for k in range(50))
        objs.append(f'<< /Length {len(lines)} >>\nstream\n{lines}endstream')
    objs.append('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    out = b'%PDF-1.4\n'
    offs = []
    for n, o in enumerate(objs, 1):
        offs.append(len(out))
        out += f'{n} 0 obj\n{o}\nendobj\n'.encode('latin-1')
    xref = len(out)
    out += f'xref\n0 {len(objs) + 1}\n0000000000 65535 f \n'.encode()
    out += ''.join(f'{o:010d} 00000 n \n' for o in offs).encode()
    out += f'trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode()
    return out


_XLSX_PARTS = {
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Veri" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '</Relationships>',
}


def xlsx(path, rows=None, target_bytes=None, cols=7):
    """Satır içi dizeli (sharedStrings yok) tek sayfalık xlsx — akışla yazılır.

    [rows] verilirse o kadar satır; [target_bytes] verilirse dosya o boyuta
    ulaşana dek (rastgele sayılar: sıkışmaz, 100 MB gerçekçi kalır).
    [cols] sütun (≤ 26): sonuncusu metin, öncekiler sayı.
    """
    rnd = random.Random(42)
    with open(path, 'wb') as raw, zipfile.ZipFile(raw, 'w', zipfile.ZIP_DEFLATED) as z:
        for n, body in _XLSX_PARTS.items():
            z.writestr(n, body)
        with z.open('xl/worksheets/sheet1.xml', 'w', force_zip64=True) as s:
            s.write(b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                    b'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>')
            i = 0
            while True:
                if rows is not None and i >= rows:
                    break
                if target_bytes is not None and i % 5000 == 0 and raw.tell() >= target_bytes:
                    break
                r = i + 1
                cells = ''.join(f'<c r="{chr(65 + c)}{r}"><v>{rnd.random() * 1e6:.6f}</v></c>' for c in range(cols - 1))
                s.write(f'<row r="{r}">{cells}<c r="{chr(64 + cols)}{r}" t="inlineStr"><is><t>satir {r}</t></is></c></row>'.encode())
                i += 1
            s.write(b'</sheetData></worksheet>')


_W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'


def docx(path, paras=3000):
    """~300 sayfalık düz docx (Faz 37 perf, B3.3d): her 10 paragrafta bir Başlık 1."""
    rnd = random.Random(7)
    words = 'belge ölçüm sayfa düzen paragraf satır yazı çizim kaydırma açılış'.split()
    body = []
    for i in range(paras):
        if i % 10 == 0:
            body.append(f'<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Bölüm {i // 10 + 1}</w:t></w:r></w:p>')
        text = ' '.join(rnd.choice(words) for _ in range(45))
        body.append(f'<w:p><w:r><w:t>{text}</w:t></w:r></w:p>')
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml',
                   '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                   '<Default Extension="xml" ContentType="application/xml"/>'
                   '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
        z.writestr('_rels/.rels',
                   '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/document.xml',
                   f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="{_W}"><w:body>'
                   + ''.join(body) + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:body></w:document>')


_SLIDE_CT = 'application/vnd.openxmlformats-officedocument.presentationml.slide+xml'


def pptx(path, slides=300):
    """Depodaki 2 slaytlık `sunum.pptx` örneğinin slaytları çoğaltılarak (Faz 38 perf)."""
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'test', 'fixtures', 'office', 'sunum.pptx')
    with zipfile.ZipFile(src) as s:
        parts = {n: s.read(n) for n in s.namelist()}
    tpl = [(parts[f'ppt/slides/slide{k}.xml'], parts[f'ppt/slides/_rels/slide{k}.xml.rels']) for k in (1, 2)]
    ids, rels, cts = [], [], []
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for n, b in parts.items():
            if not n.startswith('ppt/slides/') and n not in (
                    'ppt/presentation.xml', 'ppt/_rels/presentation.xml.rels', '[Content_Types].xml'):
                z.writestr(n, b)
        for i in range(1, slides + 1):
            xml, rel = tpl[i % 2]
            z.writestr(f'ppt/slides/slide{i}.xml', xml)
            z.writestr(f'ppt/slides/_rels/slide{i}.xml.rels', rel)
            ids.append(f'<p:sldId id="{255 + i}" r:id="rId{100 + i}"/>')
            rels.append(f'<Relationship Id="rId{100 + i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>')
            cts.append(f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="{_SLIDE_CT}"/>')
        pres = parts['ppt/presentation.xml'].decode()
        a, b = pres.index('<p:sldIdLst>') + len('<p:sldIdLst>'), pres.index('</p:sldIdLst>')
        z.writestr('ppt/presentation.xml', pres[:a] + ''.join(ids) + pres[b:])
        prel = parts['ppt/_rels/presentation.xml.rels'].decode()
        for k in (1, 2):  # özgün slayt ilişkileri çıkar, master/tema kalır
            prel = prel.replace(f'<Relationship Id="rId{k + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{k}.xml"/>', '')
        z.writestr('ppt/_rels/presentation.xml.rels', prel.replace('</Relationships>', ''.join(rels) + '</Relationships>'))
        ct = parts['[Content_Types].xml'].decode()
        for k in (1, 2):
            ct = ct.replace(f'<Override PartName="/ppt/slides/slide{k}.xml" ContentType="{_SLIDE_CT}"/>', '')
        z.writestr('[Content_Types].xml', ct.replace('</Types>', ''.join(cts) + '</Types>'))


def big_pdf(path, target_bytes):
    """Sıkıştırılmamış rastgele gri görselli sayfalarla ~[target_bytes] PDF."""
    rnd = random.Random(7)
    side = 1024  # sayfa başına ~1 MB görsel
    pages = max(1, target_bytes // (side * side))
    objs = ['<< /Type /Catalog /Pages 2 0 R >>',
            '<< /Type /Pages /Kids [' + ' '.join(f'{3 + 3 * i} 0 R' for i in range(pages)) + f'] /Count {pages} >>']
    with open(path, 'wb') as f:
        offs = []
        f.write(b'%PDF-1.4\n')

        def put(n, body):
            offs.append(f.tell())
            f.write(f'{n} 0 obj\n'.encode())
            f.write(body)
            f.write(b'\nendobj\n')

        put(1, objs[0].encode())
        put(2, objs[1].encode())
        for i in range(pages):
            page, content, img = 3 + 3 * i, 4 + 3 * i, 5 + 3 * i
            put(page, (f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
                       f'/Resources << /XObject << /Im{i} {img} 0 R >> >> /Contents {content} 0 R >>').encode())
            draw = f'q 595 0 0 842 0 0 cm /Im{i} Do Q'
            put(content, f'<< /Length {len(draw)} >>\nstream\n{draw}\nendstream'.encode())
            data = rnd.randbytes(side * side)
            put(img, f'<< /Type /XObject /Subtype /Image /Width {side} /Height {side} '
                     f'/ColorSpace /DeviceGray /BitsPerComponent 8 /Length {len(data)} >>\nstream\n'.encode()
                + data + b'\nendstream')
        xref = f.tell()
        n = len(offs) + 1
        f.write(f'xref\n0 {n}\n0000000000 65535 f \n'.encode())
        f.write(''.join(f'{o:010d} 00000 n \n' for o in offs).encode())
        f.write(f'trailer\n<< /Size {n} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    root = args[0] if args else 'olcum_verisi'
    d = os.path.join(root, 'klasor_5000')
    os.makedirs(d, exist_ok=True)
    for i in range(5000):
        with open(os.path.join(d, f'dosya_{i:05d}.txt'), 'w') as f:
            f.write(f'olcum {i}\n' * (1 + i % 20))
    g = os.path.join(root, 'galeri_2000')
    os.makedirs(g, exist_ok=True)
    for i in range(2000):
        with open(os.path.join(g, f'foto_{i:05d}.png'), 'wb') as f:
            f.write(png(640, 480, ((i * 37) % 256, (i * 91) % 256, (i * 13) % 256)))
    with open(os.path.join(root, 'belge_100.pdf'), 'wb') as f:
        f.write(pdf(100))
    with open(os.path.join(root, 'tablo_10k.csv'), 'w') as f:
        f.write('no,ad,tutar,tarih\n')
        for i in range(10000):
            f.write(f'{i},satir {i},{i * 3.5:.2f},2026-{1 + i % 12:02d}-{1 + i % 28:02d}\n')
    xlsx(os.path.join(root, 'tablo_100k.xlsx'), rows=100000)
    docx(os.path.join(root, 'word_300.docx'))
    pptx(os.path.join(root, 'slayt_300.pptx'))
    xlsx(os.path.join(root, 'tablo_10k_x20.xlsx'), rows=10000, cols=20)
    if '--buyuk' in sys.argv:
        xlsx(os.path.join(root, 'buyuk_100mb.xlsx'), target_bytes=100 << 20)
        big_pdf(os.path.join(root, 'buyuk_100mb.pdf'), 100 << 20)
    print('hazır:', root)


if __name__ == '__main__':
    main()
