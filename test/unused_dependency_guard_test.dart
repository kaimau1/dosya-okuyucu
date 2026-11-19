import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Kullanılmayan bağımlılık bekçisi** (B12 m.7, 2026-11-18).
///
/// `pubspec.yaml` `dependencies:` altındaki her paket `lib/` içinde en az bir
/// `package:<ad>/` içe aktarımıyla kullanılmalı — kullanılmayan paket APK'ya
/// boşuna kod/yerel kitaplık taşır (anayasa kural 7: APK bütçesi yalnız
/// düşer). İçe aktarılmadan bilerek tutulanlar aşağıda GEREKÇELİ; yenisini
/// eklemeden önce gerekçeyi `pubspec.yaml` yorumuna ve HAFIZA'ya yaz.
const _keptWithoutImport = {
  // SDK.
  'flutter',
  // syncfusion_flutter_pdf'in eşi: sürüm ikisi birlikte sabitlenir (HAFIZA
  // 2026-07 "SÜRÜM SABİT"); geçişli olarak zaten ağaçta, APK farkı 0.
  'syncfusion_flutter_core',
  // 2.4.x'e sabit: 2.5'te motor ayrılınca varsayılan kayıt siliniyor
  // (pubspec yorumu, Faz 46). Kaldırılırsa çözücü yeni sürümü seçer.
  'shared_preferences_android',
  // mpv yerel kitaplıkları (libmpv/FFmpeg) — Dart'tan içe aktarılmaz,
  // video_player_media_kit çalışma anında yükler.
  'media_kit_libs_android_video',
};

void main() {
  test('pubspec bağımlılıkları kodda kullanılıyor', () {
    final deps = <String>[];
    var inDeps = false;
    for (final line in File('pubspec.yaml').readAsLinesSync()) {
      if (RegExp(r'^\S').hasMatch(line)) {
        inDeps = line.startsWith('dependencies:');
        continue;
      }
      if (!inDeps) continue;
      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
      if (m != null) deps.add(m.group(1)!);
    }
    expect(deps, isNotEmpty, reason: 'pubspec dependencies okunamadı');

    final source = StringBuffer();
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        source.writeln(f.readAsStringSync());
      }
    }
    final code = source.toString();
    final unused = [
      for (final d in deps)
        if (!_keptWithoutImport.contains(d) && !code.contains('package:$d/'))
          d,
    ];
    expect(unused, isEmpty,
        reason: 'lib/ içinde hiç içe aktarılmayan paket: ${unused.join(', ')} '
            '— kaldır (ci/bagimliliklar.txt satırıyla) ya da gerekçeyle '
            'listeye ekle.');
    final stale = [
      for (final k in _keptWithoutImport)
        if (k != 'flutter' && !deps.contains(k)) k,
    ];
    expect(stale, isEmpty,
        reason: 'Listede olup pubspec\'te olmayan: ${stale.join(', ')}');
  });
}
