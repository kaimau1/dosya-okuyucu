import 'dart:typed_data';

import 'package:dosya_okuyucu/services/legacy_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/cfb_writer.dart';

Uint8List _utf16le(String s) {
  final out = <int>[];
  for (final c in s.codeUnits) {
    out.add(c & 0xFF);
    out.add((c >> 8) & 0xFF);
  }
  return Uint8List.fromList(out);
}

/// Piece table'lı sentetik Word 97 .doc üretir: 1. parça CP1252 (alan kodu
/// dahil), 2. parça UTF-16 (Türkçe). Metin sırası piece table'dan gelir.
Uint8List _sampleDoc() {
  const ansiText = 'Eski dosya testi.\r'; // 18 cp — CP1252 parçası
  const uniText = 'Türkçe ĞğŞşİı metni'; // 19 cp — UTF-16 parçası

  final wd = Uint8List(4096);
  final wdD = ByteData.sublistView(wd);
  wdD.setUint16(0, 0xA5EC, Endian.little); // wIdent (Word 97+)
  wdD.setUint16(0x0A, 0x0200, Endian.little); // piece table 1Table'da
  wdD.setUint32(0x4C, ansiText.length + uniText.length, Endian.little);
  wdD.setUint32(0x1A2, 0, Endian.little); // fcClx (Table içinde)

  // Metinleri WordDocument içine yerleştir.
  const ansiOff = 0x800; // CP1252: fc = bayt_ofseti * 2
  for (var i = 0; i < ansiText.length; i++) {
    wd[ansiOff + i] = ansiText.codeUnitAt(i);
  }
  const uniOff = 0xA00; // UTF-16LE: fc = bayt ofseti
  final uni = _utf16le(uniText);
  wd.setRange(uniOff, uniOff + uni.length, uni);

  // Table stream: Clx = [0x02][lcb][PlcPcd].
  const n = 2;
  const lcbPlc = (n + 1) * 4 + n * 8;
  final table = Uint8List(4096);
  final td = ByteData.sublistView(table);
  table[0] = 0x02;
  td.setUint32(1, lcbPlc, Endian.little);
  var p = 5;
  // CP sınırları.
  td.setUint32(p, 0, Endian.little);
  td.setUint32(p + 4, ansiText.length, Endian.little);
  td.setUint32(p + 8, ansiText.length + uniText.length, Endian.little);
  p += 12;
  // PCD'ler: [u16 bayraklar][u32 fc][u16 prm]
  td.setUint32(p + 2, (ansiOff * 2) | 0x40000000, Endian.little); // sıkıştırılmış
  p += 8;
  td.setUint32(p + 2, uniOff, Endian.little); // UTF-16
  wdD.setUint32(0x1A6, 5 + lcbPlc, Endian.little); // lcbClx

  return buildCfb({'WordDocument': wd, '1Table': table});
}

/// Sentetik PowerPoint 97 .ppt: SlideListWithText kabında SlidePersistAtom +
/// TextCharsAtom (UTF-16, Türkçe) + TextBytesAtom (CP1252).
Uint8List _samplePpt() {
  Uint8List rec(int verInst, int type, List<int> body) {
    final b = Uint8List(8 + body.length);
    final d = ByteData.sublistView(b);
    d.setUint16(0, verInst, Endian.little);
    d.setUint16(2, type, Endian.little);
    d.setUint32(4, body.length, Endian.little);
    b.setRange(8, b.length, body);
    return b;
  }

  final persist = rec(0x0000, 0x03F3, List.filled(20, 0));
  final chars = rec(0x0000, 0x0FA0, _utf16le('Başlık: Türkçe Sunum'));
  // 0x92 = CP1252 sağ akıllı tırnak (’) — eşleme testi.
  final bytesAtom = rec(
      0x0000, 0x0FA8, [...'Alt metin'.codeUnits, 0x92, ...'92'.codeUnits]);
  final payload = [...persist, ...chars, ...bytesAtom];
  final slwt = rec(0x000F, 0x0FF0, payload);

  return buildCfb({'PowerPoint Document': Uint8List.fromList(slwt)});
}

void main() {
  group('LegacyText — yapısal .doc (piece table)', () {
    test('parçalar doğru sırada, CP1252 + UTF-16 karışık, Türkçe korunur', () {
      final out = LegacyText.fromDoc(_sampleDoc());
      expect(out, isNotNull);
      // Sıra: önce ANSI parça, sonra Unicode parça; \r → \n.
      expect(out, contains('Eski dosya testi.\nTürkçe ĞğŞşİı metni'));
    });

    test('bozuk FIB (yanlış imza) yedek taramaya düşer, çökmez', () {
      final doc = _sampleDoc();
      // OLE kabı içindeki WordDocument imzasını boz: yapısal yol reddetmeli.
      // (Kap sektör 2'de başlar: 512 başlık + 2*512.)
      final broken = Uint8List.fromList(doc);
      broken[512 + 2 * 512] = 0;
      broken[512 + 2 * 512 + 1] = 0;
      final out = LegacyText.fromDoc(broken);
      // Yedek tarama yine de metin bulur (UTF-16 parça taramada görünür).
      expect(out, isNotNull);
      expect(out, contains('metni'));
    });
  });

  group('LegacyText — yapısal .ppt (kayıt ağacı)', () {
    test('metin atomları slayt işaretiyle, Türkçe ve CP1252 doğru', () {
      final out = LegacyText.fromPpt(_samplePpt());
      expect(out, isNotNull);
      expect(out, contains('[Slayt 1]'));
      expect(out, contains('Başlık: Türkçe Sunum'));
      expect(out, contains('Alt metin’92'));
    });
  });

  group('LegacyText — ikili stream\'den en iyi çaba metin', () {
  group('LegacyText — ikili stream\'den en iyi çaba metin', () {
    test('gömülü UTF-16LE metni çıkarır (Türkçe dahil)', () {
      final text = _utf16le('Merhaba Dünya bu bir test belgesidir');
      final bytes = Uint8List.fromList([
        0, 0, 0, 0, // ikili gürültü (kabul edilmez)
        ...text,
        0, 0, 0, 0,
      ]);
      final out = LegacyText.extractFromStream(bytes);
      expect(out, isNotNull);
      expect(out, contains('Merhaba'));
      expect(out, contains('Dünya'));
      expect(out, contains('belgesidir'));
    });

    test('gömülü CP1252 (tek bayt) metni çıkarır', () {
      final ascii = 'Bu eski dosyada duz metin var'.codeUnits;
      final bytes = Uint8List.fromList([1, 2, 255, ...ascii, 0, 0]);
      final out = LegacyText.extractFromStream(bytes);
      expect(out, isNotNull);
      expect(out, contains('duz metin'));
    });

    test('metin yoksa null', () {
      final bytes = Uint8List.fromList(List.filled(64, 0));
      expect(LegacyText.extractFromStream(bytes), isNull);
    });
  });
}
