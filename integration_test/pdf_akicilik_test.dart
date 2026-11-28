import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/core/app_navigator.dart';
import 'package:dosya_okuyucu/main.dart' as app;
import 'package:dosya_okuyucu/services/file_service.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/widgets/pdf_inset_scroll_thumb.dart';
import 'package:dosya_okuyucu/widgets/whats_new.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// **PDF tam akıcılık ölçümü** (2026-11-28): PDF'in tüm yüzeyleri — açılış (küçük +
/// 320 sayfa/66 MB), sayfa geçişi, içindekiler, yavaş/hızlı/yakınlaştırılmış
/// kaydırma, tutamaç sürükleme, düzenleme kipi, metin yazma, kalem/silgi.
/// Her yüzey ayrı `traceAction` (`pa_*`). Veri: `python tool/make_pdf_akicilik.py`
/// (belge_320.pdf) + `make_test_tree.py` (belge_100.pdf) → OLCUM_VERISI klasörüne.
/// Koşu: `bash tool/pdf_akicilik.sh` (`perf_driver.dart` ile aynı sürücü).
const _veri = String.fromEnvironment('OLCUM_VERISI',
    defaultValue:
        '/sdcard/Android/data/com.dosyaokuyucu.dosya_okuyucu/files/olcum');
const _yalniz = String.fromEnvironment('PA_SENARYO');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> bekle(WidgetTester t, int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await t.pump();
  }

  void log(String s) => print('PDFAKICI $s'); // ignore: avoid_print

  Future<void> bolum(
      WidgetTester t, String ad, Future<void> Function() fn) async {
    if (_yalniz.isNotEmpty && !_yalniz.split(',').contains(ad)) return;
    try {
      await fn();
    } catch (e, st) {
      log('$ad: HATA, atlandı — $e — ${st.toString().split('\n').take(5).join(' | ')}');
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      await bekle(t, 800);
    }
  }

  final fs = FileService();
  Future<PdfViewerController?> ac(WidgetTester t, String yol, String anahtar) async {
    await binding.traceAction(() async {
      final pdf = await fs.load(yol);
      navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => EntryOpener.screenFor(pdf)));
      await bekle(t, 1500);
      for (var i = 0; i < 100; i++) {
        final v = find.byType(PdfViewer);
        if (v.evaluate().isNotEmpty &&
            (t.widget<PdfViewer>(v.first).controller?.isReady ?? false)) {
          break;
        }
        await bekle(t, 100);
      }
      await bekle(t, 2500); // ilk sayfa bitmap'i
    }, reportKey: anahtar);
    final v = find.byType(PdfViewer);
    return v.evaluate().isEmpty ? null : t.widget<PdfViewer>(v.first).controller;
  }

  Future<void> kapat(WidgetTester t) async {
    navigatorKey.currentState!.popUntil((r) => r.isFirst);
    await bekle(t, 1000);
  }

  Offset orta(WidgetTester t) {
    final s = t.view.physicalSize / t.view.devicePixelRatio;
    return Offset(s.width / 2, s.height * 0.55);
  }

  /// Hızlı fırlatma (mevcut senaryolarla aynı hareket).
  Future<void> fling(WidgetTester t, {int n = 12, double dy = -700}) async {
    final s = t.view.physicalSize / t.view.devicePixelRatio;
    final from = Offset(s.width / 2, s.height * 0.7);
    for (var i = 0; i < n; i++) {
      await t.flingFrom(from, Offset(0, dy), 2500);
      await bekle(t, 450);
    }
  }

  /// Yavaş sürükleme: parmak bırakmadan ~60 px/s, 16 ms'de bir kare.
  Future<void> yavas(WidgetTester t, {int adim = 150, double px = -2}) async {
    final g = await t.startGesture(orta(t));
    for (var i = 0; i < adim; i++) {
      await g.moveBy(Offset(0, px));
      await bekle(t, 16);
    }
    await g.up();
    await bekle(t, 500);
  }

  Future<void> sikistir(WidgetTester t, {bool ac = true}) async {
    final c = orta(t);
    final a = await t.startGesture(c + const Offset(-40, 0), pointer: 11);
    final b = await t.startGesture(c + const Offset(40, 0), pointer: 12);
    for (var i = 1; i <= 25; i++) {
      final d = ac ? 8.0 * i : -8.0 * i;
      await a.moveBy(Offset(ac ? -8 : 8, 0));
      await b.moveBy(Offset(ac ? 8 : -8, 0));
      await bekle(t, 16);
      if (d > 1e9) break;
    }
    await a.up();
    await b.up();
    await bekle(t, 800);
  }

  Finder tip(String m) => find.byTooltip(m);

  /// Üst/alt çubuk gizliyse (ekran dışına kayık) sayfaya dokunup gösterir.
  Future<void> cubuk(WidgetTester t, Finder f) async {
    final s = t.view.physicalSize / t.view.devicePixelRatio;
    bool gor() {
      if (f.evaluate().isEmpty) return false;
      final c = t.getCenter(f.first);
      return c.dx >= 0 && c.dy >= 0 && c.dx <= s.width && c.dy <= s.height;
    }
    for (var i = 0; i < 3 && !gor(); i++) {
      await t.tapAt(Offset(s.width * 0.5, s.height * 0.5));
      await bekle(t, 800);
    }
  }

  /// Tanı: ekrandaki metin ve ipuçları (düğme bulunamazsa).
  void tani(WidgetTester t, String ad) {
    final m = <String>{};
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      if (w.data != null && w.data!.length < 30) m.add(w.data!);
    }
    for (final w in t.widgetList<IconButton>(find.byType(IconButton))) {
      if (w.tooltip != null) m.add('tip:${w.tooltip}');
    }
    log('$ad ekran: ${m.take(60).join(' | ')}');
  }

  testWidgets('PDF tam akıcılık', (tester) async {
    await WhatsNew.markSeen();
    tester.ensureSemantics(); // mevcut senaryolarla aynı (TalkBack açık)
    await app.main();
    await bekle(tester, 3000);

    // 1) Açılış: küçük + büyük
    await bolum(tester, 'acilis', () async {
      await ac(tester, '$_veri/belge_100.pdf', 'pa_acilis_kucuk');
      await kapat(tester);
      await ac(tester, '$_veri/belge_320.pdf', 'pa_acilis_buyuk');
      await kapat(tester);
    });

    // 2-3) Büyük belgede geçiş + kaydırma
    await bolum(tester, 'gezinti', () async {
      final ctl = await ac(tester, '$_veri/belge_320.pdf', 'pa_acilis_buyuk2');
      if (ctl == null) throw 'denetleyici yok';
      log('sayfa sayisi ${ctl.pageCount}');

      await binding.traceAction(() async {
        for (final p in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]) {
          await ctl.goToPage(pageNumber: p, duration: const Duration(milliseconds: 250));
          await bekle(tester, 400);
        }
      }, reportKey: 'pa_sayfa_gecis_yakin');
      await binding.traceAction(() async {
        for (final p in [150, 20, 300, 5, 220]) {
          await ctl.goToPage(pageNumber: p, duration: const Duration(milliseconds: 250));
          await bekle(tester, 1500); // uzak atlama: yeni sayfalar çiziliyor
        }
      }, reportKey: 'pa_sayfa_gecis_uzak');

      await binding.traceAction(() async {
        final t = tip('İçindekiler');
        for (final b in [10, 20, 30, 5, 25]) {
          await cubuk(tester, t);
          if (t.evaluate().isEmpty) tani(tester, 'icindekiler');
          await tester.tap(t.first);
          await bekle(tester, 900);
          tani(tester, 'toc_sayfa');
          final liste = find.byType(ListTile);
          if (liste.evaluate().isEmpty) throw 'içindekiler satırı yok';
          final lv = find.ancestor(of: liste.first, matching: find.byType(Scrollable));
          if (lv.evaluate().isNotEmpty) {
            await tester.drag(lv.first, Offset(0, -b * 30.0));
            await bekle(tester, 500);
          }
          await tester.tap(find.byType(ListTile).at(1));
          await bekle(tester, 1800);
        }
      }, reportKey: 'pa_icindekiler_atla');

      await ctl.goToPage(pageNumber: 20, duration: Duration.zero);
      await bekle(tester, 1500);
      await binding.traceAction(() => yavas(tester, adim: 200),
          reportKey: 'pa_kaydir_yavas');
      await binding.traceAction(() => fling(tester, n: 15),
          reportKey: 'pa_kaydir_fling');
      await binding.traceAction(() => fling(tester, n: 6, dy: 700),
          reportKey: 'pa_kaydir_fling_geri');

      // Tutamaç: sağ kenardaki küçük sürükleme kapı
      await bekle(tester, 600);
      final th = find.byType(PdfInsetScrollThumb);
      if (th.evaluate().isEmpty) {
        log('pa_tutamac: tutamaç bulunamadı');
      } else {
        final r = tester.getRect(th.first);
        final frac = ((ctl.value.y.abs()) /
                (ctl.documentSize.height - ctl.visibleRect.height))
            .clamp(0.0, 1.0);
        final pos = Offset(r.right - 13, r.top + 60 + frac * (r.height - 160));
        await binding.traceAction(() async {
          final g = await tester.startGesture(pos);
          await bekle(tester, 150);
          // yukarı-aşağı 3 uzun gezinti
          for (var tur = 0; tur < 3; tur++) {
            for (var i = 0; i < 40; i++) {
              await g.moveBy(Offset(0, tur.isEven ? 12 : -12));
              await bekle(tester, 16);
            }
          }
          await g.up();
          await bekle(tester, 800);
        }, reportKey: 'pa_tutamac_surukle');
        log('pa_tutamac sayfa ${ctl.pageNumber}');
      }

      // Yakınlaştırılmış kaydırma
      await ctl.goToPage(pageNumber: 40, duration: Duration.zero);
      await bekle(tester, 1500);
      await binding.traceAction(() => sikistir(tester), reportKey: 'pa_yakinlastir');
      log('zoom ${ctl.currentZoom}');
      await binding.traceAction(() async {
        await yavas(tester, adim: 100);
        await fling(tester, n: 8);
        final g = await tester.startGesture(orta(tester));
        for (var i = 0; i < 40; i++) {
          await g.moveBy(const Offset(-10, 0));
          await bekle(tester, 16);
        }
        await g.up();
        await bekle(tester, 600);
      }, reportKey: 'pa_kaydir_zoomlu');
      await kapat(tester);
    });

    // 4-5) Düzenleme: giriş, yazı, kalem, silgi (küçük belge)
    await bolum(tester, 'duzenle', () async {
      await ac(tester, '$_veri/belge_100.pdf', 'pa_acilis_duzenle');
      final d = find.text('Düzenle');
      await cubuk(tester, d);
      if (d.evaluate().isEmpty) {
        tani(tester, 'duzenle');
        throw 'Düzenle düğmesi yok';
      }
      await binding.traceAction(() async {
        await tester.tap(d.first);
        for (var i = 0; i < 60 && find.text('Düzenleme kipi').evaluate().isEmpty; i++) {
          await bekle(tester, 100);
        }
        await bekle(tester, 1500);
      }, reportKey: 'pa_duzenle_giris');
      if (find.text('Düzenleme kipi').evaluate().isEmpty) {
        tani(tester, 'duzenle_giris');
        throw 'düzenleme kipine girilemedi';
      }

      // Metin bloğu: ızgarada dokun, "Düzenle" çipi çıkana dek
      final s = tester.view.physicalSize / tester.view.devicePixelRatio;
      var bulundu = false;
      await bekle(tester, 3000); // blok çıkarımı (ipucu da kapansın)
      for (final fx in [0.3, 0.45, 0.2]) {
        for (var y = s.height * 0.15; y < s.height * 0.8 && !bulundu; y += 20) {
          await tester.tapAt(Offset(s.width * fx, y));
          await bekle(tester, 450);
          bulundu = find.byKey(const ValueKey('pse-chip-edit')).evaluate().isNotEmpty;
        }
        if (bulundu) break;
      }
      log('metin blogu bulundu=$bulundu');
      if (!bulundu) tani(tester, 'metin_blogu');
      if (bulundu) {
        await binding.traceAction(() async {
          await tester.tap(find.byKey(const ValueKey('pse-chip-edit')));
          await bekle(tester, 1200); // satır içi düzenleyici + klavye
        }, reportKey: 'pa_yazi_ac');
        final ef = find.byType(EditableText);
        if (ef.evaluate().isEmpty) {
          log('pa_yazi: EditableText yok');
        } else {
          await binding.traceAction(() async {
            var m = '';
            for (final ch in 'Akicilik olcum yazisi denemesi 123'.split('')) {
              m += ch;
              await tester.enterText(ef.last, m);
              await bekle(tester, 70);
            }
            await bekle(tester, 600);
          }, reportKey: 'pa_yazi_yaz');
        }
        // düzenleyiciyi kapat: boş alana dokun
        await tester.tapAt(Offset(s.width * 0.9, s.height * 0.9));
        await bekle(tester, 600);
      }

      // Kalem + silgi
      final isaret = find.text('İşaretle');
      if (!bulundu) {
        // blok yok: giriş yolunu yine de ölç — "Metin ekle" ile yeni metin kutusu
        final ekle = find.text('Metin ekle');
        if (ekle.evaluate().isNotEmpty) {
          await binding.traceAction(() async {
            await tester.tap(ekle.first);
            await bekle(tester, 600);
            await tester.tapAt(Offset(s.width * 0.4, s.height * 0.5));
            await bekle(tester, 1500);
          }, reportKey: 'pa_yazi_ac');
          final ef = find.byType(EditableText);
          if (ef.evaluate().isNotEmpty) {
            await binding.traceAction(() async {
              var m = '';
              for (final ch in 'Akicilik olcum yazisi denemesi 123'.split('')) {
                m += ch;
                await tester.enterText(ef.last, m);
                await bekle(tester, 70);
              }
              await bekle(tester, 600);
            }, reportKey: 'pa_yazi_yaz');
          } else {
            tani(tester, 'metin_ekle');
          }
        }
      }
      if (isaret.evaluate().isNotEmpty) {
        await tester.tap(isaret.first);
        await bekle(tester, 800);
      }
      Future<void> cizgi(double y0, {int adim = 60}) async {
        final g = await tester.startGesture(Offset(s.width * 0.2, y0));
        for (var i = 0; i < adim; i++) {
          await g.moveBy(Offset(s.width * 0.6 / adim, 18 * (i.isEven ? 1 : -1)));
          await bekle(tester, 8);
        }
        await g.up();
        await bekle(tester, 200);
      }
      var kalem = find.byKey(const ValueKey('pse-mk-ink'));
      if (kalem.evaluate().isEmpty && isaret.evaluate().isNotEmpty) {
        await tester.tap(isaret.first); // yazı düzenleyici ilk dokunuşu yutmuş olabilir
        await bekle(tester, 1200);
        kalem = find.byKey(const ValueKey('pse-mk-ink'));
      }
      if (kalem.evaluate().isEmpty) {
        tani(tester, 'kalem');
        log('pa_kalem: kalem düğmesi yok');
      } else {
        await tester.tap(kalem.first);
        await bekle(tester, 600);
        await binding.traceAction(() async {
          for (var k = 0; k < 6; k++) {
            await cizgi(s.height * (0.3 + 0.07 * k));
          }
        }, reportKey: 'pa_kalem_ciz');
        final silgi = find.byKey(const ValueKey('pse-mk-eraser'));
        if (silgi.evaluate().isNotEmpty) {
          await tester.tap(silgi.first);
          await bekle(tester, 600);
          await binding.traceAction(() async {
            for (var k = 0; k < 6; k++) {
              await cizgi(s.height * (0.3 + 0.07 * k), adim: 40);
            }
          }, reportKey: 'pa_silgi');
        } else {
          log('pa_silgi: silgi düğmesi yok');
        }
      }
      // çık: kaydetmeden (özgün dosya bozulmaz)
      final cik = find.byKey(const ValueKey('pse-exit'));
      if (cik.evaluate().isNotEmpty) {
        await tester.tap(cik.first);
        await bekle(tester, 1000);
        for (final m in ['Kaydetme', 'Vazgeç', 'Çık', 'At']) {
          final b = find.text(m);
          if (b.evaluate().isNotEmpty) {
            await tester.tap(b.first);
            await bekle(tester, 800);
            break;
          }
        }
      }
      await kapat(tester);
    });
    log('bitti ${File('$_veri/belge_320.pdf').existsSync()}');
  });
}
