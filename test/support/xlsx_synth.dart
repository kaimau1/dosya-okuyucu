import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// **Sentetik "zengin" Excel kitabı** (B10 m.6 sadakat bekçisi — gerçek
/// örnek dosya KVKK gereği depoya girmez). Bizim yazmadığımız ama korumak
/// zorunda olduğumuz parçaların hepsi var: özet tablo + önbellek, dilimleyici
/// (`x14` slicer), koşullu biçim `x14` uzantısı, tanımlı adlar (genel +
/// sayfa yerel), dış bağlantı, makro (`vbaProject.bin`, `.xlsm`).
const synthVbaBytes = <int>[
  0xCC, 0x61, 0x00, 0x01, 0xFF, 0xFE, 0x7F, 0x80, 0x0D, 0x0A, 0x00, 0x00,
  0x41, 0x74, 0x74, 0x72, 0x69, 0x62, 0x75, 0x74, 0x00, 0x99, 0x10, 0xEE,
];

/// Bayt bayt aynı kalması gereken (hiçbir yazıcımızın dokunmadığı) parçalar.
const synthOpaqueParts = [
  'xl/vbaProject.bin',
  'xl/pivotTables/pivotTable1.xml',
  'xl/pivotTables/_rels/pivotTable1.xml.rels',
  'xl/pivotCache/pivotCacheDefinition1.xml',
  'xl/pivotCache/_rels/pivotCacheDefinition1.xml.rels',
  'xl/pivotCache/pivotCacheRecords1.xml',
  'xl/slicers/slicer1.xml',
  'xl/slicerCaches/slicerCache1.xml',
  'xl/externalLinks/externalLink1.xml',
  'xl/externalLinks/_rels/externalLink1.xml.rels',
];

const _main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _x14 = 'http://schemas.microsoft.com/office/spreadsheetml/2009/9/main';
const _xm = 'http://schemas.microsoft.com/office/excel/2006/main';
const _mc = 'http://schemas.openxmlformats.org/markup-compatibility/2006';
const _pkgRel = 'http://schemas.openxmlformats.org/package/2006/relationships';
const _ct = 'application/vnd.openxmlformats-officedocument.spreadsheetml';

Uint8List synthXlsm() {
  final parts = <String, List<int>>{};
  void put(String name, String xml) => parts[name] = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n$xml');

  put('[Content_Types].xml',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="bin" ContentType="application/vnd.ms-office.vbaProject"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.ms-excel.sheet.macroEnabled.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="$_ct.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="$_ct.styles+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="$_ct.sharedStrings+xml"/>'
      '<Override PartName="/xl/pivotTables/pivotTable1.xml" ContentType="$_ct.pivotTable+xml"/>'
      '<Override PartName="/xl/pivotCache/pivotCacheDefinition1.xml" ContentType="$_ct.pivotCacheDefinition+xml"/>'
      '<Override PartName="/xl/pivotCache/pivotCacheRecords1.xml" ContentType="$_ct.pivotCacheRecords+xml"/>'
      '<Override PartName="/xl/slicers/slicer1.xml" ContentType="application/vnd.ms-excel.slicer+xml"/>'
      '<Override PartName="/xl/slicerCaches/slicerCache1.xml" ContentType="application/vnd.ms-excel.slicerCache+xml"/>'
      '<Override PartName="/xl/externalLinks/externalLink1.xml" ContentType="$_ct.externalLink+xml"/>'
      '</Types>');
  put('_rels/.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>');
  put('xl/workbook.xml',
      '<workbook xmlns="$_main" xmlns:r="$_r" xmlns:mc="$_mc" '
      'xmlns:x14="$_x14" mc:Ignorable="x14">'
      '<workbookPr codeName="BuCalismaKitabi"/>'
      '<bookViews><workbookView activeTab="0"/></bookViews>'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '<externalReferences><externalReference r:id="rId6"/></externalReferences>'
      '<definedNames>'
      '<definedName name="Oran">Sheet1!\$B\$1</definedName>'
      '<definedName name="Yerel" localSheetId="0">Sheet1!\$A\$2:\$A\$4</definedName>'
      '<definedName name="Slicer_Bolge">#N/A</definedName>'
      '</definedNames>'
      '<pivotCaches><pivotCache cacheId="7" r:id="rId5"/></pivotCaches>'
      '<extLst><ext uri="{BBE1A952-AA13-448e-AADC-164F8A28A991}">'
      '<x14:slicerCaches><x14:slicerCache r:id="rId7"/></x14:slicerCaches>'
      '</ext></extLst>'
      '</workbook>');
  put('xl/_rels/workbook.xml.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="$_r/styles" Target="styles.xml"/>'
      '<Relationship Id="rId3" Type="$_r/sharedStrings" Target="sharedStrings.xml"/>'
      '<Relationship Id="rId4" Type="http://schemas.microsoft.com/office/2006/relationships/vbaProject" Target="vbaProject.bin"/>'
      '<Relationship Id="rId5" Type="$_r/pivotCacheDefinition" Target="pivotCache/pivotCacheDefinition1.xml"/>'
      '<Relationship Id="rId6" Type="$_r/externalLink" Target="externalLinks/externalLink1.xml"/>'
      '<Relationship Id="rId7" Type="http://schemas.microsoft.com/office/2007/relationships/slicerCache" Target="slicerCaches/slicerCache1.xml"/>'
      '</Relationships>');
  put('xl/styles.xml',
      '<styleSheet xmlns="$_main">'
      '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '<dxfs count="1"><dxf><font><color rgb="FF9C0006"/></font></dxf></dxfs>'
      '</styleSheet>');
  put('xl/sharedStrings.xml',
      '<sst xmlns="$_main" count="4" uniqueCount="4">'
      '<si><t>Bölge</t></si><si><t>Ege</t></si><si><t>Marmara</t></si>'
      '<si><t>Akdeniz</t></si></sst>');
  put('xl/worksheets/sheet1.xml',
      '<worksheet xmlns="$_main" xmlns:r="$_r" xmlns:mc="$_mc" '
      'xmlns:x14="$_x14" xmlns:xm="$_xm" mc:Ignorable="x14">'
      '<dimension ref="A1:B4"/>'
      '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'
      '<sheetFormatPr defaultRowHeight="15"/>'
      '<sheetData>'
      '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1"><v>0.18</v></c></row>'
      '<row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2"><v>10</v></c></row>'
      '<row r="3"><c r="A3" t="s"><v>2</v></c><c r="B3"><v>5</v></c></row>'
      '<row r="4"><c r="A4" t="s"><v>3</v></c><c r="B4"><v>9</v></c></row>'
      '</sheetData>'
      '<conditionalFormatting sqref="B2:B4">'
      '<cfRule type="cellIs" dxfId="0" priority="2" operator="greaterThan"><formula>8</formula></cfRule>'
      '</conditionalFormatting>'
      '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
      '<extLst>'
      '<ext uri="{78C0D931-6437-407d-A8EE-F0AAD7539E65}">'
      '<x14:conditionalFormattings><x14:conditionalFormatting xmlns:xm="$_xm">'
      '<x14:cfRule type="dataBar" id="{00000000-0000-0000-0000-00000000B10A}">'
      '<x14:dataBar minLength="0" maxLength="100" gradient="0"/></x14:cfRule>'
      '<xm:sqref>B2:B4</xm:sqref></x14:conditionalFormatting></x14:conditionalFormattings>'
      '</ext>'
      '<ext uri="{A8765BA9-456A-4dab-B4F3-ACF838C121DE}">'
      '<x14:slicerList><x14:slicer r:id="rId2"/></x14:slicerList>'
      '</ext>'
      '</extLst>'
      '</worksheet>');
  put('xl/worksheets/_rels/sheet1.xml.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/pivotTable" Target="../pivotTables/pivotTable1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.microsoft.com/office/2007/relationships/slicer" Target="../slicers/slicer1.xml"/>'
      '</Relationships>');
  put('xl/pivotTables/pivotTable1.xml',
      '<pivotTableDefinition xmlns="$_main" name="OzetTablo1" cacheId="7" '
      'dataCaption="Değerler" applyNumberFormats="0" applyBorderFormats="0" '
      'applyFontFormats="0" applyPatternFormats="0" applyAlignmentFormats="0" '
      'applyWidthHeightFormats="1" updatedVersion="6" createdVersion="6">'
      '<location ref="D1:E5" firstHeaderRow="1" firstDataRow="1" firstDataCol="1"/>'
      '<pivotFields count="2"><pivotField axis="axisRow" showAll="0">'
      '<items count="4"><item x="0"/><item x="1"/><item x="2"/><item t="default"/></items>'
      '</pivotField><pivotField dataField="1" showAll="0"/></pivotFields>'
      '<rowFields count="1"><field x="0"/></rowFields>'
      '<dataFields count="1"><dataField name="Toplam" fld="1" baseField="0" baseItem="0"/></dataFields>'
      '</pivotTableDefinition>');
  put('xl/pivotTables/_rels/pivotTable1.xml.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/pivotCacheDefinition" Target="../pivotCache/pivotCacheDefinition1.xml"/>'
      '</Relationships>');
  put('xl/pivotCache/pivotCacheDefinition1.xml',
      '<pivotCacheDefinition xmlns="$_main" xmlns:r="$_r" r:id="rId1" '
      'refreshOnLoad="1" recordCount="3">'
      '<cacheSource type="worksheet"><worksheetSource ref="A1:B4" sheet="Sheet1"/></cacheSource>'
      '<cacheFields count="2"><cacheField name="Bölge" numFmtId="0">'
      '<sharedItems count="3"><s v="Ege"/><s v="Marmara"/><s v="Akdeniz"/></sharedItems>'
      '</cacheField><cacheField name="Oran" numFmtId="0">'
      '<sharedItems containsNumber="1" minValue="5" maxValue="10"/></cacheField></cacheFields>'
      '</pivotCacheDefinition>');
  put('xl/pivotCache/_rels/pivotCacheDefinition1.xml.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/pivotCacheRecords" Target="pivotCacheRecords1.xml"/>'
      '</Relationships>');
  put('xl/pivotCache/pivotCacheRecords1.xml',
      '<pivotCacheRecords xmlns="$_main" count="3">'
      '<r><x v="0"/><n v="10"/></r><r><x v="1"/><n v="5"/></r><r><x v="2"/><n v="9"/></r>'
      '</pivotCacheRecords>');
  put('xl/slicers/slicer1.xml',
      '<slicers xmlns="$_x14">'
      '<slicer name="Bölge" cache="Slicer_Bolge" caption="Bölge" rowHeight="241300"/>'
      '</slicers>');
  put('xl/slicerCaches/slicerCache1.xml',
      '<slicerCacheDefinition xmlns="$_x14" name="Slicer_Bolge" sourceName="Bölge">'
      '<pivotTables><pivotTable tabId="1" name="OzetTablo1"/></pivotTables>'
      '<data><tabular pivotCacheId="7"><items count="3">'
      '<i x="0" s="1"/><i x="1" s="1"/><i x="2" s="1"/></items></tabular></data>'
      '</slicerCacheDefinition>');
  put('xl/externalLinks/externalLink1.xml',
      '<externalLink xmlns="$_main" xmlns:r="$_r">'
      '<externalBook r:id="rId1"><sheetNames><sheetName val="Kaynak"/></sheetNames>'
      '<sheetDataSet><sheetData sheetId="0"><row r="1"><cell r="A1"><v>42</v></cell></row>'
      '</sheetData></sheetDataSet></externalBook></externalLink>');
  put('xl/externalLinks/_rels/externalLink1.xml.rels',
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_r/externalLinkPath" '
      'Target="kaynak.xlsx" TargetMode="External"/>'
      '</Relationships>');
  parts['xl/vbaProject.bin'] = synthVbaBytes;

  final archive = Archive();
  parts.forEach((name, data) => archive.addFile(ArchiveFile(name, data.length, data)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Paket parçaları: ad → baytlar.
Map<String, List<int>> zipParts(Uint8List bytes) => {
      for (final f in ZipDecoder().decodeBytes(bytes).files)
        if (f.isFile) f.name: f.content as List<int>,
    };
