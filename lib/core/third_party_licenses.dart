import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'edition.dart';

/// Uygulama içi lisans sayfasına (`showLicensePage`) **paket dışı** gömülü
/// bileşenlerin lisanslarını ekler (Faz 7 / N2, 2026-10-21).
///
/// KÖK NEDEN: Flutter'ın lisans sayfası yalnız pub paketlerinin LICENSE
/// dosyalarını gösteriyor. Uygulamanın içinde dağıtılan ama paket OLMAYAN
/// şeyler — gömülü fontlar (OFL 1.1 metnin dağıtımla birlikte verilmesini
/// şart koşar), Word görüntüleyicinin JS dosyaları (MIT/Apache atıf ister),
/// Syncfusion'ın Community License'ı, `libmpv`/`FFmpeg` LGPL v3.0+ tam metni —
/// uygulama içinden eksiksiz sunulmalıdır.
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
  final lgpl3 = await _asset('assets/licenses/LGPL-3.0.txt');
  final gpl3 = await _asset('assets/licenses/GPL-3.0.txt');
  yield LicenseEntryWithLineBreaks(
    const ['media_kit_libs_android_video', 'libmpv', 'FFmpeg'],
    '$_mpvFfmpeg\n\n$lgpl3\n\n$gpl3',
  );
  yield const LicenseEntryWithLineBreaks([
    'AndroidX Media3',
    'Google Play Core / Code Scanner',
    'desugar_jdk_libs',
  ], _androidDeps);
  yield const LicenseEntryWithLineBreaks([
    'ESRGAN',
    'Antalia-2 Mini',
    'EMA Lightning',
    'PaddleOCR (PP-OCRv5)',
    'ONNX Runtime Web',
  ], _aiModels);
  // Kokoro + eSpeak NG yalnız Kişisel derlemede (2026-11-25 geri geldi):
  // Play derlemelerinde ses de lisans kaydı da yok.
  if (Edition.current.has(Feature.extraVoices)) {
    yield const LicenseEntryWithLineBreaks(['Kokoro'], _kokoro);
    yield const LicenseEntryWithLineBreaks(['eSpeak NG'], _espeak);
  }
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

const _mpvFfmpeg = '''libmpv & FFmpeg (media_kit_libs_android_video v1.3.8 / libmpv-android-video-build v1.1.7) — GNU Lesser General Public License (LGPL) v3.0 veya sonrası.

Android derlemesinde GPL kodlayıcıları kapalı (--disable-gpl --disable-nonfree --enable-version3) biçimde derlenmiş dinamik kütüphane (.so) olarak bağlanır.
- media_kit (MIT): https://github.com/media-kit/media-kit
- libmpv / FFmpeg Android derleme betikleri ve karşılık gelen kaynak kodu (v1.1.7): https://github.com/media-kit/libmpv-android-video-build
- LGPL v3.0 & GPL v3.0 tam metinleri aşağıda yer almaktadır.''';

const _androidDeps = '''Android yerel bağımlılıkları:
- AndroidX Media3 (Transformer, ExoPlayer, Effect, Common) 1.5.1 — Apache License 2.0 (https://github.com/androidx/media)
- Google Play Services (Code Scanner, ML Kit Barcode / Document Scanner / Subject Segmentation) & Play Core (Review, App Update) — Google APIs Terms of Service / Android Software Development Kit License Agreement
- Core Library Desugaring (com.android.tools:desugar_jdk_libs) — GNU General Public License v2.0 with the Classpath Exception (https://github.com/google/desugar_jdk_libs)''';

const _aiModels = '''İsteğe bağlı indirilen yapay zekâ ve ses modelleri (APK'ya gömülü değildir):
- ESRGAN (captain-pool/esrgan-tf2) — Apache License 2.0 (https://tfhub.dev/captain-pool/lite-model/esrgan-tf2/1)
- Antalia-2 Mini (cloud0day3/antalia-mini) — Apache License 2.0 (https://huggingface.co/cloud0day3/antalia-mini)
- EMA Lightning (canberk7/ema-lightning) — Apache License 2.0 (https://github.com/canberk7/ema-lightning)
- PaddleOCR PP-OCRv5 mobil algılama + Arapça tanıma modelleri (PaddlePaddle/PaddleOCR; ONNX: snowfluke/ppu-paddle-ocr-models) — Apache License 2.0 (https://github.com/PaddlePaddle/PaddleOCR)
- ONNX Runtime Web — MIT License (https://github.com/microsoft/onnxruntime)''';

const _kokoro = '''İsteğe bağlı indirilen Kokoro sesleri (APK'ya gömülü değildir; yalnız Kişisel derleme):
- Kokoro Türkçe (empiriolabsai/kokoro-turkish, Kokoro-82M ince ayarı) — Apache License 2.0; Copyright 2026 EmpirioLabs.ai LLC (https://huggingface.co/empiriolabsai/kokoro-turkish). Türkçe metin kuralları depodaki g2p_tr.py'den uyarlandı (Apache 2.0).
- Kokoro-82M v1.0 (hexgrad/Kokoro-82M; ONNX: onnx-community/Kokoro-82M-v1.0-ONNX) — Apache License 2.0 (https://huggingface.co/hexgrad/Kokoro-82M). İngilizce metin kuralları kokoro.js'ten uyarlandı (Apache 2.0).''';

const _espeak = '''eSpeak NG — GNU General Public License v3.0 veya sonrası (GPL-3.0-or-later).
Telif hakkı: Jonathan Duddington, Reece H. Dunn ve eSpeak NG katkıda bulunanları.

Kokoro sesleri indirilirken telaffuz (metin → ses birimi) için ayrı bir program olarak indirilir (WebAssembly derlemesi: npm espeak-ng 1.0.2, ianmarmour/espeak-ng.js); APK'ya gömülü değildir ve uygulamanın koduyla birleştirilmez. Bu program HİÇBİR GARANTİ olmaksızın dağıtılır; GPL-3.0 koşullarıyla değiştirip yeniden dağıtabilirsiniz.
- Kaynak kodu: https://github.com/espeak-ng/espeak-ng
- WebAssembly derleme betiği: https://github.com/ianmarmour/espeak-ng.js
- GPL-3.0 metni: lisans sayfasında libmpv/FFmpeg kaydının altında tam olarak yer alır.''';
