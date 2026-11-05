import 'package:xml/xml.dart';

import 'pptx_media_ops.dart';
import 'pptx_package.dart';

export 'pptx_media_ops.dart' show SlideMediaRef;

/// Sunum sırasında bir slaytın etkileşimli öğeleri.
class SlideShowInfo {
  final List<SlideMediaRef> media;

  /// Otomatik ilerleme (`p:transition@advTm`, ms); null = tıklamayla.
  final int? advanceMs;
  const SlideShowInfo({this.media = const [], this.advanceMs});
}

/// **Faz 38 — sunum bilgisi.** Destenin her slaytı (paket sırası) için medya
/// ve zamanlama; sunum açılınca bir kez, izolatta okunur.
abstract final class PptxShowInfo {
  static List<SlideShowInfo> read(PptxPackage pkg) {
    final out = <SlideShowInfo>[];
    for (final part in pkg.slideParts()) {
      final d = pkg.xml(part);
      final tr = d?.findAllElements('p:transition').firstOrNull;
      out.add(SlideShowInfo(
        media: PptxMediaOps.mediaOf(pkg, part),
        advanceMs: int.tryParse(tr?.getAttribute('advTm') ?? ''),
      ));
    }
    return out;
  }
}
