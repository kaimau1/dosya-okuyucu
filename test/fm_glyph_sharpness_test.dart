import 'package:dosya_okuyucu/widgets/fm/fm_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Bulanık simgeler** — kullanıcı bulgusu 2026-08-30 (ekran görüntüsüyle):
/// *"simgeler çok bulanık."*
///
/// KÖK NEDEN: [FmGlyph] her şeyi **birim karede** (0..1) çiziyor ve
/// `canvas.scale(side)` ile büyütüyor. Yollar için bu kusursuz — vektör,
/// ölçekten bağımsız keskin. Ama yazı bir glif atlasına rasterleştirilip doku
/// olarak çiziliyor ve atlas düzenin PUNTOSUNA göre üretiliyor: 0,20 puntoluk
/// bir yazıyı 44-96 kat büyütmek, 0,2 pikselde pişmiş bir dokuyu gerdirmek
/// demekti. Kağıdın kenarı jilet gibi, üstündeki "XLSX" bulanıktı.
///
/// Bu testin koruduğu kural tek cümle: **yazının puntosu kutunun boyuyla
/// ölçeklenir** (birim karede sabit kalmaz). Bir sonraki düzenlemede biri
/// `fontSize: 0.20` yazıp geçerse burada kırılır.
void main() {
  group('yazı puntosu cihaz ölçüsünde', () {
    test('şerit yazısı kutu büyüdükçe orantılı büyür', () {
      expect(FmGlyphMetrics.labelFontSize('PDF', 100), closeTo(20, 1e-9));
      expect(FmGlyphMetrics.labelFontSize('PDF', 44), closeTo(8.8, 1e-9));
      // Birim karede sabit kalsaydı ikisi de 0,20 olurdu — bulanıklığın
      // kaynağı tam olarak buydu.
      expect(FmGlyphMetrics.labelFontSize('PDF', 100),
          greaterThan(FmGlyphMetrics.labelFontSize('PDF', 44)));
    });

    test('uzun uzantı daha küçük punto alır ama yine ölçeklenir', () {
      expect(FmGlyphMetrics.labelFontSize('DOCX', 100), closeTo(15.5, 1e-9));
      expect(FmGlyphMetrics.labelFontSize('DOCX', 200), closeTo(31, 1e-9));
      expect(FmGlyphMetrics.labelFontSize('DOCX', 100),
          lessThan(FmGlyphMetrics.labelFontSize('PDF', 100)));
    });

    test('harf aralığı da ölçekle taşınır', () {
      expect(FmGlyphMetrics.labelLetterSpacing('PDF', 100), closeTo(0.4, 1e-9));
      expect(FmGlyphMetrics.labelLetterSpacing('DOCX', 100), 0);
    });

    test('binen Material glifinin puntosu da kutu ölçüsünde', () {
      expect(FmGlyphMetrics.overlayFontSize(0.34, 96), closeTo(32.64, 1e-9));
      expect(FmGlyphMetrics.overlayFontSize(0.34, 24), closeTo(8.16, 1e-9));
    });
  });

  group('çizim', () {
    Future<void> paintAt(WidgetTester tester, FmGlyphSpec spec, double size) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(child: FmGlyph(spec: spec, size: size)),
          ),
        ));

    testWidgets('uzantı şeritli kağıt her ölçüde hatasız çizilir',
        (tester) async {
      for (final size in [24.0, 44.0, 96.0, 160.0]) {
        await paintAt(
          tester,
          const FmGlyphSpec(
              folder: false, color: Color(0xFF1E6F66), label: 'XLSX'),
          size,
        );
        expect(tester.takeException(), isNull, reason: '$size dp');
      }
    });

    testWidgets('klasör ve çizgi (outlined) biçimleri de çizilir',
        (tester) async {
      await paintAt(
        tester,
        const FmGlyphSpec(
          folder: true,
          color: Color(0xFFB07C2A),
          overlay: Icons.download_rounded,
        ),
        64,
      );
      expect(tester.takeException(), isNull);

      await paintAt(
        tester,
        const FmGlyphSpec(
          folder: false,
          color: Color(0xFF3A6EA5),
          label: 'PDF',
          outlined: true,
          dark: true,
        ),
        64,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
