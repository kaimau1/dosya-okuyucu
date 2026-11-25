import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/fm_colors_store.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap(
  Widget child, {
  double width = 360,
  double textScale = 1.0,
  TextDirection direction = TextDirection.ltr,
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: AppState(),
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    FmColorsStore.resetForTest();
  });

  final entry = FsEntry(
    path: '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents/'
        'Tanıdan Tedaviye Güncel Yaklaşımlar Eğitimi 2026.pdf',
    name: 'Tanıdan Tedaviye Güncel Yaklaşımlar Eğitimi 2026.pdf',
    isDir: false,
    sizeBytes: 204800,
    modifiedMs: DateTime(2026, 11, 19).millisecondsSinceEpoch,
  );

  testWidgets(
      'ad, ikinci ad, etiketler, tarih ve boyut 360 dp ekranda eksiksiz görünür',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FmEntryRow(
        entry: entry,
        selected: false,
        selecting: false,
        subtitle: 'WhatsApp',
        dateText: '19 Kas',
        subtitleEnd: '200 KB',
        alias: 'Tahlil sonucu · Kasım 2026',
        tags: const {'Sağlık', 'Hastane', 'Önemli'},
        showDivider: true,
        thumbnails: false,
        onTap: () {},
        onMore: () {},
      ),
    ));

    expect(find.text(entry.name), findsOneWidget);
    // İkinci ad + etiketler TEK satırda (2026-11-25 sadeleştirme).
    expect(find.text('Tahlil sonucu · Kasım 2026  #Hastane  #Sağlık  #Önemli'),
        findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    // Tarih ve boyut birleşik Text.rich içinde kesilmeden görünür.
    expect(find.textContaining('19 Kas'), findsOneWidget);
    expect(find.textContaining('200 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çok etikette satır taşmaz, tek satırda kalır', (tester) async {
    await tester.pumpWidget(_wrap(
      FmEntryRow(
        entry: entry,
        selected: false,
        selecting: false,
        subtitle: 'İndirilenler',
        dateText: '18 Kas',
        subtitleEnd: '136 KB',
        alias: 'E-posta · Kasım 2026',
        tags: const {'A', 'B', 'C', 'D', 'E', 'F'},
        thumbnails: false,
        onTap: () {},
      ),
    ));

    final line = find.textContaining('E-posta · Kasım 2026  #A');
    expect(line, findsOneWidget);
    expect(tester.widget<Text>(line).maxLines, 1);
    expect(find.textContaining('18 Kas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2,0x erişilebilirlik yazı ölçeğinde 360 dp ekranda taşma yok',
      (tester) async {
    await tester.pumpWidget(_wrap(
      FmEntryRow(
        entry: entry,
        selected: true,
        selecting: true,
        subtitle: 'İndirilenler / Çok Uzun Klasör Adı',
        dateText: '19 Kas 2025',
        subtitleEnd: '2,0 MB',
        alias: 'Resmî belge · Kasım 2026',
        tags: const {'Fatura', 'Vergi'},
        thumbnails: false,
        onTap: () {},
        onMore: () {},
      ),
      width: 360,
      textScale: 2.0,
    ));

    expect(find.text('19 Kas 2025'), findsOneWidget);
    expect(find.text('2,0 MB'), findsOneWidget);
    expect(find.text('Resmî belge · Kasım 2026  #Fatura  #Vergi'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL (Arapça) yönde taşma yok', (tester) async {
    await tester.pumpWidget(_wrap(
      FmEntryRow(
        entry: entry,
        selected: false,
        selecting: false,
        subtitle: 'WhatsApp',
        dateText: '19 Kas',
        subtitleEnd: '200 KB',
        alias: 'Tahlil sonucu · Kasım 2026',
        tags: const {'Sağlık'},
        showDivider: true,
        thumbnails: false,
        onTap: () {},
        onMore: () {},
      ),
      direction: TextDirection.rtl,
    ));

    expect(find.textContaining('19 Kas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tarih rengi verilince yalnız tarih o renkte', (tester) async {
    const age = Color(0xFF2E7D32);
    await tester.pumpWidget(_wrap(
      FmEntryRow(
        entry: entry,
        selected: false,
        selecting: false,
        subtitle: 'Belgeler',
        dateText: '7 gün önce',
        dateColor: age,
        subtitleEnd: '136 KB',
        thumbnails: false,
        onTap: () {},
      ),
    ));
    final rich = tester.widget<Text>(find.textContaining('7 gün önce'));
    final span = (rich.textSpan! as TextSpan).children!.first as TextSpan;
    expect(span.style?.color, age);
    expect(tester.takeException(), isNull);
  });
}
