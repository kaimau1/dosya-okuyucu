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

  test('bulanıklık: native pinch KAPALI, yakınlaştırma CSS zoom ile', () async {
    // Native pinch çizilmiş kareyi büyütür (bulanık); CSS zoom metni yeniden
    // dizer (keskin). Biri geri gelirse kullanıcı yine bulanık yazı görür.
    final html = await rootBundle.loadString('assets/word/viewer.html');
    final meta = RegExp(r'<meta name="viewport"[^>]*>').firstMatch(html)?.group(0);
    expect(meta, isNotNull);
    expect(meta, contains('user-scalable=no'));
    expect(html, contains('window.zoomBy'));
    expect(html, contains("wrap.style.zoom"));
    // Gövde zoom'u ikinci bir ölçek katmanıydı; tek yol kaldı.
    expect(html, isNot(contains('document.body.style.zoom')));
  });

  test('sayfa ekran genişliğine sığdırılırken SONUÇ doğrulanıyor', () async {
    // Kullanıcı ekran görüntüsünde sayfa ekranın ancak %59'unu kaplıyordu →
    // yazı gereksiz yere küçük ve okunaksızdı. İki koruma:
    final html = await rootBundle.loadString('assets/word/viewer.html');
    // 1) Genişlik `scrollWidth` ile ölçülmez (taşan tablo sayfayı küçültürdü).
    expect(html.contains('sec.scrollWidth'), isFalse);
    // 2) Ölçekten sonra sayfanın gerçekten ekranı doldurduğu ölçülüp
    //    gerekiyorsa bir kez düzeltiliyor.
    expect(html, contains('getBoundingClientRect().width'));
  });

  test('köprü sözleşmesi: Flutter\'ın çağırdığı JS işlevleri viewer\'da var',
      () async {
    // DocxViewState bu adları runJavaScript ile çağırıyor; biri yeniden
    // adlandırılırsa hata sessizdir (JS konsolunda kalır) — burada yakalanır.
    final html = await rootBundle.loadString('assets/word/viewer.html');
    for (final fn in [
      'setEditable',
      'setDocDir',
      'setFlow',
      'goToPage',
      'setFontFamily',
      'setFontSize',
      'zoomBy',
    ]) {
      expect(html, contains(fn), reason: '$fn viewer.html\'de yok');
    }
    // Sayfa sayacı kanalı (Flutter tarafında 'Sayfa' adıyla dinleniyor).
    expect(html, contains('window.Sayfa'));
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
