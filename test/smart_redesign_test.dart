import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fm_type.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:dosya_okuyucu/services/fm/ai_meaning_search.dart';
import 'package:dosya_okuyucu/services/fm/ai_tagger.dart';
import 'package:dosya_okuyucu/services/fm/chat_junk.dart';
import 'package:dosya_okuyucu/services/fm/collection_insights.dart';
import 'package:dosya_okuyucu/services/fm/fs_events.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart';
import 'package:dosya_okuyucu/services/fm/trash_service.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_list_controls.dart';
import 'package:dosya_okuyucu/widgets/fm/smart_inbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// 2026-10-23 turu: çöp kutusu toplu silme, sohbet temizliği canlı budama,
/// AI etiket/anlam ayrıştırıcıları, liste özeti, akıllı bildirim alanı ve
/// liste denetim şeridi.
void main() {
  const day = Duration.millisecondsPerDay;
  final now = DateTime(2026, 10, 23).millisecondsSinceEpoch;

  FsEntry e(String path, {int size = 1000, int? at}) => FsEntry(
        path: path,
        name: p.basename(path),
        isDir: false,
        sizeBytes: size,
        modifiedMs: at ?? now,
      );

  group('çöp kutusu (dolu çöpte donma)', () {
    late Directory tmp;
    late Directory volume;
    late TrashService trash;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('smart_trash');
      volume = Directory(p.join(tmp.path, 'birim'))..createSync();
      trash = TrashService(
          volumeRoots: [volume.path], fallbackRoot: p.join(tmp.path, 'app'));
    });
    tearDown(() => removeTempDir(tmp));

    test('boşaltma kayıtları toplu düşürür, değişiklik sinyali TEK', () async {
      final paths = <String>[];
      for (var i = 0; i < 30; i++) {
        final f = File(p.join(volume.path, 'd', 'f$i.txt'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('x' * i);
        paths.add(f.path);
      }
      await trash.moveToTrash(paths);
      expect(await trash.list(), hasLength(30));
      var signals = 0;
      void count() => signals++;
      FsEvents.version.addListener(count);
      try {
        final r = await trash.empty();
        expect(r.succeeded, 30);
        expect(signals, 1);
      } finally {
        FsEvents.version.removeListener(count);
      }
      expect(await trash.list(), isEmpty);
    });

    test('dışarıdan silinen dosyanın kaydı listede görünmez', () async {
      final f = File(p.join(volume.path, 'a.txt'))..writeAsStringSync('a');
      await trash.moveToTrash([f.path]);
      final item = (await trash.list()).single;
      File(item.storedPath).deleteSync();
      expect(await trash.list(), isEmpty);
    });
  });

  group('sohbet temizliği canlı budama', () {
    test('silinen dosya kovadan ve toplamdan düşer, boş kova kalkar', () {
      final a = e('/s/WhatsApp/a.jpg', size: 100);
      final b = e('/s/WhatsApp/b.jpg', size: 200);
      final c = e('/s/WhatsApp/c.webp', size: 50);
      final report = ChatJunkReport(
        buckets: [
          ChatJunkBucket(ChatJunkKind.duplicate, [a, b]),
          ChatJunkBucket(ChatJunkKind.sticker, [c]),
          // Aynı dosya iki kovada: toplamdan bir kez düşer.
          ChatJunkBucket(ChatJunkKind.stale, [a]),
        ],
        scannedFiles: 10,
        scannedBytes: 1000,
      );
      final next = report.keepOnly((path) => path == b.path);
      expect(next.buckets.map((x) => x.kind), [ChatJunkKind.duplicate]);
      expect(next.junkFiles, 1);
      expect(next.scannedFiles, 8);
      expect(next.scannedBytes, 850);
      expect(identical(report.keepOnly((_) => true), report), isTrue);
    });
  });

  group('AI etiketleme', () {
    test('yanıt etikete çevrilir, katlanarak tekilleşir, i → İ', () {
      final items = [e('/s/x.pdf'), e('/s/y.pdf'), e('/s/z.pdf')];
      final map = AiTagger.parse(
          '{"items":[{"i":0,"tags":["fatura","izin"]},'
          '{"i":1,"tags":["FATURA"]},{"i":9,"tags":["yok"]},'
          '{"i":2,"tags":[" "]}]}',
          items);
      expect(map.keys.toSet(), {'Fatura', 'İzin'});
      expect(map['Fatura'], {'/s/x.pdf', '/s/y.pdf'});
      expect(AiTagger.parse('bozuk', items), isEmpty);
    });

    test('istemde tam yol değil yalnız klasör ADI var', () {
      final prompt = AiTagger.promptFor([e('/storage/emulated/0/Gizli/Is/a.pdf')]);
      expect(prompt, contains('0|a.pdf|Is|'));
      expect(prompt, isNot(contains('/storage/emulated')));
    });
  });

  group('anlamla ara', () {
    test('plan: önce sorgunun kendi sözcükleri, tekrarsız, uzantılar noktasız',
        () {
      final plan = AiMeaningSearch.parse(
          '{"terms":["fatura","Elektrik","CK Boğaziçi","invoice"],'
          '"extensions":[".PDF","jpg"]}',
          'elektrik fatura');
      expect(plan.terms.take(2), ['elektrik', 'fatura']);
      expect(plan.terms, contains('CK Boğaziçi'));
      expect(plan.terms.where((t) => t.toLowerCase() == 'fatura'), hasLength(1));
      expect(plan.extensions, ['pdf', 'jpg']);
    });

    test('bozuk yanıtta sorgunun sözcüklerine düşer', () {
      expect(AiMeaningSearch.parse('???', 'kira sözleşmesi').terms,
          ['kira', 'sözleşmesi']);
    });
  });

  group('liste özeti', () {
    test('tür/kaynak/ay/eski/kopya sayımları', () {
      final files = [
        e('/s/Download/rapor.pdf', size: 3000, at: now - 400 * day),
        e('/s/Download/rapor (1).pdf', size: 3000, at: now - 400 * day),
        e('/s/WhatsApp/Media/b.docx', size: 500),
        e('/s/WhatsApp/Media/c.xlsx', size: 200, at: now - 40 * day),
      ];
      final ins = CollectionInsights.of(files,
          nowMs: now, tagsOf: (path) => path.endsWith('b.docx') ? {'İş'} : {});
      expect(ins.count, 4);
      expect(ins.bytes, 6700);
      expect(ins.byType.first.key, FmType.pdf);
      expect(ins.bySource.first.key, MediaBucket.download);
      expect(ins.byMonth.last.count, 1);
      expect(ins.stale, hasLength(2));
      expect(ins.copies.single.name, 'rapor (1).pdf');
      expect(ins.tagged, 1);
      expect(ins.topTags.single.key, 'İş');
      expect(ins.largest.first.sizeBytes, 3000);
    });
  });

  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: const [AppStrings.delegate],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('akıllı bildirim alanı', () {
    setUp(SmartInbox.resetForTest);

    testWidgets('boşken hiç çizilmez', (tester) async {
      await tester.pumpWidget(app(const SmartInbox()));
      expect(find.byKey(const ValueKey('smart-inbox')), findsNothing);
    });

    testWidgets('olay görünür, kapatılınca kalkar', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(app(SmartInbox(events: [
        InboxEvent(
          id: 'storage_90',
          icon: Icons.warning_amber_rounded,
          title: 'Bellek %92 dolu',
          subtitle: '20 GB boş',
          actionLabel: 'Yer aç',
          onTap: () => tapped++,
        ),
      ])));
      expect(find.text('Bellek %92 dolu'), findsOneWidget);
      await tester.tap(find.text('Yer aç'));
      expect(tapped, 1);
      await tester.tap(find.byTooltip(AppStrings.current.t('common.close')));
      await tester.pump();
      expect(find.byKey(const ValueKey('smart-inbox')), findsNothing);
    });

    testWidgets('bitmiş iş satırı ve kapatma', (tester) async {
      final job = JobQueue.instance.enqueue(
        id: 'inbox-test',
        title: 'Deneme işi',
        run: (h) async => h.report(detail: '3 dosya'),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && job.status.isActive; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpWidget(app(const SmartInbox()));
      expect(find.textContaining('3 dosya'), findsOneWidget);
      JobQueue.instance.dismiss(job.id);
      await tester.pump();
      expect(find.textContaining('3 dosya'), findsNothing);
    });
  });

  group('liste denetim şeridi', () {
    testWidgets('görünmeyen ölçütler kaldırılabilir çip, Temizle hepsini siler',
        (tester) async {
      var filter = FmFilter.none
          .withDateRange(FmDateRange.month)
          .toggleTag('Fatura')
          .withTypes({FmType.pdf});
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => app(FmListControls(
          sort: FmSort.date,
          descending: true,
          onSort: (_, __) {},
          filter: filter,
          onFilterChanged: (f) => setState(() => filter = f),
          onOpenFilter: () {},
          onTools: () {},
        )),
      ));
      // Tür çipi zaten tür satırında görünüyor → burada tekrar yazılmaz.
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(find.text('#Fatura'), findsOneWidget);
      expect(find.text(AppStrings.current.t('lc.filter_n', {'n': 3})),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lc-clear')));
      await tester.pump();
      expect(filter.isActive, isFalse);
      expect(find.byType(InputChip), findsNothing);
    });
  });

  test('çeviri: yeni metinler üç dilde dolu', () {
    for (final lang in AppLanguage.values) {
      final s = AppStrings(lang);
      for (final key in ['inbox.storage_full', 'ct.title', 'srch.meaning']) {
        expect(s.t(key, {'n': 1}), isNot(key));
      }
    }
  });
}
