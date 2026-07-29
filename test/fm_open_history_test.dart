import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/open_history.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** `record()` her dosya açılışında çağrılıyor ve
/// genellikle uygulamanın `OpenHistory`ye dokunduğu İLK yer olur. Diskteki
/// geçmiş yüklenmeden yazılırsa (kod incelemesinde yakalanan kök neden —
/// bkz. serviste `_loadFuture` üstündeki not) önceki oturumların TÜM
/// geçmişi tek bir açılışla kaybolurdu. Bu testin işi tam o senaryoyu
/// kilitlemek: "yeni oturumda ilk dosyayı açtım, eski geçmişim durmalı".
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('open_history_test');
    FmEnv.appSupportDir = tempDir.path;
    OpenHistory.resetForTest();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> makeFile(String name) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString('x');
    return file.path;
  }

  test('kaydedilen dosya sonradan bulunabilir', () async {
    final path = await makeFile('a.txt');
    await OpenHistory.record(path);
    expect(OpenHistory.forPath(path), isNotNull);
  });

  test('KÖK NEDEN: yeni oturumda ilk açılan dosya eski geçmişi SİLMEZ', () async {
    final old = await makeFile('eski.txt');
    await OpenHistory.record(old);

    // "Uygulama yeniden başlatıldı" simülasyonu: bellek sıfırlanır, disk kalır.
    OpenHistory.resetForTest();

    // Yeni oturumda kullanıcı bir dosya açar — bu, OpenHistory'ye dokunulan
    // İLK an. `ensureLoaded()` daha önce hiç çağrılmamış olmalı.
    final fresh = await makeFile('yeni.txt');
    await OpenHistory.record(fresh);

    // Belleği yine sıfırlayıp diskten oku: ikisi de duruyor mu?
    OpenHistory.resetForTest();
    await OpenHistory.ensureLoaded();
    expect(OpenHistory.forPath(old), isNotNull);
    expect(OpenHistory.forPath(fresh), isNotNull);
  });

  test('eşzamanlı ilk kayıtlar birbirinin belleğini EZMEZ', () async {
    // Future memoizasyonu doğru çalışmazsa (bool bayrak kullansaydı) ikinci
    // çağrı, birincinin yüklemesi bitmeden "yüklendi" sanıp devam ederdi.
    final a = await makeFile('a.txt');
    final b = await makeFile('b.txt');
    await Future.wait([OpenHistory.record(a), OpenHistory.record(b)]);
    expect(OpenHistory.forPath(a), isNotNull);
    expect(OpenHistory.forPath(b), isNotNull);
  });

  test('var olmayan dosyanın kaydı yüklemede TEMİZLENİR', () async {
    final path = await makeFile('gecici.txt');
    await OpenHistory.record(path);
    await File(path).delete();

    OpenHistory.resetForTest();
    await OpenHistory.ensureLoaded();
    expect(OpenHistory.forPath(path), isNull);
  });

  test('all() en yeni önce sıralar', () async {
    final a = await makeFile('a.txt');
    await OpenHistory.record(a);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = await makeFile('b.txt');
    await OpenHistory.record(b);

    final all = OpenHistory.all();
    expect(all.first.key, b);
    expect(all.last.key, a);
  });

  test('all() var olmayan dosyaları listeye HİÇ katmaz', () async {
    final path = await makeFile('kaybolan.txt');
    await OpenHistory.record(path);
    await File(path).delete();
    expect(OpenHistory.all(), isEmpty);
  });

  test('clearAll geçmişi siler ama DOSYAYA dokunmaz', () async {
    final path = await makeFile('kalici.txt');
    await OpenHistory.record(path);
    await OpenHistory.clearAll();
    expect(OpenHistory.forPath(path), isNull);
    expect(File(path).existsSync(), isTrue);
  });

  test('movePath kaydı yeni yola taşır', () async {
    final from = await makeFile('once.txt');
    await OpenHistory.record(from);
    final to = '${tempDir.path}/sonra.txt';
    await File(from).rename(to);
    await OpenHistory.movePath(from, to);
    expect(OpenHistory.forPath(from), isNull);
    expect(OpenHistory.forPath(to), isNotNull);
  });

  test('remove tek kaydı düşürür, diğerleri kalır', () async {
    final a = await makeFile('a.txt');
    final b = await makeFile('b.txt');
    await OpenHistory.record(a);
    await OpenHistory.record(b);
    await OpenHistory.remove(a);
    expect(OpenHistory.forPath(a), isNull);
    expect(OpenHistory.forPath(b), isNotNull);
  });

  test('appSupportDir boşsa çökmez (bellekte kalır, diske yazılamaz)', () async {
    FmEnv.appSupportDir = '';
    OpenHistory.resetForTest();
    final path = await makeFile('x.txt');
    await OpenHistory.record(path);
    expect(OpenHistory.forPath(path), isNotNull);
  });

  test('bozuk JSON dosyası çökertmez, sessizce boş başlar', () async {
    final historyFile = File('${tempDir.path}/open_history.json');
    await historyFile.writeAsString('{ bozuk json');
    await OpenHistory.ensureLoaded();
    expect(OpenHistory.all(), isEmpty);
  });
}
