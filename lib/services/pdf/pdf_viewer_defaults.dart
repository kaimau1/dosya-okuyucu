import 'package:pdfrx/pdfrx.dart';

/// pdfrx'in KENDİ metin seçimini kapatan ortak parametre (görüntüleyici +
/// PDF düzenleyici).
///
/// pdfrx 1.3.5'te seçim varsayılan olarak kapalıydı; 2.x'te
/// (`PdfTextSelectionParams.enabled` varsayılanı true) açık geldi ve A3.2
/// yükseltmesinde (2026-11-02) fark edilmeden açık kaldı. Bedeli:
/// sayfaların altına ikinci bir jest katmanı, HER dokunuşta tüm sayfaların
/// metnini yükleyip parçalarını tarayan bir isabet testi ve bizim
/// `PdfSelectLayer` seçimimizle yarışan ikinci bir uzun basış seçimi.
///
/// `const` olması önemli: pdfrx `didUpdateWidget`te parametreleri `!=` ile
/// karşılaştırıyor; her yapımda yeni bir örnek "değişti" sayılırdı.
const kPdfOwnSelectionOff = PdfTextSelectionParams(enabled: false);
