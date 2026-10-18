import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_index.dart';
import 'package:dosya_okuyucu/services/fm/bills.dart';
import 'package:dosya_okuyucu/services/fm/exif_reader.dart';
import 'package:dosya_okuyucu/services/fm/native_extras.dart';
import 'package:dosya_okuyucu/services/fm/photo_insights.dart';
import 'package:dosya_okuyucu/services/fm/smart_folders.dart';
import 'package:dosya_okuyucu/widgets/qr_code.dart';

/// 2026-10-18 öneri turu: akıllı klasörler, faturalar, anılar, QR, yerel
/// iş ayarı.
void main() {
  group('akıllı klasörler', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SmartFolders.instance.debugReset();
    });

    test('ad sorudan; aynı sorgu ikinci kez açılmaz; kalıcı', () async {
      final sf = SmartFolders.instance;
      final a = await sf.add('  faturalarım   nerede ');
      expect(a.name, 'Faturalarım nerede');
      final b = await sf.add('FATURALARIM NEREDE');
      expect(b.id, a.id);
      expect(sf.folders, hasLength(1));
      sf.debugReset();
      await sf.ensureLoaded();
      expect(sf.folders.single.query, 'faturalarım nerede');
      await sf.rename(a.id, 'Faturalar');
      expect(sf.folders.single.name, 'Faturalar');
      await sf.remove(a.id);
      expect(sf.folders, isEmpty);
    });

    test('yeni sayısı son bakıştan sonra değişenler', () {
      const folder = SmartFolder(
          id: 'x', name: 'x', query: 'x', createdMs: 0, seenMs: 1000);
      AiRecord rec(int mod) => AiRecord.fromJson({'p': '/a/$mod.pdf', 's': 1, 'm': mod})!;
      expect(SmartFolders.newCount(folder, [rec(500), rec(1500), rec(2000)]), 2);
    });
  });

  group('faturalar', () {
    test('tutar biçimleri', () {
      expect(Bills.parseAmount('1.234,56'), 1234.56);
      expect(Bills.parseAmount('412,50'), 412.5);
      expect(Bills.parseAmount('99.90'), 99.9);
      expect(Bills.parseAmount('0,00'), isNull);
      expect(Bills.formatAmount(1234.5, 'TL'), '1.234,50 TL');
    });

    test('cihazda tahmin: en büyük toplam, son ödeme tarihi, kurum', () {
      const text = 'ENERJİSA BAŞKENT\nAra Toplam 350,00 TL\nKDV 63,00\n'
          'ÖDENECEK TUTAR 413,00 TL\nSon Ödeme Tarihi: 25.10.2026';
      final b = Bills.guessFromText('/f.pdf', 1, text);
      expect(b.amount, 413.0);
      expect(DateTime.fromMillisecondsSinceEpoch(b.dueMs!),
          DateTime(2026, 10, 25));
      expect(b.issuer, 'ENERJİSA BAŞKENT');
      expect(b.currency, 'TL');
    });

    test('aylık özet ve yaklaşan son ödeme', () {
      final bills = Bills.instance..debugReset();
      final now = DateTime(2026, 10, 18).millisecondsSinceEpoch;
      int day(int d) => DateTime(2026, 10, d).millisecondsSinceEpoch;
      bills.debugPut(Bill(
          path: '/a', modifiedMs: 1, issuer: 'Su', amount: 100,
          dueMs: day(20), periodMs: day(5)));
      bills.debugPut(Bill(
          path: '/b', modifiedMs: 1, issuer: 'Elektrik', amount: 250.5,
          dueMs: day(30), periodMs: day(6)));
      bills.debugPut(Bill(
          path: '/c', modifiedMs: 1, issuer: 'Eski', amount: 10,
          dueMs: day(19), periodMs: day(1), paid: true));
      final months = bills.months();
      expect(months.single.totals['TL'], 360.5);
      final soon = bills.upcoming(nowMs: now);
      expect(soon.map((b) => b.issuer), ['Su']);
      final reminders = bills.reminders(nowMs: now);
      expect(reminders.map((r) => r['title']), containsAll(['Su', 'Elektrik']));
      expect(reminders.map((r) => r['title']), isNot(contains('Eski')));
    });

    test('adaylar: AI türü ya da adında fatura geçenler', () {
      AiRecord rec(String path, String type) => AiRecord.fromJson(
          {'p': path, 's': 1, 'm': 1, 'd': type})!;
      final list = Bills.candidates([
        rec('/x/a.pdf', 'Fatura'),
        rec('/x/Eryaman_Konut_Faturasi.pdf', ''),
        rec('/x/tatil.jpg', 'fotoğraf'),
      ]);
      expect(list.map((r) => r.path), hasLength(2));
    });
  });

  test('yerel iş ayarı: hatırlatmalar ve metinler JSON olarak gider', () {
    final cfg = NativeExtras.dailyConfig(
      cleanup: true,
      recoverableBytes: 42,
      reminders: [
        {'title': 'Su', 'amount': '100,00 TL', 'due': 5}
      ],
      strings: {'bill_title': 'x {title}'},
    );
    final back = jsonDecode(jsonEncode(cfg)) as Map;
    expect(back['recoverable'], 42);
    expect((back['reminders'] as List).single['title'], 'Su');
    expect(back['remindDays'], Bills.remindDays);
  });

  group('anılar', () {
    test('bu gün: yalnız geçmiş yıllar, aynı ay-gün, yeni yıl önce', () {
      FsEntry e(String name) => FsEntry(
          path: '/$name', name: name, isDir: false, sizeBytes: 1, modifiedMs: 0);
      final dates = {
        'a': DateTime(2024, 10, 18, 9),
        'b': DateTime(2021, 10, 18, 20),
        'c': DateTime(2026, 10, 18),
        'd': DateTime(2024, 10, 17),
      };
      final out = PhotoInsights.onThisDayOf(
        [for (final n in dates.keys) e(n)],
        (x) => dates[x.name]!.millisecondsSinceEpoch,
        now: DateTime(2026, 10, 18, 12),
      );
      expect(out.keys, [2024, 2021]);
      expect(out[2024]!.single.name, 'a');
    });

    test('yakın konumlar aynı kümede', () {
      expect(PhotoInsights.clusterKey(39.9008, 32.8541),
          PhotoInsights.clusterKey(39.9101, 32.8602));
      expect(PhotoInsights.clusterKey(39.92, 32.85),
          isNot(PhotoInsights.clusterKey(41.01, 28.97)));
    });

    test('EXIF GPS çözülür (K/D ve G/B işaretleri)', () {
      Uint8List jpegWithGps({required bool south}) {
        // TIFF (II): IFD0 → tek etiket 0x8825 (GPS IFD) → 4 etiket.
        final t = BytesBuilder();
        void u16(int v) => t.add([v & 0xFF, v >> 8]);
        void u32(int v) =>
            t.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, v >> 24]);
        t.add([0x49, 0x49]);
        u16(42);
        u32(8); // IFD0
        u16(1);
        u16(0x8825); u16(4); u32(1); u32(26); // GPS IFD @26
        u32(0);
        // GPS IFD @26: 4 etiket → 2 + 48 + 4 = 54 → veri @80
        u16(4);
        u16(1); u16(2); u32(2); t.add([south ? 0x53 : 0x4E, 0, 0, 0]);
        u16(2); u16(5); u32(3); u32(80);
        u16(3); u16(2); u32(2); t.add([0x45, 0, 0, 0]);
        u16(4); u16(5); u32(3); u32(104);
        u32(0);
        // 39° 55' 12" ve 32° 51' 0"
        for (final v in [39, 55, 12, 32, 51, 0]) {
          u32(v);
          u32(1);
        }
        final tiff = t.toBytes();
        final app1 = [...'Exif'.codeUnits, 0, 0, ...tiff];
        final size = app1.length + 2;
        return Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE1, size >> 8, size & 0xFF, ...app1,
          0xFF, 0xDA, 0, 2,
        ]);
      }

      final north = ExifReader.parseGps(jpegWithGps(south: false))!;
      expect(north.lat, closeTo(39.92, 0.001));
      expect(north.lon, closeTo(32.85, 0.001));
      final south = ExifReader.parseGps(jpegWithGps(south: true))!;
      expect(south.lat, closeTo(-39.92, 0.001));
      expect(ExifReader.parseGps(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });

  testWidgets('QR kodu çizilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: QrCode(data: 'http://192.168.1.5:8080'))),
    ));
    expect(find.byType(QrCode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
