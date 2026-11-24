import 'dart:convert';

import 'package:dosya_okuyucu/core/ecosystem_apps.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/services/ai_pool.dart';
import 'package:dosya_okuyucu/services/gemini_service.dart';
import 'package:dosya_okuyucu/services/offline_mode.dart';
import 'package:dosya_okuyucu/services/shared_ai_pool_client.dart';
import 'package:dosya_okuyucu/widgets/cross_app_promo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineMode.enabled = false;
  });

  tearDown(() {
    OfflineMode.enabled = false;
  });

  group('SharedAiPoolClient (dosya okuyucu sıfır Firebase istemcisi)', () {
    test('BYOK kipinde 401/403/429 hatasında ortak havuza DÜŞMEZ', () async {
      for (final code in [401, 403, 429]) {
        expect(
          () => AiPool.guardExplicitMode(
            AiSourceMode.byok,
            GeminiException('err', statusCode: code),
          ),
          throwsA(
            isA<SharedAiPoolException>().having(
              (e) => e.kind,
              'kind',
              SharedAiPoolErrorKind.byokExhausted,
            ),
          ),
        );
      }

      var calls = 0;
      final client = SharedAiPoolClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.generate(
          mode: AiSourceMode.byok,
          idToken: 'tok-1',
          contents: const [],
        ),
        throwsA(
          isA<SharedAiPoolException>().having(
            (e) => e.kind,
            'kind',
            SharedAiPoolErrorKind.byokExhausted,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('bilinen bakiye 0 ise hiç HTTP isteği atmaz', () async {
      var calls = 0;
      final client = SharedAiPoolClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      )..setKnownBalanceForTest(0);

      await expectLater(
        client.generate(
          mode: AiSourceMode.sharedPool,
          idToken: 'tok-1',
          contents: const [],
        ),
        throwsA(
          isA<SharedAiPoolException>().having(
            (e) => e.kind,
            'kind',
            SharedAiPoolErrorKind.insufficientCredits,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('OfflineMode açıkken ve oturumsuzken HTTP çağrısı yapılmaz', () async {
      var calls = 0;
      final client = SharedAiPoolClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.fetchStatus(idToken: ''),
        throwsA(
          isA<SharedAiPoolException>().having(
            (e) => e.kind,
            'kind',
            SharedAiPoolErrorKind.unauthenticated,
          ),
        ),
      );

      OfflineMode.enabled = true;
      await expectLater(
        client.fetchStatus(idToken: 'tok-1'),
        throwsA(isA<OfflineException>()),
      );
      expect(calls, 0);
    });

    test(
      'sharedAiPoolStatus ve sharedAiPoolGenerate callable zarfını çözer',
      () async {
        final paths = <String>[];
        final client = SharedAiPoolClient(
          baseUri: Uri.parse('https://example.invalid'),
          client: MockClient((req) async {
            paths.add(req.url.path);
            expect(req.headers['authorization'], 'Bearer google-id-tok');
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            expect((body['data'] as Map)['appId'], 'dosya_okuyucu');
            if (req.url.path.endsWith('/sharedAiPoolStatus')) {
              return http.Response(
                jsonEncode({
                  'result': {
                    'balance': 500,
                    'starterGranted': true,
                    'apps': ['notlar', 'dosya_okuyucu'],
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'result': {
                  'text': 'Fatura Özeti',
                  'remainingCredits': 498,
                  'cost': 2,
                },
              }),
              200,
            );
          }),
        );

        final st = await client.fetchStatus(idToken: 'google-id-tok');
        expect(st.balance, 500);
        expect(st.starterGranted, isTrue);
        expect(client.knownBalance, 500);

        final gen = await client.generate(
          mode: AiSourceMode.sharedPool,
          idToken: 'google-id-tok',
          contents: const [
            {
              'role': 'user',
              'parts': [
                {'text': 'özet'},
              ],
            },
          ],
        );
        expect(gen.text, 'Fatura Özeti');
        expect(gen.remainingCredits, 498);
        expect(client.knownBalance, 498);
        expect(paths, ['/sharedAiPoolStatus', '/sharedAiPoolGenerate']);
      },
    );

    test('AiSourceMode seçimi ve bakiye önbelleği kalıcıdır', () async {
      await SharedAiPoolClient.saveMode(AiSourceMode.sharedPool);
      expect(await SharedAiPoolClient.loadMode(), AiSourceMode.sharedPool);
      await SharedAiPoolClient.saveCachedBalance(321);
      expect(await SharedAiPoolClient.loadCachedBalance(), 321);
    });
  });

  group('EcosystemApps & CrossAppPromoCard (Notlar)', () {
    test('üç dilde tüm yeni çeviri anahtarları dolu', () {
      for (final lang in AppLanguage.values) {
        final s = AppStrings(lang);
        for (final k in const [
          'sharedpool.title',
          'sharedpool.mode_byok',
          'sharedpool.mode_shared',
          'sharedpool.subtitle',
          'sharedpool.empty',
          'sharedpool.byok_exhausted',
          'sharedpool.signin_hint',
          'sharedpool.refresh',
          'eco.notlar_title',
          'eco.notlar_sub',
          'eco.notlar_cta',
          'eco.dismiss',
          'sm.local_tag',
          'sm.local_saved',
        ]) {
          expect(
            s.t(k, {'credits': 500, 'n': 3}),
            isNot(k),
            reason: '${lang.name}:$k',
          );
        }
      }
    });

    test('kapatılınca 30 gün gizlenir', () async {
      final prefs = await SharedPreferences.getInstance();
      final t0 = DateTime(2026, 11, 24);
      expect(EcosystemApps.notlarPackage, 'dev.kaimau.notlar');
      expect(EcosystemApps.shouldShowPromo(prefs, now: t0), isTrue);

      await EcosystemApps.dismissPromo(prefs, now: t0);
      expect(
        EcosystemApps.shouldShowPromo(
          prefs,
          now: t0.add(const Duration(days: 15)),
        ),
        isFalse,
      );
      expect(
        EcosystemApps.shouldShowPromo(
          prefs,
          now: t0.add(const Duration(days: 30)),
        ),
        isTrue,
      );
    });

    testWidgets('CrossAppPromoCard kapatılınca gizlenir', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: const [AppStrings.delegate],
          home: Scaffold(body: CrossAppPromoCard(prefsOverride: prefs)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cross-app-notlar-card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('cross-app-notlar-dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cross-app-notlar-card')), findsNothing);
      expect(EcosystemApps.shouldShowPromo(prefs), isFalse);
    });
  });
}
