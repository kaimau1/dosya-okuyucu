import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/image_budget.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/screens/fm/image_gallery_screen.dart';
import 'package:dosya_okuyucu/screens/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Görsel ekranları TAM ÇÖZÜNÜRLÜKTE açmamalı: 12 MP'lik bir fotoğraf
/// bellekte 48 MB bitmap eder ve `PageView` komşuyu da canlı tutar.
/// Bu testler `cacheWidth`in gerçekten verildiğini ve sınırlar içinde
/// kaldığını sabitler (bkz. `core/image_budget.dart`).
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 1×1 saydam PNG — dosyanın var olması yeterli, çizilmesi gerekmiyor.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Widget _wrap(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: home,
    );

/// Ekrandaki tek `Image` bileşeninin çözme genişliğini döndürür.
int? _decodeWidthOf(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  for (final image in images) {
    final provider = image.image;
    if (provider is ResizeImage) return provider.width;
  }
  return null;
}

void main() {
  late Directory dir;
  late String imagePath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('image_budget_test');
    imagePath = p.join(dir.path, 'foto.png');
    await File(imagePath).writeAsBytes(_png);
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('galeri görseli sınırlı çözünürlükte açar', (tester) async {
    await tester.pumpWidget(_wrap(ImageGalleryScreen(paths: [imagePath])));
    await tester.pump();

    final width = _decodeWidthOf(tester);
    expect(width, isNotNull,
        reason: 'Image.file cacheWidth VERMEDEN kullanılıyor — '
            'tam çözünürlük belleği şişirir');
    expect(width, inInclusiveRange(ImageBudget.minWidth, ImageBudget.maxWidth));
  });

  testWidgets('görüntüleyicideki görsel de sınırlı çözünürlükte açar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: _wrap(ViewerScreen(
        doc: LoadedDoc(
          path: imagePath,
          name: 'foto.png',
          kind: DocKind.image,
        ),
      )),
    ));
    await tester.pump();

    final width = _decodeWidthOf(tester);
    expect(width, isNotNull);
    expect(width, inInclusiveRange(ImageBudget.minWidth, ImageBudget.maxWidth));
  });

  testWidgets('galeride dosya bilgisi her karede diske GİTMEZ',
      (tester) async {
    // `statSync` build içinde çağrılıyordu: yakınlaştırma/dokunma gibi her
    // `setState` bir kare içinde senkron disk erişimi demekti. Ölçüm artık
    // önbellekli → dosya silinse bile ekran çizilmeye devam eder.
    await tester.pumpWidget(_wrap(ImageGalleryScreen(paths: [imagePath])));
    await tester.pump();
    expect(find.textContaining('1/1'), findsOneWidget);

    // `deleteSync`: `testWidgets` gövdesinde GERÇEK asenkron dosya işlemi
    // sahte saat zonunda hiç tamamlanmaz ve test sonsuza dek asılır
    // (HAFIZA 2026-07-25 §F'deki tuzağın aynısı).
    File(imagePath).deleteSync();
    // Çubuğu gizle/göster → yeniden çizim. Ölçüm önbellekten geldiği için
    // boyut satırı kaybolmamalı ve hata atılmamalı.
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1/1'), findsOneWidget);
  });
}
