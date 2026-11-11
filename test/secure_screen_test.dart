import 'package:dosya_okuyucu/core/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// G1.4 (B10): FLAG_SECURE sayaçlı tek kapı.
void main() {
  final calls = <bool>[];

  setUp(() {
    calls.clear();
    SecureScreenGate.debugReset();
    SecureScreenGate.debugOverride = (v) async => calls.add(v);
  });
  tearDown(SecureScreenGate.debugReset);

  test('ilk sahip açar, son sahip kapatır (iç içe erken kapanmaz)', () {
    final a = SecureScreenGate.request();
    final b = SecureScreenGate.request();
    expect(calls, [true]);
    a();
    expect(calls, [true]);
    expect(SecureScreenGate.holders, 1);
    b();
    expect(calls, [true, false]);
    expect(SecureScreenGate.holders, 0);
  });

  test('aynı bırakma işlevi iki kez çağrılsa sayaç bir kez düşer', () {
    final a = SecureScreenGate.request();
    final b = SecureScreenGate.request();
    a();
    a();
    expect(SecureScreenGate.holders, 1);
    b();
    expect(calls, [true, false]);
  });

  testWidgets('SecureScreen görünürken bayrak açık, kapanınca kapalı',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SecureScreen(child: Text('gizli')),
    ));
    expect(calls, [true]);
    await tester.pumpWidget(const MaterialApp(home: Text('açık')));
    expect(calls, [true, false]);
  });
}
