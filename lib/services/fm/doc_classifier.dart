import '../../core/text_search.dart';

/// Bir görüntüden/belgeden okunan metnin **ne olduğu**.
enum DocClass {
  fatura,
  makbuz,
  kimlik,
  saglik,
  banka,
  sozlesme,
  egitim,
  ekranGoruntusu,
  bilet,
  diger,
}

extension DocClassInfo on DocClass {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`). [folder] çevrilmez —
  /// diskteki klasör adıdır.
  String get labelKey => switch (this) {
        DocClass.fatura => 'enum.doc_invoice',
        DocClass.makbuz => 'enum.doc_receipt',
        DocClass.kimlik => 'enum.doc_id',
        DocClass.saglik => 'enum.doc_health',
        DocClass.banka => 'enum.doc_bank',
        DocClass.sozlesme => 'enum.doc_contract',
        DocClass.egitim => 'enum.doc_education',
        DocClass.ekranGoruntusu => 'enum.doc_screenshot',
        DocClass.bilet => 'enum.doc_ticket',
        DocClass.diger => 'enum.doc_other',
      };

  String get label => switch (this) {
        DocClass.fatura => 'Fatura',
        DocClass.makbuz => 'Makbuz / fiş',
        DocClass.kimlik => 'Kimlik / resmî belge',
        DocClass.saglik => 'Sağlık belgesi',
        DocClass.banka => 'Banka / finans',
        DocClass.sozlesme => 'Sözleşme',
        DocClass.egitim => 'Eğitim / not',
        DocClass.ekranGoruntusu => 'Ekran görüntüsü',
        DocClass.bilet => 'Bilet / rezervasyon',
        DocClass.diger => 'Diğer',
      };

  /// "Önemli Dosyalar" altında önerilecek alt klasör adı.
  String get folder => switch (this) {
        DocClass.fatura => 'Faturalar',
        DocClass.makbuz => 'Makbuzlar',
        DocClass.kimlik => 'Kimlik ve Resmî Belgeler',
        DocClass.saglik => 'Sağlık',
        DocClass.banka => 'Banka',
        DocClass.sozlesme => 'Sözleşmeler',
        DocClass.egitim => 'Eğitim',
        DocClass.bilet => 'Biletler',
        DocClass.ekranGoruntusu => 'Ekran Görüntüleri',
        DocClass.diger => 'Belgeler',
      };
}

/// Sınıflandırma sonucu: tür + güven + hangi sözcüklerin karar verdirdiği.
///
/// **Kanıt gösterilir** (matched): kullanıcı "neden fatura dedi?" sorusunu
/// sorabilmeli; kara kutu bir etiket yanlış olduğunda güveni tamamen yıkar.
class DocGuess {
  final DocClass type;
  final int score;
  final List<String> matched;
  const DocGuess(this.type, this.score, this.matched);

  /// Eşik altı kalan tahminler "Diğer" sayılır.
  bool get isConfident => score >= 2 && type != DocClass.diger;
}

/// Anahtar sözcük tabloları. **KVKK notu:** metin cihazdan çıkmaz, yalnız
/// burada karşılaştırılır; hiçbir yere yazılmaz/gönderilmez (bkz. CLAUDE.md).
const _keywords = <DocClass, List<String>>{
  DocClass.fatura: [
    'fatura',
    'e-fatura',
    'e-arsiv',
    'vergi no',
    'vkn',
    'tutar',
    'kdv',
    'son odeme',
    'abone no',
    'tesisat',
    'elektrik',
    'dogalgaz',
    'su faturasi',
    'internet faturasi',
  ],
  DocClass.makbuz: [
    'makbuz',
    'fis',
    'satis fisi',
    'odendi',
    'kasa',
    'toplam tutar',
    'nakit',
    'kredi karti',
  ],
  DocClass.kimlik: [
    'kimlik',
    'nufus',
    't.c.',
    'tc kimlik',
    'ehliyet',
    'surucu belgesi',
    'pasaport',
    'ikametgah',
    'dogum yeri',
    'seri no',
  ],
  DocClass.saglik: [
    'recete',
    'tahlil',
    'rapor',
    'hasta',
    'poliklinik',
    'hastane',
    'doktor',
    'tani',
    'ilac',
    'mg',
    'sonuc raporu',
  ],
  DocClass.banka: [
    'iban',
    'hesap ozeti',
    'ekstre',
    'bakiye',
    'havale',
    'eft',
    'kredi',
    'taksit',
    'banka',
    'dekont',
  ],
  DocClass.sozlesme: [
    'sozlesme',
    'taraflar',
    'madde',
    'imza',
    'yururluk',
    'kiralayan',
    'kiraci',
    'taahhut',
    'feshi',
  ],
  DocClass.egitim: [
    'ders',
    'sinav',
    'not',
    'ogrenci',
    'universite',
    'okul',
    'odev',
    'transkript',
    'diploma',
  ],
  DocClass.bilet: [
    'bilet',
    'rezervasyon',
    'ucus',
    'sefer',
    'kalkis',
    'varis',
    'pnr',
    'koltuk',
    'otobus',
  ],
};

/// Metni sınıflandırır (saf, çevrimdışı, ücretsiz).
///
/// *Niye AI değil:* tek bir fatura fotoğrafı için ağ isteği atmak yavaş, ücretli
/// ve çevrimdışı çalışmaz. Anahtar sözcük sayımı bu belge türlerinde fazlasıyla
/// yeterli; AI özeti ayrı ve **isteğe bağlı** bir özellik (bkz. `GeminiService`).
DocGuess classifyDocumentText(String text, {String? fileName}) {
  final hay = turkishFold(text);
  final name = turkishFold(fileName ?? '');

  // Ekran görüntüsü genelde dosya adından bellidir; metinden anlaşılmaz.
  if (name.contains('screenshot') ||
      name.contains('ekran') ||
      name.contains('screen_shot')) {
    return const DocGuess(DocClass.ekranGoruntusu, 3, ['dosya adı']);
  }

  var best = DocClass.diger;
  var bestScore = 0;
  var bestMatches = <String>[];

  for (final entry in _keywords.entries) {
    final matched = <String>[];
    for (final word in entry.value) {
      if (hay.contains(word)) matched.add(word);
    }
    // Dosya adı da ipucu verir ("fatura_temmuz.pdf").
    if (name.contains(turkishFold(entry.key.name))) matched.add('dosya adı');
    if (matched.length > bestScore) {
      best = entry.key;
      bestScore = matched.length;
      bestMatches = matched;
    }
  }

  if (bestScore == 0) return const DocGuess(DocClass.diger, 0, []);
  return DocGuess(best, bestScore, bestMatches);
}
