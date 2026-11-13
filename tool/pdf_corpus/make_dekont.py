#!/usr/bin/env python3
"""DevExpress (XtraReports) tarzı e-dekont fikstürü — UYDURMA veri (KVKK).

Gerçek bir banka dekontunun YAPISINI taklit eder (2026-11-13 cihaz bulgusu):
  * her SÖZCÜK ayrı `BT … ET`, hücre kırpma dörtgeni içinde (`q x y w h re W n`);
  * Type0 / Identity-H / CIDFontType2 alt küme font (CID = özgün glif no);
  * fontta ASCII boşluk (U+0020) YOK — yalnız U+00A0; sözcük arası konumla;
  * etiket | ":" | değer sütunları, satır aralığı 1,66 × punto.

Kullanım: python tool/pdf_corpus/make_dekont.py   (fontTools gerekir)
Çıktı: test/fixtures/pdf/dx_dekont.pdf
"""
import io
import os
import zlib

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
FONT = os.path.join(ROOT, "assets", "fonts", "Carlito-Regular.ttf")
OUT = os.path.join(ROOT, "test", "fixtures", "pdf", "dx_dekont.pdf")
W, H, SIZE = 595.3, 841.9, 8.5

# (etiket x, ":" x, değer x, [(üstten y, etiket, [değer satırları])])
BOXES = [
    (56.1, 105.7, 111.05, [
        (128.8, "Şube Adı", ["Genel Müdürlük"]),
        (142.9, "Müşteri No", ["00000000"]),
        (157.0, "TCKN", ["00*******00"]),
        (171.1, "İşlem Ref", ["TEST-B-00000000000"]),
        (185.2, "Düzenleyen", ["mobile"]),
    ]),
    (56.2, 124.6, 129.95, [
        (252.9, "Gönderen Kişi", ["Ali Örnek"]),
        (267.0, "Alıcı", ["Ayşe Deneme"]),
        (281.1, "Gönderilen IBAN", ["TR00 0000 0000 0000 0000 0000 00"]),
        (295.2, "Alıcı Banka", ["Örnek Banka A.Ş."]),
        (309.3, "İşlem Yeri", ["Mobil Şube"]),
        (323.4, "Açıklama", ["Gönderen: Ali Örnek , Alıcı: Ayşe Deneme , Örnek Para",
                              "Transferi (TEST)"]),
    ]),
]
TEXT = "".join(l + "".join(v) for b in BOXES for _, l, v in b[3]) + ":"


def main():
    chars = sorted(set(TEXT) - {" "}) + [" "]
    opt = subset.Options()
    opt.retain_gids = True
    opt.notdef_outline = False
    opt.layout_features = []
    opt.drop_tables += ["GSUB", "GPOS", "GDEF", "DSIG", "kern"]
    sub = subset.Subsetter(opt)
    font = TTFont(FONT)
    cmap = font.getBestCmap()
    order = font.getGlyphOrder()
    upm = font["head"].unitsPerEm
    adv = {c: font["hmtx"][cmap[ord(c)]][0] * 1000.0 / upm for c in chars}
    gid = {c: order.index(cmap[ord(c)]) for c in chars}
    sub.populate(unicodes=[ord(c) for c in chars])
    sub.subset(font)
    del font["cmap"]  # DevExpress alt kümesinde cmap yok
    buf = io.BytesIO()
    font.save(buf)
    ttf = buf.getvalue()
    space = 0.26 * 1000

    def width(word):
        return sum(adv[c] for c in word) * SIZE / 1000

    ops = []

    def word(x, y, text, clip):
        hexes = " ".join("<%04X>" % gid[c] for c in text)
        show = "[ %s] TJ" % hexes if len(text) > 1 else "%s Tj" % hexes
        ops.append("q %.2f %.2f %.2f 12.6 re W n 0 0 0 rg BT /FNT0 %.1f Tf %.2f %.2f Td %s ET Q"
                   % (clip[0], y - 4, clip[1], SIZE, x, y, show))

    def run(x, y, text, clip):
        for w in text.split(" "):
            word(x, y, w, clip)
            x += width(w) + space * SIZE / 1000

    for lx, cx, vx, rows in BOXES:
        for top, label, values in rows:
            y = H - top
            run(lx, y, label, (lx - 0.75, cx - lx - 1.5))
            word(cx, y, ":", (cx - 0.75, 3.85))
            for i, v in enumerate(values):
                run(vx, y - i * 11.1, v, (vx - 0.75, 251.8))
    # Kutu kenarlıkları (ince dolu dörtgenler).
    for x, y, w, h in [(36, H - 200, 523, 0.75), (36, H - 110, 523, 0.75),
                       (36, H - 350, 523, 0.75), (36, H - 235, 523, 0.75)]:
        ops.append("0.6 0.7 0.65 rg %.2f %.2f %.2f %.2f re f" % (x, y, w, h))
    content = " ".join(ops).encode("latin1")

    tou = ("/CIDInit /ProcSet findresource begin 12 dict begin begincmap\n"
           "/CIDSystemInfo << /Registry (Adobe) /Ordering (DEVEXP) /Supplement 0 >> def\n"
           "/CMapName /DEVEXP def /CMapType 2 def\n"
           "1 begincodespacerange <0000> <FFFF> endcodespacerange\n"
           "%d beginbfchar\n%s\nendbfchar\nendcmap\n"
           "CMapName currentdict /CMap defineresource pop end end\n"
           % (len(chars), "\n".join("<%04X> <%04X>" % (gid[c], ord(c)) for c in chars))
           ).encode("latin1")
    warr = " ".join("%d [ %.3f ]" % (gid[c], adv[c]) for c in sorted(chars, key=gid.get))

    def stream(d, data):
        z = zlib.compress(data)
        return b"<< %s /Filter /FlateDecode /Length %d >>\nstream\n" % (d, len(z)) + z + b"\nendstream"

    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [ 3 0 R ] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [ 0 0 %.1f %.1f ] /Contents 4 0 R "
        b"/Resources << /Font << /FNT0 5 0 R >> >> >>" % (W, H),
        stream(b"", content),
        b"<< /Type /Font /Subtype /Type0 /BaseFont /DEVEXP+Carlito /Encoding /Identity-H "
        b"/ToUnicode 6 0 R /DescendantFonts [ 7 0 R ] >>",
        stream(b"", tou),
        b"<< /Type /Font /Subtype /CIDFontType2 /BaseFont /DEVEXP+Carlito /FontDescriptor 8 0 R "
        b"/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> "
        b"/DW 1000 /W [ " + warr.encode() + b" ] /CIDToGIDMap /Identity >>",
        b"<< /Type /FontDescriptor /FontName /DEVEXP+Carlito /Flags 32 /ItalicAngle 0 "
        b"/FontBBox [ -500 -250 1300 1000 ] /Ascent 950 /Descent -250 /CapHeight 650 "
        b"/StemV 0 /FontFile2 9 0 R >>",
        stream(b"/Length1 %d" % len(ttf), ttf),
    ]
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offs = []
    for i, o in enumerate(objs):
        offs.append(len(out))
        out += b"%d 0 obj\n" % (i + 1) + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offs:
        out += b"%010d 00000 n \n" % o
    out += (b"trailer\n<< /Size %d /Root 1 0 R /Info << /Producer "
            b"(Developer Express Inc. DXperience taklidi - uydurma veri) >> >>\n"
            b"startxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref))
    with open(OUT, "wb") as f:
        f.write(out)
    print(OUT, len(out))


if __name__ == "__main__":
    main()
