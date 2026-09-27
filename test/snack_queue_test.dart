import 'package:dosya_okuyucu/core/snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **"Uyarı yazıları gitmiyor, elle kapatmak gerekiyor"** (kullanıcı
/// 2026-08-30, PDF düzenlerken).
///
/// KÖK NEDEN: `ScaffoldMessenger` şeritleri KUYRUĞA alır. Bir düzenleme
/// birden çok bildirim üretebiliyor ("değiştirildi", "metin taşıyor",
/// "belge kilidi kaldırıldı", sonra kaydetme sonucu) ve her biri
/// öncekinin süresi dolana kadar bekliyordu: ekranın altı — düzenleme
/// çubuğunun tam durduğu yer — arka arkaya on saniyelerce kapalı kalıyor,
/// kullanıcı tek tek kaydırıp atmak zorunda kalıyordu.
///
/// Kural: **yeni bildirim eskisinin YERİNE geçer**, arkasına dizilmez.
void main() {
  /// İçinde bir düğmeyle şerit gösteren küçük ekran.
  Widget host(void Function(BuildContext) onTap) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onTap(context),
              child: const Text('bas'),
            ),
          ),
        ),
      );

  testWidgets('ikinci bildirim birincinin YERİNE geçer', (tester) async {
    await tester.pumpWidget(host((context) {
      showSnack(context, 'birinci');
      showSnack(context, 'ikinci');
    }));

    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Eskiden burada YALNIZ "birinci" görünürdü; "ikinci" onun 4 saniyesi
    // dolana kadar sıra beklerdi.
    expect(find.text('ikinci'), findsOneWidget);
    expect(find.text('birinci'), findsNothing);
  });

  testWidgets('bildirim kendiliğinden kaybolur (elle kapatmak gerekmez)',
      (tester) async {
    await tester.pumpWidget(host((context) => showSnack(context, 'bilgi')));

    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('bilgi'), findsOneWidget);

    // Bilgi şeridinin ömrü kısaltıldı: 3 sn + kapanış animasyonu.
    await tester.pump(kSnackInfo);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('bilgi'), findsNothing);
  });

  testWidgets('düğmeli bildirim daha uzun durur', (tester) async {
    await tester.pumpWidget(host((context) => showSnack(
          context,
          'geri al?',
          action: SnackBarAction(label: 'Geri al', onPressed: () {}),
        )));

    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    // Bilgi süresi dolduğunda hâlâ ekranda: kullanıcı okuyup basacak.
    await tester.pump(kSnackInfo);
    expect(find.text('geri al?'), findsOneWidget);
    await tester.pump(kSnackAction);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('geri al?'), findsNothing);
  });

  testWidgets('KALICI kart varken yeni bildirim onu süpürmez',
      (tester) async {
    // Arka plana alınmış bir işin ilerleme kartı iş bitene dek duruyor
    // (bkz. showFmProgress). Araya giren bir bilgi mesajı onu silseydi
    // kullanıcının işi görünmez kalırdı. Artık ikisi AYRI yuvada: kısa
    // bildirim kalıcının üstünde görünür.
    late ToastHandle sticky;
    await tester.pumpWidget(host((context) {
      sticky = showStickyToast(context, const Text('kopyalanıyor'));
      showSnack(context, 'araya giren');
    }));

    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('kopyalanıyor'), findsOneWidget);
    expect(find.text('araya giren'), findsOneWidget);

    // Kısa olan süresi dolunca gider, kalıcı kalır.
    await tester.pump(kSnackInfo);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('araya giren'), findsNothing);
    expect(find.text('kopyalanıyor'), findsOneWidget);

    sticky.close();
    await tester.pump();
    expect(find.text('kopyalanıyor'), findsNothing);
  });

  testWidgets('parmak kartın üstündeyken süre DURUR', (tester) async {
    await tester.pumpWidget(host((context) => showSnack(context, 'okuyorum')));
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('okuyorum')));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('okuyorum'), findsOneWidget);
    await gesture.up();
    await tester.pump(); // sayım yeniden başladı
    await tester.pump(kSnackInfo);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('okuyorum'), findsNothing);
  });

  testWidgets('kart ekranın EN ALTINDA, alt çubuk ve yüzen düğmenin üstünde '
      'değil', (tester) async {
    // Kullanıcı: "uyarılar çok yukarıda, alt kısma sığmalı".
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton:
            FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
        bottomNavigationBar: const SizedBox(height: 80),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSnack(context, 'altta'),
            child: const Text('bas'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final bottom = tester.getBottomLeft(find.text('altta')).dy;
    expect(screen.height - bottom, lessThan(40));
  });

  testWidgets('geri sayım çubuğu kalan süreyle kısalır', (tester) async {
    await tester.pumpWidget(host((context) => showSnack(context, 'sayaç')));
    await tester.tap(find.text('bas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FractionallySizedBox bar() => tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox).last);
    final early = bar().widthFactor!;
    await tester.pump(const Duration(milliseconds: 1500));
    final later = bar().widthFactor!;
    expect(early, greaterThan(0.9));
    expect(later, lessThan(early));
    await tester.pump(const Duration(seconds: 5));
  });
}
