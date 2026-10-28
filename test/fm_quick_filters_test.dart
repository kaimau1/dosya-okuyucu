import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hızlı süzgeç çipleri: **çipin üstündeki sayı, dokununca çıkan sonuçla aynı
/// olmalı.** Eskiden sayılar ham listeden hesaplanıyordu; başka bir çip
/// seçiliyken "Büyük dosyalar · 312" yazan çipe dokununca 4 dosya çıkıyordu
/// (kullanıcı 2026-08-09: *"filtrelerin bir çoğu doğru çalışmıyor"*).
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  const mb = 1024 * 1024;
  final now = DateTime.now().millisecondsSinceEpoch;

  FsEntry file(String path, {int size = 1000, int? ms}) => FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: false,
        sizeBytes: size,
        modifiedMs: ms ?? now,
      );

  // İki WhatsApp dosyası (biri büyük), bir kamera dosyası (büyük).
  final source = [
    file('/depo/WhatsApp/Media/WhatsApp Images/a.jpg', size: 500 * mb),
    file('/depo/WhatsApp/Media/WhatsApp Images/b.jpg', size: 100),
    file('/depo/DCIM/Camera/c.jpg', size: 400 * mb),
  ];

  Future<FmFilter> pump(WidgetTester tester, FmFilter filter) async {
    var current = filter;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => FmQuickFilters(
            source: source,
            filter: current,
            onChanged: (f) => setState(() => current = f),
          ),
        ),
      ),
    ));
    await tester.pump();
    return current;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('source-pill')));
    await tester.pumpAndSettle();
  }

  String countOf(WidgetTester tester, String key) {
    final texts = find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Text));
    return tester.widgetList<Text>(texts).last.data ?? '';
  }

  testWidgets('çip sayısı ÖTEKİ ölçütlere bağlıdır', (tester) async {
    // Süzgeç boşken: üç dosyanın ikisi 100 MB üzeri.
    await pump(tester, FmFilter.none);
    await openSheet(tester);
    expect(countOf(tester, 'src-large'), '2');
    await tester.tap(find.byKey(const ValueKey('src-done')));
    await tester.pumpAndSettle();

    // WhatsApp seçiliyken aynı kutu yalnız WhatsApp'takileri saymalı (1).
    await pump(tester, FmFilter.none.toggleBucket(MediaBucket.whatsapp));
    await openSheet(tester);
    expect(countOf(tester, 'src-large'), '1');
  });

  testWidgets('“son 6 ayda açılanlar” çipi vardır ve seçilebilir',
      (tester) async {
    await pump(tester, FmFilter.none);
    await openSheet(tester);
    expect(find.textContaining('Son 6 ayda açılanlar'), findsOneWidget);
    // Dosyaların hepsi bugün değiştirilmiş → üçü de "açılanlar" sayılır.
    expect(countOf(tester, 'src-opened'), '3');
  });

  testWidgets('karşıt çipe dokunmak öncekini kapatır', (tester) async {
    // İkisi birden açık kalsa liste her zaman boş çıkardı.
    final f = FmFilter.none.withOpenedWithinDays(180).withUntouchedDays(180);
    expect(f.openedWithinDays, isNull);
    expect(f.untouchedDays, 180);

    await pump(tester, f);
    await openSheet(tester);
    // Ölçüt açıkken kutu, sayısı sıfır olsa da çizilir — yoksa kullanıcı açtığı
    // süzgeci kapatamazdı.
    expect(find.textContaining('aydır açılmamış'), findsOneWidget);
  });

  testWidgets('çip metinleri ARAYÜZ DİLİNDE yazılır', (tester) async {
    // Boyut ve kaynak etiketleri modelde Türkçe SABİT duruyor (klasör adı
    // üretiminde kullanılıyorlar); ekranda çeviri anahtarından gelmeliler.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: Scaffold(
        body: FmQuickFilters(
          source: source,
          filter: FmFilter.none,
          onChanged: (_) {},
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('source-pill')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Over 100 MB'), findsOneWidget);
    expect(find.textContaining('Opened in the last 6 months'), findsOneWidget);
    expect(find.textContaining('100 MB üzeri'), findsNothing);
  });
}
