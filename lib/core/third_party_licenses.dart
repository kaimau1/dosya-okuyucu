import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Uygulama içi lisans sayfasına (`showLicensePage`) **paket dışı** gömülü
/// bileşenlerin lisanslarını ekler (Faz 7 / N2, 2026-10-21).
///
/// KÖK NEDEN: Flutter'ın lisans sayfası yalnız pub paketlerinin LICENSE
/// dosyalarını gösteriyor. Uygulamanın içinde dağıtılan ama paket OLMAYAN
/// şeyler — gömülü fontlar (OFL 1.1 metnin dağıtımla birlikte verilmesini
/// şart koşar), Word görüntüleyicinin JS dosyaları (MIT/Apache atıf ister),
/// Syncfusion'ın Community License'ı — hiçbir yerde görünmüyordu.
///
/// Metinler tembel yüklenir: sayfa açılmadan hiçbir varlık okunmaz.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(_entries);
}

Stream<LicenseEntry> _entries() async* {
  final ofl = await _asset('assets/fonts/OFL.txt');
  final fonts = await _asset('assets/fonts/FONTS-NOTICE.txt');
  yield LicenseEntryWithLineBreaks(
    const ['Carlito', 'Tinos', 'Arimo', 'JetBrains Mono'],
    '$fonts\n\n$ofl',
  );
  yield LicenseEntryWithLineBreaks(
    const ['docx-preview', 'JSZip'],
    await _asset('assets/word/LICENSES.txt'),
  );
  yield const LicenseEntryWithLineBreaks(['PDFium'], _pdfium);
  yield const LicenseEntryWithLineBreaks(
      ['syncfusion_flutter_pdf', 'syncfusion_flutter_core'], _syncfusion);
  yield const LicenseEntryWithLineBreaks(['Google ML Kit'], _mlkit);
}

Future<String> _asset(String path) async {
  try {
    return await rootBundle.loadString(path);
  } catch (_) {
    // Varlık paketlenmemişse (test, eksik derleme) sayfa yine açılsın.
    return path;
  }
}

const _pdfium = '''PDFium — Copyright 2014 The PDFium Authors. BSD 3-Clause License (+ Apache 2.0 parçalar). https://pdfium.googlesource.com/pdfium/+/main/LICENSE

pdfrx paketi aracılığıyla yerel kütüphane olarak dağıtılır.''';

const _syncfusion = '''Syncfusion Essential Studio (syncfusion_flutter_pdf, syncfusion_flutter_core) — Syncfusion Community License kapsamında kullanılmaktadır. Bu bir açık kaynak lisansı DEĞİLDİR; şartları: https://www.syncfusion.com/products/communitylicense

Syncfusion® ve Essential Studio® Syncfusion, Inc.'in tescilli markalarıdır.''';

const _mlkit = '''Google ML Kit (metin tanıma, belge tarayıcı, cihaz-içi çeviri) — Google APIs Terms of Service ve ML Kit Terms: https://developers.google.com/ml-kit/terms

Flutter eklentileri (google_mlkit_*) MIT lisanslıdır; lisans metinleri paket listesinde ayrıca yer alır.''';
