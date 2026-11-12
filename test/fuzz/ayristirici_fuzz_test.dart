@Tags(['fuzz'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/csv_codec.dart';
import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:dosya_okuyucu/services/office_crypto.dart';
import 'package:dosya_okuyucu/services/office_reader.dart';
import 'package:dosya_okuyucu/services/ole_cfb.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/text_decode.dart';
import 'package:dosya_okuyucu/services/xls_legacy.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// BULANIK TEST (GUVENLIK_PLANI G7.9, 2026-11-12).
///
/// Her ayrıştırıcıya sabit tohumlu bozulmuş girdiler (fixture'dan bayt çevirme,
/// kesme, tekrar, araya ekleme, uç tamsayı yazma). Beklenen: ayrıştırıcı
/// istisna atabilir (çağıranlar yakalar) ama SÜREÇ ÇÖKMEZ, sonsuz döngü yok
/// (her parti öldürülebilir izolatta, tek girdi ≤ 10 sn), bellek artışı < 512 MB.
///
/// Normal push'ta KOŞMAZ (`fuzz` etiketi; CI ayrı adım: `[tam]`, `v*`, elle
/// tetik ya da bu dosya değişince). Yerelde:
/// `flutter test --tags fuzz test/fuzz/`
void main() {
  const fx = 'test/fixtures';
  Uint8List read(String rel) => File('$fx/$rel').readAsBytesSync();

  final rssStart = ProcessInfo.currentRss;

  Future<void> fuzz(String name, Uint8List seed, int count) async {
    final r = await _runIsolated(name, seed, count);
    print('FUZZ $name: $r');
    expect(r.startsWith('tamam'), isTrue, reason: '$name: $r');
    final grew = ProcessInfo.currentRss - rssStart;
    expect(grew, lessThan(512 << 20),
        reason: '$name sonrası bellek artışı ${grew >> 20} MB');
  }

  test('xlsx_reader', () => fuzz('xlsx', read('office/satis.xlsx'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('office_reader docx', () => fuzz('docx', read('office/tablo.docx'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('office_reader pptx', () => fuzz('pptx', read('office/sunum.pptx'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('ole_cfb', () => fuzz('ole', read('ole_sample.cfb'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('xls_legacy', () => fuzz('xls', read('legacy_sample.xls'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('csv_codec', () => fuzz('csv', read('office/noktali_virgul.csv'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('text_decode', () => fuzz('text', read('office/metin_cp1254.txt'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('PdfFile.parse', () => fuzz('pdf', read('pdf/metinli.pdf'), 500),
      timeout: const Timeout(Duration(minutes: 3)));
  test('office_crypto', () {
    // Hızlı tohum: düşük spinCount (bozulmuş girdiler yine tam yoldan geçer).
    final enc = OfficeCrypto.encrypt(read('office/satis.xlsx'), 'x',
        spinCount: 1000);
    return fuzz('crypto', enc, 200);
  }, timeout: const Timeout(Duration(minutes: 4)));
  test('archive_ops listeleme (zip)',
      () => fuzz('zip', read('office/satis.xlsx'), 100),
      timeout: const Timeout(Duration(minutes: 4)));
}

/// Partiyi ayrı izolatta koşar: zaman aşımında izolat öldürülür (senkron
/// sonsuz döngü ana test izolatını kilitleyemez).
Future<String> _runIsolated(String name, Uint8List seed, int count) async {
  final port = ReceivePort();
  final iso = await Isolate.spawn(
      _batchEntry, <Object>[port.sendPort, name, seed, count],
      onError: port.sendPort);
  try {
    final msg = await port.first.timeout(const Duration(seconds: 150));
    if (msg is String) return msg;
    return 'İZOLAT HATASI: $msg';
  } on TimeoutException {
    return 'ZAMAN AŞIMI (parti 150 sn içinde bitmedi — sonsuz döngü şüphesi)';
  } finally {
    iso.kill(priority: Isolate.immediate);
    port.close();
  }
}

Future<void> _batchEntry(List<Object> args) async {
  final send = args[0] as SendPort;
  final name = args[1] as String;
  final seed = args[2] as Uint8List;
  final count = args[3] as int;
  send.send(await _batch(name, seed, count));
}

Future<String> _batch(String name, Uint8List seed, int count) async {
  final rnd = Random(0x5EED ^ name.hashCode);
  final dir = name == 'zip'
      ? Directory.systemTemp.createTempSync('fuzz_zip')
      : null;
  var thrown = 0;
  final kinds = <String>{};
  try {
    for (var i = 0; i < count; i++) {
      final input = mutate(seed, rnd);
      final sw = Stopwatch()..start();
      try {
        await _parse(name, input, dir, i);
      } catch (e) {
        thrown++;
        kinds.add(e.runtimeType.toString());
      }
      if (sw.elapsed > const Duration(seconds: 10)) {
        return 'YAVAŞ: girdi $i ${sw.elapsed.inMilliseconds} ms '
            '(${input.length} bayt)';
      }
    }
  } finally {
    try {
      dir?.deleteSync(recursive: true);
    } catch (_) {
      // Bilinçli: geçici klasör silinemezse test sonucu değişmez.
    }
  }
  return 'tamam n=$count istisna=$thrown tür=${kinds.join(',')}';
}

Future<void> _parse(String name, Uint8List b, Directory? dir, int i) async {
  switch (name) {
    case 'xlsx':
      XlsxReader.read(b);
    case 'docx':
      OfficeReader.extractDocxText(b);
    case 'pptx':
      OfficeReader.extractPptxText(b);
    case 'ole':
      final ole = OleFile.tryParse(b);
      if (ole != null) {
        ole.stream('Workbook');
        ole.stream('EncryptionInfo');
      }
    case 'xls':
      XlsLegacy.tryParse(b);
    case 'csv':
      final s = utf8.decode(b, allowMalformed: true);
      CsvCodec.parse(s, delimiter: CsvCodec.detectDelimiter(s));
    case 'text':
      TextDecode.decode(b);
      TextDecode.describeEncoding(b);
    case 'pdf':
      PdfFile.parse(b);
    case 'crypto':
      OfficeCrypto.decrypt(b, 'x');
    case 'zip':
      final f = File('${dir!.path}/g$i.zip')..writeAsBytesSync(b);
      try {
        await ArchiveOps.list(f.path);
      } finally {
        f.deleteSync();
      }
  }
}

/// Bozma işlemleri (her girdiye 1–4 tane). `@visibleForTesting` gerekmez —
/// yalnız bu dosyada.
Uint8List mutate(Uint8List seed, Random rnd) {
  var out = Uint8List.fromList(seed);
  final ops = 1 + rnd.nextInt(4);
  for (var k = 0; k < ops && out.isNotEmpty; k++) {
    switch (rnd.nextInt(6)) {
      case 0: // bayt çevirme (1–16 bayt)
        final n = 1 + rnd.nextInt(16);
        for (var j = 0; j < n; j++) {
          out[rnd.nextInt(out.length)] ^= 1 + rnd.nextInt(255);
        }
      case 1: // kesme
        out = Uint8List.sublistView(out, 0, rnd.nextInt(out.length));
        out = Uint8List.fromList(out);
      case 2: // bölüm tekrarı
        final a = rnd.nextInt(out.length);
        final len = min(out.length - a, 1 + rnd.nextInt(256));
        final at = rnd.nextInt(out.length);
        out = Uint8List.fromList([
          ...out.sublist(0, at),
          ...out.sublist(a, a + len),
          ...out.sublist(at),
        ]);
      case 3: // rastgele bayt ekleme
        final at = rnd.nextInt(out.length);
        final junk = List<int>.generate(1 + rnd.nextInt(64), (_) => rnd.nextInt(256));
        out = Uint8List.fromList([...out.sublist(0, at), ...junk, ...out.sublist(at)]);
      case 4: // uç tamsayı (başlık alanları: boy, sayı, konum)
        if (out.length >= 4) {
          const extremes = [0x00000000, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000000, 0x0000FFFF, 0x00010000];
          final at = rnd.nextInt(out.length - 3);
          ByteData.sublistView(out)
              .setUint32(at, extremes[rnd.nextInt(extremes.length)], Endian.little);
        }
      case 5: // bölüm silme
        final a = rnd.nextInt(out.length);
        final len = min(out.length - a, 1 + rnd.nextInt(128));
        out = Uint8List.fromList([...out.sublist(0, a), ...out.sublist(a + len)]);
    }
  }
  return out;
}
