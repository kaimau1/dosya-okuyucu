import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/picker_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seçici kipi süzgeci: çağıran uygulamanın istediği türe uymayan dosya
/// listelenmemeli — kullanıcı seçemeyeceği bir dosyaya dokunup "neden
/// olmuyor" dememeli.
FsEntry _file(String name) => FsEntry(
      path: '/a/$name',
      name: name,
      isDir: false,
      sizeBytes: 10,
      modifiedMs: 1,
    );

void main() {
  group('MIME eşleşmesi', () {
    test('*/* her şeyi kabul eder', () {
      const request = PickerRequest();
      expect(request.acceptsEntry(_file('a.pdf')), isTrue);
      expect(request.acceptsEntry(_file('a.bilinmeyen')), isTrue);
    });

    test('image/* yalnız görselleri geçirir', () {
      const request = PickerRequest(mimeType: 'image/*');
      expect(request.acceptsEntry(_file('a.jpg')), isTrue);
      // Tablomuzda olmayan bir görsel uzantısı da kategori ailesine düşer.
      expect(request.acceptsEntry(_file('a.heic')), isTrue);
      expect(request.acceptsEntry(_file('a.pdf')), isFalse);
      expect(request.acceptsEntry(_file('a.mp4')), isFalse);
    });

    test('tam tür isteği yalnız o türü geçirir', () {
      const request = PickerRequest(mimeType: 'application/pdf');
      expect(request.acceptsEntry(_file('rapor.pdf')), isTrue);
      expect(request.acceptsEntry(_file('rapor.docx')), isFalse);
      // Tanımadığımız belge uzantısı PDF sayılmaz (çağıran açamazdı).
      expect(request.acceptsEntry(_file('rapor.epub')), isFalse);
    });

    test('klasörler her zaman görünür (içine girilebilsin)', () {
      const request = PickerRequest(mimeType: 'image/*');
      const dir = FsEntry(
          path: '/a/Belgeler',
          name: 'Belgeler',
          isDir: true,
          sizeBytes: 0,
          modifiedMs: 1);
      expect(request.acceptsEntry(dir), isTrue);
    });

    test('uzantısız dosya genel akış türüdür', () {
      expect(
        PickerRequest.mimeForExtension('', FmCategory.other),
        'application/octet-stream',
      );
    });
  });
}
