/// **Şifreli belgede düzenleme izni** (PDF Pro Faz 54 / 5).
///
/// PDF'in iki parolası vardır: **kullanıcı** parolası belgeyi açar, **sahip**
/// parolası kısıtlamaları (yazdırma, kopyalama, DEĞİŞTİRME) kaldırır. Kullanıcı
/// parolasıyla (ya da parolasız) açılan kısıtlı belgede izin bayrakları
/// düzenlemeyi yasaklıyorsa uygulama sessizce düzenlemez: açık uyarı +
/// "sahip parolasıyla aç".
library;

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

enum PdfEditAccess {
  /// Şifresiz ya da izin veriyor.
  allowed,

  /// İzin bayrakları içerik değiştirmeyi yasaklıyor; sahip parolası gerekir.
  ownerPasswordNeeded,
}

abstract final class PdfEditAccessCheck {
  /// PDF 32000-1 Tablo 22, bit 4: "belgenin içeriğini değiştir".
  static const modifyContents = 1 << 3;

  /// İzin bayraklarından karar. Sahip parolasıyla açılan belgede PDFium bütün
  /// bitleri açık verir.
  static PdfEditAccess decide({required bool encrypted, int? permissions}) {
    if (!encrypted || permissions == null) return PdfEditAccess.allowed;
    return (permissions & modifyContents) != 0
        ? PdfEditAccess.allowed
        : PdfEditAccess.ownerPasswordNeeded;
  }

  static PdfEditAccess of(PdfDocument doc) => decide(
      encrypted: doc.isEncrypted, permissions: doc.permissions?.permissions);

  /// [password] bu belgenin SAHİP parolası mı? Belge o parolayla ayrıca
  /// açılır ve değiştirme izni verip vermediğine bakılır (kullanıcı parolası
  /// belgeyi açar ama izni vermez → false).
  static Future<bool> isOwnerPassword(
      Future<PdfDocument> Function(PdfPasswordProvider provider) open,
      String password) async {
    PdfDocument? doc;
    try {
      var asked = false;
      doc = await open(() {
        if (asked) return null; // yanlış parola: ikinci kez sorulursa vazgeç
        asked = true;
        return password;
      });
      return of(doc) == PdfEditAccess.allowed;
    } catch (_) {
      return false;
    } finally {
      await doc?.dispose();
    }
  }

  static Future<bool> isOwnerPasswordForFile(String path, String password) =>
      isOwnerPassword(
          (provider) => PdfDocument.openFile(path,
              passwordProvider: provider, firstAttemptByEmptyPassword: false),
          password);

  static Future<bool> isOwnerPasswordForData(
          Uint8List bytes, String password) =>
      isOwnerPassword(
          (provider) => PdfDocument.openData(bytes,
              passwordProvider: provider, firstAttemptByEmptyPassword: false),
          password);
}
