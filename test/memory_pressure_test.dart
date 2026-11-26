import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/core/memory_pressure.dart';

void main() {
  test('MemoryPressure registers once, dispatches both modes, unregisters', () {
    final seen = <bool>[];
    void listener(bool critical) => seen.add(critical);

    MemoryPressure.register(listener);
    MemoryPressure.register(listener); // idempotent
    addTearDown(() => MemoryPressure.unregister(listener));

    MemoryPressure.dispatch(critical: false);
    MemoryPressure.dispatch(critical: true);
    expect(seen, [false, true]);

    MemoryPressure.unregister(listener);
    MemoryPressure.dispatch(critical: true);
    expect(seen, [false, true]);
  });

  test('MemoryPressure isolates listener exceptions', () {
    var okCalled = false;
    void bad(bool _) => throw StateError('boom');
    void good(bool _) => okCalled = true;

    MemoryPressure.register(bad);
    MemoryPressure.register(good);
    addTearDown(() {
      MemoryPressure.unregister(bad);
      MemoryPressure.unregister(good);
    });

    MemoryPressure.dispatch(critical: true);
    expect(okCalled, isTrue);
  });
}
