import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/bills_screen.dart';
import 'package:dosya_okuyucu/services/pro_purchase.dart';
import 'package:dosya_okuyucu/widgets/pro_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PurchaseDetails _p(String id, PurchaseStatus st) => PurchaseDetails(
      productID: id,
      purchaseID: 'o1',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'tok',
        source: 'google_play',
      ),
      transactionDate: null,
      status: st,
    );

void main() {
  tearDown(() {
    ProUnlock.owned.value = false;
    ProPurchase.resetPriceForTest();
  });

  test('satın alınmış Lite Pro katmanını açar, Kişisel özellikleri açmaz', () {
    expect(Edition.lite.has(Feature.pdfAdvanced), isFalse);
    expect(Edition.lite.proActive, isFalse);
    ProUnlock.owned.value = true;
    expect(Edition.lite.tier, Edition.pro);
    expect(Edition.lite.has(Feature.pdfAdvanced), isTrue);
    expect(Edition.lite.has(Feature.ai), isTrue);
    expect(Edition.lite.has(Feature.apkInstall), isFalse);
    expect(Edition.lite.proActive, isTrue);
    // Kişisel derleme etkilenmez.
    expect(Edition.kisisel.tier, Edition.kisisel);
  });

  test('yalnız satın alınmış pro_unlock kaydı sahiplik sayılır', () {
    expect(ProPurchase.productId, 'pro_unlock');
    expect(ProPurchase.isOwnedPro(_p('pro_unlock', PurchaseStatus.purchased)), isTrue);
    expect(ProPurchase.isOwnedPro(_p('pro_unlock', PurchaseStatus.restored)), isTrue);
    expect(ProPurchase.isOwnedPro(_p('pro_unlock', PurchaseStatus.pending)), isFalse);
    expect(ProPurchase.isOwnedPro(_p('pro_unlock', PurchaseStatus.canceled)), isFalse);
    expect(ProPurchase.isOwnedPro(_p('baska', PurchaseStatus.purchased)), isFalse);
  });

  testWidgets('satın alınınca PRO rozeti hemen kalkar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProBadged(
        feature: Feature.audiobook,
        edition: Edition.lite,
        child: Icon(Icons.lock),
      ),
    ));
    expect(find.byKey(const ValueKey('pro-badge')), findsOneWidget);
    ProUnlock.owned.value = true;
    await tester.pump();
    expect(find.byKey(const ValueKey('pro-badge')), findsNothing);
  });

  testWidgets('açık kilitli ekran Pro satın alınınca anında açılır',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: const MaterialApp(
          locale: Locale('tr'),
          supportedLocales: AppLanguageInfo.supportedLocales,
          localizationsDelegates: [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BillsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('pro-locked-view')), findsOneWidget);
    ProUnlock.owned.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('pro-locked-view')), findsNothing);
  }, skip: Edition.current != Edition.lite);
}
