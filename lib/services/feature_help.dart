/// **Ara ve Yardım** (2026-11-14 kullanıcı isteği): "bu özellik var mı,
/// nerede, nasıl yapılır" sorusunun cevabı. Arama kutusuna yazılan sözcük
/// özellik adlarında ve anahtar sözcüklerde de aranır; eşleşen özellik
/// arama sonuçlarının üstünde, tümü "Yardım" sayfasında listelenir.
///
/// İçerik yalnız Türkçe (sabah bakılacak: çeviri). Konumlar uygulamadaki
/// menü adlarıyla aynı yazılır; menü adı değişirse burası da güncellenmeli.
library;

/// Tek bir özelliğin yardım kaydı.
class FeatureHelp {
  final String id;
  final String group;
  final String title;

  /// Nerede: "Ana ekran → Videolar → videonun ⋮ menüsü" gibi.
  final String where;

  /// Nasıl: kısa adımlar.
  final List<String> how;

  /// Eş anlamlılar / kullanıcının yazabileceği sözcükler (küçük harf).
  final List<String> keywords;

  const FeatureHelp({
    required this.id,
    required this.group,
    required this.title,
    required this.where,
    required this.how,
    this.keywords = const [],
  });
}

/// Türkçe büyük/küçük harf ve aksan katlama: "Şifre" ≈ "sifre".
String foldTr(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(switch (c) {
      'ı' => 'i',
      'ş' => 's',
      'ğ' => 'g',
      'ü' => 'u',
      'ö' => 'o',
      'ç' => 'c',
      'â' => 'a',
      'î' => 'i',
      'û' => 'u',
      _ => c,
    });
  }
  return b.toString().replaceAll('̇', '');
}

class FeatureHelpIndex {
  FeatureHelpIndex._();

  /// Sorguya göre puanlı eşleşmeler (en iyi önce). Her sözcük başlıkta,
  /// anahtar sözcüklerde ya da konumda geçmeli.
  static List<FeatureHelp> search(String query, {int limit = 50}) {
    final words = foldTr(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    if (words.isEmpty) return const [];
    final scored = <(int, FeatureHelp)>[];
    for (final f in all) {
      final title = foldTr(f.title);
      final keys = foldTr(f.keywords.join(' '));
      final rest = foldTr('${f.group} ${f.where} ${f.how.join(' ')}');
      var score = 0;
      var ok = true;
      for (final w in words) {
        if (title.contains(w)) {
          score += title.startsWith(w) ? 6 : 4;
        } else if (keys.contains(w)) {
          score += 3;
        } else if (rest.contains(w)) {
          score += 1;
        } else {
          ok = false;
          break;
        }
      }
      if (ok) scored.add((score, f));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final s in scored.take(limit)) s.$2];
  }

  static List<String> get groups {
    final seen = <String>[];
    for (final f in all) {
      if (!seen.contains(f.group)) seen.add(f.group);
    }
    return seen;
  }

  static const all = <FeatureHelp>[
    // ── Arama ve gezinme ───────────────────────────────────────────────
    FeatureHelp(
      id: 'search',
      group: 'Arama ve gezinme',
      title: 'Dosya ara',
      where: 'Ana ekran → üstteki "Ara ve Yardım" kutusu',
      how: [
        'Kutuya dokun, dosya adından en az 2 harf yaz.',
        'Süzgeç düğmesiyle tarih, boyut, tür ve kaynağa göre daralt.',
        'Bulduğun aramayı yer imi düğmesiyle kaydedebilirsin.',
      ],
      keywords: ['bul', 'arama', 'dosya bul', 'nerede'],
    ),
    FeatureHelp(
      id: 'search_content',
      group: 'Arama ve gezinme',
      title: 'Dosyanın içinde ara',
      where: 'Arama ekranı → "Dosya içinde ara" seçeneği',
      how: [
        'Aramaya kelimeyi yaz.',
        '"Dosya içinde ara"yı aç; PDF, Word, Excel ve metin dosyalarının içi okunur.',
      ],
      keywords: ['metin', 'icerik', 'kelime', 'pdf icinde'],
    ),
    FeatureHelp(
      id: 'search_meaning',
      group: 'Arama ve gezinme',
      title: 'Anlamla ara (AI)',
      where: 'Arama ekranı → üstteki yıldız (AI) düğmesi',
      how: [
        'AI düğmesine bas, aradığını cümleyle yaz ("geçen ayın faturası").',
        'Ara\'ya bas; eş anlamlı sözcüklerle cihazda aranır.',
      ],
      keywords: ['ai', 'yapay zeka', 'akilli arama', 'cumle'],
    ),
    FeatureHelp(
      id: 'browse',
      group: 'Arama ve gezinme',
      title: 'Klasörlerde gez',
      where: 'Ana ekran → bellek kartı → "Göz at"',
      how: [
        'Göz at\'a dokun, klasörlere girerek ilerle.',
        'Uzun basarak birden çok dosya seç; alttaki çubukla taşı, kopyala, sil.',
      ],
      keywords: ['klasor', 'gezgin', 'dosya yoneticisi', 'dizin'],
    ),
    FeatureHelp(
      id: 'quick_folders',
      group: 'Arama ve gezinme',
      title: 'Hızlı klasörler',
      where: 'Ana ekran → aşağıda "Hızlı klasörler"',
      how: ['İndirilenler, Kamera, Belgeler gibi klasörlere tek dokunuşla gir.'],
      keywords: ['kisayol', 'indirilenler', 'kamera klasoru'],
    ),
    FeatureHelp(
      id: 'dual_pane',
      group: 'Arama ve gezinme',
      title: 'Çift bölme (iki klasör yan yana)',
      where: 'Göz at → sağ üst "Daha fazla" menüsü → Çift bölme',
      how: ['İki klasörü yan yana açıp aralarında kopyala/taşı.'],
      keywords: ['iki pencere', 'yan yana', 'cift panel'],
    ),

    // ── Ana ekran ──────────────────────────────────────────────────────
    FeatureHelp(
      id: 'edit_home',
      group: 'Ana ekran',
      title: 'Ana ekranı düzenle',
      where: 'Ana ekran → en altta "Ana ekranı düzenle"',
      how: [
        'Kutuları ve bölümleri sürükleyerek sırala.',
        'Anahtarla gizle ya da göster.',
        '"Yeni kart" düğmesiyle kendi kartını oluştur.',
      ],
      keywords: ['siralama', 'gizle', 'kutu', 'kart', 'duzen'],
    ),
    FeatureHelp(
      id: 'custom_card',
      group: 'Ana ekran',
      title: 'Kendi kartını oluştur',
      where: 'Ana ekran → "Ana ekranı düzenle" → "Yeni kart"',
      how: [
        'Kartın adını ve içine girecek dosya türlerini seç.',
        'Galeri ya da klasör görünümünü seç, kaydet.',
      ],
      keywords: ['yeni kart', 'kart ekle', 'ozel kart'],
    ),
    FeatureHelp(
      id: 'bottom_bar',
      group: 'Ana ekran',
      title: 'Alt paneli düzenle',
      where: 'Ana ekran → en altta "Alt paneli düzenle"',
      how: [
        'Aktar\'ın solunda ve sağında 3\'er düğme olabilir.',
        'Ek düğmeleri (İşlemler, Drive…) sola ya da sağa ekle; her yana en çok 2 ek.',
      ],
      keywords: ['alt cubuk', 'dugme ekle', 'panel'],
    ),
    FeatureHelp(
      id: 'recent',
      group: 'Ana ekran',
      title: 'Son açılanlar',
      where: 'Ana ekran → "Son açılanlar" bölümü (ya da "Geçmiş" kutusu)',
      how: ['Son açtığın dosyalar burada; "Tümü" ile geçmişin tamamı.'],
      keywords: ['gecmis', 'en son', 'acilan'],
    ),

    // ── Video ve fotoğraf ─────────────────────────────────────────────
    FeatureHelp(
      id: 'video_trim',
      group: 'Video ve fotoğraf',
      title: 'Video kes / bölüm sil',
      where: 'Videolar → videoyu aç → ⋮ → "Videoyu düzenle"',
      how: [
        'Alttaki şeritte iki tutamacı sürükleyerek başı ve sonu seç.',
        'Ortadan parça atmak için "Bölüm sil".',
        'Kaydet\'e bas; asıl video bozulmaz, yeni dosya yazılır.',
      ],
      keywords: ['kirp', 'kesme', 'trim', 'video duzenle', 'kisalt'],
    ),
    FeatureHelp(
      id: 'video_mute',
      group: 'Video ve fotoğraf',
      title: 'Videonun sesini kapat / ses ekle',
      where: 'Videoyu düzenle → "Sesi kapat" ya da "Ses ekle"',
      how: ['Sesi kapat ile sessiz kopya, Ses ekle ile müzik bindir; Kaydet.'],
      keywords: ['sessiz', 'muzik ekle', 'ses'],
    ),
    FeatureHelp(
      id: 'video_rotate',
      group: 'Video ve fotoğraf',
      title: 'Videoyu döndür',
      where: 'Videoyu düzenle → "Döndür"',
      how: ['Her basışta 90° döner; Kaydet ile yeni dosya yazılır.'],
      keywords: ['cevir', 'yan', 'yatay'],
    ),
    FeatureHelp(
      id: 'video_frame',
      group: 'Video ve fotoğraf',
      title: 'Videodan kare (fotoğraf) al',
      where: 'Videoyu düzenle → üstteki fotoğraf makinesi düğmesi',
      how: ['Kareyi seç, düğmeye bas; JPG olarak videonun yanına kaydedilir.'],
      keywords: ['ekran goruntusu', 'kare', 'resim al', 'foto'],
    ),
    FeatureHelp(
      id: 'grid_size',
      group: 'Video ve fotoğraf',
      title: 'Izgarada küçük resim boyutu',
      where: 'Fotoğraflar / Videolar → iki parmakla kıstır',
      how: ['Parmakları açınca resimler büyür, kıstırınca sütun artar.'],
      keywords: ['sutun', 'buyut', 'kucult', 'zoom'],
    ),
    FeatureHelp(
      id: 'image_resize',
      group: 'Video ve fotoğraf',
      title: 'Fotoğraf boyutunu düşür',
      where: 'Fotoğrafın ⋮ menüsü → "Boyut düşür"',
      how: ['Hedef boyutu seç; küçük kopya üretilir, karşılaştırıp saklarsın.'],
      keywords: ['kucult', 'mb', 'sikistir', 'resim boyutu'],
    ),
    FeatureHelp(
      id: 'image_edit',
      group: 'Video ve fotoğraf',
      title: 'Fotoğraf düzenle (kırp, döndür, yazı)',
      where: 'Fotoğrafı aç → alttaki düzenle (ayar) düğmesi',
      how: ['Kırp, döndür, kalemle çiz ya da yazı ekle; Kaydet.'],
      keywords: ['kirp', 'resim duzenle', 'ciz'],
    ),
    FeatureHelp(
      id: 'similar',
      group: 'Video ve fotoğraf',
      title: 'Benzer ve kopya fotoğraflar',
      where: 'Ana ekran → bellek kartı → "Yer aç"',
      how: ['Birbirine benzeyen fotoğraflar gruplanır; tutacağını seç, kalanları sil.'],
      keywords: ['kopya', 'ayni', 'tekrar', 'yer ac', 'benzer'],
    ),

    // ── Ses ───────────────────────────────────────────────────────────
    FeatureHelp(
      id: 'audio_trim',
      group: 'Ses',
      title: 'Ses dosyası kes',
      where: 'Ses → dosyayı aç → ⋮ → "Sesi kes"',
      how: [
        'Şeritte iki tutamacı sürükle; sürüklerken o andan kısa bir parça çalınır.',
        'Kaydet\'e bas; yeni dosya yazılır, asıl dosya kalır.',
      ],
      keywords: ['kirp', 'kesme', 'trim', 'ses duzenle', 'zil sesi', 'kisalt'],
    ),
    FeatureHelp(
      id: 'audiobook',
      group: 'Ses',
      title: 'Belgeyi sesli kitap yap',
      where: 'Belgenin ⋮ menüsü → "Sesli kitap yap"',
      how: ['Belge sesli okunur ve ses dosyası olarak saklanır; Kitaplık\'tan dinlenir.'],
      keywords: ['sesli oku', 'dinle', 'kitaplik', 'tts'],
    ),

    // ── PDF ve belgeler ───────────────────────────────────────────────
    FeatureHelp(
      id: 'pdf_edit',
      group: 'PDF ve belgeler',
      title: 'PDF düzenle (yazı, çizim, imza)',
      where: 'PDF\'i aç → alttaki "Düzenle"',
      how: ['Metin ekle, kalemle çiz, vurgula ya da imza koy; Kaydet.'],
      keywords: ['imza', 'yazi ekle', 'not', 'isaretle'],
    ),
    FeatureHelp(
      id: 'pdf_tools',
      group: 'PDF ve belgeler',
      title: 'PDF araçları (sayfa sil, döndür, birleştir)',
      where: 'PDF\'i aç → alttaki "Araçlar"',
      how: [
        'Sayfaları seç; döndür, sil, taşı, çoğalt.',
        'Başka PDF ekleyerek birleştir, parçalara böl.',
      ],
      keywords: ['birlestir', 'bol', 'sayfa sil', 'dondur', 'sayfa sirasi'],
    ),
    FeatureHelp(
      id: 'pdf_password',
      group: 'PDF ve belgeler',
      title: 'PDF\'e parola koy / kaldır',
      where: 'PDF → "Araçlar" → "Parola koy" / "Parolayı kaldır"',
      how: ['Parolayı gir; yeni dosya parolalı kaydedilir.'],
      keywords: ['sifre', 'kilitle', 'parola'],
    ),
    FeatureHelp(
      id: 'pdf_compress',
      group: 'PDF ve belgeler',
      title: 'PDF küçült (sıkıştır)',
      where: 'PDF → "Araçlar" → "Sıkıştır"',
      how: ['Kaliteyi seç; küçük kopya üretilir.'],
      keywords: ['kucult', 'mb', 'boyut'],
    ),
    FeatureHelp(
      id: 'pdf_page_numbers',
      group: 'PDF ve belgeler',
      title: 'Sayfa numarası / filigran ekle',
      where: 'PDF → "Araçlar" → "Sayfa numarası ekle" ya da "Filigran ekle"',
      how: ['Biçimi seç (ör. "3 / 12"), uygula.'],
      keywords: ['numara', 'filigran', 'taslak'],
    ),
    FeatureHelp(
      id: 'pdf_images',
      group: 'PDF ve belgeler',
      title: 'PDF sayfalarını resme çevir',
      where: 'PDF → "Araçlar" → "Sayfaları görsel yap (PNG)"',
      how: ['Sayfaları seç; her sayfa PNG olarak kaydedilir.'],
      keywords: ['png', 'jpg', 'resme cevir', 'donustur'],
    ),
    FeatureHelp(
      id: 'pdf_ai',
      group: 'PDF ve belgeler',
      title: 'Belgeyi AI ile özetle / soru sor',
      where: 'Belgeyi aç → alttaki "AI"',
      how: ['Özet iste ya da belge hakkında soru sor.'],
      keywords: ['ozet', 'yapay zeka', 'soru', 'gemini'],
    ),
    FeatureHelp(
      id: 'translate',
      group: 'PDF ve belgeler',
      title: 'Belgeyi çevir',
      where: 'Belgeyi aç → alttaki "Çevir"',
      how: ['Dili seç; çeviri ayrı bir belge olarak açılır.'],
      keywords: ['ceviri', 'ingilizce', 'dil'],
    ),
    FeatureHelp(
      id: 'print',
      group: 'PDF ve belgeler',
      title: 'Yazdır',
      where: 'Belgeyi aç → alttaki "Yazdır"',
      how: ['Yazıcıyı seç ya da PDF olarak kaydet.'],
      keywords: ['yazici', 'cikti'],
    ),
    FeatureHelp(
      id: 'pdf_search',
      group: 'PDF ve belgeler',
      title: 'Belgede kelime bul',
      where: 'Belgeyi aç → üstteki büyüteç',
      how: ['Kelimeyi yaz; eşleşmeler arasında oklarla gez.'],
      keywords: ['bul', 'kelime', 'ara'],
    ),
    FeatureHelp(
      id: 'new_document',
      group: 'PDF ve belgeler',
      title: 'Yeni belge oluştur (Word, Excel, sunum)',
      where: 'Ana ekran → Araçlar → "Yeni belge oluştur"',
      how: ['Türü seç, adını ver; düzenleyici açılır.'],
      keywords: ['word', 'excel', 'sunum', 'yeni dosya', 'olustur'],
    ),
    FeatureHelp(
      id: 'scan',
      group: 'PDF ve belgeler',
      title: 'Belge tara (kamera ile PDF)',
      where: 'Ana ekran → alt panel → "Tara"',
      how: ['Sayfayı çek, kenarları düzelt, PDF olarak kaydet.'],
      keywords: ['tarayici', 'kamera', 'fotokopi', 'ocr'],
    ),

    // ── Dosya işlemleri ───────────────────────────────────────────────
    FeatureHelp(
      id: 'file_actions',
      group: 'Dosya işlemleri',
      title: 'Kopyala, taşı, yeniden adlandır, sil',
      where: 'Dosyanın ⋮ menüsü (ya da uzun basıp seç)',
      how: ['⋮\'ye dokun, işlemi seç; çoklu seçimde alttaki çubuğu kullan.'],
      keywords: ['kopyala', 'tasi', 'ad degistir', 'sil', 'yeniden adlandir'],
    ),
    FeatureHelp(
      id: 'compress_zip',
      group: 'Dosya işlemleri',
      title: 'ZIP yap / arşivi aç',
      where: 'Dosyanın ⋮ menüsü → "Sıkıştır" ya da arşivde "Buraya çıkar"',
      how: ['Dosyaları seç, Sıkıştır; arşivi açmak için Buraya çıkar.'],
      keywords: ['zip', 'rar', 'arsiv', 'cikar', 'ac'],
    ),
    FeatureHelp(
      id: 'split_join',
      group: 'Dosya işlemleri',
      title: 'Büyük dosyayı parçalara böl / birleştir',
      where: 'Dosyanın ⋮ menüsü → "Parçalara böl" / "Parçaları birleştir"',
      how: ['Parça boyutunu seç; birleştirmek için ilk parçada Parçaları birleştir.'],
      keywords: ['bol', 'parca', 'birlestir'],
    ),
    FeatureHelp(
      id: 'trash',
      group: 'Dosya işlemleri',
      title: 'Çöp kutusu (silineni geri al)',
      where: 'Ana ekran → alt panel → "Çöp"',
      how: ['Silinen dosyalar burada bekler; geri yükle ya da kalıcı sil.'],
      keywords: ['geri al', 'silinen', 'kurtar', 'cop'],
    ),
    FeatureHelp(
      id: 'jobs',
      group: 'Dosya işlemleri',
      title: 'İşlemler (süren ve biten işler)',
      where: 'Ana ekran → Araçlar → "İşlemler"',
      how: ['Kopyalama, dönüştürme gibi uzun işlerin durumu ve sonucu burada.'],
      keywords: ['is', 'ilerleme', 'kuyruk', 'gorev'],
    ),
    FeatureHelp(
      id: 'tags',
      group: 'Dosya işlemleri',
      title: 'Dosyayı etiketle / önemli işaretle',
      where: 'Dosyanın ⋮ menüsü → "Etiketle" ya da "Önemli Dosyalar\'a kopyala"',
      how: ['Etiket seç; Önemli Dosyalar kutusundan hepsine ulaşırsın.'],
      keywords: ['etiket', 'yildiz', 'favori', 'onemli'],
    ),
    FeatureHelp(
      id: 'properties',
      group: 'Dosya işlemleri',
      title: 'Dosya bilgisi (boyut, tarih, konum)',
      where: 'Dosyanın ⋮ menüsü → "Özellikler"',
      how: ['Boyut, oluşturma tarihi, klasör ve özet bilgileri görürsün.'],
      keywords: ['ozellik', 'bilgi', 'detay', 'boyut'],
    ),

    // ── Paylaşım ve aktarım ───────────────────────────────────────────
    FeatureHelp(
      id: 'transfer',
      group: 'Paylaşım ve aktarım',
      title: 'Bilgisayara / telefona aktar',
      where: 'Ana ekran → alt panel → "Aktar"',
      how: [
        '"Dosya ekle" ile gönderilecekleri seç.',
        'Karşı cihaz QR kodu okutur ya da adresi tarayıcıya yazar.',
      ],
      keywords: ['gonder', 'wifi', 'qr', 'bilgisayar', 'pc', 'aktarim'],
    ),
    FeatureHelp(
      id: 'share',
      group: 'Paylaşım ve aktarım',
      title: 'Paylaş',
      where: 'Dosyanın ⋮ menüsü → "Paylaş" ya da belgede "Paylaş"',
      how: ['Uygulamayı seç (WhatsApp, e-posta…).'],
      keywords: ['whatsapp', 'gonder', 'e-posta'],
    ),
    FeatureHelp(
      id: 'drive',
      group: 'Paylaşım ve aktarım',
      title: 'Google Drive',
      where: 'Alt panel → "Drive" (Alt paneli düzenle\'den eklenir)',
      how: ['Hesabını bağla; Drive dosyalarını gez, indir, yükle.'],
      keywords: ['bulut', 'yedek', 'google'],
    ),

    // ── Gizlilik ──────────────────────────────────────────────────────
    FeatureHelp(
      id: 'vault',
      group: 'Gizlilik',
      title: 'Şifreli kasa (dosya gizle)',
      where: 'Ana ekran → Araçlar → "Şifreli kasa"',
      how: [
        'İlk girişte parola belirle.',
        'Dosyanın ⋮ menüsünden "Şifreli kasaya taşı" ile dosyaları içeri al.',
      ],
      keywords: ['gizle', 'sifre', 'kilit', 'ozel', 'saklama'],
    ),

    // ── Bellek ────────────────────────────────────────────────────────
    FeatureHelp(
      id: 'cleanup',
      group: 'Bellek',
      title: 'Yer aç (gereksiz dosya temizle)',
      where: 'Ana ekran → bellek kartı → "Yer aç"',
      how: ['Önerilen grupları incele, seçtiklerini çöpe gönder.'],
      keywords: ['temizle', 'bos alan', 'cop', 'gereksiz', 'yer'],
    ),
    FeatureHelp(
      id: 'analysis',
      group: 'Bellek',
      title: 'Bellek analizi (yeri ne kaplıyor)',
      where: 'Ana ekran → bellek kartı → "Analiz"',
      how: ['Klasör ve türlere göre yer kullanımını gör, büyük dosyaları bul.'],
      keywords: ['buyuk dosya', 'yer kaplayan', 'depolama', 'kullanim'],
    ),
    FeatureHelp(
      id: 'apps',
      group: 'Bellek',
      title: 'Uygulamalar (boyut, kaldırma, APK)',
      where: 'Ana ekran → "Uygulamalar"',
      how: ['Uygulamaları boyuta göre sırala, kaldır ya da APK olarak yedekle.'],
      keywords: ['apk', 'kaldir', 'uygulama boyutu'],
    ),

    // ── AI ────────────────────────────────────────────────────────────
    FeatureHelp(
      id: 'ai_hub',
      group: 'AI',
      title: 'AI Dosya Asistanı (analiz ve öneriler)',
      where: 'Ana ekran → alt panel → "AI"',
      how: [
        '"Yeni dosyaları analiz et" ile dosyalar türlere ayrılır.',
        'Öneriler sekmesinde ad/klasör önerilerini tek tek ya da toplu seçip uygula.',
      ],
      keywords: ['yapay zeka', 'oneri', 'siniflandir', 'duzenle', 'ai merkezi'],
    ),
    FeatureHelp(
      id: 'ai_chat',
      group: 'AI',
      title: 'Dosyalarına soru sor',
      where: 'AI → "Sohbet" sekmesi',
      how: ['"Kimlik fotokopim nerede?" gibi sor; ilgili dosyalar listelenir.'],
      keywords: ['sohbet', 'soru', 'chat'],
    ),

    // ── Ayarlar ───────────────────────────────────────────────────────
    FeatureHelp(
      id: 'settings',
      group: 'Ayarlar',
      title: 'Ayarlar (tema, dil, güncelleme)',
      where: 'Ana ekran → arama kutusunun sağındaki çark',
      how: ['Koyu tema, dil, AI anahtarı ve güncelleme denetimi burada.'],
      keywords: ['tema', 'karanlik', 'dil', 'guncelle', 'ayar'],
    ),
    FeatureHelp(
      id: 'feature_request',
      group: 'Ayarlar',
      title: 'Özellik iste / öneri gönder',
      where: 'Ara ve Yardım → Yardım → "Özellik iste"',
      how: ['İsteğini yaz, Gönder; istek kaydedilir ve geliştiriciye iletilir.'],
      keywords: ['istek', 'oneri', 'geri bildirim', 'hata bildir'],
    ),
  ];
}
