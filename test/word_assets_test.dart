import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Word görünümü tamamen gömülü dosyalara bağlı: biri pubspec'ten düşerse
/// uygulama çalışırken boş sayfa gösterir. Bu test onu derlemeden önce yakalar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('word görüntüleyici varlıkları pakete gömülü', () async {
    final html = await rootBundle.loadString('assets/word/viewer.html');
    expect(html, contains('renderDocx'));
    expect(html, contains('jszip.min.js'));
    expect(html, contains('docx-preview.min.js'));

    for (final js in ['jszip.min.js', 'docx-preview.min.js']) {
      final data = await rootBundle.load('assets/word/$js');
      expect(data.lengthInBytes, greaterThan(10000), reason: '$js eksik/bozuk');
    }
  });

  test('sadakat: MS font aliasları viewer.html\'de ve dosyalar gömülü', () async {
    final html = await rootBundle.loadString('assets/word/viewer.html');
    // Metrik-uyumlu ikame olmadan satır/sayfa kırma Word'den sapar.
    expect(html, contains('@font-face'));
    expect(html, contains("font-family:'Calibri'"));
    expect(html, contains("font-family:'Times New Roman'"));
    expect(html, contains("font-family:'Arial'"));

    // viewer.html'in ../fonts/ ile gösterdiği her .ttf gerçekten pakette mi?
    // (pubspec fonts: bölümünden biri düşerse aliaslar sessizce çalışmaz.)
    final refs = RegExp(r"\.\./fonts/([\w-]+\.ttf)")
        .allMatches(html)
        .map((m) => m.group(1)!)
        .toSet();
    expect(refs, isNotEmpty, reason: 'viewer.html font referansı bulunamadı');
    for (final ttf in refs) {
      final data = await rootBundle.load('assets/fonts/$ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: '$ttf eksik/bozuk');
    }
  });
}
