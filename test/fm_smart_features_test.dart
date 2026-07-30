import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/media_bucket.dart';
import 'package:dosya_okuyucu/services/fm/auto_organize.dart';
import 'package:dosya_okuyucu/services/fm/batch_rename.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:dosya_okuyucu/services/fm/doc_classifier.dart';
import 'package:dosya_okuyucu/services/fm/duplicate_finder.dart';
import 'package:dosya_okuyucu/services/fm/file_ops.dart';
import 'package:dosya_okuyucu/services/fm/folder_lock.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/op_history.dart';
import 'package:dosya_okuyucu/services/fm/smart_query.dart';
import 'package:dosya_okuyucu/services/fm/storage_trend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yeni yeteneklerin **saf çekirdekleri**: akıllı arama çözümleyicisi, belge
/// sınıflandırma, otomatik düzenleme planı, temizlik önerileri, toplu
/// yeniden adlandırma, klasör kilidi, depolama eğilimi ve işlem geçmişi.
///
/// Bu katman dosya sistemine dokunmaz; "yanlış dosyayı önerdi/taşıdı/sildi"
/// sınıfı hataların yakalanacağı yer burasıdır.
void main() {
  final now = DateTime(2026, 7, 29, 12);

  FsEntry file(
    String path, {
    int size = 1000,
    DateTime? when,
    bool dir = false,
  }) =>
      FsEntry(
        path: path,
        name: path.split('/').last,
        isDir: dir,
        sizeBytes: size,
        modifiedMs: (when ?? now).millisecondsSinceEpoch,
      );

  group('akıllı arama', () {
    test('kategori + tarih + kaynak birlikte çözümlenir', () {
      final q = parseSmartQuery('geçen ay whatsapp videoları tatil', now: now);
      expect(q.category, FmCategory.video);
      expect(q.filter.dateRange, FmDateRange.month);
      expect(q.filter.buckets, {MediaBucket.whatsapp});
      // Anlaşılmayan sözcük ad aramasına kalır.
      expect(q.text, 'tatil');
      expect(q.hasStructure, isTrue);
    });

    test('"bu hafta pdf" → belge + uzantı + 7 gün, ad araması kalmaz', () {
      final q = parseSmartQuery('bu hafta pdf', now: now);
      expect(q.filter.dateRange, FmDateRange.week);
      expect(q.filter.extensions, {'pdf'});
      expect(q.category, FmCategory.document);
      expect(q.text, isEmpty);
    });

    test('yalın yıl o yılın tamamını kapsar', () {
      final q = parseSmartQuery('2024 fotoğrafları', now: now);
      expect(q.category, FmCategory.image);
      final window = q.filter.window(now: now);
      expect(DateTime.fromMillisecondsSinceEpoch(window.fromMs!).year, 2024);
      expect(DateTime.fromMillisecondsSinceEpoch(window.toMs!).year, 2024);
    });

    test('"büyük" ve "küçük" boyut ölçütüne çevrilir', () {
      expect(parseSmartQuery('büyük videolar', now: now).filter.sizeRange,
          FmSizeRange.large);
      expect(parseSmartQuery('küçük resimler', now: now).filter.sizeRange,
          FmSizeRange.tiny);
    });

    test('sıradan bir ad araması ölçüte dönüşmez', () {
      final q = parseSmartQuery('rapor2 toplanti notu', now: now);
      expect(q.category, isNull);
      expect(q.filter.isActive, isFalse);
      expect(q.text, contains('rapor2'));
    });

    test('AI JSON çıktısı hoşgörülü ayrıştırılır', () {
      const raw = '''
Tabii, işte:
```json
{"category":"video","dateRange":"week","sizeRange":"large",
 "buckets":["whatsapp"],"extensions":[".mp4"],"text":"tatil"}
```
''';
      final q = smartQueryFromJson(raw);
      expect(q, isNotNull);
      expect(q!.category, FmCategory.video);
      expect(q.filter.dateRange, FmDateRange.week);
      expect(q.filter.sizeRange, FmSizeRange.large);
      expect(q.filter.buckets, {MediaBucket.whatsapp});
      expect(q.filter.extensions, {'mp4'});
      expect(q.text, 'tatil');
    });

    test('bozuk AI çıktısı null döner (arama BOZULMAZ)', () {
      expect(smartQueryFromJson('özür dilerim, anlayamadım'), isNull);
      expect(smartQueryFromJson('{bozuk json'), isNull);
    });
  });

  group('belge sınıflandırma', () {
    test('fatura metni fatura olarak tanınır', () {
      final guess = classifyDocumentText(
          'ELEKTRİK FATURASI\nAbone No: 123\nTutar: 450 TL\nKDV dahil');
      expect(guess.type, DocClass.fatura);
      expect(guess.isConfident, isTrue);
      expect(guess.type.folder, 'Faturalar');
    });

    test('kimlik ve banka ayrışır', () {
      expect(
          classifyDocumentText('T.C. Kimlik No 123 Nüfus Cüzdanı seri no')
              .type,
          DocClass.kimlik);
      expect(
          classifyDocumentText('IBAN TR12 Hesap özeti bakiye EFT havale').type,
          DocClass.banka);
    });

    test('ekran görüntüsü dosya adından anlaşılır', () {
      final guess = classifyDocumentText('', fileName: 'Screenshot_2026.png');
      expect(guess.type, DocClass.ekranGoruntusu);
    });

    test('anahtar sözcük yoksa "diğer" ve güvensiz', () {
      final guess = classifyDocumentText('merhaba dünya');
      expect(guess.type, DocClass.diger);
      expect(guess.isConfident, isFalse);
    });
  });

  group('otomatik düzenleme planı', () {
    final files = [
      file('/depo/a.jpg'),
      file('/depo/b.mp4'),
      file('/depo/c.pdf'),
      file('/depo/Görüntüler/d.jpg'), // zaten yerinde
      file('/depo/klasor', dir: true),
    ];

    test('türe göre: klasör adları ve sayılar', () {
      final plan = planOrganize(files, OrganizeBy.type);
      expect(plan.fileCount, 3);
      expect(plan.folderCounts['Görüntüler'], 1);
      expect(plan.folderCounts['Videolar'], 1);
      expect(plan.folderCounts['Belgeler'], 1);
      // Zaten doğru klasörde olan taşınmaz, klasörler plana girmez.
      expect(plan.alreadyPlaced, 1);
      expect(plan.moves.any((m) => m.entry.isDir), isFalse);
    });

    test('tarihe göre klasör adı sıralanabilir biçimdedir', () {
      final plan = planOrganize(
          [file('/depo/x.jpg', when: DateTime(2026, 3, 4))], OrganizeBy.date);
      expect(plan.folderCounts.keys.single, '2026-03');
    });

    test('kaynağa göre WhatsApp ayrılır', () {
      final plan = planOrganize(
          [file('/depo/WhatsApp/Media/x.jpg')], OrganizeBy.source);
      expect(plan.folderCounts.keys.single, 'WhatsApp');
    });
  });

  group('temizlik önerileri', () {
    test('güvenli öneriler önce gelir, videolar varsayılan seçili DEĞİL', () {
      const index = StorageIndex(
        stats: {},
        byCategory: {
          FmCategory.video: [],
          FmCategory.apk: [],
        },
        largest: [],
        recent: [],
        totalFiles: 0,
        totalBytes: 0,
        skipped: 0,
      );
      final list = adviseCleanup(
        index: index,
        downloads: const [],
        duplicates: [
          DuplicateGroup(1000, [
            file('/a/x.jpg', when: DateTime(2026, 1, 1)),
            file('/b/x.jpg', when: DateTime(2026, 5, 1)),
          ]),
        ],
        trashBytes: 500,
        trashCount: 2,
        now: now,
      );
      expect(list.first.id, anyOf('trash', 'duplicates'));
      expect(list.every((s) => s.bytes >= 0), isTrue);

      final dups = list.firstWhere((s) => s.id == 'duplicates');
      // Her gruptan biri KALIR: 2 dosyadan yalnız 1'i öneriye girer.
      expect(dups.files.length, 1);
      // Korunan en eski olmalı → önerilen yeni olan.
      expect(dups.files.single.path, '/b/x.jpg');
      expect(dups.safeByDefault, isTrue);
    });

    test('eski indirilenler önerilir, tazeler önerilmez', () {
      final list = adviseCleanup(
        index: StorageIndex.empty,
        downloads: [
          file('/dl/eski.zip', when: DateTime(2025, 1, 1), size: 5000),
          file('/dl/yeni.zip', when: now, size: 5000),
        ],
        duplicates: const [],
        trashBytes: 0,
        trashCount: 0,
        now: now,
      );
      final stale = list.firstWhere((s) => s.id == 'stale_downloads');
      expect(stale.files.single.name, 'eski.zip');
      expect(stale.safeByDefault, isFalse);
    });
  });

  group('toplu yeniden adlandırma', () {
    test('kalıp + sıra numarası, uzantı korunur', () {
      final plan = planBatchRename(
        [file('/a/IMG_1.jpg'), file('/a/IMG_2.jpg')],
        pattern: 'Tatil-{n2}',
      );
      expect(plan.map((r) => r.newName), ['Tatil-01.jpg', 'Tatil-02.jpg']);
      expect(plan.every((r) => r.isValid), isTrue);
    });

    test('{ad} ve bul/değiştir birlikte çalışır', () {
      final plan = planBatchRename(
        [file('/a/tatil_kopya.jpg')],
        pattern: '{ad}-son',
        find: '_kopya',
        replace: '',
      );
      expect(plan.single.newName, 'tatil-son.jpg');
    });

    test('aynı klasörde çakışan ad sorunlu işaretlenir (atlanır)', () {
      final plan = planBatchRename(
        [file('/a/x.jpg'), file('/a/y.jpg')],
        pattern: 'aynı',
      );
      expect(plan.first.isValid, isTrue);
      expect(plan.last.isValid, isFalse);
      expect(plan.last.problem, contains('zaten üretildi'));
    });

    test('farklı klasörlerdeki aynı ad sorun DEĞİL', () {
      final plan = planBatchRename(
        [file('/a/x.jpg'), file('/b/y.jpg')],
        pattern: 'foto',
      );
      expect(plan.every((r) => r.isValid), isTrue);
    });

    test('yol ayracı temizlenir (başka klasöre yazma engellenir)', () {
      final plan = planBatchRename([file('/a/x.jpg')], pattern: '../../kok');
      expect(plan.single.newName, isNot(contains('/')));
    });
  });

  group('klasör kilidi', () {
    test('doğru PIN doğrulanır, yanlış reddedilir', () {
      final hash = FolderLock.hashPin('1234');
      expect(FolderLock.verify('1234', hash), isTrue);
      expect(FolderLock.verify('1235', hash), isFalse);
      expect(FolderLock.verify('1234', null), isFalse);
      // Özet düz PIN'i içermez.
      expect(hash.contains('1234'), isFalse);
    });

    test('kilitli klasörün ALTINDAKİ her şey kilitlidir', () {
      const locked = ['/depo/Gizli'];
      expect(FolderLock.isLocked('/depo/Gizli', locked), isTrue);
      expect(FolderLock.isLocked('/depo/Gizli/alt/x.jpg', locked), isTrue);
      expect(FolderLock.isLocked('/depo/Baska/x.jpg', locked), isFalse);
    });

    test('filterOut galeriden kilitli dosyaları düşürür', () {
      final out = FolderLock.filterOut(
        [file('/depo/Gizli/a.jpg'), file('/depo/DCIM/b.jpg')],
        ['/depo/Gizli'],
        (e) => e.path,
      );
      expect(out.map((e) => e.name), ['b.jpg']);
    });
  });

  group('depolama eğilimi', () {
    TrendPoint point(DateTime day, int total, {int video = 0}) => TrendPoint(
          dayMs: DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
          totalBytes: total,
          byCategory: {FmCategory.video: video},
        );

    test('aynı günün ikinci kaydı üzerine yazar', () {
      final first = point(now, 100);
      final second = point(now, 200);
      final merged = mergePoint([first], second);
      expect(merged.length, 1);
      expect(merged.single.totalBytes, 200);
    });

    test('7 günlük fark ve en çok büyüyen kategori', () {
      final points = [
        point(now.subtract(const Duration(days: 10)), 1000, video: 500),
        point(now, 3000, video: 2000),
      ];
      final trend = computeTrend(points, days: 7, now: now);
      expect(trend.deltaBytes, 2000);
      expect(trend.topCategory, FmCategory.video);
      expect(trend.topCategoryBytes, 1500);
    });

    test('tek kayıtla değişim iddia edilmez', () {
      final trend = computeTrend([point(now, 100)], now: now);
      expect(trend.deltaBytes, 0);
      expect(trend.hasData, isFalse);
    });
  });

  group('işlem geçmişi', () {
    test('yalnız yer değiştiren işlemler geri alınabilir', () {
      expect(OpKind.move.undoable, isTrue);
      expect(OpKind.organize.undoable, isTrue);
      expect(OpKind.copy.undoable, isFalse);
      expect(OpKind.delete.undoable, isFalse);
    });

    test('kayıt JSON turunu korur', () {
      const record = OpRecord(
        kind: OpKind.move,
        whenMs: 1000,
        summary: '3 öğe → Önemli Dosyalar',
        transfers: [FmTransfer('/a/x.jpg', '/b/x.jpg')],
      );
      final back = OpRecord.fromJson(record.toJson());
      expect(back, isNotNull);
      expect(back!.kind, OpKind.move);
      expect(back.summary, record.summary);
      expect(back.transfers.single.source, '/a/x.jpg');
      expect(back.canUndo, isTrue);
    });

    test('geçmiş en yeniden eskiye sıralanır ve 50 ile sınırlıdır', () {
      final many = [
        for (var i = 0; i < 60; i++)
          OpRecord(kind: OpKind.move, whenMs: i, summary: '$i'),
      ];
      final trimmed = OpHistory.trim(many);
      expect(trimmed.length, OpHistory.maxRecords);
      expect(trimmed.first.summary, '59');
    });
  });

  // ── Temizlik uygulama SIRASI (veri kaybı kilidi) ────────────────────────────
  // 2026-07-29 sadakat denetimi, CRITICAL 1: `duplicates` önerisi dosyaları çöpe
  // taşıyor, ardından `trash` önerisi `empty()` ile çöpü KALICI siliyordu —
  // onay penceresi ise "geri alabilirsiniz" diyordu. Bu grup o sırayı kilitler.
  group('cleanupApplyOrder', () {
    CleanupSuggestion sug(String id, {int bytes = 0}) => CleanupSuggestion(
          id: id,
          titleKey: id,
          detailKey: '',
          bytes: bytes,
          files: const [],
          safeByDefault: true,
        );

    test('çöp boşaltma, kopyalardan SONRA gelse bile başa alınır', () {
      final ordered = cleanupApplyOrder([
        sug('duplicates', bytes: 800 * 1024 * 1024),
        sug('cache', bytes: 40 * 1024 * 1024),
        sug('trash', bytes: 10 * 1024 * 1024),
      ]);
      expect(ordered.first.id, 'trash',
          reason: 'çöp sonra boşaltılırsa bu turda çöpe düşenler KALICI silinir');
      expect(ordered.map((s) => s.id).toList(),
          ['trash', 'duplicates', 'cache']);
    });

    test('çöp önerisi seçilmediyse sıra aynen korunur', () {
      final ordered =
          cleanupApplyOrder([sug('duplicates'), sug('cache'), sug('bigVideo')]);
      expect(ordered.map((s) => s.id).toList(),
          ['duplicates', 'cache', 'bigVideo']);
    });

    test('yalnız çöp seçildiyse tek eleman döner', () {
      expect(cleanupApplyOrder([sug('trash')]).single.id, 'trash');
    });

    test('boş seçim boş liste', () {
      expect(cleanupApplyOrder(const []), isEmpty);
    });

    test('hiçbir öneri kaybolmaz / çoğalmaz', () {
      final input = [
        sug('trash'),
        sug('duplicates'),
        sug('cache'),
        sug('bigVideo'),
      ];
      final ordered = cleanupApplyOrder(input);
      expect(ordered.length, input.length);
      expect(ordered.map((s) => s.id).toSet(), input.map((s) => s.id).toSet());
    });
  });
}
