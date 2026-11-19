// "Kategori ekle" (2026-11-19): elle eklenen kullanıcı kategorisi AI
// yanıtıyla düşmez; kaydı olmayan dosya AI turunda yine sorulur.
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_user_cats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cat = SmartUserCat(id: 'u:okul', name: 'Okul', about: 'Okul');
  const path = '/yok/belge.pdf';

  setUp(() {
    SmartUserCats.debugReset([cat]);
    SmartSort.debugReset();
  });

  test('elle eklenen kategori AI "hayır" deyince de kalır', () async {
    await SmartSort.addToUserCat([path], cat.id);
    final r = SmartSort.of(path)!;
    expect(r.uc[cat.id], SmartSort.manualMark);
    expect(r.modifiedMs, -1, reason: 'AI turu dosyayı yine sormalı');
    expect(SmartSort.pathsOf(cat.id), [path]);
    final after = r.withUserAnswers({cat.id: 0.1});
    expect(after.uc[cat.id], SmartSort.manualMark);
  });

  test('kategoriden çıkarılınca süzgeçte görünmez', () async {
    await SmartSort.addToUserCat([path], cat.id);
    await SmartSort.removeFromUserCat([path], cat.id);
    expect(SmartSort.pathsOf(cat.id), isEmpty);
    expect(SmartSort.userCatsOf(path), isEmpty);
  });
}
