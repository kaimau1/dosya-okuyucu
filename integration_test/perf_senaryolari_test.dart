import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/widgets/whats_new.dart';
import 'package:dosya_okuyucu/core/app_navigator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/main.dart' as app;
import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/word_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/screens/fm/analysis_screen.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/dashboard_screen.dart';
import 'package:dosya_okuyucu/screens/fm/smart_sort_screen.dart';
import 'package:dosya_okuyucu/services/file_service.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:dosya_okuyucu/widgets/state_views.dart';
import 'package:dosya_okuyucu/widgets/side_menu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Cihaz perf senaryoları** (Faz 42 / 6 — FAZ_PLANI Faz 4 P13, KALANLAR A8.1).
///
/// Koşu (telefon bağlı, profil derlemesi):
///   python3 tool/make_test_tree.py olcum_verisi
///   adb push olcum_verisi /sdcard/Android/data/PAKET/files/olcum
///   bash tool/perf_senaryo.sh
/// Her senaryo `traceAction` ile ayrı zaman çizelgesi üretir; sürücü
/// (`test_driver/perf_driver.dart`) `build/<anahtar>.timeline_summary.json`
/// yazar, betik p90/p99/en kötü kare tablosunu `docs/perf/`e çıkarır.
/// Bir senaryo grubu hata verirse (`bolum`) yazılır, kalanlar sürer (T1).
///
/// Veri klasörü uygulamanın kendi dış dizininde (izin istemez); başka bir
/// yer için `--dart-define=OLCUM_VERISI=/yol`.
/// Yalnız bu gruplar koşar (virgüllü `bolum` adları; boş = hepsi). Gerileme
/// ikiye bölmesinde tek senaryo (R1): `AB_SENARYO=klasor_galeri bash tool/ab_olcum.sh`.
const _yalniz = String.fromEnvironment('AB_SENARYO');

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

  /// Bir senaryo grubu: hata verirse yazılır, kök rotaya dönülür ve kalan
  /// gruplar sürer (T1, 2026-11-20: Huawei'de tek hata tüm koşuyu düşürdü).
  Future<void> bolum(
      WidgetTester tester, String ad, Future<void> Function() fn) async {
    if (_yalniz.isNotEmpty && !_yalniz.split(',').contains(ad)) return;
    try {
      await fn();
    } catch (e, st) {
      final yigin = st.toString().split('\n').take(6).join(' | ');
      // ignore: avoid_print
      print('PERF $ad: hata, atlandı — $e — $yigin');
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      await bekle(tester, 800);
    }
  }

  /// Ana ekranda [hedef]i bulur: kök rotaya döner, gerekirse panoyu
  /// kaydırıp görünür yapar. Yoksa tanı satırı yazar, `null` döner (senaryo
  /// atlanır). T1: Huawei'de ilk koşuda "Analiz" ve şerit sekmeleri
  /// bulunamadı — tanı neden olduğunu söyler.
  Future<Finder?> anaEkranda(
      WidgetTester tester, String ad, Finder hedef) async {
    navigatorKey.currentState!.popUntil((r) => r.isFirst);
    await bekle(tester, 600);
    final tum = hedef; // çağıran skipOffstage: false verir
    final liste = find.descendant(
        of: find.byType(DashboardScreen), matching: find.byType(Scrollable));
    if (tum.evaluate().isEmpty && liste.evaluate().isNotEmpty) {
      // Pano tembel liste: aşağıdaki bölüm henüz kurulmamış olabilir.
      try {
        await tester.scrollUntilVisible(tum, 400,
            scrollable: liste.first, maxScrolls: 15);
      } catch (_) {}
    }
    if (tum.evaluate().isEmpty) {
      final pano = find.byType(DashboardScreen, skipOffstage: false);
      // ignore: avoid_print
      print('PERF $ad: hedef yok, atlandı (pano ${pano.evaluate().length}, '
          'görünür ${find.byType(DashboardScreen).evaluate().length})');
      return null;
    }
    await tester.ensureVisible(tum.first);
    await bekle(tester, 500);
    return tum.first;
  }

  testWidgets('P13: açılış, klasör, galeri, PDF, Excel', (tester) async {
    // "Neler yeni" levhası açılış ölçümüne girmesin (taban Faz 43'te yoktu).
    await WhatsNew.markSeen();
    // Anlamsal ağaç (TalkBack) açık ölçülür — `testWidgets` varsayılanıyla
    // aynı, eski tablolarla kıyaslanabilir. Sonda kapatılıp kaydırma
    // yeniden ölçülür (`*_sk`, P13 / B3.3b): 2026-11-13 zaman çizelgesinde
    // UI izleğinin %56'sı SEMANTICS evresiydi — erişilebilirlik hizmeti
    // kapalı kullanıcı o payı ödemez.
    final anlam = tester.ensureSemantics();
    await binding.traceAction(() async {
      await app.main();
      await bekle(tester, 3000);
    }, reportKey: 'soguk_acilis');

    // Boşta: hiçbir şey dokunulmadan 3 sn — kare sayısı ~0 olmalı (k.6).
    // Hiç kare yoksa sürücü "kare yok" yazar (özet çıkarılamaz).
    await bolum(tester, 'pano_bosta', () async {
      await binding.traceAction(() => bekle(tester, 3000),
          reportKey: 'pano_bosta');
    });

    // T1: sol menü açılış + kapanış (3 kez).
    await bolum(tester, 'sol_menu', () async {
      await binding.traceAction(() async {
        for (var i = 0; i < 3; i++) {
          unawaited(SideMenuView.show());
          await bekle(tester, 900);
          navigatorKey.currentState!.pop();
          await bekle(tester, 700);
        }
      }, reportKey: 'sol_menu_acilis');
    });

    // T1: Bellek Analizi — kullanıcının yolu (bellek kartındaki "Analiz").
    await bolum(tester, 'bellek_analizi', () async {
      final ctx = navigatorKey.currentContext!;
      final dugme = await anaEkranda(tester, 'bellek_analizi',
          find.text(ctx.t('home.analysis'), skipOffstage: false));
      if (dugme == null) return;
      await binding.traceAction(() async {
        await tester.tap(dugme);
        await bekle(tester, 2500);
      }, reportKey: 'bellek_analizi_acilis');
      if (find.byType(AnalysisScreen).evaluate().isEmpty) {
        // ignore: avoid_print
        print('PERF bellek_analizi: ekran açılmadı');
        navigatorKey.currentState!.popUntil((r) => r.isFirst);
        await bekle(tester, 800);
        return;
      }
      await binding.traceAction(() => kaydir(tester, n: 6),
          reportKey: 'bellek_analizi_kaydirma');
      await kapat(tester);
    });

    // T1: Akıllı düzen ekranı (ana ekrandaki kutuyla aynı giriş).
    await bolum(tester, 'akilli_duzen', () async {
      await binding.traceAction(() async {
        unawaited(SmartSortScreen.open(navigatorKey.currentContext!));
        await bekle(tester, 2500);
      }, reportKey: 'akilli_duzen_acilis');
      await binding.traceAction(() => kaydir(tester, n: 6),
          reportKey: 'akilli_duzen_kaydirma');
      await kapat(tester);
    });

    await bolum(tester, 'klasor_galeri', () async {
      await ac(tester, const BrowserScreen(path: '$_veri/klasor_5000'));
      await binding.traceAction(() => kaydir(tester),
          reportKey: 'klasor_5000_kaydirma');
      await kapat(tester);

      await ac(tester, const BrowserScreen(path: '$_veri/galeri_2000'));
      await binding.traceAction(() => kaydir(tester),
          reportKey: 'galeri_2000_kaydirma');
      await kapat(tester);
    });

    final fs = FileService();
    await bolum(tester, 'pdf_100', () async {
      await binding.traceAction(() async {
        final pdf = await fs.load('$_veri/belge_100.pdf');
        await ac(tester, EntryOpener.screenFor(pdf));
      }, reportKey: 'pdf_100_acilis');
      await binding.traceAction(() => kaydir(tester, n: 20),
          reportKey: 'pdf_100_kaydirma');
      await kapat(tester);
    });

    await bolum(tester, 'xlsx_100k', () async {
      await binding.traceAction(() async {
        final xlsx = await fs.load('$_veri/tablo_100k.xlsx');
        await ac(tester, EntryOpener.screenFor(xlsx));
        await bekle(tester, 4000); // izolatta ayrıştırma
      }, reportKey: 'xlsx_100k_acilis');
      await binding.traceAction(() => kaydir(tester, n: 20),
          reportKey: 'xlsx_100k_kaydirma');
      await kapat(tester);
    });

    // T1: ana ekran "Son dosyalar" şeridinin sekmeleri (Son dosyalar /
    // Geçmiş / Yeniler, U3). Dosyalar açıldıktan SONRA — geçmiş dolu olsun.
    await bolum(tester, 'ana_sekmeler', () async {
      final sekmeler = [
        for (final m in ['opened', 'fresh', 'auto'])
          find.byKey(ValueKey('recent-strip-tab-$m')),
      ];
      if (await anaEkranda(tester, 'ana_sekmeler',
              find.byKey(const ValueKey('recent-strip-tab-opened'),
                  skipOffstage: false)) ==
          null) {
        return;
      }
      await binding.traceAction(() async {
        for (var tur = 0; tur < 2; tur++) {
          for (final s in sekmeler) {
            if (s.evaluate().isEmpty) continue;
            await tester.tap(s);
            await bekle(tester, 700);
          }
        }
      }, reportKey: 'ana_sekmeler');
    });

    // P12 (KALANLAR B3.3a / K23): 10 bin × 20 — kullanıcının yolu
    // (`EntryOpener.open`: yükleme + ekran), dokunuştan ilk hücre karesine
    // kadar. Süre logcat'e `OFIS_PERF faz=acilis_…` (ab_karar.py okur).
    const x20 = '$_veri/tablo_10k_x20.xlsx';
    await bolum(tester, 'xlsx_10k_x20', () async {
      if (!File(x20).existsSync()) {
        // ignore: avoid_print
        print('PERF xlsx_10k_x20: dosya yok, atlandı');
        return;
      }
      final sw = Stopwatch();
      await binding.traceAction(() async {
        sw.start();
        // Rota kapanınca biter; beklenmez.
        unawaited(EntryOpener.open(navigatorKey.currentContext!, x20));
        while (find.byType(SheetCell).evaluate().isEmpty &&
            sw.elapsed < const Duration(seconds: 40)) {
          await bekle(tester, 16);
        }
        sw.stop();
        await bekle(tester, 500);
      }, reportKey: 'xlsx_10k_x20_acilis');
      // ignore: avoid_print
      print('OFIS_PERF faz=acilis_xlsx_10k_x20 ms=${sw.elapsedMilliseconds}');
      await binding.traceAction(() => kaydir(tester, n: 20),
          reportKey: 'xlsx_10k_x20_kaydirma');
      await kapat(tester);
    });

    // H0.2: büyük PDF aç + 50 sayfa hızlı kaydır. Sayfa sayısı
    // denetleyiciden; fırlatma sayısı tavanlı (bitmezse kaç sayfa gidildi
    // logda).
    await bolum(tester, 'pdf_buyuk', () async {
      if (!File(_buyukPdf).existsSync()) {
        // ignore: avoid_print
        print('PERF pdf_buyuk: dosya yok, atlandı');
        return;
      }
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
    });

    // P14 — Word (Faz 37 + KALANLAR B3.3d) ve Slayt (Faz 38). Veri
    // `make_test_tree.py` (word_300.docx, slayt_300.pptx); yoksa atlanır.
    // Pro bayrağı kapalı (`_pro0`) / açık (`_pro1`) = Faz 37/38 öncesi/sonrası
    // arayüz (anayasa k.9) — aynı derlemede karşılaştırma.
    final prefs = await SharedPreferences.getInstance();
    const docx = '$_veri/word_300.docx';
    await bolum(tester, 'word_300', () async {
      if (!File(docx).existsSync()) {
        // ignore: avoid_print
        print('PERF word_300: dosya yok, atlandı');
        return;
      }
      // Sayfa görünümü (hybrid composition WebView) — B3.3d şüphelisi.
      await binding.traceAction(() async {
        await ac(tester, EntryOpener.screenFor(await fs.load(docx)));
        await bekle(tester, 6000); // docx-preview 300 sayfayı dizer
      }, reportKey: 'word_300_acilis');
      // ⋮ menüsü 5 kez aç/kapat: WebView üstüne açılan katman. Kaydırmadan
      // ÖNCE (okuma kipi kaydırınca üst çubuğu gizler); yalnız menü açıldıysa
      // pop — yoksa Word ekranı kapanırdı.
      final more = find.byKey(const ValueKey('editor-more'));
      final menu = find.byWidgetPredicate((w) => w is PopupMenuItem);
      await binding.traceAction(() async {
        for (var i = 0; i < 5 && more.evaluate().isNotEmpty; i++) {
          await tester.tap(more);
          await bekle(tester, 600);
          if (menu.evaluate().isEmpty) break;
          navigatorKey.currentState!.pop();
          await bekle(tester, 600);
        }
      }, reportKey: 'word_300_menu');
      await binding.traceAction(() => kaydir(tester),
          reportKey: 'word_300_kaydirma');
      await binding.traceAction(() => kapat(tester),
          reportKey: 'word_300_kapanis');

      // Mobil görünüm editörü (Faz 37 pro araçlarının yüzeyi).
      for (final pro in [false, true]) {
        await prefs.setBool('word_pro_v1', pro);
        final k = pro ? 'pro1' : 'pro0';
        await binding.traceAction(() async {
          await ac(tester,
              const WordMobileEditorScreen(path: docx, name: 'word_300'));
          await bekle(tester, 3000);
        }, reportKey: 'word_mobil_acilis_$k');
        await binding.traceAction(() => kaydir(tester),
            reportKey: 'word_mobil_kaydirma_$k');
        await kapat(tester);
      }
    });
    await prefs.remove('word_pro_v1');

    const pptx = '$_veri/slayt_300.pptx';
    await bolum(tester, 'slayt_300', () async {
      if (!File(pptx).existsSync()) {
        // ignore: avoid_print
        print('PERF slayt_300: dosya yok, atlandı');
        return;
      }
      for (final pro in [false, true]) {
        await prefs.setBool('slides_pro_v1', pro);
        final k = pro ? 'pro1' : 'pro0';
        await binding.traceAction(() async {
          await ac(tester, EntryOpener.screenFor(await fs.load(pptx)));
          await bekle(tester, 3000);
        }, reportKey: 'slayt_300_acilis_$k');
        await binding.traceAction(() => kaydir(tester, n: 20),
            reportKey: 'slayt_300_kaydirma_$k');
        await binding.traceAction(() => kapat(tester),
            reportKey: 'slayt_300_kapanis_$k');
      }
    });
    await prefs.remove('slides_pro_v1');

    // B13 m.1: dosya satırına dokunuştan (kullanıcının yolu, `EntryOpener`)
    // ilk okunur kareye süre + açılış/kapanış geçişinin kareleri. Süre
    // logcat'e `OFIS_PERF faz=acilis_gecis_<tür>`. "Okunur": Excel hücresi ya
    // da ilk sayfa önizlemesi · Slayt önizleme/iskelet bitti · Word iskelet
    // bitti (WebView içi çizim görülemez) · PDF denetleyicisi hazır.
    await bolum(tester, 'acilis_gecis', () async {
      await ac(tester, const BrowserScreen(path: _veri));
      // Dikey dosya listesi (üstteki yol şeridi de bir Scrollable).
      final liste = find.descendant(
          of: find.byType(BrowserScreen),
          matching: find.byWidgetPredicate((w) =>
              w is Scrollable && w.axisDirection == AxisDirection.down));
      bool iskeletYok() => find.byType(AppSkeleton).evaluate().isEmpty;
      final turler = <String, (String, bool Function())>{
        // Listedeki sırayla (aşağı kaydırarak bulunur).
        'pdf': (
          'belge_100',
          () {
            final v = find.byType(PdfViewer);
            return v.evaluate().isNotEmpty &&
                (tester.widget<PdfViewer>(v.first).controller?.isReady ??
                    false);
          }
        ),
        'pptx': (
          'slayt_300',
          () =>
              find.byType(SlidesEditorScreen).evaluate().isNotEmpty &&
              iskeletYok()
        ),
        'xlsx': (
          'tablo_10k_x20',
          () =>
              find.byType(SheetCell).evaluate().isNotEmpty ||
              find.byType(OfficeLoadingPreview).evaluate().isNotEmpty
        ),
        'docx': (
          'word_300',
          () =>
              find.byType(WordEditorScreen).evaluate().isNotEmpty &&
              iskeletYok()
        ),
      };
      for (final MapEntry(key: tur, value: (ad, okunur)) in turler.entries) {
        final satir = find.textContaining(ad);
        if (satir.evaluate().isEmpty && liste.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(satir, 300,
              scrollable: liste.first, maxScrolls: 10);
        }
        await tester.ensureVisible(satir.first);
        await bekle(tester, 400);
        final sw = Stopwatch();
        await binding.traceAction(() async {
          sw.start();
          await tester.tap(satir.first);
          while (!okunur() && sw.elapsed < const Duration(seconds: 40)) {
            await bekle(tester, 16);
          }
          sw.stop();
          await bekle(tester, 600);
        }, reportKey: 'gecis_${tur}_acilis');
        // ignore: avoid_print
        print('OFIS_PERF faz=acilis_gecis_$tur ms=${sw.elapsedMilliseconds}');
        await binding.traceAction(() => kapat(tester),
            reportKey: 'gecis_${tur}_kapanis');
      }
      await kapat(tester);
    });

    // B3.3b: aynı kaydırmalar anlamsal ağaç KAPALI (cihazda erişilebilirlik
    // hizmeti açıksa motor yine açar — o koşu `_sk`yi açık ölçer).
    anlam.dispose();
    await bekle(tester, 500);
    await bolum(tester, 'klasor_galeri_sk', () async {
      await ac(tester, const BrowserScreen(path: '$_veri/klasor_5000'));
      await binding.traceAction(() => kaydir(tester),
          reportKey: 'klasor_5000_kaydirma_sk');
      await kapat(tester);
      await ac(tester, const BrowserScreen(path: '$_veri/galeri_2000'));
      await binding.traceAction(() => kaydir(tester),
          reportKey: 'galeri_2000_kaydirma_sk');
      await kapat(tester);
    });
  }, semanticsEnabled: false, timeout: const Timeout(Duration(minutes: 25)));
}
