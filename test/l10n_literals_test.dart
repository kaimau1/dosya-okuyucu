import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Çevrilmemiş metin BEKÇİSİ.**
///
/// KALANLAR'daki "kalan ekranlar hâlâ Türkçe" maddesi 2026-08-08'de kapandı;
/// bu test onu KAPALI TUTAR. Kaynakta kullanıcıya görünen yerlere (`Text(...)`,
/// `tooltip:`, `label:`, `title:`, `hintText:`…) doğrudan Türkçe bir dize
/// yazılırsa test kırmızı yanar ve yazan kişi `context.t('anahtar')`a
/// yönlendirilir.
///
/// **Niye kaynak taraması, niye çalışma anı değil:** çevrilmemiş bir metin
/// çalışırken hata vermez — yalnız İngilizce/Arapça kullanan birinin ekranında
/// Türkçe olarak görünür. Kimse fark etmez, tur sonunda liste yeniden şişer.
/// `l10n_test` yalnız tablodaki eksikleri yakalar; tabloya HİÇ girmemiş metni
/// ancak kaynağa bakan bir test yakalayabilir.
///
/// **İzin listesi (`_allowed`) bilinçli ve dar:** marka adı, dosya içi teknik
/// değer, JSON anahtarı ve biçim adı çevrilmez. Yeni bir satır eklemek
/// gerekiyorsa gerekçesi yanına yazılmalı.
void main() {
  test('kullanıcıya görünen yerlerde sabit Türkçe metin YOK', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_skipLine.hasMatch(line)) continue;
        // Yuva ile metin AYNI satırda olmayabilir: `Text(` satır sonunda
        // bitip dize bir alt satıra düşünce (biçimlendiricinin sık yaptığı
        // şey) yalnız bu satıra bakan bir tarama körleşir — `markdown_text`
        // içindeki `'kod'` tam olarak böyle sızmıştı. Bir önceki satır bir
        // yuva AÇIP kapatmadan bittiyse bu satır da taranır.
        final continuation = i > 0 && _openSlot.hasMatch(lines[i - 1]);
        if (!_uiSlot.hasMatch(line) && !continuation) continue;
        for (final match in _literal.allMatches(line)) {
          final text = match.group(1)!;
          if (text.contains(r'$')) continue; // saf değer araya sokma
          if (_allowed.contains(text)) continue;
          if (!_turkish.hasMatch(text)) continue;
          offenders.add('${file.path}:${i + 1}  →  "$text"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Bu metinler doğrudan koda yazılmış; İngilizce/Arapça seçen\n'
          'kullanıcı bunları Türkçe görür. `lib/core/l10n/app_strings.dart`e\n'
          'üç dilli satır ekleyip `context.t(...)` kullanın:\n'
          '${offenders.join('\n')}',
    );
  });
}

/// Kullanıcıya metin veren parametre/çağrı adları.
final _uiSlot = RegExp(
  r'Text\(|label:|title:|hintText:|tooltip:|labelText:|'
  r'message:|content:|subtitle:|helperText:',
);

/// Satır sonunda AÇIK kalan yuva: `Text(`/`label:` yazılıp dize alt satıra
/// bırakılmış. Bir sonraki satır bu yüzden taranır.
final _openSlot = RegExp(
  r'(Text\(|label:|title:|hintText:|tooltip:|labelText:|'
  r'message:|content:|subtitle:|helperText:)\s*$',
);

/// Tek tırnaklı düz dize (kaçışsız — çok satırlı/ham dizeler kapsam dışı).
final _literal = RegExp(r"'([^'\\\n]{2,})'");

/// Türkçe'ye özgü harfler ya da yalnız Türkçe'de geçen yaygın kelimeler.
///
/// **Bu bir sezgi, kanıt değil.** Türkçe'ye özgü harf taşımayan ve listede
/// olmayan bir kelime (ör. `'Aktar'`, `'Sunum (PDF)'`) buradan sızabilir —
/// 2026-08-08'de sohbet ekranındaki dışa aktarma menüsünde tam olarak bu
/// oldu, gözle bakarken yakalandı. Sızıntı görüldükçe kelime listesi
/// büyütülüyor; testin işi "hepsini yakalamak" değil, **ucuz ve gürültüsüz
/// olanı yakalamak**. Yanlış pozitif üretmemesi (İngilizce/marka dizeleri
/// kızdırmaması) doğru yakalama oranından daha değerli: bağıran ama yanılan
/// bir test kısa sürede susturulur.
///
/// **Türkçe EKLEMELİ bir dildir — gövde listesi tek başına yetmez.** Kelime
/// listesi 2026-08-08'de `\b(gövde)\b` ile aranıyordu; `'Dosyalar'` bu yüzden
/// sızdı: `dosya` gövdesi listedeydi ama `-lar` eki sondaki `\b`yi kaydırıyor
/// ve tam kelime eşleşmesi tutmuyordu. Aynı sebeple `'Uygulamalar'`,
/// `'Yolu kopyala'`, `'Boyutu hesapla'` de görünmezdi.
///
/// Çözüm: gövdenin ardından **en çok iki Türkçe eki** kabul ediliyor
/// (`uygula`+`ma`+`lar`). Ek listesi açık ve sonlu — gövdeye serbest son ek
/// takmak (`gövde\w*`) İngilizce'yi de yakardı: `bu` gövdesi `button`,
/// `build`, `buffer`; `bas` gövdesi `base` ile eşleşirdi. Kapalı ek listesi
/// bunları dışarıda tutar, çünkü `tton`/`ild` Türkçe eki değildir.
///
/// Ekler çoğunlukla ASCII: Türkçe'ye özgü harf taşıyan biçimler (`dosyayı`,
/// `klasörü`) zaten üstteki harf sınıfına takılıyor — bu liste yalnız
/// `-lar/-de/-den/-in/-ma` gibi **düz ASCII** eklerin açtığı deliği kapatır.
final _turkish = RegExp(
  '[çğıöşüÇĞİÖŞÜ]|'
  r'\b(?:' + _stems + r')(?:' + _suffixes + r'){0,2}\b',
  caseSensitive: false,
);

/// Yalnız Türkçe'de geçen yaygın gövdeler (ek ALMADAN yazılır).
const _stems = 've|için|bir|bu|yok|var|ile|dosya|klasör|kaydet|sil|kapat|'
    'tamam|iptal|hata|seç|yeni|geri|ileri|gir|dene|yenile|temizle|sonraki|'
    'önceki|tara|aktar|sunum|ekle|gönder|indir|paylas|paylaş|ara|bul|'
    'degistir|baslat|durdur|devam|bitir|boyut|konum|uygula|parola|yol|'
    'slayt|bellek|motor|hesapla|yoksay|tablo|kart|kopya|arka|bas';

/// Gövdeye eklenebilen Türkçe ekler. Uzun olan kısa olandan ÖNCE gelmeli
/// (`ları` | `lar`): alternatifler soldan denenir, kısa olan önce yazılırsa
/// uzun biçim hiç denenmez ve sondaki `\b` tutmaz.
const _suffixes = 'ları|leri|lar|ler|sı|si|su|sü|nın|nin|nun|nün|ın|in|un|'
    'ün|dan|den|tan|ten|da|de|ta|te|ya|ye|na|ne|mak|mek|ma|me|la|le|'
    'yı|yi|yu|yü|ı|i|u|ü|a|e|m|n';

/// Metin sayılmayacak satırlar: içe aktarma, yorum, çeviri çağrısının kendisi.
final _skipLine = RegExp(
  r'import |assert\(|debugPrint|^\s*//|/// |\.t\(|RegExp|jsonEncode|'
  r'ValueKey|fontFamily|package:',
);

/// Çevrilmeyecek dizeler — her biri gerekçesiyle.
const _allowed = <String>{
  'Dosya Okuyucu', // marka adı (MaterialApp.title)
  'Google Drive', // marka adı
  'ZIP', // biçim adı
  'title', // JSON anahtarı (JobRecipe çözümlemesi)
  'yok', // disk göstergesi (OCR "bu sayfada metin yok" işareti)
  'AIza...', // API anahtarı ipucu (Google'ın kendi ön eki)
  'sendSelectionText()', // WebView'e gönderilen JS çağrısı
  '{ad} {n} {n2} {tarih} {uzanti}', // toplu adlandırma desen SÖZDİZİMİ
};
