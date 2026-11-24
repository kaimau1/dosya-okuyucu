import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/menu_search.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/widgets/menu_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void _noop() {}

void main() {
  group('MenuSearch motoru (normal + işlev sözlüğü)', () {
    const sample = <(String, String)>[
      ('İmzala', 'PDF'),
      ('Çevir', 'Dönüştür'),
      ('Boyutu düşür', 'Görsel'),
      ('Sesli oku', 'Dinle'),
      ('Parola ile koru', 'Güvenlik'),
      ('Bölmeleri dondur', 'Görünüm'),
      ('Yazdır', 'Çıktı'),
      ('Aranabilir yap (OCR)', 'Dönüştür'),
      ('Grafik ekle', 'Ekle'),
      ('Yinelenenleri kaldır', 'Veri'),
      ('Çöp kutusu', 'Temizlik'),
    ];

    List<String> search(String q) => MenuSearch.filter<(String, String)>(
          sample,
          q,
          labelOf: (e) => e.$1,
          groupOf: (e) => e.$2,
        ).map((h) => h.item.$1).toList();

    test('Türkçe harf ve büyük/küçük harf duyarsız normal arama çalışır', () {
      expect(search('cevir'), contains('Çevir'));
      expect(search('imza'), contains('İmzala'));
      expect(search('yazdir'), contains('Yazdır'));
      expect(search('cop'), contains('Çöp kutusu'));
      expect(search('İMZALA').first, 'İmzala');
    });

    test('işlev ve eşanlamlı sözlüğü gündelik ifadeleri doğru eşleştirir', () {
      expect(search('paraf'), contains('İmzala'));
      expect(search('tercüme'), contains('Çevir'));
      expect(search('ingilizce'), contains('Çevir'));
      expect(search('mb düşür'), contains('Boyutu düşür'));
      expect(search('hafiflet'), contains('Boyutu düşür'));
      expect(search('dinle'), contains('Sesli oku'));
      expect(search('tts'), contains('Sesli oku'));
      expect(search('kilit'), contains('Parola ile koru'));
      expect(search('şifrele'), contains('Parola ile koru'));
      expect(search('sabitle'), contains('Bölmeleri dondur'));
      expect(search('çıktı'), contains('Yazdır'));
      expect(search('printer'), contains('Yazdır'));
      expect(search('resimden yazı'), contains('Aranabilir yap (OCR)'));
      expect(search('pasta'), contains('Grafik ekle'));
      expect(search('tekilleştir'), contains('Yinelenenleri kaldır'));
    });

    test('doğrudan eşleşme işlev eşleşmesinden yüksek puan alır', () {
      final hits = MenuSearch.filter<(String, String)>(
        sample,
        'yazdır',
        labelOf: (e) => e.$1,
        groupOf: (e) => e.$2,
      );
      expect(hits.first.item.$1, 'Yazdır');
      expect(hits.first.byIntent, isFalse);

      final intentHits = MenuSearch.filter<(String, String)>(
        sample,
        'paraf',
        labelOf: (e) => e.$1,
        groupOf: (e) => e.$2,
      );
      expect(intentHits.first.item.$1, 'İmzala');
      expect(intentHits.first.byIntent, isTrue);
    });
  });

  group('MenuSections menü içi arama arayüzü', () {
    testWidgets('5+ işlemli menüde arama kutusu görünür ve işlevle süzer',
        (tester) async {
      var signedTapped = false;
      final sections = [
        MenuKitSection(title: 'Sayfa', actions: [
          MenuKitAction(
              icon: Icons.edit_rounded,
              label: 'İmzala',
              onTap: () => signedTapped = true),
          const MenuKitAction(
              icon: Icons.print_rounded, label: 'Yazdır', onTap: _noop),
          const MenuKitAction(
              icon: Icons.translate_rounded, label: 'Çevir', onTap: _noop),
        ]),
        const MenuKitSection(title: 'Güvenlik', actions: [
          MenuKitAction(
              icon: Icons.lock_rounded,
              label: 'Parola ile koru',
              onTap: _noop),
          MenuKitAction(
              icon: Icons.delete_rounded, label: 'Sil', onTap: _noop),
        ]),
      ];

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MenuSections(sections: sections, look: MenuLook.bento),
          ),
        ),
      ));

      final field = find.byKey(const ValueKey('menu-search-field'));
      expect(field, findsOneWidget);

      // İşlevsel sorgu: "paraf" -> "İmzala"
      await tester.enterText(field, 'paraf');
      await tester.pump();
      expect(find.text('İmzala'), findsOneWidget);
      expect(find.text('Yazdır'), findsNothing);

      await tester.tap(find.text('İmzala'));
      await tester.pump();
      expect(signedTapped, isTrue);

      // Eşleşmeyen sorguda boş durum görünür.
      await tester.enterText(field, 'zzzzxyyy');
      await tester.pump();
      expect(find.text('Eşleşen işlem bulunamadı'), findsOneWidget);
    });
  });
}
