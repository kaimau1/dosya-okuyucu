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
}
