import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `DosyaOkuyucuApp`in yazı ölçeği kilidiyle AYNI kurulum: sistem ölçeği
/// `copyWith(textScaler:)` ile yerinden edilir.
Widget _app(double uiScale, {required double systemScale}) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(systemScale)),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(uiScale)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('Merhaba', style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );

double _renderedSize(WidgetTester tester) {
  final text = tester.widget<Text>(find.text('Merhaba'));
  final scaler = tester
      .element(find.text('Merhaba'))
      .dependOnInheritedWidgetOfExactType<MediaQuery>()!
      .data
      .textScaler;
  return scaler.scale(text.style!.fontSize!);
}

void main() {
  testWidgets('sistemin yazı boyutu ayarı uygulamayı ETKİLEMEZ',
      (tester) async {
    // Kullanıcı isteği 2026-08-07: "yazı boyutu ve fontumuz tüm telefonlarda
    // sabit olmalı, sadece uygulama içerisinden değiştirilebilmeli".
    await tester.pumpWidget(_app(1.0, systemScale: 1.6));
    expect(_renderedSize(tester), 20.0);

    await tester.pumpWidget(_app(1.0, systemScale: 0.8));
    expect(_renderedSize(tester), 20.0);
  });

  testWidgets('uygulama içi ölçek DEĞİŞTİRİR', (tester) async {
    await tester.pumpWidget(_app(1.25, systemScale: 1.0));
    expect(_renderedSize(tester), 25.0);
  });

  test('varsayılan arayüz yazı tipi gömülü Carlito', () {
    // Ekranda okumak için tasarlanmış hümanist sans; Word/Excel varsayılanı
    // Calibri ile de aynı metrik.
    expect(AppTheme.fontBody, 'Carlito');
    expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Carlito');
    // Seçenekler APK'da GÖMÜLÜ ailelerle sınırlı — cihazda kurulu olup
    // olmamasına bağlı bir aile "her telefonda aynı" olmazdı.
    // Seçenekler APK'da GÖMÜLÜ ailelerle sınırlı; cihazın kendi 'monospace'i
    // telefondan telefona değiştiği için listede yok — yerine JetBrains Mono.
    expect(AppTheme.uiFonts.map((f) => f.$2),
        containsAll(<String>['Carlito', 'Inter', 'Merriweather', 'JetBrains Mono']));
    expect(AppTheme.uiFonts.length, greaterThanOrEqualTo(8));
  });

  test('varsayılan seçim BAŞLIK dahil her yere Carlito koyar', () {
    final theme = AppTheme.light(bodyFont: AppTheme.uiFontDefault);
    expect(AppTheme.uiFontDefault, AppTheme.fontBody);
    expect(theme.textTheme.titleLarge?.fontFamily, 'Carlito');
    expect(theme.extension<AppFonts>()?.mono, 'Carlito');
  });

  test('hazır boyut kademeleri: küçük / orta / büyük / çok büyük', () {
    // Kullanıcı isteği 2026-08-07: kaydırıcı tek başına "kolay seçim" değil.
    expect(AppTheme.uiTextScales.length, 4);
    expect(AppTheme.uiTextScales.map((s) => s.$2), [0.9, 1.0, 1.15, 1.3]);
    // Hepsi AppState'in izin verdiği aralıkta olmalı, yoksa seçilen kademe
    // kısılıp çubukta başka bir yer seçili görünürdü.
    for (final s in AppTheme.uiTextScales) {
      expect(s.$2, inInclusiveRange(0.85, 1.4));
    }
  });

  test('seçilen yazı tipi BAŞLIK ve VERİ satırlarına da işler', () {
    // 2026-08-07 kullanıcı: gezgin listesinde ad = başlık stili, tarih =
    // tek aralıklı; yalnız gövdeyi değiştiren ayar orada hiçbir şeyi
    // değiştirmiyordu ("hep aynı kalıyor").
    final theme = AppTheme.dark(bodyFont: 'Tinos');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Tinos');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Tinos');
    final fonts = theme.extension<AppFonts>();
    expect(fonts?.heading, 'Tinos');
    expect(fonts?.mono, 'Tinos');
  });

  test('ölçek okunur sınırlara kısılır', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    expect(state.uiTextScale, 1.0);
    await state.setUiTextScale(5);
    expect(state.uiTextScale, 1.4);
    await state.setUiTextScale(0.1);
    expect(state.uiTextScale, 0.85);
  });
}
