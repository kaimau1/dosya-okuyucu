import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/cleanup_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

/// B18: benzer kareler + sohbet medyası derin taramaları Yer aç'a katılır.
void main() {
  FsEntry f(String path, int bytes) => FsEntry(
      path: path,
      name: path.split('/').last,
      isDir: false,
      sizeBytes: bytes,
      modifiedMs: 0);

  final best = f('/p/best.jpg', 500);
  final a = f('/p/a.jpg', 100);
  final b = f('/p/b.jpg', 200);
  final quickDup = f('/p/dup.jpg', 300);
  final chat1 = f('/w/c1.jpg', 40);

  final quick = [
    CleanupSuggestion(
        id: 'duplicates',
        titleKey: 't',
        detailKey: 'd',
        bytes: 300,
        files: [quickDup],
        safeByDefault: true),
  ];

  group('deepCleanupSuggestions', () {
    final deep = deepCleanupSuggestions(
      quick: quick,
      similarGroups: [
        [best, a, b, quickDup],
        [f('/p/tek.jpg', 1)], // tek kareli grup → yok sayılır
      ],
      chatJunk: [chat1, a], // a zaten benzer karelerde
    );
    final sim = deep.firstWhere((s) => s.id == 'similar');
    final chat = deep.firstWhere((s) => s.id == 'chat_media');

    test('en iyi kare öneriye girmez, originals en iyi kare', () {
      expect(sim.files.map((e) => e.path), isNot(contains(best.path)));
      expect(sim.originals[a.path]?.path, best.path);
      expect(sim.originals[b.path]?.path, best.path);
      expect(sim.detailVars['n'], 1);
    });

    test('hızlı taramayla ve kendi arasında çift sayım yok', () {
      expect(sim.files.map((e) => e.path), [a.path, b.path]);
      expect(sim.bytes, 300);
      expect(chat.files.map((e) => e.path), [chat1.path]);
      expect(chat.bytes, 40);
    });

    test('derin öneriler varsayılan seçili değil', () {
      expect(sim.safeByDefault, isFalse);
      expect(chat.safeByDefault, isFalse);
    });

    test('seçim toplamı', () {
      expect(cleanupTotal([...quick, ...deep]), 300 + 300 + 40);
    });

    test('boş girdi → öneri yok', () {
      expect(deepCleanupSuggestions(quick: quick), isEmpty);
    });
  });

  group('cleanupSeedSelection', () {
    test('derin sonuç gelince mevcut seçim silinmez, küme aynı nesne', () {
      final sigs = <String, String>{};
      final fileless = <String>{};
      final files = <String, Set<String>>{};
      cleanupSeedSelection(quick,
          signatures: sigs, fileless: fileless, files: files);
      final dupSel = files['duplicates']!;
      expect(dupSel, {quickDup.path});

      // Kullanıcı derin öneriden bir kare seçer, sonra liste yenilenir.
      final deep = deepCleanupSuggestions(quick: quick, similarGroups: [
        [best, a, b]
      ]);
      cleanupSeedSelection([...quick, ...deep],
          signatures: sigs, fileless: fileless, files: files);
      final simSel = files['similar']!;
      expect(simSel, isEmpty, reason: 'İncele varsayılan seçilmez');
      simSel.add(a.path);

      // Grup değişir (b silindi): seçim korunur, olmayan düşer.
      final deep2 = deepCleanupSuggestions(quick: quick, similarGroups: [
        [best, a, f('/p/yeni.jpg', 7)]
      ]);
      cleanupSeedSelection([...quick, ...deep2],
          signatures: sigs, fileless: fileless, files: files);
      expect(identical(files['similar'], simSel), isTrue);
      expect(identical(files['duplicates'], dupSel), isTrue);
      expect(simSel, {a.path});
      expect(dupSel, {quickDup.path});
    });

    test('dosyasız güvenli öneri yeni gelince seçilir, kalkınca düşer', () {
      final sigs = <String, String>{};
      final fileless = <String>{};
      final files = <String, Set<String>>{};
      const trash = CleanupSuggestion(
          id: 'trash',
          titleKey: 't',
          detailKey: 'd',
          bytes: 10,
          safeByDefault: true);
      cleanupSeedSelection([trash],
          signatures: sigs, fileless: fileless, files: files);
      expect(fileless, {'trash'});
      cleanupSeedSelection(const [],
          signatures: sigs, fileless: fileless, files: files);
      expect(fileless, isEmpty);
      expect(sigs, isEmpty);
    });
  });
}
