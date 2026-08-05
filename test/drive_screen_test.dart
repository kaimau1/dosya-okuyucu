import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/drive_screen.dart';
import 'package:dosya_okuyucu/services/fm/app_signature.dart';
import 'package:dosya_okuyucu/services/fm/drive_service.dart';
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
  testWidgets('kapsam uyarısı liste DOLUYKEN de görünür', (tester) async {
    // Uyarı yalnız boş listede gösterilseydi, tek dosya yükleyen kullanıcı
    // geri kalan Drive dosyalarının neden görünmediğini bir daha öğrenemezdi.
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining('yalnız'), findsOneWidget);
      expect(find.text('rapor.pdf'), findsOneWidget);
    },
        () => MockClient((_) async => http.Response(
            '{"files":[{"id":"1","name":"rapor.pdf","mimeType":"application/pdf","size":"2048"}]}',
            200)));
  });

  testWidgets('boş listede "henüz yüklemediniz" yazar, hata DEĞİL',
      (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _signedIn());
      expect(find.textContaining('yüklemediniz'), findsOneWidget);
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
    },
        () => MockClient((_) async => http.Response(
            '{"error":{"message":"Insufficient Permission"}}', 403)));
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
