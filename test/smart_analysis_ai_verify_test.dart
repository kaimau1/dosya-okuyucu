import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

FsEntry _f(String path) => FsEntry(
    path: path, name: path.split('/').last, isDir: false, sizeBytes: 1, modifiedMs: 0);

/// B2 dilim 4 — akıllı temizlikte AI doğrulaması: yalnız selamlaşma ve
/// bulanık kovası sorulur; AI'ın açıkça reddettiği dosya kovadan düşer.
void main() {
  test('yalnız selamlaşma ve bulanık kovası doğrulanır', () {
    expect(SmartAnalysis.verifyQuestion(SmartKind.greeting), isNotNull);
    expect(SmartAnalysis.verifyQuestion(SmartKind.blurry), isNotNull);
    expect(SmartAnalysis.verifyQuestion(SmartKind.dark), isNull);
    expect(SmartAnalysis.verifyQuestion(SmartKind.copyNamed), isNull);
  });

  test('reddedilen düşer, sorulmayan ve kararsız kalır', () {
    final files = [_f('/a.jpg'), _f('/b.jpg'), _f('/c.jpg'), _f('/d.jpg')];
    final kept = SmartAnalysis.dropRejected(files, {
      '/a.jpg': 0.9, // AI: evet, selamlaşma
      '/b.jpg': 0.05, // AI: hayır → yanlış eşleşme
      '/c.jpg': 0.4, // kararsız → kalır
    });
    expect(kept.map((e) => e.path), ['/a.jpg', '/c.jpg', '/d.jpg']);
  });
}
