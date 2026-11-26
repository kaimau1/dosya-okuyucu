import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/smart_learn.dart';
import 'package:dosya_okuyucu/services/fm/smart_local_rules.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort.dart';
import 'package:dosya_okuyucu/services/fm/smart_sort_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmartLearn.forgetAll();
  });

  FsEntry entry(String path) => FsEntry(
    path: path,
    name: path.split('/').last,
    isDir: false,
    sizeBytes: 1024,
    modifiedMs: 1700000000000,
  );

  group('SmartLocalRules (0 kredi yerel sınıflandırma)', () {
    test(
      'Türkçe katlama ile fatura, banka, resmi, sağlık, kimlik ve APK tanır',
      () {
        final inv = SmartLocalRules.classify(
          entry('/Download/Fatura_İGDAŞ_Doğalgaz.pdf'),
        );
        expect(inv, isNotNull);
        expect(inv!.cat, 'invoice');
        expect(inv.sub, 'natural_gas');
        expect(inv.provider, 'igdas');
        expect(inv.conf, greaterThanOrEqualTo(0.85));

        final bnk = SmartLocalRules.classify(
          entry('/Download/Ziraat_EFT_Dekont_2026.pdf'),
        );
        expect(bnk, isNotNull);
        expect(bnk!.cat, 'bank');
        expect(bnk.sub, 'transfer');
        expect(bnk.bank, 'ziraat');

        final off = SmartSort.classifyLocal(
          entry('/Download/edevlet_ikametgah_belgesi.pdf'),
        );
        expect(off, isNotNull);
        expect(off!.cat, 'official');
        expect(off.sub, 'e_government');

        final hlt = SmartLocalRules.classify(
          entry('/Download/Hastane_Kan_Tahlil_2026.pdf'),
        );
        expect(hlt, isNotNull);
        expect(hlt!.cat, 'health');
        expect(hlt.sub, 'lab_result');

        final pkg = SmartLocalRules.classify(entry('/Download/notlar_v2.apk'));
        expect(pkg, isNotNull);
        expect(pkg!.cat, SmartTaxonomy.package);
        expect(pkg.sub, 'installer');

        final shot = SmartLocalRules.classify(
          entry('/Pictures/Screenshots/Screenshot_20261124_com.foo.png'),
        );
        expect(shot, isNotNull);
        expect(shot!.cat, 'screenshot');
      },
    );

    test('belirsiz dosya adlarında null döner ve işi AI kararına bırakır', () {
      expect(
        SmartLocalRules.classify(entry('/Download/belge_4821.pdf')),
        isNull,
      );
      expect(
        SmartLocalRules.classify(entry('/DCIM/IMG_20261124_120000.jpg')),
        isNull,
      );
    });

    test('SmartLearn düzeltmesini yerel kural çıktısına uygular', () async {
      const path1 = '/Docs/Sirket/musteri_proje_fatura_taslak.pdf';
      const path2 = '/Docs/Sirket/musteri_proje_fatura_ekim.pdf';
      // Tek düzeltmenin benzerliği (~0,71) oy eşiğinin (0,85) altında:
      // SmartLearn bilinçli olarak en az iki benzer düzeltme ister.
      await SmartLearn.record(path1, 'invoice', 'work');
      await SmartLearn.record(
          '/Docs/Sirket/musteri_proje_fatura_kasim.pdf', 'invoice', 'work');

      final adapted = SmartLocalRules.classify(entry(path2));
      expect(adapted, isNotNull);
      expect(adapted!.cat, 'work');
      expect(adapted.conf, greaterThanOrEqualTo(0.90));
    });

    test('runLocalOnly API anahtarı olmadan yerel kuralları kaydeder', () async {
      final dir = Directory.systemTemp.createTempSync('smart_local_only');
      final downloadDir = Directory('${dir.path}/Download')
        ..createSync(recursive: true);
      final root0 = FmEnv.primaryRoot;
      FmEnv.primaryRoot = dir.path;
      SmartSort.debugReset();
      try {
        final invFile = File('${downloadDir.path}/Fatura_IGDAS_2026.pdf')
          ..writeAsStringSync('pdf');
        final unkFile = File('${downloadDir.path}/rastgele_belge_999.pdf')
          ..writeAsStringSync('pdf');

        final res =
            await SmartSort.runLocalOnly(scope: const AiScope(settings: AiScopeSettings()));
        expect(res.processed, 1);
        expect(res.reused, 1);
        expect(SmartSort.of(invFile.path)?.cat, 'invoice');
        expect(SmartSort.of(unkFile.path), isNull);
      } finally {
        FmEnv.primaryRoot = root0;
        SmartSort.debugReset();
        dir.deleteSync(recursive: true);
      }
    });
  });
}
