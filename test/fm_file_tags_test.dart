import 'dart:io';

import 'package:dosya_okuyucu/services/fm/file_tags.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** etiket, kullanıcının ELLE girdiği tek veri —
/// WhatsApp/Telegram dosyalarında gönderen bilgisi diskte olmadığı için
/// "Ayşe'den gelenler" süzgeci yalnız bu kayda dayanır. Kaybı geri alınamaz:
/// yüzlerce dosyayı yeniden etiketlemek kimsenin yapmayacağı bir iş.
///
/// 2026-07-29 sadakat denetiminde iki kök neden bulundu ve buradaki testler tam
/// o iki senaryoyu kilitliyor:
/// 1. `bool _loaded` bayrağı diskten okuma BAŞLAMADAN "yüklendi" işaretleniyor,
///    o aralıkta gelen ikinci yazıcı boş harita üstüne yazıp dosyayı biçiyordu.
/// 2. `existsSync()` false dönen her kayıt "silinmiş" sayılıp atılıyordu — oysa
///    depolama izni yokken ya da SD kart çıkarılmışken HER yol false döner.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_tags_test');
    FmEnv.appSupportDir = tempDir.path;
    FileTags.resetForTest();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<String> makeFile(String name) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString('x');
    return file.path;
  }

  test('etiket yazılır ve geri okunur', () async {
    final path = await makeFile('a.jpg');
    await FileTags.add([path], 'Ayşe');
    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(path), {'Ayşe'});
  });

  test('KÖK NEDEN: yeni oturumda ilk etiketleme eski etiketleri SİLMEZ',
      () async {
    final old = await makeFile('eski.jpg');
    await FileTags.add([old], 'İş grubu');

    // "Uygulama yeniden başlatıldı": bellek sıfırlanır, disk kalır.
    FileTags.resetForTest();

    final fresh = await makeFile('yeni.jpg');
    await FileTags.add([fresh], 'Fatura');

    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(old), {'İş grubu'});
    expect(FileTags.forPath(fresh), {'Fatura'});
  });

  test('eşzamanlı ilk yazmalar birbirini EZMEZ', () async {
    final a = await makeFile('a.jpg');
    final b = await makeFile('b.jpg');
    await FileTags.add([a], 'A');
    FileTags.resetForTest();

    final c = await makeFile('c.jpg');
    await Future.wait([
      FileTags.add([b], 'B'),
      FileTags.add([c], 'C'),
    ]);

    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(a), {'A'});
    expect(FileTags.forPath(b), {'B'});
    expect(FileTags.forPath(c), {'C'});
  });

  test('gerçekten silinmiş dosyanın etiketi yüklemede düşer', () async {
    final path = await makeFile('gecici.jpg');
    await FileTags.add([path], 'Silinecek');
    await File(path).delete();

    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(path), isEmpty);
  });

  test('KÖK NEDEN: KLASÖRÜ görünmeyen dosyanın etiketi KORUNUR', () async {
    // "SD kart çıkarıldı / depolama izni geri alındı" durumu: ne dosya ne de
    // klasörü görünüyor. Bu bir silme DEĞİL, geçici erişimsizliktir.
    final gone = '${tempDir.path}/olmayan-klasor/foto.jpg';
    await FileTags.add([gone], 'Ayşe');

    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(gone), {'Ayşe'},
        reason: 'erişilemeyen yol "silinmiş" sayılırsa tüm etiketler gider');
  });

  test('ölü kayıt yüklemede diske YAZILMAZ (yalnız bellekten düşer)', () async {
    final path = await makeFile('gecici.jpg');
    final kalici = await makeFile('kalici.jpg');
    await FileTags.add([path], 'Silinecek');
    await FileTags.add([kalici], 'Kalıcı');
    await File(path).delete();

    FileTags.resetForTest();
    await FileTags.ensureLoaded();

    // Disk dosyası hâlâ eski kaydı içeriyor: yükleme onu silmedi.
    final raw = await File('${tempDir.path}/file_tags.json').readAsString();
    expect(raw, contains('gecici.jpg'));
    expect(FileTags.forPath(kalici), {'Kalıcı'});
  });

  test('appSupportDir boşken KİLİTLENMEZ, dizin gelince diske yazar', () async {
    // Paylaşımla ("Birlikte aç") soğuk başlayan açılışta `FmEnv.ensureInit()`
    // henüz koşmamış olabilir. Bir kez boş kilitlenirse bütün etiketler kaybolur.
    FmEnv.appSupportDir = '';
    FileTags.resetForTest();
    final path = await makeFile('a.jpg');
    await FileTags.add([path], 'Erken');
    expect(FileTags.forPath(path), {'Erken'});

    FmEnv.appSupportDir = tempDir.path;
    await FileTags.add([path], 'Sonra');
    FileTags.resetForTest();
    await FileTags.ensureLoaded();
    expect(FileTags.forPath(path), {'Erken', 'Sonra'});
  });

  test('movePath etiketi yeni yola taşır', () async {
    final from = await makeFile('once.jpg');
    await FileTags.add([from], 'Ayşe');
    final to = '${tempDir.path}/sonra.jpg';
    await File(from).rename(to);
    await FileTags.movePath(from, to);
    expect(FileTags.forPath(from), isEmpty);
    expect(FileTags.forPath(to), {'Ayşe'});
  });

  test('remove / deleteTag / renameTag', () async {
    final a = await makeFile('a.jpg');
    final b = await makeFile('b.jpg');
    await FileTags.add([a, b], 'Grup');
    await FileTags.add([a], 'Tek');

    await FileTags.remove([b], 'Grup');
    expect(FileTags.forPath(b), isEmpty);

    await FileTags.renameTag('Grup', 'İş grubu');
    expect(FileTags.forPath(a), {'İş grubu', 'Tek'});

    await FileTags.deleteTag('Tek');
    expect(FileTags.forPath(a), {'İş grubu'});
    expect(FileTags.counts(), {'İş grubu': 1});
  });

  test('setTags kümeyi tümüyle yazar, boş küme kaydı düşürür', () async {
    final path = await makeFile('a.jpg');
    await FileTags.setTags(path, {'X', ' Y ', ''});
    expect(FileTags.forPath(path), {'X', 'Y'});
    await FileTags.setTags(path, {});
    expect(FileTags.forPath(path), isEmpty);
  });

  test('bozuk JSON çökertmez, sessizce boş başlar', () async {
    await File('${tempDir.path}/file_tags.json').writeAsString('{ bozuk');
    await FileTags.ensureLoaded();
    expect(FileTags.counts(), isEmpty);
  });
}
