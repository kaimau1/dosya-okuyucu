import 'package:dosya_okuyucu/core/screen_awake.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wakelock **pil harcar**: kilidin ne zaman alındığı ve — daha önemlisi — ne
/// zaman BIRAKILDIĞI birim testle sabitleniyor. Bir önceki tur pil kaçaklarını
/// kapatmakla geçti; buraya sızan bir kaçak o işi geri alırdı.
void main() {
  late List<bool> calls;

  setUp(() {
    ScreenAwake.debugReset();
    calls = [];
    ScreenAwake.debugOverride = (enable) async => calls.add(enable);
  });

  tearDown(ScreenAwake.debugReset);

  test('ilk sahip kilidi açar, sonuncusu bırakır', () {
    expect(ScreenAwake.isHeld, isFalse);

    final release = ScreenAwake.request();
    expect(ScreenAwake.isHeld, isTrue);
    expect(calls, [true]);

    release();
    expect(ScreenAwake.isHeld, isFalse);
    expect(calls, [true, false]);
  });

  test('iç içe sahiplerde platform yalnız uçlarda çağrılır', () {
    // İki sahip varken biri bırakınca ekran ötekinin altından sönmemeli.
    final a = ScreenAwake.request();
    final b = ScreenAwake.request();
    expect(calls, [true], reason: 'ikinci istek yeni bir çağrı yapmamalı');

    a();
    expect(ScreenAwake.isHeld, isTrue, reason: 'b hâlâ tutuyor');
    expect(calls, [true]);

    b();
    expect(ScreenAwake.isHeld, isFalse);
    expect(calls, [true, false]);
  });

  test('aynı bırakma işlevi iki kez çağrılsa sayaç eksiye DÜŞMEZ', () {
    // Gerçek risk: `dispose` ve "duraklat" aynı anda bırakmaya çalışır.
    final release = ScreenAwake.request();
    release();
    release();
    expect(ScreenAwake.holders, 0);
    expect(calls, [true, false], reason: 'ikinci bırakma sessiz kalmalı');

    // Sayaç bozulmadıysa yeni bir istek yine kilidi açabilmeli.
    ScreenAwake.request();
    expect(calls, [true, false, true]);
  });

  test('eklenti hata atarsa akış bloklanmaz', () {
    ScreenAwake.debugOverride = (_) async => throw StateError('platform yok');
    // Atmamalı: desteklemeyen ROM'da ekran normal davranır, uygulama sürer.
    expect(ScreenAwake.request, returnsNormally);
  });
}
