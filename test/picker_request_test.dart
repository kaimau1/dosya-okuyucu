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

  // Ekosistem (2026-10-17): Notlar PDF/ses isterken seçici doğrudan o türün
  // dosyalarıyla açılmalı — istek EXTRA_MIME_TYPES + uzantı listesiyle gelir.
  group('çoklu tür ve uzantı', () {
    test('EXTRA_MIME_TYPES listesindeki her tür kabul edilir', () {
      const request = PickerRequest(
        mimeType: 'image/*',
        mimeTypes: ['image/jpeg', 'image/png'],
      );
      expect(request.acceptsEntry(_file('a.jpg')), isTrue);
      expect(request.acceptsEntry(_file('a.png')), isTrue);
      expect(request.acceptsEntry(_file('a.gif')), isFalse);
      expect(request.isSpecific, isTrue);
      expect(request.category, FmCategory.image);
    });

    test('karışık tür (ses + video + görsel) kategoriye daraltılmaz', () {
      const request = PickerRequest(
        mimeTypes: ['audio/*', 'video/*', 'image/*'],
      );
      expect(request.acceptsEntry(_file('a.mp3')), isTrue);
      expect(request.acceptsEntry(_file('a.mp4')), isTrue);
      expect(request.acceptsEntry(_file('a.pdf')), isFalse);
      expect(request.category, isNull);
    });

    test('uzantı listesi MIME tutmasa da dosyayı geçirir', () {
      const request = PickerRequest(
        mimeType: 'text/plain',
        extensions: {'md', 'txt'},
      );
      expect(request.acceptsEntry(_file('not.md')), isTrue);
      expect(request.acceptsEntry(_file('not.txt')), isTrue);
      expect(request.acceptsEntry(_file('not.pdf')), isFalse);
    });

    test('PDF isteği belirli ve belge kategorisinde', () {
      const request = PickerRequest(
        mimeType: 'application/pdf',
        extensions: {'pdf'},
      );
      expect(request.isSpecific, isTrue);
      expect(request.category, FmCategory.document);
      expect(request.kindLabel, 'PDF');
    });

    test('*/* belirli değil — ana sayfa açılır', () {
      const request = PickerRequest();
      expect(request.isSpecific, isFalse);
      expect(request.category, isNull);
      expect(request.kindLabel, isEmpty);
    });

    test('uzun uzantı listesi kısaltılır', () {
      const request = PickerRequest(
        mimeType: 'audio/*',
        extensions: {'mp3', 'm4a', 'wav', 'ogg', 'flac', 'amr'},
      );
      expect(request.kindLabel, 'AMR · FLAC · M4A · MP3…');
      expect(request.category, FmCategory.audio);
    });
  });
}
