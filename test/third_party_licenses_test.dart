import 'package:dosya_okuyucu/core/edition.dart';
import 'package:dosya_okuyucu/core/third_party_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lisans sayfası paket DIŞI gömülü bileşenleri de listeler (Faz 7 / N2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fontlar, Word JS, PDFium, Syncfusion, ML Kit, LGPL v3.0 kayıtlı',
      () async {
    registerThirdPartyLicenses();
    final packages = <String>{};
    final texts = StringBuffer();
    await for (final e in LicenseRegistry.licenses) {
      packages.addAll(e.packages);
      for (final p in e.paragraphs) {
        texts.writeln(p.text);
      }
    }
    for (final want in [
      'Carlito',
      'Tinos',
      'Arimo',
      'JetBrains Mono',
      'docx-preview',
      'JSZip',
      'PDFium',
      'syncfusion_flutter_pdf',
      'Google ML Kit',
      'libmpv',
      'FFmpeg',
      'ESRGAN',
      'Antalia-2 Mini',
      'EMA Lightning',
      'ONNX Runtime Web',
      'PaddleOCR (PP-OCRv5)',
    ]) {
      expect(packages, contains(want));
    }
    // Kokoro/eSpeak NG (GPL-3.0) yalnız Kişisel derlemede (2026-11-25).
    final extra = Edition.current.has(Feature.extraVoices);
    expect(packages.contains('eSpeak NG'), extra);
    expect(packages.contains('Kokoro'), extra);
    expect(Edition.lite.has(Feature.extraVoices), isFalse);
    expect(Edition.pro.has(Feature.extraVoices), isFalse);
    final all = texts.toString();
    expect(all, contains('SIL OPEN FONT LICENSE'));
    expect(all, contains('Community License'));
    expect(all, contains('GNU LESSER GENERAL PUBLIC LICENSE'));
    expect(all, contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
