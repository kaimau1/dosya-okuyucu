// PDF Pro Faz 54 / 5: şifreli belge — izin bayrakları ve sahip parolası.
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  group('karar (izin bayrakları)', () {
    test('şifresiz belge düzenlenir', () {
      expect(PdfEditAccessCheck.decide(encrypted: false),
          PdfEditAccess.allowed);
      expect(PdfEditAccessCheck.decide(encrypted: false, permissions: 0),
          PdfEditAccess.allowed);
    });

    test('değiştirme biti kapalıysa sahip parolası gerekir', () {
      // Yalnız yazdırma (bit 3) açık.
      expect(PdfEditAccessCheck.decide(encrypted: true, permissions: 4),
          PdfEditAccess.ownerPasswordNeeded);
      // Açıklama ekleme (bit 6) içerik değiştirme değildir.
      expect(PdfEditAccessCheck.decide(encrypted: true, permissions: 4 | 32),
          PdfEditAccess.ownerPasswordNeeded);
      expect(PdfEditAccessCheck.decide(encrypted: true, permissions: 0),
          PdfEditAccess.ownerPasswordNeeded);
    });

    test('değiştirme biti açıksa (ya da sahip parolasıyla açıldıysa) düzenlenir',
        () {
      expect(PdfEditAccessCheck.decide(encrypted: true, permissions: 8),
          PdfEditAccess.allowed);
      expect(
          PdfEditAccessCheck.decide(encrypted: true, permissions: 0xFFFFFFFF),
          PdfEditAccess.allowed);
      // PDFium işaretli 32 bit döndürürse (-1) de bütün bitler açıktır.
      expect(PdfEditAccessCheck.decide(encrypted: true, permissions: -1),
          PdfEditAccess.allowed);
    });
  });

  group('gerçek PDFium (külliyat: rl_sifreli — kullanıcı parolası boş, sahip '
      '"sahip", değiştirme yasak)', () {
    setUpAll(() async => pdfrxInitialize());
    const path = 'test/fixtures/pdf_corpus/rl_sifreli.pdf';

    test('parolasız açılan kısıtlı belgede düzenleme yasak', () async {
      final doc = await PdfDocument.openFile(path);
      addTearDown(doc.dispose);
      expect(doc.isEncrypted, isTrue);
      expect(PdfEditAccessCheck.of(doc), PdfEditAccess.ownerPasswordNeeded);
    });

    test('şifresiz külliyat belgesi düzenlenir', () async {
      final doc = await PdfDocument.openFile(
          'test/fixtures/pdf_corpus/rl_paragraflar.pdf');
      addTearDown(doc.dispose);
      expect(PdfEditAccessCheck.of(doc), PdfEditAccess.allowed);
    });

    test('sahip parolası tanınır, yanlış parola tanınmaz', () async {
      expect(await PdfEditAccessCheck.isOwnerPasswordForFile(path, 'sahip'),
          isTrue);
      expect(await PdfEditAccessCheck.isOwnerPasswordForFile(path, 'yanlis'),
          isFalse);
      expect(
          await PdfEditAccessCheck.isOwnerPasswordForData(
              File(path).readAsBytesSync(), 'sahip'),
          isTrue);
    });
  });
}
