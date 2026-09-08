import 'dart:io';

import 'package:dosya_okuyucu/services/fm/content_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2026-09-06 denetim turu: arama yalnız dosya ADINA bakıyordu. Kullanıcının
/// en sık kaybettiği şey ise adını hatırlamadığı bir not — "içinde 'fatura no'
/// geçen dosya" sorusunun uygulamada hiçbir cevabı yoktu.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cs-test');
    File(p.join(temp.path, 'notlar.txt'))
        .writeAsStringSync('birinci satır\nfatura no: 2024/17\nüçüncü');
    File(p.join(temp.path, 'liste.csv'))
        .writeAsStringSync('ad;tutar\nfatura;100');
    File(p.join(temp.path, 'foto.jpg')).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    Directory(p.join(temp.path, 'alt')).createSync();
    File(p.join(temp.path, 'alt', 'derin.md'))
        .writeAsStringSync('# başlık\nFATURA burada');
  });

  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('metin dosyalarının içi aranır, alt klasörler dahil', () async {
    final hits = await ContentSearch.search(temp.path, 'fatura');
    expect(hits.map((h) => p.basename(h.path)).toSet(),
        {'notlar.txt', 'liste.csv', 'derin.md'});
  });

  test('TÜRKÇE büyük/küçük harf doğru eşleşir', () async {
    // 'FATURA' ile 'fatura': Dart'ın kendi katlaması Türkçe'de yanılır.
    final hits = await ContentSearch.search(temp.path, 'FATURA');
    expect(hits.any((h) => p.basename(h.path) == 'derin.md'), isTrue);
    final turkish = File(p.join(temp.path, 'tr.txt'))
      ..writeAsStringSync('IŞIK yandı');
    final hits2 = await ContentSearch.search(temp.path, 'ışık');
    expect(hits2.any((h) => h.path == turkish.path), isTrue);
  });

  test('satır numarası ve eşleşme sayısı doğru', () async {
    File(p.join(temp.path, 'çok.txt'))
        .writeAsStringSync('a\nb\nhedef\nc\nhedef');
    final hits = await ContentSearch.search(temp.path, 'hedef');
    final hit = hits.firstWhere((h) => p.basename(h.path) == 'çok.txt');
    expect(hit.line, 3);
    expect(hit.total, 2);
  });

  test('bağlam parçası eşleşmeyi taşır', () async {
    final hits = await ContentSearch.search(temp.path, 'fatura no');
    final hit = hits.firstWhere((h) => p.basename(h.path) == 'notlar.txt');
    expect(hit.snippet.toLowerCase(), contains('fatura no'));
    expect(hit.snippet.contains('\n'), isFalse, reason: 'tek satır olmalı');
  });

  test('metin OLMAYAN dosyalar okunmaz', () async {
    expect(ContentSearch.isSearchable('/a/foto.jpg'), isFalse);
    expect(ContentSearch.isSearchable('/a/film.mp4'), isFalse);
    expect(ContentSearch.isSearchable('/a/belge.pdf'), isFalse);
    expect(ContentSearch.isSearchable('/a/not.txt'), isTrue);
    expect(ContentSearch.isSearchable('/a/kayıt.LOG'), isTrue);
    expect(ContentSearch.isSearchable('/a/.gitignore'), isTrue);
  });

  test('2 MB üstü dosya ATLANIR (tarama kilitlenmesin)', () async {
    final big = File(p.join(temp.path, 'kayit.log'));
    big.writeAsStringSync('hedefkelime${'x' * (3 * 1024 * 1024)}');
    final hits = await ContentSearch.search(temp.path, 'hedefkelime');
    expect(hits.any((h) => h.path == big.path), isFalse);
  });

  test('sonuç sınırına ulaşınca durur', () async {
    for (var i = 0; i < 30; i++) {
      File(p.join(temp.path, 'd$i.txt')).writeAsStringSync('ortak');
    }
    final hits = await ContentSearch.search(temp.path, 'ortak', limit: 5);
    expect(hits, hasLength(5));
  });

  test('durdurma isteği taramayı keser', () async {
    for (var i = 0; i < 40; i++) {
      File(p.join(temp.path, 'x$i.txt')).writeAsStringSync('ortak');
    }
    var seen = 0;
    final hits = await ContentSearch.search(
      temp.path,
      'ortak',
      isCancelled: () => ++seen > 12,
    );
    expect(hits.length, lessThan(40));
  });

  test('gizli klasörler atlanır (.thumbnails gibi)', () async {
    final hidden = Directory(p.join(temp.path, '.gizli'))..createSync();
    File(p.join(hidden.path, 'g.txt')).writeAsStringSync('fatura');
    final hits = await ContentSearch.search(temp.path, 'fatura');
    expect(hits.any((h) => h.path.contains('.gizli')), isFalse);
  });

  test('boş sorgu hiçbir şey aramaz', () async {
    expect(await ContentSearch.search(temp.path, '  '), isEmpty);
  });

  test('UTF-16 dosyanın içi de aranır', () async {
    // Windows Not Defteri'nin "Unicode" kaydı — TextDecode üzerinden geçiyor.
    const text = 'gizli kelime';
    final bytes = <int>[
      0xFF, 0xFE,
      for (final unit in text.codeUnits) ...[unit & 0xFF, unit >> 8],
    ];
    File(p.join(temp.path, 'unicode.txt')).writeAsBytesSync(bytes);
    final hits = await ContentSearch.search(temp.path, 'gizli kelime');
    expect(hits.any((h) => p.basename(h.path) == 'unicode.txt'), isTrue);
  });
}
