import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/widgets/fm/media_resize_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Faz 14 — boyutlandırma levhası.** Kabul ölçütü: "1600 yazınca yükseklik
/// alanı anında doluyor"; kilit kapalıyken dört yerleşim; %150'de büyütme
/// uyarısı; hazır ayarlar tek dokunuş.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _photo = MediaSourceInfo(
    name: 'tatil.jpg',
    sizeBytes: 4200000,
    isVideo: false,
    width: 4000,
    height: 3000);

void main() {
  /// Levhayı açar; "Başlat" dönüşü [result]'a yazılır.
  Future<ValueNotifier<MediaResizeOptions?>> open(WidgetTester tester,
      {MediaResizeOptions initial = const MediaResizeOptions(),
      bool hasVideos = false}) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final result = ValueNotifier<MediaResizeOptions?>(null);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.value = await showMediaResizeSheet(
              context,
              hasImages: true,
              hasVideos: hasVideos,
              fileCount: 1,
              initial: initial,
              sources: const [_photo],
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets('fotoğrafta fotoğraf kipleri, videoda kademeler', (tester) async {
    await open(tester);
    for (final m in ['longEdge', 'aspect', 'fileSize', 'custom', 'percent']) {
      expect(find.byKey(ValueKey('mode-$m')), findsOneWidget, reason: m);
    }
    expect(find.byKey(const ValueKey('mode-p720')), findsNothing);
    // Hatırlanan 1080p (video kademesi) fotoğrafta uzun kenara çevrilir.
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('mode-longEdge')))
            .selected,
        isTrue);
  });

  testWidgets('video seçiminde fotoğraf kipleri yok', (tester) async {
    await open(tester, hasVideos: true);
    expect(find.byKey(const ValueKey('mode-p720')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-fileSize')), findsNothing);
  });

  testWidgets('kilitli: 1600 yazınca yükseklik ANINDA 1200', (tester) async {
    final result = await open(tester);
    await tapKey(tester, 'mode-custom');
    await tester.enterText(find.byKey(const ValueKey('width-field')), '1600');
    await tester.pump();
    expect(fieldText(tester, 'height-field'), '1200');
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    // Modelde YALNIZ yazılan alan: çoklu seçimde her dosya kendi oranında.
    expect(result.value!.customWidth, 1600);
    expect(result.value!.customHeight, isNull);
    expect(result.value!.lockAspect, isTrue);
  });

  testWidgets('kilit açılınca iki alan + dört yerleşim', (tester) async {
    final result = await open(tester);
    await tapKey(tester, 'mode-custom');
    await tester.enterText(find.byKey(const ValueKey('width-field')), '1080');
    await tester.pump();
    await tapKey(tester, 'lock-aspect');
    await tester.enterText(find.byKey(const ValueKey('height-field')), '1080');
    await tester.pumpAndSettle();
    for (final f in ResizeFit.values) {
      expect(find.byKey(ValueKey('fit-${f.name}')), findsOneWidget);
    }
    await tapKey(tester, 'fit-pad');
    expect(find.text('Bulanık arka plan'), findsOneWidget);
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    final o = result.value!;
    expect((o.customWidth, o.customHeight, o.lockAspect, o.fit),
        (1080, 1080, false, ResizeFit.pad));
  });

  testWidgets('%150 → büyütme uyarısı (K14)', (tester) async {
    await open(tester,
        initial: const MediaResizeOptions(
            resolution: ResolutionChoice.percent, percent: 150));
    expect(find.textContaining('netlik artmaz'), findsOneWidget);
    expect(find.textContaining('6000×4500'), findsOneWidget);
  });

  testWidgets('hazır ayar "Başvuru ≤ 200 KB" → dosya boyutu kipi, kalite gizli',
      (tester) async {
    final result = await open(tester);
    expect(find.text('JPEG kalitesi (fotoğraf)'), findsOneWidget);
    await tapKey(tester, 'preset-rs.preset_form');
    expect(find.text('JPEG kalitesi (fotoğraf)'), findsNothing);
    expect(
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('kb-200'))).selected,
        isTrue);
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    expect(result.value!.resolution, ResolutionChoice.fileSize);
    expect(result.value!.targetKb, 200);
  });

  testWidgets('oran kipi: 4:5 + kenar boşluğu', (tester) async {
    final result = await open(tester);
    await tapKey(tester, 'mode-aspect');
    await tapKey(tester, 'aspect-4:5');
    await tapKey(tester, 'aspect-fit-pad');
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    final o = result.value!;
    expect((o.aspectW, o.aspectH, o.fit), (4.0, 5.0, ResizeFit.pad));
  });
}
