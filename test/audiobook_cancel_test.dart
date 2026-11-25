import 'dart:async';

import 'package:dosya_okuyucu/services/audiobook/audiobook_maker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AudiobookMaker.cancelPoll = const Duration(milliseconds: 5));

  test('uzun adım beklenirken durdurulunca bekleme hemen biter', () async {
    final never = Completer<int>();
    var cancelled = false;
    final f = AudiobookMaker.orCancel(never.future, () => cancelled);
    Future<void>.delayed(const Duration(milliseconds: 20), () {
      cancelled = true;
    });
    await expectLater(f, throwsA(isA<AudiobookCancelled>()));
  });

  test('iptal yoksa sonuç aynen döner', () async {
    final v = await AudiobookMaker.orCancel(Future.value(7), () => false);
    expect(v, 7);
  });

  test('arkada süren işin sonraki hatası yutulur', () async {
    final work = Completer<int>();
    final f = AudiobookMaker.orCancel(work.future, () => true);
    await expectLater(f, throwsA(isA<AudiobookCancelled>()));
    work.completeError(StateError('geç gelen hata'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
}
