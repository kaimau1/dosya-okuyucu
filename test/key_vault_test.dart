import 'dart:typed_data';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/services/key_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 11a / madde 7: Gemini anahtarı Keystore'la sarılı saklanır; eski düz
/// kayıt açılışta göç eder; Keystore yoksa anahtar KAYBOLMAZ (düz yol).
void main() {
  // Sahte "Keystore": baytları ters çevirip başına imza koyar.
  void fakeKeystore() {
    KeyVault.wrap = (p) async => Uint8List.fromList([0x4B, ...p.reversed]);
    KeyVault.unwrap = (b) async => b.isEmpty || b.first != 0x4B
        ? null
        : Uint8List.fromList(b.sublist(1).reversed.toList());
  }

  tearDown(KeyVault.reset);

  test('eski düz anahtar açılışta sarılı biçime göç eder', () async {
    fakeKeystore();
    SharedPreferences.setMockInitialValues({
      'gemini_api_key': 'AIza-eski',
    });
    final state = AppState();
    await state.init();
    expect(state.apiKeys, ['AIza-eski']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gemini_api_keys_sealed'), isNotNull);
    expect(prefs.getString('gemini_api_key'), isNull);
    expect(prefs.getStringList('gemini_api_keys'), isNull);
    expect(prefs.getString('gemini_api_keys_sealed'), isNot(contains('AIza')));

    // Yeniden açılış sarılı kayıttan okur.
    final again = AppState();
    await again.init();
    expect(again.apiKeys, ['AIza-eski']);
  });

  test('Keystore yoksa düz yol sürer (anahtar kaybolmaz)', () async {
    KeyVault.wrap = (_) async => null;
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    await state.setApiKeys(['AIza-1', 'AIza-2']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('gemini_api_keys'), ['AIza-1', 'AIza-2']);
    expect(prefs.getString('gemini_api_keys_sealed'), isNull);
    final again = AppState();
    await again.init();
    expect(again.apiKeys, ['AIza-1', 'AIza-2']);
  });

  test('sarılı kayıt açılamazsa (Keystore sıfırlandı) düz kayda düşer',
      () async {
    KeyVault.unwrap = (_) async => null;
    SharedPreferences.setMockInitialValues({
      'gemini_api_keys_sealed': 'Ym96dWs=',
      'gemini_api_keys': ['AIza-yedek'],
    });
    KeyVault.wrap = (_) async => null;
    final state = AppState();
    await state.init();
    expect(state.apiKeys, ['AIza-yedek']);
  });
}
