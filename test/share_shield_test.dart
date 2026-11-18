import 'dart:io';

import 'package:dosya_okuyucu/screens/fm/share_shield.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Paylaşmadan önce kişisel veri kalkanı (2026-11-18).
void main() {
  test('varsayılan KAPALI; açılınca kalıcı', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await ShareShield.enabled(), isFalse);
    await ShareShield.setEnabled(true);
    expect(await ShareShield.enabled(), isTrue);
    await ShareShield.setEnabled(false);
  });

  test('yalnız var olan görsel/PDF, en çok 5 dosya', () async {
    final dir = await Directory.systemTemp.createTemp('kalkan');
    addTearDown(() => dir.delete(recursive: true));
    final paths = <String>[];
    for (final name in [
      'a.jpg', 'b.pdf', 'c.png', 'd.jpeg', 'e.webp', 'f.jpg', 'not.txt', 'ses.mp3',
    ]) {
      final f = File(p.join(dir.path, name))..writeAsBytesSync([1, 2, 3]);
      paths.add(f.path);
    }
    paths.add(p.join(dir.path, 'yok.jpg'));
    final picked = await ShareShield.candidates(paths);
    expect(picked, hasLength(5));
    expect(picked.any((x) => x.endsWith('.txt') || x.endsWith('.mp3')), isFalse);
    expect(picked.any((x) => x.endsWith('yok.jpg')), isFalse);
  });
}
