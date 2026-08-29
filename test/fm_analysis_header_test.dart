import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/fm/analysis_screen.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var (kullanıcı 2026-08-29: *"bellek analizi kısmı üst kısım
/// özellikle yılın şeklinde duruyor, daha modern bir tasarıma geçmeli tüm
/// sayfa"*):**
///
/// Ekranın manşeti artık **kalan yer** — eskiden en önemli sayı 12 puntoluk
/// gri bir satırın içinde, iki başka sayının arasında kayboluyordu. Analiz
/// araçları da üç ayrı kart yerine tek kartta. Bu test manşetin gerçekten
/// çizildiğini ve büyük yazı ölçeğinde de taşmadığını doğrular.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  // Kapasite ONDALIK: `capacityBytes` ham boyutu cihazın üstünde yazan sayıya
  // yuvarlıyor (AOSP `roundStorageSize`). 512 GB tam bir basamak olduğu için
  // yuvarlama onu değiştirmez ve yüzde tam çıkar: 512 → 256 boş = %50.
  const gb = 1000 * 1000 * 1000;
  const volume = StorageVolume(
    path: '/storage/emulated/0',
    isPrimary: true,
    labelKey: 'fm.vol_internal',
    totalBytes: 512 * gb,
    freeBytes: 256 * gb,
  );

  Future<void> pump(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const AnalysisScreen(
            index: StorageIndex.empty,
            volumes: [volume],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('manşet KALAN YER; doluluk yüzdesi rozette', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    // "… boş" manşeti (kapasite ondalık gösterilir — telefonun üstünde yazan
    // sayı bu).
    expect(
      find.textContaining(RegExp(r'boş$')),
      findsWidgets,
      reason: 'kalan yer manşeti çizilmedi',
    );
    // 512 GB'ın 256 GB'ı boş → %50 rozeti.
    expect(find.text('%50'), findsOneWidget);
  });

  testWidgets('üç analiz aracı TEK kartta, çizgilerle ayrılmış',
      (tester) async {
    await pump(tester);
    const strings = AppStrings(AppLanguage.tr);
    for (final key in const [
      'ana.free_space',
      'ana.find_dupes',
      'fmap.title',
    ]) {
      expect(find.text(strings.t(key)), findsOneWidget, reason: key);
    }
    // Üç satır, iki ayraç: üç ayrı kart olsaydı hiç `Divider` olmazdı.
    expect(find.byType(Divider), findsWidgets);
  });

  testWidgets('1.5 yazı ölçeğinde de taşmaz', (tester) async {
    await pump(tester, textScale: 1.5);
    expect(tester.takeException(), isNull);
  });
}
