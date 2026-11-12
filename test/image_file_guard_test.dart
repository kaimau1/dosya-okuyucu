import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// G7.7 (GUVENLIK_PLANI): dosyadan görsel YALNIZ `FmFileImage` ile çözülür —
/// o her durumda piksel tavanı (24 MP) uygular. Çıplak `Image.file` 1000×1e6
/// gibi uç en-boy oranlı "bomba" görselde belleği patlatır.
void main() {
  test('lib/ altında çıplak Image.file yok', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final c = raw.indexOf('//');
        final code = c < 0 ? raw : raw.substring(0, c);
        if (code.contains('Image.file(')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty,
        reason: 'Image(image: FmFileImage(yol, cacheWidth: …)) kullan: ${hits.join(', ')}');
  });
}
