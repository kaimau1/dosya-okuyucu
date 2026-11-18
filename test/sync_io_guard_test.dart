import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B12 madde 1 (PLAN §1.12) — ana iş parçacığında eşzamanlı dosya G/Ç bekçisi.
///
/// Ekran ve bileşen kodu (`lib/screens`, `lib/widgets`) UI izleğinde koşar;
/// orada `existsSync/statSync/listSync/lengthSync/readAs*Sync/openSync …`
/// her çağrıda diske gider ve `build` içindeyse her karede.
/// Dosya başına sayı tavanlı (MANDAL: YALNIZ DÜŞER); yeni dosyada 0.
/// Yeni G/Ç → eşzamansız (`exists()`, `length()` …) ya da izolat.
///
/// Tavandakiler gerekçeli. "C2" yazanlar ÖLÇÜM KAPISI yüzeyinde (ana ekran,
/// pano, dosya listesi, PDF kabuğu): cihaz A/B ile C2'de taşınacak.
void main() {
  const ceilings = <String, int>{
    // İzolatta koşan statik `_readAndParse` (compute) — UI izleği değil.
    'lib/screens/editors/spreadsheet_editor_screen.dart': 1,
    // Açılışta TEK `lengthSync` (okuma konumu anahtarı / büyük xlsx eşiği);
    // eşzamansızı widget testinin sahte saatinde bitmiyor (kodda yazılı).
    'lib/screens/editors/word_editor_screen.dart': 1,
    'lib/screens/editors/spreadsheet/edit_ops.dart': 1,
    // Parolalı xlsx denetimi: açılışta 8 baytlık imza (openSync + readSync).
    'lib/screens/editors/spreadsheet/pro_data.dart': 2,
    'lib/screens/editors/slides/actions.dart': 1,
    // PDF araçları açılışında tek boy denetimi (bütçe üstü PDF'i reddeder).
    'lib/screens/pdf_tools/actions.dart': 1,
    // PDF kabuğu (ÖLÇÜM KAPISI) — C2: okuma konumu boyu açılışta tek stat.
    'lib/screens/viewer_screen.dart': 1,
    // PDF kabuğu — yalnız hata kartında (sıcak yol değil).
    'lib/screens/viewer/pdf_navigation.dart': 1,
    // Ana ekran (ÖLÇÜM KAPISI) — C2: başlangıç klasörü, açılışta tek stat.
    'lib/screens/home_screen.dart': 1,
    // Pano (ÖLÇÜM KAPISI) — C2: Önemli Dosyalar kutusu `build`'de stat.
    'lib/screens/fm/dashboard/tiles.dart': 1,
    // `downloadsPathIn` ana ekran/pano `build`'inden çağrılıyor — C2.
    'lib/screens/fm/downloads_screen.dart': 1,
    // Dosya seçici panosu (dosya listesi ailesi) — C2: Önemli kutusu.
    'lib/screens/fm/pick_file_screen/parts.dart': 1,
    // Galeri: bilgi satırı statı yol başına önbellekli; iyileştirme kopyası
    // denetimi yalnız iyileştirilmiş görselde — C2 (görüntüleyici kabuğu).
    'lib/screens/fm/image_gallery_screen.dart': 2,
    // Açılışta tek stat; eşzamansızı a11y testinin sahte saatinde bitmiyor.
    'lib/screens/fm/important_screen.dart': 1,
    // Dokunuşta (QR ile al) tek stat — build/kaydırma değil.
    'lib/screens/fm/remote/qr_receive_flow.dart': 1,
    // İndirme öncesi/sonrası stat; eşzamansızı sahte saatte bitmiyor (kodda).
    'lib/screens/fm/remote/remote_browser/actions.dart': 2,
    // İş bitince bir kez (çift kurulurken) — kaydırma/build değil.
    'lib/screens/fm/resize_compare_screen.dart': 3,
  };

  // `sync_io_ratchet_test` (A4.4, toplam tavan) ile aynı çağrı ailesi; bu
  // bekçi dosya başına tavanlar — G/Ç başka dosyaya kayamaz.
  final call = RegExp(r'\b(existsSync|statSync|listSync|lengthSync|'
      r'lastModifiedSync|typeSync|deleteSync|createSync|renameSync|copySync|'
      r'openSync|readSync|writeSync|readAs\w*Sync|writeAs\w*Sync)\(');

  String stripLineComments(String src) {
    final out = StringBuffer();
    for (final raw in src.split('\n')) {
      final c = raw.indexOf('//');
      out.writeln(c < 0 ? raw : raw.substring(0, c));
    }
    return out.toString();
  }

  test('ekran/bileşen kodunda eşzamanlı dosya G/Ç tavanı (mandal)', () {
    final counts = <String, int>{};
    for (final root in ['lib/screens', 'lib/widgets']) {
      for (final f in Directory(root).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll('\\', '/');
        final n = call
            .allMatches(stripLineComments(f.readAsStringSync()))
            .length;
        if (n > 0) counts[path] = n;
      }
    }
    final over = [
      for (final e in counts.entries)
        if (e.value > (ceilings[e.key] ?? 0))
          '${e.key}: ${e.value} > ${ceilings[e.key] ?? 0}',
    ];
    expect(over, isEmpty,
        reason: 'UI izleğinde yeni eşzamanlı dosya G/Ç: eşzamansız sürümü '
            '(exists/length/stat) ya da izolat kullan.');
    // Mandal: düşen tavan tabloda da düşürülsün (eski sayı geri gelmesin).
    final slack = [
      for (final e in ceilings.entries)
        if ((counts[e.key] ?? 0) < e.value)
          '${e.key}: ${counts[e.key] ?? 0} < ${e.value}',
    ];
    expect(slack, isEmpty, reason: 'Tavan düştü: tabloyu güncelle.');
  });
}
