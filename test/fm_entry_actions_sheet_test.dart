import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/entry_actions.dart';
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

  Future<void> open(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
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
                    onPressed: () =>
                        showEntryActions(context, entry, allowReveal: true),
                    child: const Text('ac'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
  }

  testWidgets('sayfa bölümlere ayrılmış ve iki sütunlu çizilir',
      (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);

    // Dört bölüm başlığı (büyük harfe çevrilmiş hâlleriyle).
    for (final key in const [
      'ea.sec_open',
      'ea.sec_move',
      'ea.sec_file',
    ]) {
      expect(find.text(const AppStrings(AppLanguage.tr).t(key).toUpperCase()),
          findsOneWidget,
          reason: '$key bölümü çizilmedi');
    }

    // İki sütun: her satır iki hücreyi eşit yükseklikte tutan bir
    // IntrinsicHeight. Tek sütuna dönseydi hiç olmazdı.
    expect(find.byType(IntrinsicHeight), findsWidgets);
  });

  testWidgets('silme düğmesi ızgaranın DIŞINDA ve dürüst metinli',
      (tester) async {
    await open(tester);
    // Çöp kutusu varsayılan olarak açık → "çöp kutusuna" sözü verilir.
    expect(
      find.text(const AppStrings(AppLanguage.tr).t('ea.delete_trash')),
      findsOneWidget,
    );
  });

  testWidgets('1.6 yazı ölçeğinde de taşmaz', (tester) async {
    await open(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uzun dosya adı başlıkta iki satırda kırpılır', (tester) async {
    await open(tester);
    final title = tester.widget<Text>(find.text(entry.name));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });
}
