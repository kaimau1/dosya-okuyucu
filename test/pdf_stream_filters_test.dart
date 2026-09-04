import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_filters.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_page_context.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_xobject.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Akış filtreleri ve kaynak tabloları** — kullanıcı bulgusu 2026-09-04:
/// bir belgede PDF düzenleyici hem *"Bu sayfada gömülü görsel yok"* hem
/// *"Bu sayfada düzenlenebilir metin bulunamadı"* diyordu, oysa sayfada iki
/// büyük görsel duruyordu.
///
/// İki kök neden vardı ve ikisi de SESSİZDİ (hata bile vermiyorlardı):
/// 1. `/Filter [/FlateDecode]` — filtre **dizi** yazıldığında okunamıyor,
///    kod "filtre yok" sanıp sıkıştırılmış baytları içerik akışı diye geri
///    veriyordu.
/// 2. `/Resources << /XObject 12 0 R >>` — kategori sözlüğü **dolaylı**
///    yazıldığında kaynak tablosu boş çıkıyordu.
///
/// Buradaki belgeler tam olarak o iki yazımı kuruyor; ölçüt de kullanıcının
/// gördüğü şey: sayfada görsel BULUNUYOR mu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Verilen sözlük/akış gövdeleriyle klasik (xref tablolu) PDF kurar.
  List<int> buildPdf({
    required String resources,
    required List<int> contentStream,
    required String contentDict,
    String extra = '',
  }) {
    final out = BytesBuilder();
    final offsets = <int, int>{};
    void addObject(int number, String body, {List<int>? stream}) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n$body'));
      if (stream != null) {
        out.add(latin1.encode('\nstream\n'));
        out.add(stream);
        out.add(latin1.encode('\nendstream'));
      }
      out.add(latin1.encode('\nendobj\n'));
    }

    out.add(latin1.encode('%PDF-1.5\n'));
    addObject(1, '<< /Type /Catalog /Pages 2 0 R >>');
    addObject(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    addObject(
        3,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] '
        '/Contents 4 0 R /Resources $resources >>');
    addObject(4, '<< /Length ${contentStream.length} $contentDict >>',
        stream: contentStream);
    // 5: görsel XObject (baytları önemsiz — yalnız /Subtype okunuyor).
    addObject(5, '<< /Type /XObject /Subtype /Image /Width 10 /Height 10 '
        '/ColorSpace /DeviceGray /BitsPerComponent 8 /Length 4 >>',
        stream: const [0, 0, 0, 0]);
    if (extra.isNotEmpty) {
      // 6: dolaylı kaynak alt sözlüğü.
      addObject(6, extra);
    }

    final xrefAt = out.length;
    final maxNumber = offsets.keys.reduce((a, b) => a > b ? a : b);
    final table = StringBuffer('xref\n0 ${maxNumber + 1}\n0000000000 65535 f \n');
    for (var i = 1; i <= maxNumber; i++) {
      final at = offsets[i] ?? 0;
      table.write('${at.toString().padLeft(10, '0')} 00000 n \n');
    }
    table.write('trailer\n<< /Size ${maxNumber + 1} /Root 1 0 R >>\n'
        'startxref\n$xrefAt\n%%EOF\n');
    out.add(latin1.encode(table.toString()));
    return out.takeBytes();
  }

  /// 100 × 50'lik bir görseli (200, 400) noktasına çizen içerik akışı.
  final drawImage = latin1.encode('q 100 0 0 50 200 400 cm /Im1 Do Q');

  group('filtre DİZİSİ (/Filter [/FlateDecode])', () {
    test('dizi yazımında da akış çözülür ve görsel BULUNUR', () {
      final packed = const ZLibEncoder().encode(drawImage);
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: packed,
        contentDict: '/Filter [/FlateDecode]',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      final objects = findPageObjects(ctx.contents, resources: ctx.xobjectTree);
      expect(objects, hasLength(1),
          reason: 'dizi yazımı okunamayınca sayfa "görselsiz" görünüyordu');
      expect(objects.single.left, closeTo(200, 1e-6));
      expect(objects.single.width, closeTo(100, 1e-6));
    });

    test('tek ad yazımı (eski yol) bozulmadı', () {
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: const ZLibEncoder().encode(drawImage),
        contentDict: '/Filter /FlateDecode',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      expect(findPageObjects(ctx.contents, resources: ctx.xobjectTree),
          hasLength(1));
    });

    test('zincir: ASCII85 + Flate sırayla uygulanır', () {
      final packed = const ZLibEncoder().encode(drawImage);
      final ascii = _ascii85Encode(packed);
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: ascii,
        contentDict: '/Filter [/ASCII85Decode /FlateDecode]',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      expect(findPageObjects(ctx.contents, resources: ctx.xobjectTree),
          hasLength(1));
    });

    test('TANINMAYAN filtre artık FIRLATIR (ham bayt dönmez)', () {
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: drawImage,
        contentDict: '/Filter /JBIG2Decode',
      );
      // Sessizce çöp veri dönmesindense reddetmek yeğdir: çağıran katman
      // kullanıcıya "bu sayfa çözümlenemedi" diyebiliyor.
      expect(() => PdfPageContext.open(bytes, 0), throwsA(isA<PdfPageRefused>()));
    });
  });

  group('DOLAYLI kaynak alt sözlüğü (/XObject 6 0 R)', () {
    test('dolaylı yazımda da görsel bulunur', () {
      final bytes = buildPdf(
        resources: '<< /XObject 6 0 R >>',
        contentStream: drawImage,
        contentDict: '',
        extra: '<< /Im1 5 0 R >>',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      final objects = findPageObjects(ctx.contents, resources: ctx.xobjectTree);
      expect(objects, hasLength(1),
          reason: 'Ghostscript/tarayıcı çıktıları kaynağı böyle yazıyor');
    });
  });

  group('satır içi görsel (BI … ID … EI)', () {
    test('kutusuyla listelenir ama DÜZENLENEMEZ olarak işaretlenir', () {
      final inline = latin1.encode(
          'q 100 0 0 50 200 400 cm BI /W 2 /H 2 /CS /G /BPC 8 ID \x00\x01\x02\x03 EI Q');
      final bytes = buildPdf(
        resources: '<< >>',
        contentStream: inline,
        contentDict: '',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      final objects = findPageObjects(ctx.contents, resources: ctx.xobjectTree);
      expect(objects, hasLength(1),
          reason: 'gözle görülen görsel "yok" sayılmamalı');
      expect(objects.single.isInline, isTrue);
      expect(objects.single.editable, isFalse);
      expect(objects.single.left, closeTo(200, 1e-6));
      expect(objects.single.height, closeTo(50, 1e-6));
    });

    test('ikili veri operatör sanılmaz (akışın geri kalanı doğru okunur)', () {
      // İkili verinin içinde `Do`, `q` ve `Q` baytları var: atlama
      // çalışmazsa bunlar operatör sayılır ve tarama bozulurdu.
      final inline = latin1.encode(
          'BI /W 2 /H 2 ID q Q Do cm EI q 10 0 0 10 5 5 cm /Im1 Do Q');
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: inline,
        contentDict: '',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      final objects = findPageObjects(ctx.contents, resources: ctx.xobjectTree);
      // Satır içi görsel + gerçek XObject = iki nesne; XObject'in kutusu
      // ikili verideki `cm` sızmadığı için tam 10 × 10.
      final named = objects.where((o) => !o.isInline).toList();
      expect(named, hasLength(1));
      expect(named.single.width, closeTo(10, 1e-6));
      expect(named.single.left, closeTo(5, 1e-6));
    });
  });

  group('/DecodeParms /Predictor (PNG ön kestirimi)', () {
    test('Up süzgeci geri alınır ve akış doğru okunur', () {
      // Ön kestirim uygulanmış akış: her satırın başında süzgeç baytı var.
      // Satır uzunluğu içeriğe göre seçildi; 2. satır bir öncekinin FARKI
      // olarak yazılıyor (süzgeç 2 = Up).
      final raw = latin1.encode('q 100 0 0 50 200 400 cm /Im1 Do Q       ');
      const columns = 20;
      final rows = <List<int>>[];
      for (var at = 0; at < raw.length; at += columns) {
        rows.add(raw.sublist(at, at + columns));
      }
      final filtered = <int>[];
      var prior = List<int>.filled(columns, 0);
      for (final row in rows) {
        filtered.add(2); // Up
        for (var i = 0; i < columns; i++) {
          filtered.add((row[i] - prior[i]) & 0xFF);
        }
        prior = row;
      }
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: const ZLibEncoder().encode(filtered),
        contentDict:
            '/Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns $columns >>',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      final objects = findPageObjects(ctx.contents, resources: ctx.xobjectTree);
      expect(objects, hasLength(1));
      expect(objects.single.left, closeTo(200, 1e-6));
    });

    test('/DecodeParms dizisi filtre sırasıyla eşleşir', () {
      final packed = const ZLibEncoder().encode(drawImage);
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: _ascii85Encode(packed),
        contentDict:
            '/Filter [/ASCII85Decode /FlateDecode] /DecodeParms [null null]',
      );
      final ctx = PdfPageContext.open(bytes, 0);
      expect(findPageObjects(ctx.contents, resources: ctx.xobjectTree),
          hasLength(1));
    });
  });

  group('belge yapısındaki öteki dolaylı yazımlar', () {
    test('/Contents DOLAYLI bir DİZİYİ gösterebilir', () {
      // `/Contents 6 0 R` → 6. nesne bir dizi (`[4 0 R]`). Eskiden içerik
      // "okunamadı" sayılıyor ve sayfa hiç açılmıyordu.
      final bytes = buildPdf(
        resources: '<< /XObject << /Im1 5 0 R >> >>',
        contentStream: drawImage,
        contentDict: '',
        extra: '[4 0 R]',
      );
      final patched = latin1.decode(bytes, allowInvalid: true)
          .replaceFirst('/Contents 4 0 R', '/Contents 6 0 R');
      final ctx = PdfPageContext.open(latin1.encode(patched), 0);
      expect(findPageObjects(ctx.contents, resources: ctx.xobjectTree),
          hasLength(1));
    });

    test('ters yazılmış /MediaBox düzeltilir (yükseklik negatif çıkmaz)', () {
      final bytes = buildPdf(
        resources: '<< >>',
        contentStream: drawImage,
        contentDict: '',
      );
      final patched = latin1.decode(bytes, allowInvalid: true)
          .replaceFirst('/MediaBox [0 0 400 600]', '/MediaBox [0 600 400 0]');
      final ctx = PdfPageContext.open(latin1.encode(patched), 0);
      expect(ctx.pageWidth, closeTo(400, 1e-6));
      expect(ctx.pageHeight, closeTo(600, 1e-6));
    });
  });

  group('saf filtre çözücüleri', () {
    test('ASCIIHexDecode — tek kalan basamak 0 ile tamamlanır', () {
      expect(pdfAsciiHexDecode(latin1.encode('48 65 6C6C 6F>')),
          latin1.encode('Hello'));
      expect(pdfAsciiHexDecode(latin1.encode('4>')), [0x40]);
    });

    test('ASCII85Decode — z kısayolu ve eksik grup', () {
      expect(pdfAscii85Decode(latin1.encode('z~>')), [0, 0, 0, 0]);
      final round = pdfAscii85Decode(_ascii85Encode(latin1.encode('Dosya')));
      expect(round, latin1.encode('Dosya'));
    });

    test('RunLengthDecode — hem düz hem tekrar dizisi', () {
      // 2 → sonraki 3 bayt düz; 254 → sonraki bayt 3 kez; 128 → son.
      expect(pdfRunLengthDecode([2, 65, 66, 67, 254, 68, 128, 99]),
          [65, 66, 67, 68, 68, 68]);
    });

    test('LZWDecode — PDF başvuru kılavuzunun örneği', () {
      // PDF 32000-1, Tablo 8'deki örnek: `45 45 45 45 45 65 45 45 45 66`
      // dizisi `80 0B 60 50 22 0C 0C 85 01` olarak kodlanır. Örnek özellikle
      // "tabloya yeni girilen kodun HEMEN kullanılması" durumunu (kod ==
      // tablo uzunluğu) içerdiği için seçildi — çözücülerin klasik hata yeri.
      const encoded = [0x80, 0x0B, 0x60, 0x50, 0x22, 0x0C, 0x0C, 0x85, 0x01];
      expect(pdfLzwDecode(encoded), [45, 45, 45, 45, 45, 65, 45, 45, 45, 66]);
    });

    test('bozuk girdi FIRLATMAZ, eldeki kadarını döner', () {
      expect(() => pdfLzwDecode([0xFF, 0xFF, 0xFF]), returnsNormally);
      expect(() => pdfAscii85Decode([0x21]), returnsNormally);
      expect(() => pdfRunLengthDecode([200]), returnsNormally);
    });
  });
}

/// Test için ASCII85 kodlayıcı (`z` kısayolu kullanılmaz — çözücü ikisini de
/// anlamalı).
List<int> _ascii85Encode(List<int> data) {
  final out = <int>[];
  for (var i = 0; i < data.length; i += 4) {
    final chunk = data.skip(i).take(4).toList();
    final take = chunk.length;
    while (chunk.length < 4) {
      chunk.add(0);
    }
    var value = 0;
    for (final b in chunk) {
      value = value * 256 + b;
    }
    final digits = List<int>.filled(5, 0);
    for (var k = 4; k >= 0; k--) {
      digits[k] = value % 85;
      value ~/= 85;
    }
    out.addAll(digits.take(take + 1).map((d) => d + 0x21));
  }
  out.addAll(latin1.encode('~>'));
  return out;
}
