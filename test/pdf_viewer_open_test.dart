import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/screens/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-11-03 hata kaydı (sürüm 475): her PDF "Bu ekran çizilemedi" —
/// pdfrx 2.x `PdfTextSearcher` yapıcısı bağlanmamış denetleyicinin belgesine
/// abone oluyordu (`initState`). Ekran ilk karede düşmemeli.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('PDF görüntüleyici ilk karede düşmüyor', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ViewerScreen(
          doc: LoadedDoc(path: '/tmp/yok.pdf', name: 'yok.pdf', kind: DocKind.pdf),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(ViewerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
