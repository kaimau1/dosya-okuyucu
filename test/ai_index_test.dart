import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_ask.dart';
import 'package:dosya_okuyucu/services/fm/ai_index.dart';
import 'package:dosya_okuyucu/services/fm/ai_report.dart';
import 'package:dosya_okuyucu/services/fm/ai_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI indeksi, raporu ve soru elemesi — hepsi saf mantık, ağ yok.
///
/// `resetForTest` bellekteki indeksi kurar ve "yüklendi" işaretler; böylece
/// `FmEnv`/path_provider platform kanalına hiç gidilmez (test ortamında yok).
AiRecord _record(
  String path, {
  String type = '',
  int importance = 0,
  String summary = '',
  List<String> tags = const [],
  String suggestedName = '',
  String suggestedFolder = '',
  int size = 1000,
  int modifiedMs = 1000,
  int analyzedMs = 5,
}) =>
    AiRecord(
      path: path,
      sizeBytes: size,
      modifiedMs: modifiedMs,
      category: FmCategory.document,
      docType: type,
      importance: importance,
      summary: summary,
      tags: tags,
      suggestedName: suggestedName,
      suggestedFolder: suggestedFolder,
      analyzedMs: analyzedMs,
    );

void main() {
  setUp(AiIndex.resetForTest);

  group('kayıt', () {
    test('JSON gidiş-dönüşü', () {
      final before = _record(
        '/a/fatura.pdf',
        type: 'fatura',
        importance: 80,
        summary: 'Temmuz elektrik faturası',
        tags: ['fatura', 'elektrik'],
        suggestedName: 'Elektrik Temmuz.pdf',
      );
      final after = AiRecord.fromJson(before.toJson())!;
      expect(after.path, before.path);
      expect(after.docType, 'fatura');
      expect(after.importance, 80);
      expect(after.tags, ['fatura', 'elektrik']);
      expect(after.suggestedName, 'Elektrik Temmuz.pdf');
      expect(after.analyzedMs, before.analyzedMs);
    });

    test('yolsuz satır çözülmez (bozuk indeks satırı atlanır)', () {
      expect(AiRecord.fromJson(const {'s': 5}), isNull);
    });

    test('dosya değişince kayıt bayatlar', () {
      final record = _record('/a/x.pdf', size: 10, modifiedMs: 100);
      const same = FsEntry(
          path: '/a/x.pdf',
          name: 'x.pdf',
          isDir: false,
          sizeBytes: 10,
          modifiedMs: 100);
      const edited = FsEntry(
          path: '/a/x.pdf',
          name: 'x.pdf',
          isDir: false,
          sizeBytes: 11,
          modifiedMs: 200);
      expect(record.matches(same), isTrue);
      expect(record.matches(edited), isFalse);
    });
  });

  group('indeks', () {
    test('aynı yol için son yazılan kazanır', () async {
      await AiIndex.putAll([_record('/a/x.pdf', type: 'eski')]);
      await AiIndex.putAll([_record('/a/x.pdf', type: 'yeni')]);
      expect(AiIndex.count, 1);
      expect(AiIndex.of('/a/x.pdf')!.docType, 'yeni');
    });

    test('kapsam dışına alınan klasörün kayıtları silinir', () async {
      await AiIndex.putAll([
        _record('/a/DCIM/Camera/1.jpg'),
        _record('/a/Belgeler/1.pdf'),
      ]);
      final removed = await AiIndex.dropOutOfScope(
          (path) => !path.startsWith('/a/DCIM/Camera'));
      expect(removed, 1);
      expect(AiIndex.of('/a/DCIM/Camera/1.jpg'), isNull);
      expect(AiIndex.of('/a/Belgeler/1.pdf'), isNotNull);
    });

    test('öneri uygulanınca kayıt yeni yola taşınır ve öneri düşer', () async {
      await AiIndex.putAll([
        _record('/a/IMG_1.pdf',
            suggestedName: 'Fatura.pdf', suggestedFolder: 'Faturalar')
      ]);
      await AiIndex.movePath('/a/IMG_1.pdf', '/a/Faturalar/Fatura.pdf');
      expect(AiIndex.of('/a/IMG_1.pdf'), isNull);
      final moved = AiIndex.of('/a/Faturalar/Fatura.pdf')!;
      expect(moved.hasSuggestion, isFalse,
          reason: 'uygulanan öneri tekrar önerilmemeli');
    });

    test('süzgeç: tür, önem ve öneri', () async {
      await AiIndex.putAll([
        _record('/a/1.pdf', type: 'fatura', importance: 80),
        _record('/a/2.pdf', type: 'fatura', importance: 10),
        _record('/a/3.pdf', type: 'bilet', importance: 90, suggestedName: 'x.pdf'),
      ]);
      expect(AiIndex.where(docType: 'fatura').length, 2);
      expect(AiIndex.where(minImportance: 70).length, 2);
      expect(AiIndex.where(onlySuggestions: true).length, 1);
      expect(AiIndex.docTypeCounts()['fatura'], 2);
    });
  });

  group('rapor', () {
    test('önemli / çöp / öneri ayrımı', () {
      final report = AiReport.build([
        _record('/a/kimlik.pdf', type: 'kimlik', importance: 95, size: 100),
        _record('/a/mem.jpg', type: 'ekran görüntüsü', importance: 10, size: 500),
        _record('/a/x.pdf', importance: 50, suggestedName: 'y.pdf'),
        // Analiz edilmemiş kayıt hiçbir sayıya girmez.
        _record('/a/ham.pdf', analyzedMs: 0),
      ]);
      expect(report.analyzed, 3);
      expect(report.important.single.path, '/a/kimlik.pdf');
      expect(report.junk.single.path, '/a/mem.jpg');
      expect(report.junkBytes, 500);
      expect(report.suggestions.single.path, '/a/x.pdf');
    });

    test('önem 0 (değerlendirilmedi) çöp sayılmaz', () {
      final report = AiReport.build([_record('/a/x.pdf', importance: 0)]);
      expect(report.junk, isEmpty);
    });
  });

  group('soru elemesi (yerel, ücretsiz)', () {
    const scope = AiScope(settings: AiScopeSettings());

    test('ada ve türe göre eşleşir, alakasızı eler', () async {
      await AiIndex.putAll([
        _record('/a/elektrik-faturasi.pdf', type: 'fatura', importance: 70),
        _record('/a/tatil.jpg', type: 'fotoğraf'),
      ]);
      final hits = AiAsk.rank('faturalarım nerede', scope: scope);
      expect(hits, hasLength(1));
      expect(hits.single.path, '/a/elektrik-faturasi.pdf');
    });

    test('Türkçe katlama: "sözleşme" ile "sozlesme" eşleşir', () async {
      await AiIndex.putAll([_record('/a/kira-sozlesme.pdf', type: 'sözleşme')]);
      expect(AiAsk.rank('sözleşme', scope: scope), hasLength(1));
      expect(AiAsk.rank('sozlesme', scope: scope), hasLength(1));
    });

    test('kapsam dışı klasörün eski kaydı cevaba karışmaz', () async {
      await AiIndex.putAll([
        _record('/storage/emulated/0/DCIM/Camera/fatura.jpg', type: 'fatura'),
      ]);
      const narrowed = AiScope(
        settings: AiScopeSettings(
          excludedFolders: ['/storage/emulated/0/DCIM/Camera'],
        ),
      );
      expect(AiAsk.rank('fatura', scope: narrowed), isEmpty);
      expect(AiAsk.rank('fatura', scope: scope), hasLength(1));
    });

    test('zaman ipucu eski dosyaları eler', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = DateTime.now()
          .subtract(const Duration(days: 200))
          .millisecondsSinceEpoch;
      await AiIndex.putAll([
        _record('/a/yeni-fatura.pdf', type: 'fatura', modifiedMs: now),
        _record('/a/eski-fatura.pdf', type: 'fatura', modifiedMs: old),
      ]);
      final hits = AiAsk.rank('bu hafta gelen fatura', scope: scope);
      expect(hits, hasLength(1));
      expect(hits.single.path, '/a/yeni-fatura.pdf');
    });

    test('önemli evrak eşit puanda öne gelir', () async {
      await AiIndex.putAll([
        _record('/a/fatura-a.pdf', type: 'fatura', importance: 10),
        _record('/a/fatura-b.pdf', type: 'fatura', importance: 90),
      ]);
      final hits = AiAsk.rank('fatura', scope: scope);
      expect(hits.first.path, '/a/fatura-b.pdf');
    });
  });
}
