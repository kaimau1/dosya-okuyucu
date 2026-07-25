#!/usr/bin/env python3
"""test/fixtures/rich_sheet.xlsx üretir.

Bu ortamda Excel/LibreOffice yok; sadakat testleri için Excel'in yazdığına
birebir benzeyen bir paket ELLE üretilir (bkz. HAFIZA: fixture'lar Python
zipfile ile yazılır). İçerik kasten "zor": birleşik hücre, dondurulmuş bölme,
gizli satır/sütun, tema rengi + tint, kenarlıklar, hizalama/kaydırma/girinti,
özel sayı biçimleri, formül + Excel'in önbelleklediği sonuç, koşullu biçim
(cellIs + colorScale), veri doğrulama listesi ve ikinci sayfa.
"""
import zipfile

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>"""

ROOT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""

WORKBOOK = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<workbookPr/>
<sheets>
<sheet name="Veri" sheetId="1" r:id="rId1"/>
<sheet name="Diğer" sheetId="2" r:id="rId2"/>
</sheets>
</workbook>"""

WORKBOOK_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
</Relationships>"""

# clrScheme sırası: dk1, lt1, dk2, lt2, accent1..6, hlink, folHlink
THEME = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Test">
<a:themeElements>
<a:clrScheme name="Test">
<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
<a:dk2><a:srgbClr val="44546A"/></a:dk2>
<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
<a:accent1><a:srgbClr val="4472C4"/></a:accent1>
<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
<a:accent4><a:srgbClr val="FFC000"/></a:accent4>
<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
<a:accent6><a:srgbClr val="70AD47"/></a:accent6>
<a:hlink><a:srgbClr val="0563C1"/></a:hlink>
<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
</a:clrScheme>
</a:themeElements>
</a:theme>"""

SHARED = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="8" uniqueCount="8">
<si><t>Başlık</t></si>
<si><t>Ürün</t></si>
<si><t>Fiyat</t></si>
<si><t>Oran</t></si>
<si><t>Tarih</t></si>
<si><t>Kalem</t></si>
<si><t>Defter</t></si>
<si><t>Uzun açıklama metni kaydırılarak gösterilmeli</t></si>
</sst>"""

# ── styles ────────────────────────────────────────────────────────────────
# fonts:   0 normal, 1 kalın 14 kırmızı, 2 tema renkli (accent1 + tint)
# fills:   0 none, 1 gray125, 2 sarı düz, 3 dxf kırmızı
# borders: 0 yok, 1 dört kenar thin, 2 yalnız alt kalın
# cellXfs: 0 genel
#          1 başlık (font1, fill2, border1, ortalı, dikey ortalı)
#          2 para   (numFmt 164)
#          3 yüzde  (numFmt 9)
#          4 tarih  (numFmt 14)
#          5 kaydırmalı + üste hizalı + girintili (font2)
#          6 sağa hizalı, alt kenarlıklı
STYLES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1">
<numFmt numFmtId="164" formatCode="#,##0.00\\ &quot;₺&quot;"/>
</numFmts>
<fonts count="3">
<font><sz val="11"/><name val="Calibri"/></font>
<font><b/><sz val="14"/><color rgb="FFFF0000"/><name val="Calibri"/></font>
<font><sz val="10"/><color theme="4" tint="-0.25"/><name val="Arial"/></font>
</fonts>
<fills count="4">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFFFC7CE"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="3">
<border><left/><right/><top/><bottom/><diagonal/></border>
<border>
<left style="thin"><color rgb="FF000000"/></left>
<right style="thin"><color rgb="FF000000"/></right>
<top style="thin"><color rgb="FF000000"/></top>
<bottom style="thin"><color rgb="FF000000"/></bottom>
</border>
<border><left/><right/><top/><bottom style="thick"><color rgb="FF0000FF"/></bottom></border>
</borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="7">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
<alignment horizontal="center" vertical="center"/></xf>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="9" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">
<alignment horizontal="left" vertical="top" wrapText="1" indent="2"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="2" xfId="0" applyBorder="1" applyAlignment="1">
<alignment horizontal="right"/></xf>
</cellXfs>
<dxfs count="1">
<dxf><font><color rgb="FF9C0006"/></font><fill><patternFill><bgColor rgb="FFFFC7CE"/></patternFill></fill></dxf>
</dxfs>
</styleSheet>"""

SHEET1 = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetPr><tabColor rgb="FF00B050"/></sheetPr>
<dimension ref="A1:E8"/>
<sheetViews>
<sheetView tabSelected="1" workbookViewId="0" showGridLines="1">
<pane xSplit="1" ySplit="2" topLeftCell="B3" activePane="bottomRight" state="frozen"/>
</sheetView>
</sheetViews>
<sheetFormatPr defaultRowHeight="15" defaultColWidth="8.43"/>
<cols>
<col min="1" max="1" width="20" customWidth="1"/>
<col min="2" max="2" width="12" customWidth="1"/>
<col min="5" max="5" width="9" hidden="1" customWidth="1"/>
</cols>
<sheetData>
<row r="1" ht="24" customHeight="1">
<c r="A1" s="1" t="s"><v>0</v></c>
<c r="B1" s="1"/>
<c r="C1" s="1"/>
</row>
<row r="2">
<c r="A2" t="s"><v>1</v></c>
<c r="B2" t="s"><v>2</v></c>
<c r="C2" t="s"><v>3</v></c>
<c r="D2" t="s"><v>4</v></c>
</row>
<row r="3">
<c r="A3" t="s"><v>5</v></c>
<c r="B3" s="2"><v>1234.5</v></c>
<c r="C3" s="3"><v>0.15</v></c>
<c r="D3" s="4"><v>46224</v></c>
</row>
<row r="4">
<c r="A4" t="s"><v>6</v></c>
<c r="B4" s="2"><v>250</v></c>
<c r="C4" s="3"><v>0.4</v></c>
<c r="D4" s="4"><v>46225</v></c>
</row>
<row r="5">
<c r="A5" s="6" t="str"><f>A3&amp;" toplam"</f><v>Kalem toplam</v></c>
<c r="B5" s="2"><f>SUM(B3:B4)</f><v>1484.5</v></c>
</row>
<row r="6" ht="40" customHeight="1">
<c r="A6" s="5" t="s"><v>7</v></c>
</row>
<row r="7" hidden="1">
<c r="A7"><v>999</v></c>
</row>
<row r="8">
<c r="A8" t="b"><v>1</v></c>
<c r="B8" t="e"><v>#DIV/0!</v></c>
</row>
</sheetData>
<mergeCells count="1"><mergeCell ref="A1:C1"/></mergeCells>
<dataValidations count="1">
<dataValidation type="list" allowBlank="1" sqref="A3:A4">
<formula1>"Kalem,Defter,Silgi"</formula1>
</dataValidation>
</dataValidations>
<conditionalFormatting sqref="B3:B4">
<cfRule type="cellIs" dxfId="0" priority="1" operator="greaterThan"><formula>1000</formula></cfRule>
</conditionalFormatting>
<conditionalFormatting sqref="C3:C4">
<cfRule type="colorScale" priority="2">
<colorScale>
<cfvo type="min"/><cfvo type="max"/>
<color rgb="FFFFFFFF"/><color rgb="FF63BE7B"/>
</colorScale>
</cfRule>
</conditionalFormatting>
</worksheet>"""

SHEET2 = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<dimension ref="A1:A1"/>
<sheetViews><sheetView showGridLines="0" workbookViewId="0"/></sheetViews>
<sheetData>
<row r="1"><c r="A1"><v>5</v></c></row>
</sheetData>
</worksheet>"""


def main() -> None:
    parts = {
        "[Content_Types].xml": CONTENT_TYPES,
        "_rels/.rels": ROOT_RELS,
        "xl/workbook.xml": WORKBOOK,
        "xl/_rels/workbook.xml.rels": WORKBOOK_RELS,
        "xl/theme/theme1.xml": THEME,
        "xl/sharedStrings.xml": SHARED,
        "xl/styles.xml": STYLES,
        "xl/worksheets/sheet1.xml": SHEET1,
        "xl/worksheets/sheet2.xml": SHEET2,
    }
    with zipfile.ZipFile(
        "test/fixtures/rich_sheet.xlsx", "w", zipfile.ZIP_DEFLATED
    ) as z:
        for name, data in parts.items():
            z.writestr(name, data)
    print("test/fixtures/rich_sheet.xlsx yazıldı")


if __name__ == "__main__":
    main()
