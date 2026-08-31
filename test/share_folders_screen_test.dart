import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/remote/share_folders_screen.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_service.dart';
import 'package:dosya_okuyucu/services/fm/remote/ftp_tree.dart';
import 'package:dosya_okuyucu/services/fm/remote/share_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Paylaşılacak klasörler ekranı** (kullanıcı isteği 2026-08-31):
/// *"paylaşılacak klasör seçimi tümünü seç kaldır seçeneği olmalı"*.
///
/// Ölçülen şey ekranın SÖZÜ: her dokunuş kapsamı anında değiştiriyor (kaydet
/// düğmesi yok), "tümünü seç" tek dokunuşta hepsini alıp hepsini bırakıyor ve
/// "yalnız Paylaşılan" kipi kutu listesini kapatıyor.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Liste tembel çiziliyor: varsayılan 800×600 tuvalde kutuların yarısı hiç
  // kurulmaz ve "bulunamadı" hatası ekranı değil TUVALİ ölçerdi.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(
    locale: Locale('tr'),
    supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
    localizationsDelegates: _delegates,
    home: ShareFoldersScreen(),
  ));
  await tester.pumpAndSettle();
}

/// Ekranın kapsamı servise yazması asenkron (`SharedPreferences`); dokunuştan
/// sonra kuyruğun boşalması bekleniyor.
Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Servis tekil (singleton): testler birbirinin kapsamını devralmasın.
    await FtpService.instance.setShareScope(ShareScope.all);
  });

  testWidgets('varsayılan: hepsi seçili, düğme "Seçimi kaldır" diyor',
      (tester) async {
    await _pump(tester);
    expect(find.text('Seçimi kaldır'), findsOneWidget);
    expect(find.text('Tümünü seç'), findsNothing);
    // Kutuların her biri listede: kullanıcı neyi paylaştığını görebilmeli.
    expect(find.byType(CheckboxListTile),
        findsNWidgets(FtpTree.allBoxes.length + 1)); // +1: toptan seçim satırı
  });

  testWidgets('"Seçimi kaldır" hepsini bırakır, sonra hepsini geri alır',
      (tester) async {
    await _pump(tester);
    await _tapText(tester, 'Seçimi kaldır');
    expect(FtpService.instance.shareScope.boxes, isEmpty);
    // Boş kapsam SESSİZ kalmıyor: paylaşım açılsa da PC boş görürdü.
    expect(find.textContaining('Hiçbir klasör seçili değil'), findsOneWidget);

    await _tapText(tester, 'Tümünü seç');
    expect(FtpService.instance.shareScope.boxes,
        FtpTree.allBoxes.toSet());
  });

  testWidgets('tek kutuyu kaldırmak yalnız onu çıkarır', (tester) async {
    await _pump(tester);
    await _tapText(tester, 'Belgeler');
    final boxes = FtpService.instance.shareScope.boxes!;
    expect(boxes, isNot(contains('Belgeler')));
    expect(boxes, contains('Resimler'));
    expect(boxes.length, FtpTree.allBoxes.length - 1);
  });

  testWidgets('"Yalnız Paylaşılan" kipi kutu listesini KAPATIR',
      (tester) async {
    await _pump(tester);
    await _tapText(tester, 'Yalnız Paylaşılan klasörü');
    expect(FtpService.instance.shareScope.mode, ShareMode.sharedOnly);
    // Liste gizlenmiyor, SÖNÜKLEŞİYOR: kipin ne yaptığı görünür kalsın.
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles.every((t) => t.onChanged == null), isTrue);

    // Kutu seçimleri kaybolmuyor: kipi geri alınca eski liste duruyor.
    await _tapText(tester, 'Seçtiğim klasörler');
    expect(FtpService.instance.shareScope.mode, ShareMode.boxes);
    expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .any((t) => t.onChanged != null),
        isTrue);
  });
}
