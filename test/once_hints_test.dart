import 'package:dosya_okuyucu/core/once_hints.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ferrari H7.3: ipucu bir kez; "İpuçlarını yeniden göster" hepsini
/// (tarama rehberi sayacı dahil) sıfırlar.
void main() {
  test('ipucu bir kez, sıfırlayınca yeniden', () async {
    SharedPreferences.setMockInitialValues({'scan_tips_shown': 999, 'other': 1});
    expect(await OnceHints.take('a'), isTrue);
    expect(await OnceHints.take('a'), isFalse);
    expect(await OnceHints.take('b'), isTrue);
    await OnceHints.resetAll();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('scan_tips_shown'), isFalse);
    expect(prefs.getInt('other'), 1);
    expect(await OnceHints.take('a'), isTrue);
  });
}
