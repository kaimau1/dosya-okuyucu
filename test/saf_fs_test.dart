import 'package:dosya_okuyucu/services/fm/remote/remote_fs.dart';
import 'package:dosya_okuyucu/services/fm/remote/saf_fs.dart';
import 'package:flutter_test/flutter_test.dart';

/// **SAF gezintisi** — kullanıcı 2026-09-02: USB takılıyken Android belleği
/// dosya YOLU olarak vermiyor; Android 11+ üzerinde herkese açık çözüm SAF.
///
/// Burada test edilen, SAF'ın YOLDAN farklı olan yanı: URI'lerde ebeveyn
/// hesaplanamaz, gezinti sırasında öğrenilir. Taban sınıfın yol kesen
/// `parentOf`u burada yanlış cevap verirdi — bu yüzden geçersiz kılındı.
void main() {
  const root = 'content://com.android.externalstorage.documents/tree/1A2B-3C4D%3A';
  const child =
      'content://com.android.externalstorage.documents/tree/1A2B-3C4D%3A/document/1A2B-3C4D%3ADCIM';

  SafFs makeFs() => SafFs(rootUri: root, rootName: 'USB sürücü');

  test('bilinmeyen klasörün ebeveyni KÖK olur (ağacın dışına çıkılamaz)', () {
    expect(makeFs().parentPath(child), root);
  });

  test('kökün ebeveyni yine köktür', () {
    expect(makeFs().parentPath(root), root);
  });

  test('TUZAK — taban sınıfın yol kesmesi URI\'de yanlış cevap verirdi', () {
    // Yol mantığı son `/`den keser; URI'de o parça belge KİMLİĞİdir.
    expect(RemoteFs.parentOf(child), isNot(root));
    // Geçersiz kılma bu tuzağı kapatıyor.
    expect(makeFs().parentPath(child), root);
  });

  test('çocuk yolu ebeveyn + ad olarak kurulur (klasör oluşturma)', () {
    // Ad hiçbir dosya sisteminde `/` içeremez, bu yüzden son `/` her zaman
    // doğru yerde böler — `makeDirectory` buna dayanıyor.
    final fs = makeFs();
    final made = fs.childPath(child, 'Yeni Klasör');
    expect(made, '$child/Yeni Klasör');
    expect(made.substring(0, made.lastIndexOf('/')), child);
    expect(made.substring(made.lastIndexOf('/') + 1), 'Yeni Klasör');
  });

  test('sahte bağlantı kaydı kök URI\'sini taşır', () {
    final fs = makeFs();
    expect(fs.connection.rootPath, root);
    expect(fs.connection.name, 'USB sürücü');
    // Kimlik ağaca özgü: iki farklı bellek iki farklı kayıt olsun.
    expect(fs.connection.id, contains(root));
  });

  test('parola diske YAZILMAZ (sunucu değil, saklanacak sır yok)', () {
    expect(makeFs().connection.savePassword, isFalse);
  });
}
