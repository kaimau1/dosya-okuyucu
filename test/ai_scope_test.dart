import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_analyzer.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Kapsam bekçisi.** Kullanıcının açık isteği (2026-08-10): kamera klasörü
/// AI analizine girmemeli. Bu testler o sözü kilitler — kapsam mantığında
/// yapılan bir "iyileştirme" sessizce kamera klasörünü açarsa test kırılır.
FsEntry _file(String path, {int size = 1000, int modified = 1000}) => FsEntry(
      path: path,
      name: path.split('/').last,
      isDir: false,
      sizeBytes: size,
      modifiedMs: modified,
    );

void main() {
  const root = '/storage/emulated/0';

  group('kapsam dışı klasörler', () {
    test('varsayılan kurulum kamera klasörünü dışlar', () {
      final scope = AiScope(
        settings: const AiScopeSettings()
            .copyWith(excludedFolders: AiScope.defaultExclusions(root)),
      );
      expect(scope.allowsDir('$root/DCIM/Camera'), isFalse);
      expect(scope.allowsFile(_file('$root/DCIM/Camera/IMG_0001.jpg')), isFalse);
      // Kameranın ALTINDAKİ alt klasör de kapalı.
      expect(scope.allowsFile(_file('$root/DCIM/Camera/Panorama/p1.jpg')),
          isFalse);
      // Başka bir görsel klasörü etkilenmez.
      expect(scope.allowsFile(_file('$root/Download/fatura.jpg')), isTrue);
    });

    test('dışlanan klasör içeriği buluta da gitmez', () {
      const scope = AiScope(
        settings: AiScopeSettings(
          excludedFolders: ['$root/Gizli'],
          sendText: true,
          sendImages: true,
        ),
      );
      expect(scope.allowsUpload(_file('$root/Gizli/rapor.pdf')), isFalse);
      expect(scope.allowsUpload(_file('$root/Belgeler/rapor.pdf')), isTrue);
    });

    test('kilitli klasör (PIN) otomatik kapsam dışı', () {
      const scope = AiScope(
        settings: AiScopeSettings(),
        lockedFolders: ['$root/Onemli'],
      );
      expect(scope.allowsFile(_file('$root/Onemli/kimlik.pdf')), isFalse);
    });

    test('Android/data ve çöp kutusu kullanıcı istese de kapalı', () {
      const scope = AiScope(settings: AiScopeSettings());
      expect(scope.allowsDir('$root/Android/data/com.x/files'), isFalse);
      expect(scope.allowsDir('$root/Android/obb/com.x'), isFalse);
      expect(scope.allowsDir('$root/.dosya-okuyucu-cop'), isFalse);
    });
  });

  group('tür ve gizlilik süzgeci', () {
    test('kapalı tür hiç okunmaz', () {
      const scope = AiScope(
        settings: AiScopeSettings(categories: {FmCategory.document}),
      );
      expect(scope.allowsFile(_file('$root/Belgeler/a.pdf')), isTrue);
      expect(scope.allowsFile(_file('$root/Resimler/a.jpg')), isFalse);
    });

    test('gizli dosya varsayılan olarak kapsam dışı', () {
      const scope = AiScope(settings: AiScopeSettings());
      expect(scope.allowsFile(_file('$root/Belgeler/.gizli.pdf')), isFalse);
      const open = AiScope(settings: AiScopeSettings(includeHidden: true));
      expect(open.allowsFile(_file('$root/Belgeler/.gizli.pdf')), isTrue);
    });

    test('büyük dosyanın içeriği okunmaz ama meta kapsamda kalır', () {
      const scope = AiScope(settings: AiScopeSettings(maxContentMb: 1));
      final big = _file('$root/Belgeler/dev.pdf', size: 5 * 1024 * 1024);
      expect(scope.allowsFile(big), isTrue);
      expect(scope.allowsContent(big), isFalse);
    });

    test('görsel yüklemesi varsayılan KAPALI (metin açıkken bile)', () {
      const scope = AiScope(settings: AiScopeSettings());
      expect(scope.settings.sendImages, isFalse);
      expect(scope.allowsUpload(_file('$root/Resimler/a.jpg')), isFalse);
      expect(scope.allowsUpload(_file('$root/Belgeler/a.pdf')), isTrue);
    });

    test('metin gönderimi kapatılınca hiçbir içerik çıkmaz', () {
      const scope = AiScope(settings: AiScopeSettings(sendText: false));
      expect(scope.allowsUpload(_file('$root/Belgeler/a.pdf')), isFalse);
      // Dosya yine indekslenir — yalnız içeriği paylaşılmaz.
      expect(scope.allowsFile(_file('$root/Belgeler/a.pdf')), isTrue);
    });
  });

  group('ayarların kalıcılığı', () {
    test('JSON gidiş-dönüşü tüm alanları korur', () {
      const before = AiScopeSettings(
        excludedFolders: ['/a/b'],
        categories: {FmCategory.document, FmCategory.audio},
        maxContentMb: 7,
        includeHidden: true,
        sendText: false,
        sendImages: true,
        excerptKb: 12,
        dailyFileBudget: 50,
      );
      final after = AiScopeSettings.fromJson(before.toJson());
      expect(after.excludedFolders, before.excludedFolders);
      expect(after.categories, before.categories);
      expect(after.maxContentMb, 7);
      expect(after.includeHidden, isTrue);
      expect(after.sendText, isFalse);
      expect(after.sendImages, isTrue);
      expect(after.excerptKb, 12);
      expect(after.dailyFileBudget, 50);
    });

    test('bozuk kayıtta KISITLAYICI varsayılana düşülür', () {
      final fallback = AiScopeSettings.fromJson(const {'excluded': 42});
      expect(fallback.sendImages, isFalse, reason: 'görsel gönderimi kapalı');
      expect(fallback.includeHidden, isFalse);
      expect(fallback.categories, AiScopeSettings.defaultCategories);
    });
  });

  group('günlük bütçe', () {
    test('varsayılan SINIRSIZ (0)', () {
      // Kullanıcı 2026-08-10: "400 analizden sonra 'yarın devam' diyor ama
      // kotam var, sınır koymasın." Gerçek kotayı AiPool ölçüyor.
      expect(const AiScopeSettings().dailyFileBudget, 0);
    });

    test('kullanıcı isterse sınır koyabilir ve kayıt korunur', () {
      const limited = AiScopeSettings(dailyFileBudget: 400);
      expect(AiScopeSettings.fromJson(limited.toJson()).dailyFileBudget, 400);
    });
  });

  group('öneri güvenliği (safeName)', () {
    test('uzantı korunur', () {
      expect(AiAnalyzer.safeName('Elektrik faturası', 'IMG_1.pdf'),
          'Elektrik faturası.pdf');
      expect(AiAnalyzer.safeName('Fatura.txt', 'belge.pdf'), 'Fatura.pdf');
    });

    test('klasör ayıracı ve yasak karakterler temizlenir', () {
      expect(AiAnalyzer.safeName('Fatura/Temmuz.pdf', 'a.pdf'),
          'Fatura Temmuz.pdf');
      expect(AiAnalyzer.safeName('a:b*c?.pdf', 'a.pdf'), isNot(contains(':')));
    });

    test('aynı ad öneri sayılmaz', () {
      expect(AiAnalyzer.safeName('a.pdf', 'a.pdf'), '');
      expect(AiAnalyzer.safeName('', 'a.pdf'), '');
    });
  });
}
