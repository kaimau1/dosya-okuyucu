import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// G1 (2026-11-20, kullanıcı: "Fotoğraflarda eski görüntülere hızlıca inip
/// açmak istediğimde kasma donma oluyor").
///
/// Kök: galerinin küçük resim şeridi `ListView.separated` idi (öğe boyu
/// bilinmiyor). Açılışta seçili fotoğrafa atlarken liste o ofsete kadar
/// bütün öğeleri + ayraçları kurup ölçüyordu: 5 bin fotoğrafta en eski
/// fotoğraf açılırken tek kare ~700 ms (tablette ölçüldü, docs/perf).
/// Bekçi: şerit sabit öğe boyuyla (`itemExtent`) kurulur, ayraçlı liste yok.
void main() {
  test('galeri şeridi sabit öğe boylu (uzak atlama O(1))', () {
    final src =
        File('lib/screens/fm/image_gallery/widgets.dart').readAsStringSync();
    final start = src.indexOf('class _FilmStripState');
    expect(start, isNonNegative);
    final end = src.indexOf('\nclass ', start + 1);
    final strip = src.substring(start, end < 0 ? src.length : end);
    expect(strip, contains('itemExtent:'));
    expect(strip, isNot(contains('ListView.separated')));
  });
}
