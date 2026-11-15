import 'dart:ui' show Tristate;

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/state/appearance_state.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/entry_actions.dart';
import 'package:dosya_okuyucu/widgets/menu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var (kullanıcı 2026-08-29: *"3 noktaya basınca çıkan ayarlar
/// çok yılın olmuş, yeniden sıralanmalı ve düzenlenmeli, gerekirse 2 sütunlu
/// olabilir"*):**
///
/// İşlem sayfası artık bölümlü ve **iki sütunlu**. İki sütun demek, her
/// hücrenin genişliğinin yarıya inmesi demek — uzun Türkçe etiketler ("Önemli
/// dosyalara kopyala") ve büyütülmüş yazı ölçeği burada taşma üretir ve bu
/// yalnız telefonda görünürdü. Test her ölçekte çizip taşma olmadığını ve
/// silme düğmesinin **ızgaranın dışında** kaldığını doğrular.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  const entry = FsEntry(
    path: '/depo/Belgeler/AHBS_Egitim_Videosu_1080_cok_uzun_ad.txt',
    name: 'AHBS_Egitim_Videosu_1080_cok_uzun_ad.txt',
    isDir: false,
    sizeBytes: 2 * 1024 * 1024 * 1024,
    modifiedMs: 1756000000000,
  );

  const tr = AppStrings(AppLanguage.tr);

  AppearanceState lookState(MenuLook look) => AppearanceState()
    ..apply(
      themeMode: ThemeMode.light,
      skin: AppSkin.bento,
      background: 'default',
      language: AppLanguage.tr,
      uiFont: AppTheme.uiFontDefault,
      uiTextScale: 1.0,
      menuLook: look,
    );

  Future<void> open(WidgetTester tester,
      {double textScale = 1.0,
      MenuLook? look,
      Future<void> Function(BuildContext context)? show}) async {
    final app = MaterialApp(
      theme: AppTheme.light(),
      // Dil AÇIKÇA Türkçe: test ortamı varsayılan olarak `en` seçiyor ve
      // Türkçe metin arayan bir doğrulama sessizce hep boş dönerdi.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => show != null
                    ? show(context)
                    : showEntryActions(context, entry, allowReveal: true),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        // Görünüm sağlayıcısı yoksa (test, bağımsız ağaç) sekmeli.
        child: look == null
            ? app
            : ChangeNotifierProvider<AppearanceState>.value(
                value: lookState(look), child: app),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
  }

  testWidgets('varsayılan sekmeli: Aç + Paylaş/Sil, sekmeler bölüm başlıkları',
      (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, tr.t('common.open')),
        findsOneWidget);
    expect(find.byTooltip(tr.t('common.share')), findsOneWidget);
    expect(find.byTooltip(tr.t('common.delete')), findsOneWidget);
    // Sekmeler: "Sık kullanılan" + mevcut bölüm başlıkları (büyük harf YOK).
    for (final key in const [
      'menu.tab_common',
      'ea.sec_open',
      'ea.sec_move',
      'ea.sec_file',
    ]) {
      expect(find.text(tr.t(key)), findsOneWidget,
          reason: '$key sekmesi çizilmedi');
    }
    // İlk sekme seçili; seçili olmayan sekmenin işleri ağaçta yok.
    expect(find.text(tr.t('fm.move')), findsOneWidget);
    expect(find.text(tr.t('ea.compress')), findsNothing);
    expect(find.byType(MenuGroupTitle), findsNothing);
  });

  testWidgets('sık kullanılan: hızlı paylaş, önemli işaretle; Sil ayrı',
      (tester) async {
    await open(tester);
    for (final key in const [
      'ea.quick_share',
      'fm.copy_to_important',
      'fm.rename',
    ]) {
      expect(find.text(tr.t(key)), findsOneWidget, reason: '$key yok');
    }
    // Sil ızgarada değil, "Aç"ın yanındaki tehlike düğmesi.
    expect(find.text(tr.t('common.delete')), findsNothing);
    expect(find.byTooltip(tr.t('common.delete')), findsOneWidget);
  });

  testWidgets('sekme değişince o bölümün işleri görünür, levha zıplamaz',
      (tester) async {
    await open(tester);
    final card = find.byType(MenuGroupCard);
    final before = tester.getSize(card).height;
    await tester.ensureVisible(find.text(tr.t('ea.sec_file')));
    await tester.tap(find.text(tr.t('ea.sec_file')));
    await tester.pumpAndSettle();
    expect(find.text(tr.t('ea.compress')), findsOneWidget);
    expect(find.text(tr.t('fm.properties')), findsOneWidget);
    expect(find.text(tr.t('fm.move')), findsNothing);
    // Gövde yüksekliği en uzun sekmeye göre sabit.
    expect(tester.getSize(card).height, before);
    // Seçili sekme erişilebilirlikte "seçili".
    final handle = tester.ensureSemantics();
    await tester.pump();
    final node = tester.getSemantics(find.text(tr.t('ea.sec_file')));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('Bento: bütün bölümler başlıklarıyla, Sil karo olarak',
      (tester) async {
    await open(tester, look: MenuLook.bento);
    expect(tester.takeException(), isNull);
    for (final key in const ['ea.sec_open', 'ea.sec_move', 'ea.sec_file']) {
      expect(
          find.widgetWithText(MenuGroupTitle, tr.t(key)), findsOneWidget,
          reason: '$key bölümü çizilmedi');
    }
    for (final key in const [
      'common.open',
      'common.share',
      'common.delete',
      'fm.move',
      'ea.compress',
      'fm.properties',
    ]) {
      expect(find.text(tr.t(key)), findsOneWidget, reason: '$key yok');
    }
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('görüntüleyici ⋮: türe özel grup seçili açılır, Sil ortak sekmede',
      (tester) async {
    var ran = false;
    await open(tester,
        show: (context) => showEntryActions(context, entry,
            inViewer: true,
            showShare: false,
            groups: [
              EntryExtraGroup('PDF', [
                EntryExtraAction(
                    icon: Icons.edit, label: 'Sayfaları düzenle', onTap: () => ran = true),
              ]),
            ]));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Sayfaları düzenle'), findsOneWidget);
    await tester.tap(find.text(tr.t('menu.tab_common')));
    await tester.pumpAndSettle();
    expect(find.text(tr.t('common.delete')), findsOneWidget);
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sayfaları düzenle'));
    await tester.pumpAndSettle();
    expect(ran, isTrue);
  });

  testWidgets('1.6 yazı ölçeğinde de taşmaz (iki görünüm)', (tester) async {
    await open(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(tr.t('ea.sec_open')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MenuSections))).pop();
    await tester.pumpAndSettle();
    await open(tester, textScale: 1.6, look: MenuLook.bento);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uzun dosya adı başlıkta iki satırda kırpılır', (tester) async {
    await open(tester);
    final title = tester.widget<Text>(find.text(entry.name));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });
}
