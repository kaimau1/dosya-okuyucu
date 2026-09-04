import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/playback_positions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// **"Kaldığın yerden devam"** — kullanıcı isteği 2026-09-03 (premium
/// oynatıcı). Buradaki ölçüt kuralların TAM olarak tutması: yanlış yerde
/// "devam et" demek, hiç dememekten daha can sıkıcı.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('positions');
    FmEnv.appSupportDir = dir.path;
    PlaybackPositions.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    removeTempDir(dir);
  });

  const film = '/videolar/film.mp4';
  const total = Duration(minutes: 90);

  test('yarıda bırakılan dosyanın konumu hatırlanıyor', () {
    PlaybackPositions.record(film, const Duration(minutes: 23), total);
    expect(PlaybackPositions.positionOf(film), const Duration(minutes: 23));
    expect(PlaybackPositions.progressOf(film), closeTo(23 / 90, 0.001));
  });

  test('ilk 30 saniye kaydedilmez (jenerikte "devam et?" sorulmasın)', () {
    PlaybackPositions.record(film, const Duration(seconds: 12), total);
    expect(PlaybackPositions.positionOf(film), isNull);
  });

  test('sona gelen dosya "bitti" sayılır ve kayıt DÜŞER', () {
    PlaybackPositions.record(film, const Duration(minutes: 20), total);
    PlaybackPositions.record(film, const Duration(minutes: 89), total);
    expect(PlaybackPositions.positionOf(film), isNull,
        reason: 'bir daha açıldığında baştan başlamalı');
  });

  test('başa sarınca eski kayıt silinir', () {
    PlaybackPositions.record(film, const Duration(minutes: 20), total);
    PlaybackPositions.record(film, const Duration(seconds: 3), total);
    expect(PlaybackPositions.positionOf(film), isNull);
  });

  test('kısa dosyalar (zil sesi, sesli not) hiç kaydedilmez', () {
    PlaybackPositions.record(
        '/ses/not.m4a', const Duration(seconds: 40), const Duration(seconds: 50));
    expect(PlaybackPositions.positionOf('/ses/not.m4a'), isNull);
  });

  test('diske yazılıp geri okunuyor', () async {
    PlaybackPositions.record(film, const Duration(minutes: 23), total);
    await PlaybackPositions.save();
    final file = File('${dir.path}/playback_positions.json');
    expect(file.existsSync(), isTrue);
    final raw = jsonDecode(file.readAsStringSync()) as Map;
    expect(raw[film]['p'], const Duration(minutes: 23).inMilliseconds);

    PlaybackPositions.debugReset();
    await PlaybackPositions.ensureLoaded();
    expect(PlaybackPositions.positionOf(film), const Duration(minutes: 23));
  });

  test('kayıt sayısı sınırı aşılmıyor (en eskiler düşer)', () async {
    for (var i = 0; i < PlaybackPositions.maxEntries + 25; i++) {
      PlaybackPositions.record('/f/$i.mp4', const Duration(minutes: 5), total);
    }
    await PlaybackPositions.save();
    expect(PlaybackPositions.count, PlaybackPositions.maxEntries);
  });

  test('bilinmeyen dosya null döner (uydurma konum yok)', () {
    expect(PlaybackPositions.positionOf('/yok/dosya.mp4'), isNull);
    expect(PlaybackPositions.progressOf('/yok/dosya.mp4'), isNull);
  });
}
