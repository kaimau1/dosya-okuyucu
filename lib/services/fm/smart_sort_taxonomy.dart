import '../gemini_decisions.dart';

/// **Akıllı düzen sınıflandırma şeması** (2026-11-18, kullanıcı: *"sorulacak
/// sorular, kategorizasyonlar iyi düşünülmüş, araştırılmış … yalnız Türkçe
/// değil, diğer dillerde de"*).
///
/// ## Tasarım ilkeleri
/// * **Talimatlar İngilizce.** Model (gemini-decision-1) İngilizce talimatla
///   en iyi kalibre; belge hangi dilde olursa olsun (Türkçe fatura, Arapça
///   rapor, İngilizce bilet) içeriği okur — soru dili belge dilinden bağımsız.
///   Belirteç farkı yok denecek kadar az (soru başına ~30–60 girdi belirteci;
///   çıktı belirteci SIFIR). Kullanıcıya görünen her şey kimlikten çevrilir
///   (`ss.c_<id>`, `ss.s_<id>`, `ss.m<ay>`): dil değişince ikinci adlar da
///   o dilde yeniden kurulur, kayıtta metin değil KİMLİK durur.
/// * **Kapalı küme, karşılıklı dışlayan.** Model serbest metin yazmaz; ikinci
///   ad = alt tür (yoksa kategori) · kurum · belgedeki ay/yıl.
/// * **Her soruda "none/other" kaçışı** — model zorla yanlış seçmesin.
/// * **Tek istek.** Bütün sorular aynı girdiyle tek geçişte (dosya bir kez
///   faturalanır); alt tür soruları her kategori için birlikte sorulur, yalnız
///   seçilen kategorininki kullanılır.
/// * **Kişisel fotoğrafa ikinci ad verilmez** (her kamera karesine "Kişisel
///   fotoğraf" yazmak gürültü); kategori yine süzgeçte durur.
///
/// ## Ayrıntılı şema (2.0, 2026-11-18 — PLAN §1.1 m.1)
/// * Her belge kategorisinde alt tür (fiş, vergi/SGK, sözleşme, resmî,
///   sigorta/araç, iş, kılavuz; görselde ekran görüntüsü ve fotoğraf).
/// * Kurum: banka (genişledi) + fatura kesen şirket ([providers]: GSM,
///   elektrik, doğalgaz, su, internet/TV); kurum yalnız ilgili kategoride.
/// * Tarih: istekte BUGÜN verilir; son ödeme ([dueBuckets]) ve geçerlilik
///   ([validBuckets]) bugüne göre aralık olarak sorulur → "Ödemesi geçmiş
///   fatura" / "Süresi dolmuş belge" ([SmartDates]).
/// * Tutar aralığı ([amountBuckets]) — Akıllı düzen ekranındaki süzgeç.
/// * APK/arşiv → yalnız [package] kategorisi ve alt türü (kurulum · yedek ·
///   indirme); içerik okunmaz, tek soru.
abstract final class SmartTaxonomy {
  /// **Hassas kategoriler** (B2, 2026-11-19): kimlik, sağlık, banka, vergi.
  /// PIN kuruluysa ve uygulama kilidi kapalıysa listeleri oturumda bir kez
  /// PIN ister (uygulama kilidi açıkken zaten girişte sorulmuştur).
  static const sensitive = {'id', 'health', 'bank', 'tax_salary'};

  /// Belge kategorileri (ikinci ad alır).
  static const docCategories = <String, String>{
    'invoice': 'An invoice or utility bill: electricity, water, natural gas, '
        'phone, internet/TV, rent or building dues.',
    'receipt': 'A shop receipt, POS slip, order confirmation, e-commerce '
        'invoice for a purchase, or other proof of purchase.',
    'bank': 'A banking document: money transfer receipt, account statement, '
        'credit card statement, loan or deposit document.',
    'tax_salary': 'A tax, social security, pension, payroll or salary '
        'document.',
    'contract': 'A contract, agreement, lease, terms and conditions, power of '
        'attorney or other legal agreement.',
    'official': 'An official or government document: e-Government printout, '
        'court or notary paper, petition, official letter, certificate of '
        'residence or registry record.',
    'id': 'An identity document or card: national ID card, passport, driving '
        'licence, residence permit, or a bank/credit card.',
    'health': 'A medical document: lab or blood test result, prescription, '
        "doctor's report, discharge summary, imaging report, vaccination or "
        'appointment record.',
    'insurance_vehicle': 'An insurance policy or claim, or a vehicle '
        'document: registration, inspection, traffic fine.',
    'travel': 'A travel document: flight, bus or train ticket, boarding pass, '
        'hotel or car reservation, visa, itinerary.',
    'education': 'School or university material: diploma, certificate, '
        'transcript, exam paper or result, homework, lecture notes, course '
        'book.',
    'work': 'Work material: CV/résumé, business report, presentation, '
        'spreadsheet, meeting notes, offer or business letter.',
    'manual': 'A product manual, warranty card, user guide, installation '
        'guide or technical datasheet.',
    'reading': 'A book, e-book, magazine, article or other long reading '
        'material.',
    'email': 'A printed or saved e-mail message or newsletter (for example a '
        'mail printed to PDF from Gmail or Outlook), or a saved web page.',
    'note': 'A handwritten note, whiteboard, sticky note or a photo of a '
        'paper that fits none of the other document categories.',
  };

  /// Görsel/ekran kategorileri.
  static const imageCategories = <String, String>{
    'screenshot_chat': 'A screenshot of a messaging app or social media '
        'conversation.',
    'screenshot': 'Any other screenshot of a phone or computer screen: app, '
        'website, map, settings, game.',
    'greeting': 'A greeting or celebration image card: good morning / good '
        'night, religious or national holiday wishes, Friday blessing, '
        'birthday or anniversary card, inspirational quote image.',
    'meme': 'A meme, joke image, cartoon, sticker-like image or viral picture.',
    'photo_people': 'A personal camera photo in which people are the main '
        'subject.',
    'photo_other': 'A personal camera photo of a place, food, object, pet, '
        'vehicle or nature, with no document in it.',
  };

  /// Kurulum dosyası / arşiv (APK ve sıkıştırılmış arşivler YALNIZ bu
  /// kategoriye girer; alt türü ad · boyut · klasörden seçilir).
  static const package = 'package';

  /// Ses kaydı / video (2026-11-18, PLAN §1.1 m.2): kategori uzantıdan
  /// kesin; alt türü (sesli not, toplantı… / aile videosu, ekran kaydı…)
  /// dosyanın kendisinden tek istekte sorulur.
  static const audio = 'audio';
  static const video = 'video';

  static const other = 'other';

  /// Uzantıdan kesin kategoriler (kategori sorulmaz; öğrenme çevirmez).
  static const fixedCategories = {package, audio, video};

  /// Bütün kategori kimlikleri (sıralı: belge → görsel → ses/video →
  /// kurulum → diğer).
  static List<String> get categoryIds => [
        ...docCategories.keys,
        ...imageCategories.keys,
        audio,
        video,
        package,
        other,
      ];

  static bool isDoc(String cat) => docCategories.containsKey(cat);

  /// Kişisel fotoğraf: ikinci ad almaz.
  static bool isPersonalPhoto(String cat) =>
      cat == 'photo_people' || cat == 'photo_other';

  /// Hassas kategoriler (kilit açıkken görünür).
  static const sensitive = {'id', 'health', 'bank', 'tax_salary'};

  /// Gereksiz sayılan kategoriler (Ayıkla).
  static const clutterCategories = {'greeting', 'meme'};

  /// Alt türler: kategori → (kimlik → İngilizce açıklama). Her listede
  /// `other` kaçışı var. Alt tür kimlikleri BÜTÜN kategorilerde tekil
  /// (çeviri anahtarı `sm.s_<kimlik>`; test denetler).
  static const subtypes = <String, Map<String, String>>{
    'invoice': {
      'electricity': 'Electricity bill.',
      'water': 'Water bill.',
      'natural_gas': 'Natural gas or heating bill.',
      'mobile_phone': 'Mobile or landline phone bill.',
      'internet_tv': 'Internet, cable or TV subscription bill.',
      'rent_dues': 'Rent, building dues or maintenance fee.',
      'other': 'Another kind of invoice or bill.',
    },
    'receipt': {
      'grocery': 'A supermarket or grocery store receipt.',
      'restaurant': 'A restaurant, cafe or food delivery receipt.',
      'fuel': 'A fuel station receipt.',
      'online_order': 'An online shopping order, e-commerce invoice or '
          'delivery confirmation.',
      'pharmacy': 'A pharmacy receipt.',
      'other': 'Another kind of receipt.',
    },
    'bank': {
      'transfer': 'A money transfer / payment receipt (EFT, wire, FAST, '
          'remittance).',
      'account_statement': 'A bank account statement.',
      'card_statement': 'A credit card statement.',
      'loan': 'A loan, mortgage or installment document.',
      'other': 'Another banking document.',
    },
    'tax_salary': {
      'payslip': 'A payslip or payroll statement.',
      'tax_certificate': 'A tax registration certificate, tax return or tax '
          'assessment.',
      'service_record': 'A social security service record or contribution '
          'statement.',
      'pension': 'A pension or retirement document.',
      'other': 'Another tax or social security document.',
    },
    'contract': {
      'rental': 'A rental or lease agreement.',
      'employment': 'An employment contract.',
      'sales': 'A sales or purchase agreement.',
      'subscription': 'A subscription or service agreement (phone, internet, '
          'gym and similar).',
      'power_of_attorney': 'A power of attorney.',
      'other': 'Another kind of contract.',
    },
    'official': {
      'e_government': 'An e-Government printout or online official '
          'certificate.',
      'court': 'A court, enforcement or bailiff document.',
      'notary': 'A notary document.',
      'land_registry': 'A land registry or title deed document.',
      'civil_registry': 'A civil registry, population or residence '
          'certificate.',
      'military': 'A military service document.',
      'other': 'Another official document.',
    },
    'health': {
      'lab_result': 'A laboratory or blood test result.',
      'prescription': 'A prescription.',
      'medical_report': "A doctor's report, medical certificate or sick note.",
      'imaging': 'A radiology / imaging report or image (X-ray, MRI, CT, '
          'ultrasound).',
      'discharge': 'A hospital discharge summary or epicrisis.',
      'other': 'Another medical document.',
    },
    'id': {
      'id_card': 'A national identity card.',
      'passport': 'A passport.',
      'driving_licence': 'A driving licence.',
      'residence_permit': 'A residence or work permit.',
      'bank_card': 'A bank, debit or credit card.',
      'other': 'Another identity document.',
    },
    'insurance_vehicle': {
      'traffic_insurance': 'A compulsory motor (traffic) insurance policy.',
      'casco': 'A comprehensive car insurance (casco) policy.',
      'health_insurance': 'A health or life insurance policy.',
      'vehicle_registration': 'A vehicle registration certificate.',
      'vehicle_inspection': 'A vehicle inspection report.',
      'traffic_fine': 'A traffic fine or penalty notice.',
      'other': 'Another insurance or vehicle document.',
    },
    'travel': {
      'flight': 'A flight ticket or boarding pass.',
      'bus': 'A bus or coach ticket.',
      'train': 'A train or metro ticket.',
      'hotel': 'A hotel or accommodation reservation.',
      'visa': 'A visa or entry permit.',
      'other': 'Another travel document.',
    },
    'education': {
      'diploma': 'A diploma, degree or certificate of completion.',
      'transcript': 'A transcript, report card or grade list.',
      'exam': 'An exam paper, test or exam result.',
      'homework': 'Homework or an assignment.',
      'lecture_notes': 'Lecture notes or study notes.',
      'other': 'Other education material.',
    },
    'work': {
      'cv': 'A CV or résumé.',
      'report': 'A business report or analysis.',
      'presentation': 'A business presentation or slide deck.',
      'spreadsheet': 'A business spreadsheet, list or table.',
      'quote_order': 'A price quote, offer, proposal or purchase order.',
      'meeting': 'Meeting notes, minutes or an agenda.',
      'other': 'Other work material.',
    },
    'manual': {
      'user_manual': 'A product user manual or user guide.',
      'warranty': 'A warranty card or warranty certificate.',
      'installation': 'An installation or assembly guide.',
      'other': 'Another manual or technical document.',
    },
    'screenshot': {
      'map': 'A screenshot of a map, route or location.',
      'shopping': 'A screenshot of a shopping app, product page or cart.',
      'social': 'A screenshot of a social media post or profile (not a '
          'chat).',
      'settings': 'A screenshot of phone or app settings.',
      'game': 'A screenshot of a game.',
      'ticket_qr': 'A screenshot of a ticket, QR code, pass or booking.',
      'other': 'Another kind of screenshot.',
    },
    'photo_other': {
      'food': 'A photo of food or drink.',
      'landscape': 'A photo of a landscape, city or nature.',
      'product': 'A photo of a product or object.',
      'pet': 'A photo of a pet or animal.',
      'vehicle': 'A photo of a car or other vehicle.',
      'other': 'Another kind of photo.',
    },
    package: {
      'installer': 'An app installer package, downloaded to install an app.',
      'backup': 'A backup: chat, app or phone backup, or an archive of older '
          'files kept for safety.',
      'download': 'An archive downloaded from the web or received from '
          'someone (documents, photos, project files).',
      'other': 'None of these.',
    },
    audio: _audioSubs,
    video: _videoSubs,
  };

  /// Konuşma dili (ses). Kimlik ISO 639-1; `none` = konuşma yok (müzik,
  /// sessizlik). Görünen ad `sm.l_<kimlik>`.
  static const speechLanguages = <String, String>{
    'tr': 'Turkish',
    'en': 'English',
    'ar': 'Arabic',
    'ku': 'Kurdish',
    'de': 'German',
    'fr': 'French',
    'ru': 'Russian',
    'fa': 'Persian',
    'es': 'Spanish',
    'az': 'Azerbaijani',
    'other': 'Another language.',
    'none': 'There is no speech (music only, silence or noise).',
  };

  /// Ses kalitesi / gürültü.
  static const audioQualities = <String, String>{
    'clear': 'Clear: speech or music is easy to hear, little background '
        'noise.',
    'noisy': 'Noisy: strong background noise (street, wind, crowd, music) '
        'but still understandable.',
    'poor': 'Poor: very hard to understand, distorted, cut off, mostly '
        'silence or recorded by accident (for example in a pocket).',
  };

  /// Alt tür sorusu yalnız görselde sorulan kategoriler.
  static const _imageOnlySubs = {'screenshot', 'photo_other'};

  static const _subjects = {
    'invoice': 'an invoice or bill',
    'receipt': 'a receipt or proof of purchase',
    'bank': 'a banking document',
    'tax_salary': 'a tax, social security or payroll document',
    'contract': 'a contract or agreement',
    'official': 'an official or government document',
    'health': 'a medical document',
    'id': 'an identity document or card',
    'insurance_vehicle': 'an insurance or vehicle document',
    'travel': 'a travel document',
    'education': 'school or education material',
    'work': 'work material',
    'manual': 'a manual, guide or warranty',
    'screenshot': 'a screenshot (not of a chat)',
    'photo_other': 'a personal photo without people or documents',
  };

  /// Alt türün kategorisi (yoksa null).
  static String? categoryOfSub(String sub) {
    if (sub.isEmpty || sub == other) return null;
    for (final e in subtypes.entries) {
      if (e.value.containsKey(sub)) return e.key;
    }
    return null;
  }

  /// Kurum soruları (yalnız banka belgesinde kullanılır). Özel adlar
  /// çevrilmez. Türkiye'deki en yaygın bankalar + kaçış.
  static const banks = <String, String>{
    'ziraat': 'Ziraat Bankası',
    'isbank': 'Türkiye İş Bankası',
    'garanti': 'Garanti BBVA',
    'akbank': 'Akbank',
    'yapikredi': 'Yapı Kredi',
    'halkbank': 'Halkbank',
    'vakifbank': 'VakıfBank',
    'qnb': 'QNB',
    'denizbank': 'DenizBank',
    'enpara': 'Enpara',
    'teb': 'TEB',
    'ing': 'ING',
    'kuveytturk': 'Kuveyt Türk',
    'turkiyefinans': 'Türkiye Finans',
    'albaraka': 'Albaraka Türk',
    'ziraatkatilim': 'Ziraat Katılım',
    'vakifkatilim': 'Vakıf Katılım',
    'emlakkatilim': 'Emlak Katılım',
    'sekerbank': 'Şekerbank',
    'odeabank': 'Odeabank',
    'fibabanka': 'Fibabanka',
    'hsbc': 'HSBC',
    'anadolubank': 'Anadolubank',
    'alternatif': 'Alternatif Bank',
    'burgan': 'Burgan Bank',
    'other': 'Another bank or not stated.',
  };

  static String bankName(String id) => id == 'other' ? '' : (banks[id] ?? '');

  /// Fatura kesen kurumlar: GSM, internet/TV, elektrik, doğalgaz, su —
  /// Türkiye'de en yaygın olanlar + kaçış. Ayraçtaki açıklama yalnız modele
  /// gider; görünen ad ayraçtan öncesi ([providerName]).
  static const providers = <String, String>{
    'turkcell': 'Turkcell (mobile, Superonline internet)',
    'vodafone': 'Vodafone',
    'turktelekom': 'Türk Telekom (mobile, landline, internet)',
    'turknet': 'TurkNet',
    'digiturk': 'Digiturk',
    'dsmart': 'D-Smart',
    'enerjisa': 'Enerjisa (electricity: Başkent, İstanbul Anadolu Yakası, '
        'Toroslar)',
    'ck_enerji': 'CK Enerji (electricity: Boğaziçi, Çamlıbel, Akdeniz, Aras)',
    'aydem': 'Aydem (electricity: Aydem, Gediz, ADM)',
    'uludag': 'Uludağ Elektrik (electricity, UEDAŞ)',
    'sepas': 'Sepaş (electricity, SEDAŞ)',
    'dicle': 'Dicle Elektrik (electricity, Dicle EDAŞ)',
    'osmangazi': 'Osmangazi Elektrik (electricity, OEDAŞ)',
    'igdas': 'İGDAŞ (natural gas, İstanbul)',
    'baskentgaz': 'Başkentgaz (natural gas, Ankara)',
    'izmirgaz': 'İzmirgaz (natural gas)',
    'enerya': 'Enerya (natural gas)',
    'aksagaz': 'Aksa Doğalgaz (natural gas)',
    'bursagaz': 'Bursagaz (natural gas)',
    'iski': 'İSKİ (water, İstanbul)',
    'aski': 'ASKİ (water, Ankara)',
    'izsu': 'İZSU (water, İzmir)',
    'buski': 'BUSKİ (water, Bursa)',
    'other': 'Another company or not stated.',
  };

  /// Kurum → uyduğu fatura alt türleri ("kurum yalnız ilgili kategoride").
  static const _providerSubs = <String, Set<String>>{
    'turkcell': {'mobile_phone', 'internet_tv'},
    'vodafone': {'mobile_phone', 'internet_tv'},
    'turktelekom': {'mobile_phone', 'internet_tv'},
    'turknet': {'internet_tv'},
    'digiturk': {'internet_tv'},
    'dsmart': {'internet_tv'},
    'enerjisa': {'electricity'},
    'ck_enerji': {'electricity'},
    'aydem': {'electricity'},
    'uludag': {'electricity'},
    'sepas': {'electricity'},
    'dicle': {'electricity'},
    'osmangazi': {'electricity'},
    'igdas': {'natural_gas'},
    'baskentgaz': {'natural_gas'},
    'izmirgaz': {'natural_gas'},
    'enerya': {'natural_gas'},
    'aksagaz': {'natural_gas'},
    'bursagaz': {'natural_gas'},
    'iski': {'water'},
    'aski': {'water'},
    'izsu': {'water'},
    'buski': {'water'},
  };

  /// Kurum bu kategoride/alt türde anlamlı mı? Yalnız faturada; alt tür
  /// biliniyorsa kurumun hizmetiyle uyuşmalı (elektrik faturasına GSM
  /// şirketi yazılmaz). Alt tür yoksa her bilinen kurum geçer.
  static bool providerFits(String provider, String cat, String sub) {
    if (cat != 'invoice') return false;
    final subs = _providerSubs[provider];
    if (subs == null) return false;
    return sub.isEmpty || sub == other || subs.contains(sub);
  }

  /// Kurumun görünen adı (ayraçtaki model açıklaması atılır).
  static String providerName(String id) {
    if (id.isEmpty || id == other) return '';
    final v = providers[id] ?? '';
    final cut = v.indexOf(' (');
    return cut < 0 ? v : v.substring(0, cut);
  }

  /// Belgedeki ay (1–12) + yok.
  static const months = {
    '1': 'January', '2': 'February', '3': 'March', '4': 'April', '5': 'May',
    '6': 'June', '7': 'July', '8': 'August', '9': 'September',
    '10': 'October', '11': 'November', '12': 'December',
    'none': 'No clear document date is visible.',
  };

  /// Belgedeki yıl: son 8 yıl + daha eski + yok.
  static Map<String, String> years(int now) => {
        for (var y = now; y > now - 8; y--) '$y': '$y',
        'older': 'Before ${now - 7}.',
        'none': 'No clear document year is visible.',
      };

  /// Son ödeme tarihi — istekteki BUGÜNE göre aralık ([SmartDates.overdue]).
  static const dueBuckets = <String, String>{
    'past': 'The payment due date is before today.',
    'week': 'The payment due date is today or within the next 7 days.',
    'month': 'The payment due date is 8 to 31 days after today.',
    'later': 'The payment due date is more than 31 days after today.',
    'none': 'No payment due date is visible.',
  };

  /// Geçerlilik / bitiş tarihi — istekteki bugüne göre aralık.
  static const validBuckets = <String, String>{
    'past': 'It has already expired: its expiry or validity end date is '
        'before today.',
    'month': 'It expires today or within the next 31 days.',
    'year': 'It expires 32 days to one year after today.',
    'later': 'It expires more than one year after today.',
    'none': 'No expiry or validity end date is visible.',
  };

  /// Son ödeme tarihi anlamlı kategoriler.
  static const dueCategories = {'invoice'};

  /// Geçerlilik tarihi anlamlı (süresi dolabilen) kategoriler.
  static const expiringCategories = {
    'id', 'insurance_vehicle', 'contract', 'travel', 'manual', 'official',
    'health',
  };

  /// Tutar aralığı (toplam ödenecek / ödenen).
  static const amountBuckets = <String, String>{
    'lt100': 'The total amount is less than 100 (in the currency shown).',
    '100_500': 'The total amount is between 100 and 500.',
    '500_2000': 'The total amount is between 500 and 2000.',
    'gt2000': 'The total amount is more than 2000.',
    'none': 'No total amount is visible.',
  };

  /// Tutar sorulan kategoriler.
  static const amountCategories = {'invoice', 'receipt', 'bank'};

  /// Süzgeç sırası ("yok" hariç).
  static const amountOrder = ['lt100', '100_500', '500_2000', 'gt2000'];

  /// Görsel kategorisi mi (ekran görüntüsü, fotoğraf, kutlama, caps)?
  static bool isImageCat(String cat) => imageCategories.containsKey(cat);

  /// İstekteki "bugün" (YYYY-AA-GG).
  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Tek istekte sorulan sorular. [image] görsel mi (bulanıklık soruları ve
  /// görsel kategorileri yalnız görselde — PDF/belgeye "ekran görüntüsü"
  /// seçeneği sunulmaz; kök 2026-11-18: Gmail'den yazdırılan e-posta PDF'i
  /// "Ekran görüntüsü" çıkıyordu), [nowYear] yıl seçenekleri için, [today]
  /// son ödeme / geçerlilik aralıkları için (verilmezse şimdi).
  ///
  /// [meta] (APK/arşiv, içerik okunmaz): kategori sabit [package], yalnız
  /// alt türü sorulur (tek soru).
  ///
  /// [learned] (2026-11-18): kullanıcının düzeltmelerinden geri bildirim
  /// (`SmartLearn.hint` — yalnız kategori kimlikleri ve sayılar) kategori
  /// sorusunun talimatına eklenir.
  static List<DecisionQuestion> questions({
    required bool image,
    bool meta = false,
    bool audio = false,
    bool video = false,
    int? nowYear,
    DateTime? today,
    String learned = '',
  }) {
    if (audio) return audioQuestions;
    if (video) return videoQuestions;
    if (meta) {
      return [
        DecisionQuestion.choice(
          'sub_$package',
          'sub_$package',
          'Only the name, type, size and folder of this app package or '
              'archive are known. What is it most likely?',
          subtypes[package]!,
        ),
      ];
    }
    final now = today ?? DateTime.now();
    final year = nowYear ?? now.year;
    final day = isoDay(now);
    final tail = learned.isEmpty ? '' : ' $learned';
    return [
      DecisionQuestion.choice(
        'cat',
        'cat',
        (image
                ? 'What kind of file is this? Judge by its content (whatever '
                    'its language), not by the file name.'
                : 'This is a document file (PDF or text). What kind of '
                    'document is it? Judge by its content (whatever its '
                    'language), not by the file name or how the pages look.') +
            tail,
        {
          ...docCategories,
          if (image) ...imageCategories,
          other: 'None of the above.',
        },
      ),
      for (final e in subtypes.entries)
        if (!fixedCategories.contains(e.key) && (image || !_imageOnlySubs.contains(e.key)))
          DecisionQuestion.choice(
            'sub_${e.key}',
            'sub_${e.key}',
            'If this is ${_subjects[e.key]}, which kind is it? If it is not, '
                'choose "other".',
            e.value,
          ),
      const DecisionQuestion.choice(
        'bank_name',
        'bank_name',
        'If this is a banking document, which bank issued it?',
        banks,
      ),
      const DecisionQuestion.choice(
        'provider',
        'provider',
        'If this is an invoice or bill (phone, internet/TV, electricity, '
            'natural gas or water), which company issued it? If it is not a '
            'bill, choose "other".',
        providers,
      ),
      const DecisionQuestion.choice(
        'month',
        'month',
        'In which month is the document dated (issue, invoice or statement '
            'date)? Use the date printed in the content, not the file date.',
        months,
      ),
      DecisionQuestion.choice(
        'year',
        'year',
        'In which year is the document dated? Use the date printed in the '
            'content, not the file date.',
        years(year),
      ),
      DecisionQuestion.choice(
        'due',
        'due',
        'Today is $day. If this is a bill or invoice with a payment due date '
            '(last payment date) printed on it, when is that date compared '
            'with today? Otherwise choose "none".',
        dueBuckets,
      ),
      DecisionQuestion.choice(
        'valid',
        'valid',
        'Today is $day. If this document has an expiry or validity end date '
            '(ID card, passport, licence, insurance policy, contract end, '
            'warranty, visa, permit, report validity), when is that date '
            'compared with today? Otherwise choose "none".',
        validBuckets,
      ),
      const DecisionQuestion.choice(
        'amount',
        'amount',
        'If this is a bill, receipt or banking document, what is the total '
            'amount to pay or paid (the grand total, not a single line)?',
        amountBuckets,
      ),
      if (image) ...const [
        DecisionQuestion.yesNo(
          'blurry',
          'blurry',
          'Is the image clearly blurry, out of focus or motion-blurred so '
              'that its main subject is hard to see?',
        ),
        DecisionQuestion.yesNo(
          'accidental',
          'accidental',
          'Does this look like an accidental shot: pocket photo, finger over '
              'the lens, almost completely black or white, floor or ceiling, '
              'or nothing recognisable?',
        ),
      ],
    ];
  }

  /// Ses kaydı soruları (tek istek, 3 soru): tür, konuşma dili, kalite.
  static const audioQuestions = [
    DecisionQuestion.choice(
      'sub_$audio',
      'sub_$audio',
      'This is an audio recording. Listen to it: what kind of recording is '
          'it? Judge by the sound, not by the file name.',
      _audioSubs,
    ),
    DecisionQuestion.choice(
      'speech_lang',
      'speech_lang',
      'Which language is mainly spoken in this recording?',
      speechLanguages,
    ),
    DecisionQuestion.choice(
      'quality',
      'quality',
      'How is the sound quality of this recording?',
      audioQualities,
    ),
  ];

  /// Video soruları (yalnız ilk 60 sn, düşük çözünürlük): tür + yanlışlıkla.
  static const videoQuestions = [
    DecisionQuestion.choice(
      'sub_$video',
      'sub_$video',
      'This is the beginning of a video. What kind of video is it? Judge by '
          'what is seen and heard, not by the file name.',
      _videoSubs,
    ),
    DecisionQuestion.yesNo(
      'accidental',
      'accidental',
      'Does this look like an accidental or useless recording: filmed in a '
          'pocket, almost completely dark or black, pointing at the floor or '
          'ceiling, only a second or two long, or nothing recognisable?',
    ),
  ];

  // [subtypes] ve soru listeleri aynı sabit haritaları paylaşır.
  static const _audioSubs = {
    'voice_note': 'A personal voice note or voice memo: one person '
        'speaking to themselves (reminder, idea, list).',
    'whatsapp_voice': 'A voice message sent in a messaging app (WhatsApp, '
        'Telegram…): short, informal, spoken to another person.',
    'meeting_recording': 'A recording of a meeting, interview or group discussion '
        'with several speakers.',
    'lecture': 'A recording of a lesson, lecture, seminar, sermon, talk or '
        'podcast.',
    'call_recording': 'A recording of a phone call: two sides, narrow '
        'telephone sound.',
    'music': 'Music or a song (with or without singing), or a ringtone.',
    'other': 'None of these.',
  };
  static const _videoSubs = {
    'family_video': 'A personal or family video: people, children, a '
        'celebration, a trip, pets or daily life.',
    'screen_recording': 'A screen recording of a phone or computer screen.',
    'lecture_video': 'A lesson, lecture, tutorial, course or talk.',
    'clip_meme': 'A forwarded clip, meme, funny or viral video, greeting '
        'video or social media video.',
    'document_video': 'A video of a document, whiteboard, blackboard, '
        'slides or a paper being shown.',
    'other': 'None of these.',
  };

  /// Ekranda gösterilen her kategori için arama eşanlamları (dilden bağımsız,
  /// küçük harf). Çeviri tablosundaki üç dildeki adlara EK olarak aranır.
  static const synonyms = <String, List<String>>{
    'invoice': ['bill', 'utility', 'fatura', 'فاتورة', 'elektrik', 'su', 'doğalgaz'],
    'receipt': ['fiş', 'makbuz', 'receipt', 'siparis', 'sipariş', 'إيصال'],
    'bank': ['dekont', 'ekstre', 'statement', 'iban', 'havale', 'eft', 'بنك'],
    'tax_salary': ['vergi', 'sgk', 'bordro', 'maaş', 'payroll', 'tax', 'ضريبة'],
    'contract': ['sözleşme', 'kira', 'agreement', 'lease', 'عقد'],
    'official': ['e-devlet', 'edevlet', 'resmi', 'resmî', 'noter', 'mahkeme', 'رسمي'],
    'id': ['kimlik', 'pasaport', 'ehliyet', 'passport', 'license', 'هوية'],
    'health': ['tahlil', 'reçete', 'rapor', 'epikriz', 'hastane', 'lab', 'medical', 'طبي'],
    'insurance_vehicle': ['sigorta', 'poliçe', 'ruhsat', 'muayene', 'insurance', 'تأمين'],
    'travel': ['bilet', 'uçak', 'otel', 'vize', 'ticket', 'boarding', 'تذكرة'],
    'education': ['okul', 'diploma', 'sınav', 'ödev', 'transkript', 'school', 'exam'],
    'work': ['iş', 'cv', 'özgeçmiş', 'rapor', 'sunum', 'work', 'resume'],
    'manual': ['kılavuz', 'garanti', 'manual', 'warranty', 'دليل'],
    'reading': ['kitap', 'makale', 'book', 'article', 'كتاب'],
    'email': ['e-posta', 'eposta', 'mail', 'gmail', 'email', 'bülten', 'newsletter', 'بريد'],
    'note': ['not', 'tahta', 'whiteboard', 'note', 'ملاحظة'],
    'screenshot_chat': ['ekran görüntüsü', 'sohbet', 'screenshot', 'chat', 'whatsapp'],
    'screenshot': ['ekran görüntüsü', 'screenshot', 'لقطة شاشة'],
    'greeting': ['günaydın', 'iyi geceler', 'bayram', 'kandil', 'cuma', 'kutlama', 'greeting', 'تهنئة'],
    'meme': ['caps', 'mizah', 'meme', 'komik', 'ميم'],
    'photo_people': ['fotoğraf', 'photo', 'insan', 'people', 'selfie'],
    'photo_other': ['fotoğraf', 'photo', 'manzara', 'yemek'],
    'audio': ['ses', 'kayıt', 'sesli not', 'ses kaydı', 'audio', 'recording', 'voice', 'تسجيل'],
    'video': ['video', 'klip', 'ekran kaydı', 'clip', 'فيديو'],
    'package': ['apk', 'kurulum', 'arşiv', 'zip', 'rar', 'yedek', 'installer', 'archive', 'backup', 'أرشيف'],
  };
}

/// **Tarih rozetleri** (2026-11-18, PLAN §1.1 m.1): model son ödeme /
/// geçerlilik tarihini istekteki BUGÜNE göre aralık olarak verir; kayıtta
/// aralık + sorulduğu gün durur. Zaman geçtikçe "bir hafta içinde" olan
/// fatura kendiliğinden "ödemesi geçmiş" olur — yeniden sormadan. Saf,
/// birim testli. Gün = UTC gün numarası (1970'ten beri).
abstract final class SmartDates {
  static int dayOf(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Son ödeme tarihi [today] itibarıyla kesin geçmiş mi? [asked] sorunun
  /// sorulduğu gün; 0 = bilinmiyor (yalnız "geçmiş" yanıtı sayılır).
  static bool overdue(String bucket, int asked, int today) => switch (bucket) {
        'past' => true,
        'week' => asked > 0 && today - asked > 7,
        'month' => asked > 0 && today - asked > 31,
        _ => false,
      };

  /// Geçerlilik tarihi [today] itibarıyla kesin dolmuş mu?
  static bool expired(String bucket, int asked, int today) => switch (bucket) {
        'past' => true,
        'month' => asked > 0 && today - asked > 31,
        'year' => asked > 0 && today - asked > 366,
        _ => false,
      };
}
