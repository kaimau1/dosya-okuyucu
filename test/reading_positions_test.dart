import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/reading_positions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// **"Kaldığın sayfadan devam"** — 400 sayfalık bir kitapta her açılışta
/// 1. sayfadan başlamak, uzun belgelerle çalışan herkesin ilk şikâyeti.
/// Ölçüt kuralların TAM tutması: yanlış yerde "devam" demek, hiç dememekten
/// daha can sıkıcı.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('reading');
    FmEnv.appSupportDir = dir.path;
    ReadingPositions.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    removeTempDir(dir);
  });

  const book = '/belgeler/kitap.pdf';

  test('yarıda bırakılan belgenin sayfası hatırlanıyor', () {
    ReadingPositions.record(book, 42, 400);
    expect(ReadingPositions.pageOf(book), 42);
    expect(ReadingPositions.progressOf(book), closeTo(41 / 399, 0.001));
  });

  test('ilk sayfa kaydedilmez (dönülecek yer yok)', () {
    ReadingPositions.record(book, 1, 400);
    expect(ReadingPositions.pageOf(book), isNull);
  });

  test('başa dönülünce eski kayıt DÜŞER', () {
    ReadingPositions.record(book, 42, 400);
    ReadingPositions.record(book, 1, 400);
    expect(ReadingPositions.pageOf(book), isNull,
        reason: 'baştan okumaya karar veren kullanıcıya "devam" sorulmaz');
  });

  test('son sayfa "bitti" sayılır', () {
    ReadingPositions.record(book, 42, 400);
    ReadingPositions.record(book, 400, 400);
    expect(ReadingPositions.pageOf(book), isNull);
  });

  test('kısa belgede (fatura) konum tutulmaz', () {
    ReadingPositions.record('/belgeler/fatura.pdf', 2, 3);
    expect(ReadingPositions.pageOf('/belgeler/fatura.pdf'), isNull);
  });

  test('diske yazılıp geri okunuyor', () async {
    ReadingPositions.record(book, 42, 400);
    await ReadingPositions.save();
    final file = File('${dir.path}/reading_positions.json');
    expect(file.existsSync(), isTrue);
    expect((jsonDecode(file.readAsStringSync()) as Map)[book]['p'], 42);

    ReadingPositions.debugReset();
    await ReadingPositions.ensureLoaded();
    expect(ReadingPositions.pageOf(book), 42);
  });

  test('kayıt sınırı aşılmıyor', () async {
    for (var i = 0; i < ReadingPositions.maxEntries + 30; i++) {
      ReadingPositions.record('/b/$i.pdf', 5, 100);
    }
    await ReadingPositions.save();
    expect(ReadingPositions.count, ReadingPositions.maxEntries);
  });

  test('bilinmeyen belge null döner', () {
    expect(ReadingPositions.pageOf('/yok.pdf'), isNull);
    expect(ReadingPositions.progressOf('/yok.pdf'), isNull);
  });
}
