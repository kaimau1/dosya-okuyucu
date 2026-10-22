import 'package:dosya_okuyucu/core/third_party_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lisans sayfası paket DIŞI gömülü bileşenleri de listeler (Faz 7 / N2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fontlar, Word JS, PDFium, Syncfusion, ML Kit kayıtlı', () async {
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
    ]) {
      expect(packages, contains(want));
    }
    final all = texts.toString();
    expect(all, contains('SIL OPEN FONT LICENSE'));
    expect(all, contains('Community License'));
  });
}
