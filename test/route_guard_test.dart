import 'dart:io';

import 'package:dosya_okuyucu/core/route_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Çökme 2026-10-22 (1.0.393): uygulama açıkken başka uygulamadan dosya
/// açılınca Flutter'ın derin bağlantısı `content://…` adresini sayfa adı
/// diye itiyordu → "Null check operator … didPushRouteInformation".
Future<void> _pushContentUri(WidgetTester tester) async {
  const codec = JSONMethodCodec();
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    codec.encodeMethodCall(const MethodCall('pushRouteInformation', {
      'location': 'content://com.whatsapp.provider.media/item/123',
      'state': null,
    })),
    (_) {},
  );
  await tester.pump();
}

void main() {
  testWidgets('korumasız: içerik adresi sayfa adı diye itilince hata',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('ana')));
    await _pushContentUri(tester);
    // Hata ayıklama derlemesinde onUnknownRoute iddiası; release'de `!`.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('RouteInformationGuard itmeyi yutar, ekran yerinde kalır',
      (tester) async {
    RouteInformationGuard.install();
    await tester.pumpWidget(const MaterialApp(home: Text('ana')));
    await _pushContentUri(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('ana'), findsOneWidget);
  });

  test('manifest derin bağlantıyı kapatıyor', () {
    final m = File('ci/AndroidManifest.xml').readAsStringSync();
    expect(
        RegExp(r'android:name="flutter_deeplinking_enabled"\s*'
                r'android:value="false"')
            .hasMatch(m),
        isTrue);
  });
}
