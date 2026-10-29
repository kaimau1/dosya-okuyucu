// 2026-10-29 tasarım görüntüleri — Yakındakiler, kabul ekranı, ortak menü
// dili (uzun basma / klasör ⋮ / seçim levhası), Kırık beyaz tema:
//
//   flutter test tool/design_shots_birlik_test.dart
//
// → docs/design/birlik/*.png. Normal test takımında KOŞMAZ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/entry_actions.dart';
import 'package:dosya_okuyucu/screens/fm/remote/nearby_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:dosya_okuyucu/services/fm/list_memory.dart';
import 'package:dosya_okuyucu/widgets/app_action_sheet.dart';
import 'package:dosya_okuyucu/widgets/doc_more_sheet.dart';
import 'package:dosya_okuyucu/widgets/fm/transfer_offer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const out = 'docs/design/birlik';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    Directory(out).createSync(recursive: true);
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    AppSkin skin = AppSkin.paper,
    Brightness brightness = Brightness.light,
    Future<void> Function(WidgetTester, BuildContext)? after,
    double height = 860,
  }) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ListMemory.resetForTest();
    final state = AppState();
    await tester.runAsync(state.init);
    tester.view.physicalSize = Size(400, height) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light(skin: skin)
              : AppTheme.dark(skin: skin),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (after != null) {
      await after(tester, nav.currentContext!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$out/$name.png').writeAsBytesSync(bytes!);
  }

  const blank = Scaffold(body: SizedBox.expand());

  testWidgets('yakındakiler', (t) async {
    await shot(t, 'yakindakiler', const NearbyScreen(services: false),
        height: 1700);
  });

  testWidgets('yakındakiler kırık beyaz', (t) async {
    await shot(t, 'yakindakiler_ivory', const NearbyScreen(services: false),
        skin: AppSkin.ivory, height: 1700);
  });

  testWidgets('kabul ekranı', (t) async {
    await shot(t, 'kabul', blank, after: (t, ctx) async {
      showTransferOffer(ctx,
          from: 'Ayşe\'nin telefonu',
          count: 14,
          totalBytes: 48 * 1024 * 1024,
          saveDir: '/storage/emulated/0/Download',
          items: const [
            OfferRow(name: 'Tatil.zip', size: 30000000, folderFiles: 9),
            OfferRow(name: 'rapor.pdf', size: 1200000),
            OfferRow(name: 'sunum.pptx', size: 5400000),
            OfferRow(name: 'video.mp4', size: 9000000),
            OfferRow(name: 'not.txt', size: 1200),
          ]);
    });
  });

  testWidgets('uzun basma menüsü', (t) async {
    await shot(t, 'uzun_basma', blank, height: 1300, after: (t, ctx) async {
      showEntryActions(
          ctx,
          const FsEntry(
              path: '/storage/emulated/0/Download/rapor.pdf',
              name: 'rapor.pdf',
              isDir: false,
              sizeBytes: 1200000,
              modifiedMs: 1761700000000));
    });
  });

  testWidgets('klasör menüsü (Daha fazla levhası)', (t) async {
    await shot(t, 'klasor_menu', blank, after: (t, ctx) async {
      DocMoreSheet.show(ctx, [
        DocMoreGroup('Bu öğe', [
          DocMoreItem(AppIcons.hidden, 'Gizlileri göster', () {}, selected: true),
          DocMoreItem(AppIcons.starEmpty, 'Favori', () {}, selected: false),
          DocMoreItem(AppIcons.lock, 'Klasörü kilitle', () {}),
          DocMoreItem(AppIcons.selectAll, 'Tümünü seç', () {}),
        ]),
        DocMoreGroup('Diğer', [
          DocMoreItem(AppIcons.organize, 'Düzenle', () {}),
          DocMoreItem(AppIcons.cleanEmpty, 'Boş klasörler', () {}),
          DocMoreItem(AppIcons.refresh, 'Yenile', () {}),
        ]),
      ]);
    });
  });

  testWidgets('seçim levhası', (t) async {
    await shot(t, 'secim_levha', blank, after: (t, ctx) async {
      showAppActionSheet<int>(ctx, title: '3 öğe seçildi', groups: const [
        AppActionGroup(title: 'Düzenle', actions: [
          AppAction(value: 1, icon: AppIcons.rename, label: 'Yeniden adlandır'),
          AppAction(value: 2, icon: AppIcons.ai, label: 'AI ile etiketle', accent: true),
        ]),
        AppActionGroup(title: 'Kopyala / Taşı', actions: [
          AppAction(value: 3, icon: AppIcons.copy, label: 'Önemli dosyalara kopyala',
              hint: 'Kopyası Önemli Dosyalar\'a gider'),
          AppAction(value: 4, icon: AppIcons.delete, label: 'Kalıcı sil', destructive: true),
        ]),
      ]);
    });
  });

  testWidgets('ayarlar', (t) async {
    await shot(t, 'ayarlar', const SettingsScreen(), height: 1400);
  });
}
