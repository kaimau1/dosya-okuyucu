import 'dart:io';

import 'package:dosya_okuyucu/widgets/whats_new.dart';
import 'package:dosya_okuyucu/core/app_navigator.dart';
import 'package:dosya_okuyucu/main.dart' as app;
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/services/file_service.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// **Cihaz perf senaryoları** (Faz 42 / 6 — FAZ_PLANI Faz 4 P13, KALANLAR A8.1).
///
/// Koşu (telefon bağlı, profil derlemesi):
///   python3 tool/make_test_tree.py olcum_verisi
///   adb push olcum_verisi /sdcard/Android/data/PAKET/files/olcum
///   bash tool/perf_senaryo.sh
/// Her senaryo `traceAction` ile ayrı zaman çizelgesi üretir; sürücü
/// (`test_driver/perf_driver.dart`) `build/<anahtar>.timeline_summary.json`
/// yazar, betik p90/p99/en kötü kare tablosunu `docs/perf/`e çıkarır.
///
/// Veri klasörü uygulamanın kendi dış dizininde (izin istemez); başka bir
/// yer için `--dart-define=OLCUM_VERISI=/yol`.
const _veri = String.fromEnvironment('OLCUM_VERISI',
    defaultValue:
        '/sdcard/Android/data/com.dosyaokuyucu.dosya_okuyucu/files/olcum');

/// Büyük PDF (Ferrari H0.2, §2 işlem 1–2). Varsayılan
/// `make_test_tree.py --buyuk` çıktısı; USB'deki gerçek dosya için
/// `--dart-define=BUYUK_PDF=/storage/<usb>/x.pdf` (`tool/ab_olcum.sh` geçirir).
/// Dosya yoksa senaryo atlanır (öteki senaryolar koşar).
const _buyukPdf = String.fromEnvironment('BUYUK_PDF',
    defaultValue: '$_veri/buyuk_100mb.pdf');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Gerçek zamanlı bekleme (canlı bağlamada kareler motordan gelir).
  Future<void> bekle(WidgetTester tester, int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pump();
  }

  /// Ekranın ortasından [n] kez yukarı fırlatma (liste, PDF ve ızgara için
  /// aynı hareket — A/B karşılaştırılabilir kalsın).
  Future<void> kaydir(WidgetTester tester, {int n = 12}) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final from = Offset(size.width / 2, size.height * 0.7);
    for (var i = 0; i < n; i++) {
      await tester.flingFrom(from, const Offset(0, -700), 2500);
      await bekle(tester, 450);
    }
  }

  Future<void> ac(WidgetTester tester, Widget screen) async {
    navigatorKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    await bekle(tester, 1500);
  }

  Future<void> kapat(WidgetTester tester) async {
    navigatorKey.currentState!.pop();
    await bekle(tester, 800);
  }

  testWidgets('P13: açılış, klasör, galeri, PDF, Excel', (tester) async {
    // "Neler yeni" levhası açılış ölçümüne girmesin (taban Faz 43'te yoktu).
    await WhatsNew.markSeen();
    await binding.traceAction(() async {
      await app.main();
      await bekle(tester, 3000);
    }, reportKey: 'soguk_acilis');

    // Boşta: hiçbir şey dokunulmadan 3 sn — kare sayısı ~0 olmalı (k.6).
    await binding.traceAction(() => bekle(tester, 3000),
        reportKey: 'pano_bosta');

    await ac(tester, const BrowserScreen(path: '$_veri/klasor_5000'));
    await binding.traceAction(() => kaydir(tester),
        reportKey: 'klasor_5000_kaydirma');
    await kapat(tester);

    await ac(tester, const BrowserScreen(path: '$_veri/galeri_2000'));
    await binding.traceAction(() => kaydir(tester),
        reportKey: 'galeri_2000_kaydirma');
    await kapat(tester);

    final fs = FileService();
    await binding.traceAction(() async {
      final pdf = await fs.load('$_veri/belge_100.pdf');
      await ac(tester, EntryOpener.screenFor(pdf));
    }, reportKey: 'pdf_100_acilis');
    await binding.traceAction(() => kaydir(tester, n: 20),
        reportKey: 'pdf_100_kaydirma');
    await kapat(tester);

    await binding.traceAction(() async {
      final xlsx = await fs.load('$_veri/tablo_100k.xlsx');
      await ac(tester, EntryOpener.screenFor(xlsx));
      await bekle(tester, 4000); // izolatta ayrıştırma
    }, reportKey: 'xlsx_100k_acilis');
    await binding.traceAction(() => kaydir(tester, n: 20),
        reportKey: 'xlsx_100k_kaydirma');
    await kapat(tester);

    // H0.2: büyük PDF aç + 50 sayfa hızlı kaydır. Sayfa sayısı
    // denetleyiciden; fırlatma sayısı tavanlı (bitmezse kaç sayfa gidildi
    // logda).
    if (File(_buyukPdf).existsSync()) {
      await binding.traceAction(() async {
        final pdf = await fs.load(_buyukPdf);
        await ac(tester, EntryOpener.screenFor(pdf));
        await bekle(tester, 3000); // ilk sayfa bitmap'i (PDFPRO_PERF)
      }, reportKey: 'pdf_buyuk_acilis');
      final ctl = tester.widget<PdfViewer>(find.byType(PdfViewer)).controller;
      final ilk = ctl?.pageNumber ?? 1;
      var n = 0;
      await binding.traceAction(() async {
        while (n < 60 && (ctl?.pageNumber ?? ilk) < ilk + 50) {
          await kaydir(tester, n: 1);
          n++;
        }
      }, reportKey: 'pdf_buyuk_50_sayfa');
      // ignore: avoid_print
      print('PERF pdf_buyuk_50_sayfa: $n fırlatma, sayfa $ilk → '
          '${ctl?.pageNumber}');
      await kapat(tester);
    } else {
      // ignore: avoid_print
      print('PERF pdf_buyuk: dosya yok, atlandı');
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
