import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/onboarding/onboarding_screen.dart';
import 'package:dosya_okuyucu/widgets/permission_gate.dart';
import 'package:dosya_okuyucu/widgets/whats_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProbe extends PermissionProbe {
  @override
  Future<GateStatus> status(AppPermission p) async => GateStatus.denied;
  @override
  Future<GateStatus> request(AppPermission p) async => GateStatus.denied;
  @override
  Future<void> openSettings() async {}
}

Widget _app() => const MaterialApp(
      locale: Locale('tr'),
      supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: OnboardingGate(child: Scaffold(body: Text('ana ekran'))),
    );

/// Faz 11a / N1: ilk açılış rehberi yalnız YENİ kurulumda, bir kez.
void main() {
  setUp(() => PermissionGate.probe = _FakeProbe());

  testWidgets('yeni kurulumda üç sayfa; "Başla" kapatır ve bir daha çıkmaz',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionStatusRow), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Başla'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('ana ekran'), findsOneWidget);
    expect(await OnboardingScreen.isDone(), isTrue);
  });

  testWidgets('Faz 40 / 4: okuyucu · düzenleyici · tara; son sayfada örnekler',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Her dosyayı hızla oku'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Düzenle, dönüştür, paylaş'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Kâğıdı tara'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-samples')), findsOneWidget);
  });

  testWidgets('güncelleyen kullanıcı (eski kayıt var) rehberi görmez',
      (tester) async {
    SharedPreferences.setMockInitialValues({'recent_files': <String>['x']});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('"Neler yeni": güncelleyene bir kez, yeni kuruluma hiç',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whats-new-ok')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('whats-new-ok')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WhatsNew.prefKey), WhatsNew.current);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('whats-new-ok')), findsNothing);
    expect(
        (await SharedPreferences.getInstance()).getString(WhatsNew.prefKey),
        WhatsNew.current);
  });

  testWidgets('"Atla" da bitirmiş sayılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await OnboardingScreen.isDone(), isTrue);
  });
}
