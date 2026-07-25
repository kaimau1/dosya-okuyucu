#!/usr/bin/env python3
"""test/fixtures/wide_freeze.xlsx üretir.

Kullanıcının bildirdiği hatanın fixture'ı: dosyada **ekrandan geniş**
dondurulmuş bölme var (5 sabit sütun × 30 karakter genişlik ≈ 1075 px).
Böyle bir dosyada eski yerleşim, kaydırılan bölgeye hiç yer bırakmıyor ve
"sağ tarafı göremiyorum" hatası çıkıyordu.

Ayrıca:
- 40 sütun veri (sağ uçtaki hücre yalnız yatay kaydırınca görünür),
- BİZİM MOTORUN desteklemediği bir fonksiyon (TREND) + Excel'in
  önbelleklediği sonuç → hücre hata kodu değil Excel'in değerini göstermeli,
- Excel'in kendi hata sonucu (#DIV/0!) → Türkçe gösterilmeli,
- PAYLAŞILAN formül (`t="shared"`, formül metni yalnız ana hücrede).
"""
import zipfile

COLS = 40


def col_name(index: int) -> str:
    name = ""
    i = index
    while i >= 0:
        name = chr(65 + i % 26) + name
        i = i // 26 - 1
    return name


CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>"""

ROOT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""

WORKBOOK = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Genis" sheetId="1" r:id="rId1"/></sheets>
</workbook>"""

WORKBOOK_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"""

STYLES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="1"><fill><patternFill patternType="none"/></fill></fills>
<borders count="1"><border/></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>"""


def inline(ref: str, text: str) -> str:
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'


def sheet1() -> str:
    last = col_name(COLS - 1)
    rows = []

    # 1. satır: başlıklar (dondurulmuş satır)
    cells = [inline(f"{col_name(c)}1", f"S{c + 1}") for c in range(COLS)]
    rows.append(f'<row r="1">{"".join(cells)}</row>')

    # 2. satır: sayılar; en sağdaki hücre işaretli
    cells = []
    for c in range(COLS):
        ref = f"{col_name(c)}2"
        if c == COLS - 1:
            cells.append(inline(ref, "SONSUTUN"))
        else:
            cells.append(f'<c r="{ref}"><v>{(c + 1) * 10}</v></c>')
    rows.append(f'<row r="2">{"".join(cells)}</row>')

    # 3. satır: desteklemediğimiz fonksiyon + Excel'in hata sonucu
    rows.append(
        '<row r="3">'
        '<c r="A3" t="inlineStr"><is><t>Hesap</t></is></c>'
        "<c r=\"B3\"><f>TREND(B2:C2)</f><v>4242</v></c>"
        '<c r="C3" t="e"><f>A2/0</f><v>#DIV/0!</v></c>'
        "<c r=\"D3\"><f>SUM(A2:C2)</f><v>60</v></c>"
        "</row>"
    )

    # 4-5. satır: PAYLAŞILAN formül — Excel formül metnini yalnız ilk hücreye
    # yazar, ikincisinde sadece si vardır (aşağı çekilmiş formül).
    rows.append(
        '<row r="4">'
        '<c r="A4"><f t="shared" ref="A4:B4" si="0">A2*2</f><v>20</v></c>'
        '<c r="B4"><f t="shared" si="0"/><v>40</v></c>'
        "</row>"
    )

    cols = "".join(
        f'<col min="{c + 1}" max="{c + 1}" width="30" customWidth="1"/>'
        for c in range(5)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<dimension ref="A1:{last}4"/>
<sheetViews>
<sheetView tabSelected="1" workbookViewId="0">
<pane xSplit="5" ySplit="1" topLeftCell="F2" activePane="bottomRight" state="frozen"/>
</sheetView>
</sheetViews>
<sheetFormatPr defaultRowHeight="15" defaultColWidth="8.43"/>
<cols>{cols}</cols>
<sheetData>{"".join(rows)}</sheetData>
</worksheet>"""


def main() -> None:
    parts = {
        "[Content_Types].xml": CONTENT_TYPES,
        "_rels/.rels": ROOT_RELS,
        "xl/workbook.xml": WORKBOOK,
        "xl/_rels/workbook.xml.rels": WORKBOOK_RELS,
        "xl/styles.xml": STYLES,
        "xl/worksheets/sheet1.xml": sheet1(),
    }
    with zipfile.ZipFile(
        "test/fixtures/wide_freeze.xlsx", "w", zipfile.ZIP_DEFLATED
    ) as z:
        for name, data in parts.items():
            z.writestr(name, data)
    print("test/fixtures/wide_freeze.xlsx yazıldı")


if __name__ == "__main__":
    main()
