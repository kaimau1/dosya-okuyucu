import 'package:dosya_okuyucu/services/fm/custom_cards.dart';
import 'package:dosya_okuyucu/services/fm/quick_folders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuickFolders.instance.debugReset();
  });

  test('standart klasör çıkarılınca gizlenir, eklenince geri gelir', () async {
    final q = QuickFolders.instance;
    const dcim = '/storage/emulated/0/DCIM';
    expect(q.contains(dcim, standard: true), isTrue);
    await q.remove(dcim, standard: true);
    expect(q.contains(dcim, standard: true), isFalse);
    await q.add(dcim, standard: true);
    expect(q.contains(dcim, standard: true), isTrue);
  });

  test('kullanıcı klasörü eklenir, çıkarılır, kayıt kalıcı', () async {
    final q = QuickFolders.instance;
    const dir = '/storage/emulated/0/Kartlarım/Deneme';
    await q.add(dir, standard: false);
    await q.add(dir, standard: false);
    expect(q.added, [dir]);
    q.debugReset();
    await q.ensureLoaded();
    expect(q.added, [dir]);
    await q.remove(dir, standard: false);
    expect(q.added, isEmpty);
  });

  test('standart klasör tanıma diske bakmaz', () {
    const roots = ['/storage/emulated/0', '/storage/ABCD-1234'];
    expect(QuickFolders.isStandardPath('/storage/emulated/0/DCIM', roots),
        isTrue);
    expect(QuickFolders.isStandardPath('/storage/ABCD-1234/Download', roots),
        isTrue);
    expect(QuickFolders.isStandardPath('/storage/emulated/0/a/DCIM', roots),
        isFalse);
    expect(QuickFolders.isStandardPath('/storage/emulated/0/Deneme', roots),
        isFalse);
  });

  test('kısayol kartı bayrağı JSON gidiş-dönüşünde korunur', () {
    const c = CustomCard(
        id: 'x', name: 'Deneme', path: '/a/Deneme', shortcut: true);
    expect(CustomCard.fromJson(c.toJson())!.shortcut, isTrue);
    expect(CustomCard.fromJson(c.copyWith(name: 'B').toJson())!.shortcut,
        isTrue);
    const plain = CustomCard(id: 'y', name: 'N', path: '/a/N');
    expect(CustomCard.fromJson(plain.toJson())!.shortcut, isFalse);
  });
}
