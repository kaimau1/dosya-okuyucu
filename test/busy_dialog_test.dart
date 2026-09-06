import 'dart:async';

import 'package:dosya_okuyucu/core/busy_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Kararan ekranın testi** (kullanıcı hatası 2026-09-06: *"kopyala gibi
/// işlemler yapıldıktan sonra ekran kararıyor, kapatıp açmak gerekiyor"*).
///
/// Kök neden şuydu: "çalışıyor" penceresi `showDialog` ile açılıyor, sonra
/// `Navigator.pop(context)` ile kapatılıyordu. `pop` bir pencereyi değil
/// **yığının en üstündekini** kapatır; pencere aradan çıkmışsa (kullanıcı
/// geri tuşuna bastı — `barrierDismissible: false` geri tuşunu ENGELLEMEZ)
/// o `pop` arkadaki SAYFAYI kapatıyordu. Sayfa tek başınaysa `Navigator`
/// boşalıyor ve ekran kararıyordu.
///
/// Testler ürünün gerçek yerleşimini kuruyor: iş sayfası kök sayfanın
/// ÜSTÜNDE, pencere de onun üstünde.
void main() {
  /// Kök sayfa + üstünde iş sayfası. Dönen `BuildContext` iş sayfasınındır.
  Future<BuildContext> pushWorkPage(WidgetTester tester) async {
    late BuildContext workContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) {
                workContext = ctx;
                return const Scaffold(body: Text('iş sayfası'));
              },
            )),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('iş sayfası'), findsOneWidget);
    return workContext;
  }

  testWidgets('pencere kapanır, sayfa yerinde kalır', (tester) async {
    final context = await pushWorkPage(tester);
    final busy = showBusyDialog(context,
        builder: (_) => const AlertDialog(content: Text('çalışıyor')));
    await tester.pumpAndSettle();
    expect(find.text('çalışıyor'), findsOneWidget);

    busy.close();
    await tester.pumpAndSettle();
    expect(find.text('çalışıyor'), findsNothing);
    expect(find.text('iş sayfası'), findsOneWidget);
  });

  testWidgets(
      'KULLANICI GERİ TUŞUYLA kapattıysa close() sayfayı KAPATMAZ '
      '(kararan ekranın kök nedeni)', (tester) async {
    final context = await pushWorkPage(tester);
    final busy = showBusyDialog(context,
        builder: (_) => const AlertDialog(content: Text('çalışıyor')));
    await tester.pumpAndSettle();

    // Kullanıcı beklemekten sıkıldı, geri tuşuna bastı: pencere kapandı.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('çalışıyor'), findsNothing);
    expect(find.text('iş sayfası'), findsOneWidget);

    // İş bitti ve kapatma şimdi geliyor. ESKİ KOD BURADA SAYFAYI KAPATIYORDU.
    busy.close();
    await tester.pumpAndSettle();
    expect(find.text('iş sayfası'), findsOneWidget);
    expect(busy.isOpen, isFalse);
  });

  testWidgets('üstüne başka pencere bindiyse YALNIZ kendini kaldırır',
      (tester) async {
    final context = await pushWorkPage(tester);
    final busy = showBusyDialog(context,
        builder: (_) => const AlertDialog(content: Text('çalışıyor')));
    await tester.pumpAndSettle();

    // Araya giren ikinci bir pencere (ör. bir hata sorusu).
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('soru')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('soru'), findsOneWidget);

    busy.close();
    await tester.pumpAndSettle();
    // Soru penceresi AYAKTA, "çalışıyor" gitti: `pop` olsaydı tam tersi olurdu.
    expect(find.text('soru'), findsOneWidget);
    expect(find.text('çalışıyor'), findsNothing);
    expect(find.text('iş sayfası'), findsOneWidget);
  });

  testWidgets(
      'iş İLK KAREDEN ÖNCE biterse pencere yine kapanır '
      '(küçük dosyada kopyalama)', (tester) async {
    final context = await pushWorkPage(tester);
    final busy = showBusyDialog(context,
        builder: (_) => const AlertDialog(content: Text('çalışıyor')));
    // Hiç `pump` YOK: pencere daha çizilmedi. Eski kodun "kapatacak
    // `context` henüz yok" tuzağı buydu — pencere sonradan açılıp ekranda
    // asılı kalıyor ya da bir kare sonra kendi kendine `pop` atıp yanlış
    // rotayı kapatıyordu.
    busy.close();
    await tester.pumpAndSettle();
    expect(find.text('çalışıyor'), findsNothing);
    expect(find.text('iş sayfası'), findsOneWidget);
  });

  testWidgets('iki kez close() çağırmak zararsız', (tester) async {
    final context = await pushWorkPage(tester);
    final busy = showBusyDialog(context,
        builder: (_) => const AlertDialog(content: Text('çalışıyor')));
    await tester.pumpAndSettle();
    busy.close();
    busy.close();
    await tester.pumpAndSettle();
    expect(find.text('iş sayfası'), findsOneWidget);
  });
}
