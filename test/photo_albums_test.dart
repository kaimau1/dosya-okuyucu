import 'package:dosya_okuyucu/services/fm/photo_albums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PhotoAlbums.resetForTest();
  });

  test('albüm oluştur, ekle, çıkar, gizle, sil — kayıt kalıcı', () async {
    final a = await PhotoAlbums.create('Tatil', paths: ['/a.jpg']);
    expect(await PhotoAlbums.add(a.key, ['/a.jpg', '/b.mp4']), 1);
    expect(PhotoAlbums.byKey(a.key)!.paths, ['/a.jpg', '/b.mp4']);

    await PhotoAlbums.removePaths(a.key, ['/a.jpg']);
    expect(PhotoAlbums.byKey(a.key)!.paths, ['/b.mp4']);

    await PhotoAlbums.setHidden(a.key, true);
    await PhotoAlbums.setHidden('dir:/depo/Kamera', true);
    await PhotoAlbums.rename(a.key, 'Yaz');

    // Diskten yeniden oku.
    PhotoAlbums.resetForTest();
    await PhotoAlbums.ensureLoaded();
    expect(PhotoAlbums.albums.single.name, 'Yaz');
    expect(PhotoAlbums.isHidden(a.key), isTrue);
    expect(PhotoAlbums.isHidden('dir:/depo/Kamera'), isTrue);

    await PhotoAlbums.delete(a.key);
    expect(PhotoAlbums.albums, isEmpty);
    expect(PhotoAlbums.isHidden(a.key), isFalse);
  });
}
