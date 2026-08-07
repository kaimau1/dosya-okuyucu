import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/page_arrival.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tek sütunlu düzende 7. sayfanın yeri gibi bir dikdörtgen.
  const page = Rect.fromLTWH(0, 6000, 600, 800);

  test('sayfa tam ekranda: varıldı', () {
    expect(
      arrivedAtPage(
          pageRect: page, visibleRect: const Rect.fromLTWH(0, 6000, 600, 800)),
      isTrue,
    );
  });

  test('YAKINLAŞTIRILMIŞ görünüm: sayfanın %5\'i görünse de varıldı', () {
    // Kullanıcı %400 yakınlaştırmışsa sayfanın küçük bir parçası görünür ama
    // baktığı sayfa BUDUR. Eski ölçü (yalnız kesişim oranı) burada
    // "gidilemedi" diyordu.
    expect(
      arrivedAtPage(
          pageRect: page, visibleRect: const Rect.fromLTWH(100, 6200, 150, 200)),
      isTrue,
    );
  });

  test('komşu sayfaya kaymış: varılmadı', () {
    expect(
      arrivedAtPage(
          pageRect: page, visibleRect: const Rect.fromLTWH(0, 6900, 600, 800)),
      isFalse,
    );
  });

  test('sayfanın dörtte biri görünüyor: varıldı (uzaklaşmış görünüm)', () {
    // Görünen alanın merkezi bir SONRAKİ sayfada, ama hedefin %25'i ekranda.
    expect(
      arrivedAtPage(
          pageRect: page, visibleRect: const Rect.fromLTWH(0, 6600, 600, 800)),
      isTrue,
    );
  });

  test('hiç kesişmiyor: negatif kesişim "alan" sayılmaz', () {
    // `Rect.intersect` kesişme yokken negatif kenarlı dikdörtgen döndürür;
    // eksi × eksi = artı olduğu için naif alan hesabı burada "varıldı" derdi.
    expect(
      arrivedAtPage(
          pageRect: page, visibleRect: const Rect.fromLTWH(0, 0, 600, 800)),
      isFalse,
    );
  });

  test('bozuk/ölçülmemiş sayfa dikdörtgeni: varılmadı', () {
    expect(
      arrivedAtPage(
          pageRect: Rect.zero, visibleRect: const Rect.fromLTWH(0, 0, 10, 10)),
      isFalse,
    );
  });
}
