import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/drive_screen.dart';
import 'package:dosya_okuyucu/services/fm/app_signature.dart';
import 'package:dosya_okuyucu/services/fm/drive_service.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Oturum açılmış gibi davranan servis (sahte yetki başlığı).
DriveService _signedIn() =>
    DriveService(authHeadersOverride: () async => {'Authorization': 'Bearer t'});

/// Oturumsuz servis: `authHeadersOverride` null döndürür.
DriveService _signedOut() => DriveService(authHeadersOverride: () async => null);

/// Girişi `notConfigured` ile reddeden servis (ApiException 10 benzetimi).
class _NotConfiguredService extends DriveService {
  _NotConfiguredService() : super(authHeadersOverride: () async => null);

  @override
  Future<DriveSignIn> signIn() async =>
      const DriveSignIn(DriveSignInError.notConfigured);
}

Future<void> _pump(
  WidgetTester tester,
  DriveService service, {
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
    localizationsDelegates: _delegates,
    home: DriveScreen(service: service),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kök klasör listelenir, kırıntı yolu görünür', (tester) async {
    // Tam erişimden sonra ekran gerçek bir gezgin: kökten başlar ve nerede
    // olduğunu kırıntı yoluyla söyler.
    late Uri seen;
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.text('rapor.pdf'), findsOneWidget);
      expect(find.text('Drive\'ım'), findsOneWidget);
      // Kök listesi ÜST KLASÖRE göre istenmeli, yoksa Drive'ın tamamı düz
      // bir yığın hâlinde gelirdi.
      expect(seen.queryParameters['q'], contains("'root' in parents"));
    }, () => MockClient((req) async {
          seen = req.url;
          return http.Response(
              '{"files":[{"id":"1","name":"rapor.pdf","mimeType":"application/pdf","size":"2048"}]}',
              200);
        }));
  });

  testWidgets('klasöre dokunmak İÇİNE girer, geri tuşu üst klasöre çıkarır',
      (tester) async {
    final asked = <String?>[];
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      await tester.tap(find.text('Belgeler'));
      await tester.pumpAndSettle();
      // İkinci istek klasörün kimliğiyle yapılmalı.
      expect(asked.last, contains("'fid' in parents"));
      expect(find.text('Belgeler'), findsWidgets); // kırıntı yolunda

      // Geri tuşu ekranı KAPATMAZ, bir üst klasöre çıkarır.
      final popped =
          await tester.binding.handlePopRoute().then((v) => v, onError: (_) => false);
      await tester.pumpAndSettle();
      expect(popped, isTrue, reason: 'geri tuşu tüketilmeli');
      expect(asked.last, contains("'root' in parents"));
    }, () => MockClient((req) async {
          asked.add(req.url.queryParameters['q']);
          return http.Response(
              '{"files":[{"id":"fid","name":"Belgeler",'
              '"mimeType":"application/vnd.google-apps.folder"}]}',
              200);
        }));
  });

  testWidgets('boş klasörde "bu klasör boş" yazar, hata DEĞİL', (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining('klasör boş'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{"files":[]}', 200)));
  });

  testWidgets('oturum yoksa bağlan düğmesi çıkar, liste istenmez',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await _pump(tester, _signedOut());
      expect(find.text('Google ile bağlan'), findsOneWidget);
      expect(calls, 0, reason: 'oturumsuzken ağa çıkılmamalı');
    }, () => MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }));
  });

  testWidgets('Drive hatası kullanıcıya AÇIKÇA yazılır', (tester) async {
    // Sessiz boş liste, gerçekten boş bir Drive'dan ayırt edilemezdi.
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining('izin vermedi'), findsOneWidget);
      // Google'ın kendi mesajı da görünür: sınıflandırma tutmazsa kullanıcının
      // bildirebileceği tek ipucu bu (2026-08-05'te atılıyordu).
      expect(find.textContaining('sufficient rights'), findsOneWidget);
      // Hata varken "henüz yüklemediniz" YAZILMAZ — liste boş çünkü çağrı
      // düştü, kullanıcı yüklemediği için değil.
      expect(find.textContaining('yüklemediniz'), findsNothing);
    },
        () => MockClient((_) async => http.Response(
            '{"error":{"message":"The user does not have sufficient rights"}}',
            403)));
  });

  testWidgets('API kapalıysa ekran "Drive API etkin değil" der, sahiplik değil',
      (tester) async {
    // Kullanıcı ekran görüntüsü 2026-08-05: giriş çalışıyor ama liste 403.
    // Eski metin ("bu dosya uygulamamızla yüklenmemiş olabilir") kullanıcıyı
    // dosya sahipliğine baktırıyordu; asıl neden API'nin açılmamış olmasıydı.
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining('Kitaplık'), findsOneWidget);
      expect(find.textContaining('uygulamamızla yüklenmemiş'), findsNothing);
    },
        () => MockClient((_) async => http.Response(
            '{"error":{"errors":[{"reason":"accessNotConfigured"}],'
            '"code":403,"message":"Google Drive API has not been used in '
            'project 123 before or it is disabled."}}',
            403)));
  });

  testWidgets('Google E-Tablosu boyut yerine "—" ve dışa aktarım biçimi gösterir',
      (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      // "0 B" YAZILMAMALI: Google biçimlerinin bayt karşılığı yoktur, boş
      // oldukları anlamına gelmez.
      expect(find.textContaining('0 B'), findsNothing);
      expect(find.textContaining('XLSX'), findsOneWidget);
    },
        () => MockClient((_) async => http.Response(
            '{"files":[{"id":"1","name":"Bütçe","mimeType":"application/vnd.google-apps.spreadsheet"}]}',
            200)));
  });

  testWidgets('satırda SON DEĞİŞTİRİLME tarihi yazar', (tester) async {
    // Kullanıcı ekran görüntüsü 2026-08-07: listede yalnız boyut vardı,
    // aynı adın iki sürümünden hangisinin yeni olduğu anlaşılmıyordu.
    // Beklenen metin `humanDate` ile üretiliyor — saat dilimi makineye göre
    // değiştiği için sabit dizgi yazmak testi kırılgan yapardı.
    final when = FsPaths.humanDate(
        DateTime.utc(2026, 8, 6, 23, 41).millisecondsSinceEpoch);
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining(when), findsOneWidget);
      expect(find.textContaining('2,0 KB'), findsOneWidget);
    },
        () => MockClient((_) async => http.Response(
            '{"files":[{"id":"1","name":"rapor.pdf",'
            '"mimeType":"application/pdf","size":"2048",'
            '"modifiedTime":"2026-08-06T23:41:00.000Z"}]}',
            200)));
  });

  testWidgets('her belge KENDİ simgesiyle: PDF, Excel, Word ayrı',
      (tester) async {
    // Kullanıcı 2026-08-07: "PDF PDF simgesinde, Excel kendi simgesinde gibi
    // olmalı; şu an hepsi aynı belge işareti var".
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.table_chart), findsNWidgets(2)); // .xls + Google E-Tablo
      expect(find.byIcon(Icons.description), findsOneWidget); // Word
      expect(find.byIcon(Icons.android_rounded), findsOneWidget); // APK
    },
        () => MockClient((_) async => http.Response(
            '{"files":['
            '{"id":"1","name":"rapor.pdf","mimeType":"application/pdf"},'
            '{"id":"2","name":"butce.xls","mimeType":"application/vnd.ms-excel"},'
            '{"id":"3","name":"yazi.docx","mimeType":"application/msword"},'
            '{"id":"4","name":"Tablom","mimeType":"application/vnd.google-apps.spreadsheet"},'
            '{"id":"5","name":"uygulama.apk","mimeType":"application/vnd.android.package-archive"}'
            ']}',
            200)));
  });

  testWidgets('sıralama seçimi Drive orderBy ile yeniden listeler',
      (tester) async {
    final orders = <String?>[];
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(orders.first, 'folder,name');
      await tester.tap(find.byTooltip('Sıralama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarihe göre sırala'));
      await tester.pumpAndSettle();
      expect(orders.last, 'folder,modifiedTime desc');
    }, () => MockClient((req) async {
          orders.add(req.url.queryParameters['orderBy']);
          return http.Response(
              '{"files":[{"id":"1","name":"rapor.pdf",'
              '"mimeType":"application/pdf","size":"2048"}]}',
              200);
        }));
  });

  testWidgets('bilgi penceresi: ham damga değil okunur tarih + sahip/paylaşım',
      (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bilgi'));
      await tester.pumpAndSettle();
      final when = FsPaths.humanDate(
          DateTime.utc(2026, 8, 6, 23, 41).millisecondsSinceEpoch);
      expect(find.textContaining('Değiştirilme: $when'), findsOneWidget);
      expect(find.textContaining('Sahibi: Ayşe'), findsOneWidget);
      expect(find.textContaining('Paylaşım: Paylaşılmış'), findsOneWidget);
      // Ham MIME kullanıcıya hiçbir şey anlatmıyordu.
      expect(find.textContaining('application/pdf'), findsNothing);
      // Eski hâl: "2026-08-06 23:41:00.000Z".
      expect(find.textContaining('.000'), findsNothing);
    },
        () => MockClient((_) async => http.Response(
            '{"files":[{"id":"1","name":"rapor.pdf",'
            '"mimeType":"application/pdf","size":"2048",'
            '"modifiedTime":"2026-08-06T23:41:00.000Z",'
            '"createdTime":"2026-08-01T10:00:00.000Z",'
            '"owners":[{"displayName":"Ayşe"}],"shared":true}]}',
            200,
            // Başlıksız `http.Response` gövdeyi LATIN-1 sayar ve "ş" harfi
            // orada yok → yanıt hiç kurulamaz, liste boş gelirdi.
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets('İngilizce arayüzde ekran İngilizce', (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _signedOut(), locale: const Locale('en'));
      expect(find.text('Connect with Google'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{}', 200)));
  });

  testWidgets(
      'notConfigured girişinde kurulum kartı paket adı + SHA-1 gösterir',
      (tester) async {
    // "Kayıt gerekiyor" demek yetmiyordu: kullanıcının elinde kayıt için
    // gereken iki değer de yoktu ("google drive girmiyorum", 2026-08-05).
    //
    // Kanal SAHTELENMELİ: işleyicisiz bir platform kanalı testte hiç yanıt
    // vermez ve SHA-1 satırı asla çizilmez. null yanıt → bilinen CI değerine
    // düşüş de böylece sınanmış oluyor.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dosya_okuyucu/app_storage'),
      (_) async => null,
    );
    await http.runWithClient(() async {
      await _pump(tester, _NotConfiguredService());
      await tester.tap(find.text('Google ile bağlan'));
      await tester.pumpAndSettle();
      // Hata şeridi + kurulum kartı birlikte.
      expect(find.textContaining('etkinleştirilmemiş'), findsOneWidget);
      expect(find.textContaining(AppSignature.packageName), findsOneWidget);
      // Testte platform kanalı yok → CI anahtarının bilinen SHA-1'ine düşer.
      expect(
        find.textContaining(AppSignature.colonize(AppSignature.ciSha1Hex)),
        findsOneWidget,
      );
    }, () => MockClient((_) async => http.Response('{}', 200)));
  });

  test('AppSignature.colonize iki nokta biçimler', () {
    expect(AppSignature.colonize('f55d0c'), 'F5:5D:0C');
    // Zaten biçimliyse ikinci kez bozulmaz (kanal biçimli döndürürse diye).
    expect(AppSignature.colonize('F5:5D:0C'), 'F5:5D:0C');
    expect(
      AppSignature.colonize(AppSignature.ciSha1Hex),
      'F5:5D:0C:09:9F:97:71:3B:7A:1B:8D:B7:E8:6D:6A:0A:DA:EE:9D:B5',
    );
  });

  test('DriveScreen hata → çeviri anahtarı eşlemesi tam', () {
    // Her DriveError'ın bir metni olmalı; biri unutulursa ekran anahtarın
    // kendisini yazardı.
    for (final error in DriveError.values) {
      final key = 'drive.error_${_snake(error.name)}';
      expect(AppStrings.keys.contains(key), isTrue, reason: 'eksik: $key');
    }
  });
}

String _snake(String camel) => camel
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
