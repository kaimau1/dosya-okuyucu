import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/models/drive_file.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/temp_dir.dart';

/// Ağ, `gemini_service_test`teki desenle yakalanır: `http.runWithClient`
/// zon istemcisi + `MockClient`. Gerçek Google oturumu gerekmesin diye
/// `authHeadersOverride` sahte başlık veriyor.
DriveService _service() => DriveService(
    authHeadersOverride: () async => {'Authorization': 'Bearer t'});

Future<T> _withMock<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request req) handler, {
  List<http.Request>? seen,
}) {
  return http.runWithClient(
      body,
      () => MockClient((req) async {
            seen?.add(req);
            return handler(req);
          }));
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  group('DriveFile', () {
    test('size METİN gelir, sayıya çevrilir', () {
      final f = DriveFile.fromJson({
        'id': '1',
        'name': 'a.pdf',
        'mimeType': 'application/pdf',
        'size': '1048576',
        'modifiedTime': '2026-07-30T12:00:00.000Z',
      });
      expect(f.sizeBytes, 1048576);
      expect(
          f.modifiedAtMs, DateTime.utc(2026, 7, 30, 12).millisecondsSinceEpoch);
      expect(f.isFolder, isFalse);
      expect(f.isGoogleDoc, isFalse);
    });

    test('Google Dokümanı: boyut YOK, dışa aktarım biçimi var', () {
      // `size` alanı Google biçimlerinde HİÇ gelmiyor; 0 kalması ve arayüzün
      // "0 B" yerine "—" göstermesi bilinçli.
      final f = DriveFile.fromJson({
        'id': '2',
        'name': 'Bütçe',
        'mimeType': 'application/vnd.google-apps.spreadsheet',
      });
      expect(f.sizeBytes, 0);
      expect(f.isGoogleDoc, isTrue);
      expect(f.exportAs?.$2, 'xlsx');
      // Drive'daki adın uzantısı yok → indirilen dosyaya uzantı eklenmeli,
      // yoksa telefonda hiçbir uygulama açamaz.
      expect(f.localName(), 'Bütçe.xlsx');
    });

    test('adın uzantısı zaten doğruysa ikinci kez eklenmez', () {
      final f = DriveFile.fromJson({
        'id': '3',
        'name': 'Rapor.docx',
        'mimeType': 'application/vnd.google-apps.document',
      });
      expect(f.localName(), 'Rapor.docx');
    });

    test('oluşturulma / sahip / paylaşım okunur', () {
      final f = DriveFile.fromJson({
        'id': '9',
        'name': 'Rapor.pdf',
        'mimeType': 'application/pdf',
        'createdTime': '2026-07-01T08:30:00.000Z',
        'modifiedTime': '2026-07-30T12:00:00.000Z',
        'owners': [
          {'displayName': 'Ayşe', 'emailAddress': 'a@x.com'}
        ],
        'shared': true,
      });
      expect(
          f.createdAtMs, DateTime.utc(2026, 7, 1, 8, 30).millisecondsSinceEpoch);
      expect(f.ownerName, 'Ayşe');
      expect(f.shared, isTrue);
    });

    test('sahip adı yoksa e-postaya düşer, alan hiç yoksa boş kalır', () {
      final withEmail = DriveFile.fromJson({
        'id': '10',
        'name': 'a.pdf',
        'mimeType': 'application/pdf',
        'owners': [
          {'emailAddress': 'a@x.com'}
        ],
      });
      expect(withEmail.ownerName, 'a@x.com');
      final none = DriveFile.fromJson(
          {'id': '11', 'name': 'a.pdf', 'mimeType': 'application/pdf'});
      expect(none.ownerName, '');
      expect(none.shared, isFalse);
      expect(none.createdAtMs, 0);
    });

    test('kategori uzantıdan gelir; Google biçiminde dışa aktarımdan', () {
      // Listede ikon/renk buradan seçiliyor: yanlış kategori = yanlış ikon.
      DriveFile file(String name, [String mime = 'application/octet-stream']) =>
          DriveFile(id: '1', name: name, mimeType: mime);
      expect(file('uygulama.apk').category, FmCategory.apk);
      expect(file('rapor.pdf').category, FmCategory.document);
      expect(file('foto.jpg').category, FmCategory.image);
      expect(file('K', DriveFile.folderMime).category, FmCategory.folder);
      // Google E-Tablosu'nun adında uzantı YOK — dışa aktarım uzantısı
      // olmasa "Diğer"e düşerdi.
      expect(
          file('Bütçe', 'application/vnd.google-apps.spreadsheet').category,
          FmCategory.document);
    });

    test('klasör tanınır', () {
      final f = DriveFile.fromJson(
          {'id': '4', 'name': 'K', 'mimeType': DriveFile.folderMime});
      expect(f.isFolder, isTrue);
    });
  });

  group('adresler', () {
    test('listede çöp kutusu elenir ve alanlar AÇIKÇA istenir', () {
      final uri = DriveService.listUri();
      expect(uri.queryParameters['q'], 'trashed = false');
      expect(uri.queryParameters['spaces'], 'drive');
      // Alanlar yazılmazsa Drive yalnız id+name döndürür; boyut/tarih
      // sütunları sessizce boş kalırdı.
      expect(uri.queryParameters['fields'], contains('modifiedTime'));
      expect(uri.queryParameters['fields'], contains('size'));
      // 2026-08-07: bilgi penceresi oluşturulma/sahip/paylaşım da gösteriyor —
      // alanlar istenmezse o satırlar sessizce "—" kalırdı.
      expect(uri.queryParameters['fields'], contains('createdTime'));
      expect(uri.queryParameters['fields'], contains('owners'));
      expect(uri.queryParameters['fields'], contains('shared'));
    });

    test('sıralama Drive\'ın orderBy\'ına gider, klasörler hep üstte', () {
      // Yerelde sıralamak yalnız elimizdeki SAYFAYI sıralardı; liste
      // sunucuda sayfalanıyor.
      expect(DriveService.listUri(sort: DriveSort.modified)
          .queryParameters['orderBy'], 'folder,modifiedTime desc');
      // Boyutun Drive'daki anahtarı `size` DEĞİL — `size` yazmak 400 verir.
      expect(DriveService.listUri(sort: DriveSort.size)
          .queryParameters['orderBy'], 'folder,quotaBytesUsed desc');
    });

    test('aramada tek tırnak KAÇIRILIR (sorgu dili sınırlayıcısı)', () {
      final uri = DriveService.listUri(query: "Ali'nin raporu");
      expect(uri.queryParameters['q'],
          contains(r"name contains 'Ali\'nin raporu'"));
    });

    test('klasör gezinme: parentId "in parents" süzgecine çevrilir', () {
      final root = DriveService.listUri(parentId: DriveService.rootId);
      expect(
          root.queryParameters['q'], "trashed = false and 'root' in parents");
      // Klasörler önce, sonra ada göre — dosya yöneticisi sıralaması.
      expect(root.queryParameters['orderBy'], 'folder,name');

      final sub = DriveService.listUri(parentId: 'abc123');
      expect(sub.queryParameters['q'], contains("'abc123' in parents"));
    });

    test('arama klasör sınırı TANIMAZ: parentId verilse de yok sayılır', () {
      // Kullanıcı "ara" dediğinde Drive'ın tamamında arar; bulunduğu klasörle
      // sınırlamak dosya yöneticilerinin beklenen davranışı değil.
      final uri = DriveService.listUri(parentId: 'abc123', query: 'rapor');
      expect(uri.queryParameters['q'], contains('name contains'));
      expect(uri.queryParameters['q'], isNot(contains('in parents')));
    });

    test('üstveri ve içerik uç noktaları AYRI', () {
      // Yeniden adlandırmayı upload adresine göndermek dosyanın içeriğini
      // silerdi — iki adres karışmamalı.
      expect(DriveService.metadataUri('id7').toString(),
          startsWith('https://www.googleapis.com/drive/v3/files/id7'));
      expect(DriveService.updateUri('id7').toString(),
          startsWith('https://www.googleapis.com/upload/drive/v3/files/id7'));

      final moved = DriveService.metadataUri('id7',
          addParents: 'yeni', removeParents: 'eski');
      expect(moved.queryParameters['addParents'], 'yeni');
      expect(moved.queryParameters['removeParents'], 'eski');
    });

    test('normal dosya alt=media, Google biçimi EXPORT ile iner', () {
      const pdf =
          DriveFile(id: 'a', name: 'x.pdf', mimeType: 'application/pdf');
      expect(DriveService.downloadUri(pdf).queryParameters['alt'], 'media');
      expect(DriveService.downloadUri(pdf).path, endsWith('/files/a'));

      const doc = DriveFile(
          id: 'b', name: 'y', mimeType: 'application/vnd.google-apps.document');
      final uri = DriveService.downloadUri(doc);
      // Google biçimi alt=media ile İNDİRİLEMEZ (403); export şart.
      expect(uri.path, endsWith('/files/b/export'));
      expect(uri.queryParameters['mimeType'], contains('wordprocessingml'));
      expect(uri.queryParameters.containsKey('alt'), isFalse);
    });
  });

  group('multipart gövdesi', () {
    test('üstveri + ham baytlar doğru sınırla sarılır', () {
      final body = DriveService.multipartBody(
        name: 'a.txt',
        mimeType: 'text/plain',
        bytes: utf8.encode('merhaba'),
      );
      final text = utf8.decode(body);
      const b = DriveService.multipartBoundary;
      expect(text, startsWith('--$b\r\n'));
      expect(text, contains('"name":"a.txt"'));
      expect(text, contains('merhaba'));
      expect(text, endsWith('--$b--\r\n'));
    });

    test('ikili içerik BOZULMADAN geçer', () {
      // Gövde metne çevrilip birleştirilseydi UTF-8 olmayan baytlar bozulurdu.
      final bytes = [0x00, 0xFF, 0xFE, 0x10];
      final body = DriveService.multipartBody(
          name: 'a.bin', mimeType: 'application/octet-stream', bytes: bytes);
      final head = utf8.encode('\r\n\r\n');
      final start = _indexOfLast(body, head) + head.length;
      expect(body.sublist(start, start + 4), bytes);
    });
  });

  group('mimeForName', () {
    test('Office ve yaygın biçimler', () {
      expect(DriveService.mimeForName('a.pdf'), 'application/pdf');
      expect(DriveService.mimeForName('a.XLSX'), contains('spreadsheetml'));
      expect(DriveService.mimeForName('a.jpeg'), 'image/jpeg');
    });

    test('uzantısız/bilinmeyen → octet-stream (Drive yine kabul eder)', () {
      expect(DriveService.mimeForName('LICENSE'), 'application/octet-stream');
      expect(DriveService.mimeForName('a.qqq'), 'application/octet-stream');
    });
  });

  group('parseList', () {
    test('kimliksiz/bozuk kayıt tüm listeyi DÜŞÜRMEZ', () {
      final files = DriveService.parseList(jsonEncode({
        'files': [
          {'id': '1', 'name': 'iyi.pdf', 'mimeType': 'application/pdf'},
          'çöp',
          {'name': 'kimliksiz'},
          {'id': '2', 'name': 'iyi2.txt', 'mimeType': 'text/plain'},
        ]
      }));
      expect(files.map((f) => f.id), ['1', '2']);
    });

    test('beklenmedik gövde boş liste verir, fırlatmaz', () {
      expect(DriveService.parseList('{"hata":1}'), isEmpty);
    });
  });

  group('çağrılar', () {
    test('list yetki başlığını gönderir ve dosyaları döndürür', () async {
      final seen = <http.Request>[];
      final files = await _withMock(
        () => _service().list(query: 'rapor'),
        (_) async => _json({
          'files': [
            {'id': '1', 'name': 'rapor.pdf', 'mimeType': 'application/pdf'}
          ]
        }),
        seen: seen,
      );
      expect(files.single.name, 'rapor.pdf');
      expect(seen.single.headers['Authorization'], 'Bearer t');
      expect(seen.single.url.queryParameters['q'], contains('rapor'));
    });

    test('SAYFALAR takip edilir: 200. dosyadan sonrası kaybolmaz', () async {
      // `nextPageToken` hiç okunmadığı için kalabalık klasörlerin kuyruğu
      // sessizce kesiliyordu — kullanıcı "dosyam Drive'da yok" derdi.
      final seen = <http.Request>[];
      final files = await _withMock(
        () => _service().list(parentId: DriveService.rootId),
        (req) async => req.url.queryParameters['pageToken'] == null
            ? _json({
                'nextPageToken': 'T2',
                'files': [
                  {'id': '1', 'name': 'a.pdf', 'mimeType': 'application/pdf'}
                ]
              })
            : _json({
                'files': [
                  {'id': '2', 'name': 'b.pdf', 'mimeType': 'application/pdf'}
                ]
              }),
        seen: seen,
      );
      expect(files.map((f) => f.id), ['1', '2']);
      expect(seen.length, 2);
      expect(seen.last.url.queryParameters['pageToken'], 'T2');
    });

    test('sayfa üst sınırı: sonsuz belirteç telefonu kilitlemez', () async {
      final seen = <http.Request>[];
      final files = await _withMock(
        () => _service().list(maxPages: 3),
        (_) async => _json({
          'nextPageToken': 'hep-var',
          'files': [
            {'id': '1', 'name': 'a.pdf', 'mimeType': 'application/pdf'}
          ]
        }),
        seen: seen,
      );
      expect(seen.length, 3);
      expect(files.length, 3);
    });

    test('indirme dosyayı diske yazar, Google biçimine uzantı ekler', () async {
      final dir = await Directory.systemTemp.createTemp('drive_dl');
      addTearDown(() => removeTempDir(dir));
      const doc = DriveFile(
          id: 'b',
          name: 'Bütçe',
          mimeType: 'application/vnd.google-apps.spreadsheet');
      final file = await _withMock(
        () => _service().download(doc, dir.path),
        (_) async => http.Response.bytes([1, 2, 3], 200),
      );
      expect(file.path, endsWith('Bütçe.xlsx'));
      expect(file.readAsBytesSync(), [1, 2, 3]);
    });

    test('indirme ilerlemesi bildirilir (inen bayt + toplam)', () async {
      // 2026-08-06 kullanıcı bulgusu: büyük dosyada "ne oluyor belli değil".
      // Akan indirme her parçada (inen, toplam) bildirmeli ki ekran yüzde
      // gösterebilsin.
      final dir = await Directory.systemTemp.createTemp('drive_dl');
      addTearDown(() => removeTempDir(dir));
      const pdf =
          DriveFile(id: 'a', name: 'rapor.pdf', mimeType: 'application/pdf');
      final ticks = <(int, int?)>[];
      final file = await _withMock(
        () => _service().download(pdf, dir.path,
            onProgress: (received, total) => ticks.add((received, total))),
        (_) async => http.Response.bytes([1, 2, 3, 4], 200),
      );
      expect(file.readAsBytesSync(), [1, 2, 3, 4]);
      expect(ticks, isNotEmpty);
      expect(ticks.last.$1, 4, reason: 'son bildirim tüm baytları saymalı');
      expect(ticks.last.$2, 4, reason: 'toplam Content-Length\'ten gelmeli');
    });

    test('ilerlemede toplam yoksa üstverideki boyut kullanılır', () {
      // Content-Length'i olmayan yanıtı MockClient ile kurmak zor; en azından
      // hata YOLU akan indirmede de sınıflandırılmalı.
      final dir = Directory.systemTemp.createTempSync('drive_dl_err');
      addTearDown(() => removeTempDir(dir));
      const pdf =
          DriveFile(id: 'a', name: 'rapor.pdf', mimeType: 'application/pdf');
      expect(
        _withMock(
          () => _service().download(pdf, dir.path, onProgress: (_, __) {}),
          (_) async => http.Response('{"error":{"message":"x"}}', 404),
        ),
        throwsA(isA<DriveException>()
            .having((e) => e.error, 'error', DriveError.notFound)),
      );
    });

    test('yükleme multipart POST atar', () async {
      final dir = await Directory.systemTemp.createTemp('drive_up');
      addTearDown(() => removeTempDir(dir));
      final local = File('${dir.path}/not.txt')..writeAsStringSync('içerik');

      final seen = <http.Request>[];
      final result = await _withMock(
        () => _service().upload(local),
        (_) async => _json({
          'id': 'new',
          'name': 'not.txt',
          'mimeType': 'text/plain',
          'size': '6'
        }),
        seen: seen,
      );
      expect(result.id, 'new');
      expect(seen.single.method, 'POST');
      expect(seen.single.url.queryParameters['uploadType'], 'multipart');
      expect(seen.single.headers['Content-Type'],
          contains(DriveService.multipartBoundary));
    });

    test('güncelleme PATCH ile İÇERİĞİ değiştirir (kimlik korunur)', () async {
      final dir = await Directory.systemTemp.createTemp('drive_patch');
      addTearDown(() => removeTempDir(dir));
      final local = File('${dir.path}/a.txt')..writeAsStringSync('yeni');

      final seen = <http.Request>[];
      await _withMock(
        () => _service().update('id7', local),
        (_) async =>
            _json({'id': 'id7', 'name': 'a.txt', 'mimeType': 'text/plain'}),
        seen: seen,
      );
      expect(seen.single.method, 'PATCH');
      expect(seen.single.url.path, endsWith('/files/id7'));
      expect(seen.single.url.queryParameters['uploadType'], 'media');
    });

    test('klasör oluşturma: klasör MIME + üst klasör gönderilir', () async {
      final seen = <http.Request>[];
      final folder = await _withMock(
        () => _service().createFolder('Faturalar', parentId: 'p1'),
        (_) async => _json({
          'id': 'f1',
          'name': 'Faturalar',
          'mimeType': DriveFile.folderMime,
        }),
        seen: seen,
      );
      expect(folder.isFolder, isTrue);
      expect(seen.single.method, 'POST');
      final body = jsonDecode(seen.single.body) as Map;
      expect(body['mimeType'], DriveFile.folderMime);
      expect(body['parents'], ['p1']);
      // İçerik yükleme adresine GİTMEMELİ.
      expect(seen.single.url.host, 'www.googleapis.com');
      expect(seen.single.url.path, '/drive/v3/files');
    });

    test('yeniden adlandırma yalnız ADI yazar, içeriğe dokunmaz', () async {
      final seen = <http.Request>[];
      await _withMock(
        () => _service().rename('id7', 'Yeni ad.pdf'),
        (_) async => _json({
          'id': 'id7',
          'name': 'Yeni ad.pdf',
          'mimeType': 'application/pdf'
        }),
        seen: seen,
      );
      expect(seen.single.method, 'PATCH');
      expect(jsonDecode(seen.single.body), {'name': 'Yeni ad.pdf'});
      // Üstveri adresi — upload/ DEĞİL (orası içeriği ezerdi).
      expect(seen.single.url.path, '/drive/v3/files/id7');
    });

    test('taşımada eski üst klasör KALDIRILIR (yoksa iki yerde görünür)',
        () async {
      final seen = <http.Request>[];
      await _withMock(
        () => _service().move('id7', toParentId: 'yeni', fromParentId: 'eski'),
        (_) async => _json(
            {'id': 'id7', 'name': 'a.pdf', 'mimeType': 'application/pdf'}),
        seen: seen,
      );
      expect(seen.single.url.queryParameters['addParents'], 'yeni');
      expect(seen.single.url.queryParameters['removeParents'], 'eski');
    });

    test('yükleme bulunulan klasöre yapılır (parents üstveride)', () async {
      final dir = await Directory.systemTemp.createTemp('drive_up_parent');
      addTearDown(() => removeTempDir(dir));
      final local = File('${dir.path}/not.txt')..writeAsStringSync('x');

      final seen = <http.Request>[];
      await _withMock(
        () => _service().upload(local, parentId: 'klasor1'),
        (_) async =>
            _json({'id': 'n', 'name': 'not.txt', 'mimeType': 'text/plain'}),
        seen: seen,
      );
      // Üst klasör yazılmazsa dosya HER ZAMAN köke düşerdi.
      expect(seen.single.body, contains('"parents":["klasor1"]'));
    });

    test('silmede 204 başarı sayılır', () async {
      await _withMock(
        () => _service().delete('x'),
        (_) async => http.Response('', 204),
      );
    });

    test('oturum yoksa notSignedIn fırlatır (sessiz boş liste DEĞİL)',
        () async {
      final service = DriveService(authHeadersOverride: () async => null);
      await expectLater(
        service.list(),
        throwsA(isA<DriveException>()
            .having((e) => e.error, 'error', DriveError.notSignedIn)),
      );
    });

    test('HTTP durumu anlaşılır nedene çevrilir, Drive mesajı taşınır',
        () async {
      // Tanıyamadığımız bir 403: "bu dosya bizim değil" yorumuna düşer.
      await expectLater(
        _withMock(
          () => _service().list(),
          (_) async => _json({
            'error': {'message': 'The user does not have sufficient rights'}
          }, 403),
        ),
        throwsA(isA<DriveException>()
            .having((e) => e.error, 'error', DriveError.forbidden)
            .having((e) => e.detail, 'detail',
                'The user does not have sufficient rights')),
      );
    });

    test('errorFor eşlemesi', () {
      expect(DriveService.errorFor(401), DriveError.notSignedIn);
      expect(DriveService.errorFor(404), DriveError.notFound);
      expect(DriveService.errorFor(503), DriveError.temporary);
      expect(DriveService.errorFor(418), DriveError.unknown);
    });

    test('403 AYRIŞTIRILIR: API kapalı / kapsam eksik / dosya bizim değil', () {
      // Üçü de 403 ama üçü de BAŞKA bir adım gerektiriyor. Tek "izin vermedi"
      // metni kullanıcıyı dosya sahipliğine baktırıyordu, oysa asıl neden
      // çoğu kez API'nin hiç açılmamış olması (ekran görüntüsü 2026-08-05).
      const notEnabled =
          '{"error":{"errors":[{"reason":"accessNotConfigured"}],'
          '"code":403,"message":"Google Drive API has not been used in project '
          '123 before or it is disabled."}}';
      expect(DriveService.classify(403, notEnabled), DriveError.apiNotEnabled);

      const noScope =
          '{"error":{"errors":[{"reason":"insufficientPermissions"}],'
          '"code":403,"message":"Insufficient Permission"}}';
      expect(DriveService.classify(403, noScope), DriveError.insufficientScope);

      // Tanıyamadığımız 403 eski davranışta kalır.
      expect(DriveService.classify(403, '{"error":{"message":"Nope"}}'),
          DriveError.forbidden);
      // Başka durumlar gövdeden etkilenmez.
      expect(DriveService.classify(404, notEnabled), DriveError.notFound);
    });

    test('API kapalıyken list apiNotEnabled fırlatır, Google mesajı taşınır',
        () async {
      await expectLater(
        _withMock(
          () => _service().list(),
          (_) async => _json({
            'error': {
              'errors': [
                {'reason': 'accessNotConfigured'}
              ],
              'code': 403,
              'message': 'Google Drive API has not been used in project 123 '
                  'before or it is disabled.'
            }
          }, 403),
        ),
        throwsA(isA<DriveException>()
            .having((e) => e.error, 'error', DriveError.apiNotEnabled)
            .having((e) => e.detail, 'detail', contains('has not been used'))),
      );
    });
  });
}

/// Gövdedeki SON `\r\n\r\n` (üstveri ile ham baytları ayıran) konumu.
int _indexOfLast(List<int> haystack, List<int> needle) {
  for (var i = haystack.length - needle.length; i >= 0; i--) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
