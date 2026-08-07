import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı isteği 2026-07-31: *"çöp kutusunu bulmak çok zor, üstteki büyük
/// simgelerden 1'i olsun, altta olmasın ve doluysa animasyonu olsun."*
///
/// Animasyonun **koşullu** olması işin özü: her zaman oynayan bir kutu bir
/// süre sonra görünmez olur, hiç oynamayan kutu da "dolu" bilgisini vermez.
Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: SizedBox(width: 150, height: 150, child: child)),
      ),
    );

FmTileData _tile({required bool pulse}) => FmTileData(
      icon: pulse ? Icons.delete : Icons.delete_outline,
      color: const Color(0xFFE65100),
      label: 'Çöp kutusu',
      subtitle: pulse ? '3 öğe' : 'Boş',
      pulse: pulse,
      onTap: () {},
    );

void main() {
  testWidgets('dolu çöp kutusu kutucuğu canlanır', (tester) async {
    await tester.pumpWidget(_wrap(FmCategoryTile(data: _tile(pulse: true))));

    expect(find.byKey(FmCategoryTile.pulseKey), findsOneWidget);
    expect(find.text('3 öğe'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    // Ölçek gerçekten değişiyor mu (sabit bir ScaleTransition işe yaramaz).
    ScaleTransition current() => tester.widget<ScaleTransition>(find.descendant(
        of: find.byKey(FmCategoryTile.pulseKey),
        matching: find.byType(ScaleTransition)));
    final basla = current().scale.value;
    await tester.pump(const Duration(milliseconds: 650));
    expect(current().scale.value, isNot(closeTo(basla, 0.001)));

    // Süresiz animasyon testi kilitlemesin.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('canlanma birkaç saniye sonra DURUR (pil)', (tester) async {
    // 2026-08-07 pil denetimi: animasyon sonsuza kadar dönüyordu, yani pano
    // açıkken uygulama hiç boşa geçmiyor ve 120 Hz ekranda saniyede 120 kare
    // üretiliyordu. Dikkat çekme işi birkaç saniyede biter.
    await tester.pumpWidget(_wrap(FmCategoryTile(data: _tile(pulse: true))));
    await tester.pump(const Duration(milliseconds: 650));

    // Yeterince beklendiğinde bekleyen kare kalmamalı: `pumpAndSettle`
    // sonsuz animasyonda zaman aşımına düşer, bu satır tam onu yakalar.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    final scale = tester
        .widget<ScaleTransition>(find.descendant(
            of: find.byKey(FmCategoryTile.pulseKey),
            matching: find.byType(ScaleTransition)))
        .scale
        .value;
    expect(scale, closeTo(1.0, 0.01),
        reason: 'durunca dinlenme boyutuna dönmeli, büyük kalmamalı');
  });

  testWidgets('boş çöp kutusu sessiz durur', (tester) async {
    await tester.pumpWidget(_wrap(FmCategoryTile(data: _tile(pulse: false))));

    expect(find.byKey(FmCategoryTile.pulseKey), findsNothing);
    expect(find.text('Boş'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  /// Hareket duyarlılığı olan kullanıcıya sürekli titreyen bir kutu
  /// dayatılmamalı; kutu o durumda renk ve simgeyle ayırt ediliyor.
  testWidgets('cihazda animasyonlar kapalıysa oynamaz', (tester) async {
    await tester.pumpWidget(_wrap(
      FmCategoryTile(data: _tile(pulse: true)),
      disableAnimations: true,
    ));
    await tester.pump(const Duration(milliseconds: 650));

    final scale = tester
        .widget<ScaleTransition>(find.descendant(
            of: find.byKey(FmCategoryTile.pulseKey),
            matching: find.byType(ScaleTransition)))
        .scale
        .value;
    expect(scale, closeTo(1.0, 0.001));
    // Bekleyen animasyon kalmamalı (pumpAndSettle asılı kalmaz).
    await tester.pumpAndSettle();
  });
}
