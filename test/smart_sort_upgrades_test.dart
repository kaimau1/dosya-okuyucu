import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/smart_sort_screen.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_input.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ss_up_');
  });

  tearDown(() {
    SmartSort.debugReset();
    SmartSort.lastUsage.value = null;
    SmartSort.progress.value = null;
    FmFilter.aliasOf = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('token tasarrufu ve girdi optimizasyonu', () {
    test('optimizeImageBytes: büyük görsel <=1024px JPEG olarak küçülür', () {
      final big = imglib.Image(width: 2400, height: 1600);
      imglib.fill(big, color: imglib.ColorRgb8(245, 245, 245));
      for (var y = 100; y < 1500; y += 20) {
        imglib.drawLine(big,
            x1: 50, y1: y, x2: 2350, y2: y, color: imglib.ColorRgb8(30, 30, 30));
      }
      final pngBytes = Uint8List.fromList(imglib.encodePng(big));
      final opt =
          SmartSortInput.optimizeImageBytes(pngBytes, mime: 'image/png');
      expect(opt.mime, 'image/jpeg');
      final decoded = imglib.decodeImage(opt.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(SmartSortInput.maxImageDim));
      expect(decoded.height, lessThanOrEqualTo(SmartSortInput.maxImageDim));
      expect(decoded.width, SmartSortInput.maxImageDim);
    });

    test('optimizeImageBytes: küçük görsel CPU harcamadan ham kalır', () {
      final small = imglib.Image(width: 320, height: 240);
      final pngBytes = Uint8List.fromList(imglib.encodePng(small));
      final opt =
          SmartSortInput.optimizeImageBytes(pngBytes, mime: 'image/png');
      expect(opt.mime, 'image/png');
      expect(opt.bytes.length, pngBytes.length);
    });

    test('PDF metin hızlı yolu: metinli PDF text bloğu, boş PDF ham document',
        () async {
      // Metin katmanlı PDF oluştur.
      final doc = PdfDocument();
      final page = doc.pages.add();
      page.graphics.drawString(
        'ELEKTRIK FATURASI - ENERJISA\n'
        'Abone No: 9876543210\n'
        'Fatura Donemi: Ekim 2026 - Son Odeme Tarihi: 2026-11-25\n'
        'Toplam Odenecek Tutar: 1245.50 TL\n'
        'Bu belge elektronik fatura olarak duzenlenmistir. '
        'Otomatik odeme talimati mevcut degildir, son odeme tarihine kadar '
        'banka veya yetkili odeme noktalarindan odeyebilirsiniz.',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 500, 400),
      );
      final textPdfBytes = Uint8List.fromList(await doc.save());
      doc.dispose();

      final textFile = File('${tmp.path}/fatura.pdf')
        ..writeAsBytesSync(textPdfBytes);
      final block = await SmartSortInput.blockFor(FsEntry(
        path: textFile.path,
        name: 'fatura.pdf',
        isDir: false,
        sizeBytes: textPdfBytes.length,
        modifiedMs: 1,
      ));
      expect(block['type'], 'text');
      expect(block['text'] as String, contains('ENERJISA'));
      expect(block['text'] as String, contains('1245.50 TL'));

      // Metinsiz (taranmış benzeri) boş PDF ham document bloğuna düşer.
      final blank = PdfDocument();
      blank.pages.add();
      final blankBytes = Uint8List.fromList(await blank.save());
      blank.dispose();
      final blankFile = File('${tmp.path}/tarama.pdf')
        ..writeAsBytesSync(blankBytes);
      final rawBlock = await SmartSortInput.blockFor(FsEntry(
        path: blankFile.path,
        name: 'tarama.pdf',
        isDir: false,
        sizeBytes: blankBytes.length,
        modifiedMs: 1,
      ));
      expect(rawBlock['type'], 'document');
      expect(rawBlock['mime_type'], 'application/pdf');
    });

    test('clip: uzun belgede hem başı hem sonundaki toplam/tarih korunur', () {
      final header = 'ELEKTRİK FATURASI BAŞLIK\n';
      final middle = 'Kalem satırı açıklama detayı\n' * 400;
      final footer = '\nGENEL TOPLAM: 1.850,00 TL\nSON ÖDEME: 28.11.2026';
      final clipped = SmartSortInput.clip(header + middle + footer);
      expect(clipped.length, lessThanOrEqualTo(SmartSortInput.maxTextChars));
      expect(clipped, contains('ELEKTRİK FATURASI BAŞLIK'));
      expect(clipped, contains('GENEL TOPLAM: 1.850,00 TL'));
      expect(clipped, contains('SON ÖDEME: 28.11.2026'));
    });

    test('sıkıştırılmış soru şeması kompakt boyutta', () {
      final qs = SmartTaxonomy.questions(
          image: true, today: DateTime(2026, 11, 23));
      final encoded = jsonEncode([for (final q in qs) q.toJson()]);
      // Sıkıştırma sonrası toplam soru şeması kompakt kalır (~10 KB).
      expect(encoded.length, lessThan(10500));
    });
  });

  group('hızlandırma ve sıfır belirteçli yerel kopya', () {
    test('uyarlanabilir işçi sayısı: tek anahtarda 4, çoklu anahtarda 6', () {
      expect(SmartSort.workerCountFor(1), 4);
      expect(SmartSort.workerCountFor(2), 6);
      expect(SmartSort.workerCountFor(4), 6);
    });

    test('contentFingerprint: özdeş dosyalar aynı, farklı içerik farklı',
        () async {
      final data = List<int>.generate(90 * 1024, (i) => i % 251);
      final a = File('${tmp.path}/a.pdf')..writeAsBytesSync(data);
      final b = File('${tmp.path}/b.pdf')..writeAsBytesSync(data);
      final diffData = [...data]..[data.length - 5] = 99;
      final c = File('${tmp.path}/c.pdf')..writeAsBytesSync(diffData);

      final fpA = await SmartSort.contentFingerprint(a.path, data.length);
      final fpB = await SmartSort.contentFingerprint(b.path, data.length);
      final fpC = await SmartSort.contentFingerprint(c.path, diffData.length);
      expect(fpA, isNotNull);
      expect(fpA, fpB);
      expect(fpA, isNot(fpC));
    });

    test('SmartRecord.cloneFor sınıflandırmayı yeni yola kopyalar', () {
      const src = SmartRecord(
        path: '/a/f1.pdf',
        size: 100,
        modifiedMs: 10,
        cat: 'invoice',
        conf: 0.91,
        sub: 'electricity',
        provider: 'enerjisa',
        month: 10,
        year: 2026,
        user: true,
        hidden: true,
      );
      final clone = src.cloneFor(const FsEntry(
        path: '/b/f2.pdf',
        name: 'f2.pdf',
        isDir: false,
        sizeBytes: 100,
        modifiedMs: 20,
      ));
      expect(clone.path, '/b/f2.pdf');
      expect(clone.cat, 'invoice');
      expect(clone.sub, 'electricity');
      expect(clone.provider, 'enerjisa');
      expect(clone.year, 2026);
      expect(clone.user, isFalse);
      expect(clone.hidden, isFalse);
    });
  });

  group('filtrasyon düzeltmeleri ve yeni akıllı süzgeçler', () {
    final today = DateTime(2026, 11, 23);
    final day = SmartDates.dayOf(today);

    test('FmFilter.matches: çok kelimeli ve ad+ikinci ad çapraz araması', () {
      FmFilter.aliasOf = (_) => 'Dekont · Ziraat Bankası · Ekim 2026';
      const e = FsEntry(
        path: '/Download/IMG_0042.pdf',
        name: 'IMG_0042.pdf',
        isDir: false,
        sizeBytes: 500,
        modifiedMs: 1,
      );
      expect(FmFilter.none.matches(e, query: 'ziraat 2026'), isTrue);
      expect(FmFilter.none.matches(e, query: 'img_0042 dekont'), isTrue);
      expect(FmFilter.none.matches(e, query: 'ekim bankasi'), isTrue);
      expect(FmFilter.none.matches(e, query: 'ziraat 2024'), isFalse);
    });

    test('yeni SmartSort süzgeçleri: yaklaşan, düşük güven, yıl, kurum, alt tür',
        () {
      SmartSort.debugReset([
        SmartRecord(
          path: '/d/el_2026.pdf',
          size: 100,
          modifiedMs: 10,
          cat: 'invoice',
          conf: 0.92,
          sub: 'electricity',
          provider: 'enerjisa',
          year: 2026,
          due: 'week',
          asked: day,
          amount: '500_2000',
        ),
        SmartRecord(
          path: '/d/su_gecmis.pdf',
          size: 100,
          modifiedMs: 9,
          cat: 'invoice',
          conf: 0.90,
          sub: 'water',
          provider: 'iski',
          year: 2025,
          due: 'past',
          asked: day,
          amount: '100_500',
        ),
        SmartRecord(
          path: '/d/pasaport.pdf',
          size: 100,
          modifiedMs: 8,
          cat: 'id',
          conf: 0.55,
          sub: 'passport',
          year: 2026,
          valid: 'month',
          asked: day,
        ),
        const SmartRecord(
          path: '/d/dekont_ziraat.pdf',
          size: 100,
          modifiedMs: 7,
          cat: 'bank',
          conf: 0.88,
          sub: 'transfer',
          bank: 'ziraat',
          year: 2026,
        ),
      ]);

      expect(SmartSort.upcomingDue(today).map((r) => r.path), ['/d/el_2026.pdf']);
      expect(SmartSort.overdue(today).map((r) => r.path), ['/d/su_gecmis.pdf']);
      expect(
          SmartSort.expiringSoon(today).map((r) => r.path), ['/d/pasaport.pdf']);
      expect(SmartSort.lowConfidence().map((r) => r.path), ['/d/pasaport.pdf']);
      expect(SmartSort.yearCounts(), {2026: 3, 2025: 1});
      expect(SmartSort.withYear(2025).map((r) => r.path), ['/d/su_gecmis.pdf']);
      expect(SmartSort.institutionCounts().keys,
          containsAll(['Enerjisa', 'İSKİ', 'Ziraat Bankası']));
      expect(SmartSort.withInstitution('Ziraat Bankası').map((r) => r.path),
          ['/d/dekont_ziraat.pdf']);
      expect(SmartSort.subtypeCounts('invoice'), {'electricity': 1, 'water': 1});
      expect(SmartSort.yearsOf('invoice'), [2026, 2025]);
      expect(SmartSort.institutionsOf('invoice'),
          containsAll(['Enerjisa', 'İSKİ']));
      expect(
        SmartSort.pathsOfFiltered('invoice', sub: 'electricity', year: 2026),
        ['/d/el_2026.pdf'],
      );
      // Dosya adıyla da SmartSort.matches bulur.
      expect(
        SmartSort.matches('dekont_ziraat').map((r) => r.path),
        ['/d/dekont_ziraat.pdf'],
      );
    });

    test('SmartTaxonomy.groupOf tüm grupları doğru eşler', () {
      expect(SmartTaxonomy.groupOf('invoice'), SmartCatGroup.finance);
      expect(SmartTaxonomy.groupOf('bank'), SmartCatGroup.finance);
      expect(SmartTaxonomy.groupOf('health'), SmartCatGroup.docs);
      expect(SmartTaxonomy.groupOf('screenshot'), SmartCatGroup.images);
      expect(SmartTaxonomy.groupOf('video'), SmartCatGroup.media);
      expect(SmartTaxonomy.groupOf('other'), isNull);
    });
  });

  group('SmartSortScreen UX ve filtre widget testleri', () {
    testWidgets(
        'arama, akıllı süzgeç şeridi, grup filtreleri, durdur ve tasarruf rozeti',
        (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'smart_sort_on': true});
        await SmartSort.setSettings(enabled: true);
      });
      final day = SmartDates.dayOf(DateTime.now());
      SmartSort.debugReset([
        SmartRecord(
          path: '/d/enerjisa_ekim.pdf',
          size: 100,
          modifiedMs: 100,
          cat: 'invoice',
          conf: 0.92,
          sub: 'electricity',
          provider: 'enerjisa',
          year: 2026,
          due: 'week',
          asked: day,
          amount: '500_2000',
        ),
        const SmartRecord(
          path: '/d/tahlil.pdf',
          size: 100,
          modifiedMs: 90,
          cat: 'health',
          conf: 0.52,
          sub: 'lab_result',
          year: 2026,
        ),
        const SmartRecord(
          path: '/d/shot.png',
          size: 100,
          modifiedMs: 80,
          cat: 'screenshot',
          conf: 0.95,
        ),
      ]);
      SmartSort.lastUsage.value =
          const SmartUsage(10, 18000, 220, reused: 4);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(),
          child: const MaterialApp(
            localizationsDelegates: [AppStrings.delegate],
            home: SmartSortScreen(),
          ),
        ),
      );
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Üst kart, belirteç ve yerelden eşleşme rozeti.
      expect(find.byKey(const ValueKey('ss-status')), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-usage')), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-reused')), findsOneWidget);

      // Akıllı süzgeç şeridi yeni süzgeçlerle dolu.
      expect(find.byKey(const ValueKey('ss-filters')), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-upcoming-due')), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-low-conf')), findsOneWidget);

      // Grup süzgeci: Finans seçilince yalnız Fatura kalır, Ekran görüntüsü gider.
      expect(find.byKey(const ValueKey('ss-cat-screenshot')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ss-group-finance')));
      await tester.pump();
      expect(find.byKey(const ValueKey('ss-cat-invoice')), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-cat-screenshot')), findsNothing);

      // Anlık arama: enerjisa yazınca sonuç gelir, temizleyince ızgara döner.
      await tester.enterText(
          find.byKey(const ValueKey('ss-search')), 'enerjisa');
      await tester.pump();
      expect(find.text('enerjisa_ekim.pdf'), findsOneWidget);
      expect(find.byKey(const ValueKey('ss-grid')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ss-search-clear')));
      await tester.pump();
      expect(find.byKey(const ValueKey('ss-grid')), findsOneWidget);

      // Çalışırken Durdur düğmesi görünür.
      SmartSort.progress.value = const SmartProgress(3, 10);
      await tester.pump();
      expect(find.byKey(const ValueKey('ss-stop')), findsOneWidget);
    });

    test('yeni çeviri anahtarları üç dilde dolu', () {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang);
        for (final k in const [
          'sm.stop',
          'sm.reused_n',
          'sm.search_hint',
          'sm.search_results',
          'sm.search_empty',
          'sm.filters_section',
          'sm.upcoming_due',
          'sm.expiring_soon',
          'sm.low_conf',
          'sm.year_title',
          'sm.inst_title',
          'sm.group_all',
          'sm.group_finance',
          'sm.group_docs',
          'sm.group_images',
          'sm.group_media',
          'sm.sub_all',
          'sm.clear_filter',
        ]) {
          expect(s.t(k, {'n': 2, 'y': 2026, 'name': 'X'}), isNot(k),
              reason: '${lang.name}:$k');
        }
      }
    });
  });
}
