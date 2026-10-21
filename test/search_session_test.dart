import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/search_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// P10: arama ekranı açıkken dizin uzun ömürlü isolate'te; sonuçlar tek
// seferlik yolla aynı olmalı ve dizin değişince (forget) tazelenmeli.
void main() {
  late Directory tmp;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FmEnv.ensureInit(); // testte path_provider yok → sonra elle ayarla
    tmp = await Directory.systemTemp.createTemp('search_session');
    FmEnv.appSupportDir = p.join(tmp.path, 'support');
    final data = Directory(p.join(tmp.path, 'data'))..createSync();
    for (final n in ['Şubat rapor.pdf', 'subat_not.txt', 'mart.txt']) {
      File(p.join(data.path, n)).writeAsStringSync('x');
    }
    await SearchIndex.rebuild(roots: [data.path]);
  });

  tearDown(() async {
    SearchIndex.closeSession();
    await SearchIndex.clear();
    FmEnv.appSupportDir = '';
    await tmp.delete(recursive: true);
  });

  Future<List<String>> names(String q) async =>
      (await SearchIndex.query(q)).map((e) => e.name).toList()..sort();

  test('oturumlu ve oturumsuz sorgu aynı sonucu verir, yeniden kurulum yansır',
      () async {
    final once = await names('şubat');
    expect(once, ['Şubat rapor.pdf']); // büyük/küçük Türkçe katlama

    SearchIndex.openSession();
    expect(await names('şubat'), once);

    // Dizin yeniden kurulunca isolate dosyayı yeniden okumalı.
    final data = p.join(tmp.path, 'data');
    expect(await names('nisan'), isEmpty);
    File(p.join(data, 'nisan.txt')).writeAsStringSync('x');
    await SearchIndex.rebuild(roots: [data]);
    expect(await names('nisan'), ['nisan.txt']);
  });
}
