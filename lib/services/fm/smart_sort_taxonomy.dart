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
/// Akıllı klasör grupları (ekrandaki hızlı grup süzgeci için).
enum SmartCatGroup { all, finance, docs, images, media }

abstract final class SmartTaxonomy {
  /// Belge kategorileri (ikinci ad alır).
  static const docCategories = <String, String>{
    'invoice': 'Invoice/utility bill: electricity, water, gas, phone, internet/TV, rent, dues.',
    'receipt': 'Shop receipt, POS slip, order confirmation or e-commerce purchase proof.',
    'bank': 'Banking doc: transfer receipt, account/card statement, loan or deposit.',
    'tax_salary': 'Tax, social security, pension, payroll or salary doc.',
    'contract': 'Contract, lease, agreement, terms or power of attorney.',
    'official': 'Official/gov doc: e-Gov printout, court, notary, petition, registry.',
    'id': 'ID card, passport, licence, residence permit or bank/credit card.',
    'health': 'Medical doc: lab/blood test, prescription, doctor report, imaging, epicrisis, vaccine, appointment.',
    'insurance_vehicle': 'Insurance policy/claim or vehicle doc: registration, inspection, traffic fine.',
    'travel': 'Travel doc: flight/bus/train ticket, boarding pass, hotel/car booking, visa.',
    'education': 'School/uni: diploma, certificate, transcript, exam, homework, lecture notes.',
    'work': 'Work: CV, business report, slides, spreadsheet, meeting notes, quote/letter.',
    'manual': 'Product manual, warranty, user/install guide or datasheet.',
    'reading': 'Book, e-book, magazine, article or long reading.',
    'email': 'Printed/saved e-mail, newsletter or saved web page.',
    // 2026-11-20: davetiye / etkinlik duyurusu eskiden "kutlama" (Ayıkla
    // = silme önerisi) ya da "diğer"e düşüyordu.
    'event': 'Invitation (wedding/ceremony/graduation), event poster/announcement, or concert/cinema/match/museum ticket.',
    'note': 'Handwritten note, whiteboard, sticky note or uncategorized paper photo.',
  };

  /// Görsel/ekran kategorileri.
  static const imageCategories = <String, String>{
    'screenshot_chat': 'Chat or messaging app conversation screenshot.',
    'screenshot': 'Other phone/PC screenshot: app, web, map, settings, game.',
    'greeting': 'Greeting/holiday/blessing/quote image card (NOT invitation, poster or event).',
    'meme': 'Meme, joke, cartoon, sticker or viral picture.',
    'photo_people': 'Personal photo with people as main subject.',
    'photo_other': 'Personal photo of place, food, object, pet, vehicle or nature (no document).',
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

  /// Kategori → ekran grubu (`other` yalnız "Tümü"nde).
  static SmartCatGroup? groupOf(String cat) {
    if (const {'invoice', 'receipt', 'bank', 'tax_salary'}.contains(cat)) {
      return SmartCatGroup.finance;
    }
    if (docCategories.containsKey(cat)) return SmartCatGroup.docs;
    if (imageCategories.containsKey(cat)) return SmartCatGroup.images;
    if (fixedCategories.contains(cat)) return SmartCatGroup.media;
    return null;
  }

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

  /// Hassas kategoriler (B2, 2026-11-19): PIN kuruluysa ve uygulama kilidi
  /// kapalıysa Akıllı düzen listeleri oturumda bir kez PIN ister (uygulama
  /// kilidi açıkken girişte zaten sorulmuştur).
  static const sensitive = {'id', 'health', 'bank', 'tax_salary'};

  /// Gereksiz sayılan kategoriler (Ayıkla).
  static const clutterCategories = {'greeting', 'meme'};

  /// Alt türler: kategori → (kimlik → İngilizce açıklama). Her listede
  /// `other` kaçışı var. Alt tür kimlikleri BÜTÜN kategorilerde tekil
  /// (çeviri anahtarı `sm.s_<kimlik>`; test denetler).
  static const subtypes = <String, Map<String, String>>{
    'invoice': {
      'electricity': 'Electricity bill',
      'water': 'Water bill',
      'natural_gas': 'Gas/heating bill',
      'mobile_phone': 'Phone bill',
      'internet_tv': 'Internet/TV bill',
      'rent_dues': 'Rent/building dues',
      'other': 'Other bill',
    },
    'receipt': {
      'grocery': 'Grocery/supermarket receipt',
      'restaurant': 'Restaurant/cafe/food delivery receipt',
      'fuel': 'Fuel station receipt',
      'online_order': 'Online order/e-commerce invoice',
      'pharmacy': 'Pharmacy receipt',
      'other': 'Other receipt',
    },
    'bank': {
      'transfer': 'Transfer receipt (EFT/wire/FAST)',
      'account_statement': 'Bank account statement',
      'card_statement': 'Credit card statement',
      'loan': 'Loan/mortgage/installment doc',
      'other': 'Other banking doc',
    },
    'tax_salary': {
      'payslip': 'Payslip/payroll',
      'tax_certificate': 'Tax certificate/return/assessment',
      'service_record': 'Social security service record',
      'pension': 'Pension/retirement doc',
      'other': 'Other tax/SS doc',
    },
    'contract': {
      'rental': 'Rental/lease agreement',
      'employment': 'Employment contract',
      'sales': 'Sales/purchase agreement',
      'subscription': 'Subscription/service agreement',
      'power_of_attorney': 'Power of attorney',
      'other': 'Other contract',
    },
    'official': {
      'e_government': 'e-Gov printout/certificate',
      'court': 'Court/enforcement doc',
      'notary': 'Notary doc',
      'land_registry': 'Land registry/title deed',
      'civil_registry': 'Civil registry/residence cert',
      'military': 'Military service doc',
      'petition': 'Petition/application letter',
      'other': 'Other official doc',
    },
    'health': {
      'lab_result': 'Lab/blood test result',
      'prescription': 'Prescription',
      'medical_report': 'Doctor report/sick note',
      'imaging': 'Radiology/X-ray/MRI/CT/US report',
      'discharge': 'Discharge summary/epicrisis',
      'vaccination': 'Vaccination record',
      'appointment': 'Appointment slip/reminder',
      'other': 'Other medical doc',
    },
    'id': {
      'id_card': 'National ID card',
      'passport': 'Passport',
      'driving_licence': 'Driving licence',
      'residence_permit': 'Residence/work permit',
      'bank_card': 'Bank/credit card',
      'other': 'Other ID doc',
    },
    'insurance_vehicle': {
      'traffic_insurance': 'Traffic insurance policy',
      'casco': 'Comprehensive car insurance (casco)',
      'health_insurance': 'Health/life insurance policy',
      'vehicle_registration': 'Vehicle registration',
      'vehicle_inspection': 'Vehicle inspection report',
      'traffic_fine': 'Traffic fine notice',
      'other': 'Other insurance/vehicle doc',
    },
    'travel': {
      'flight': 'Flight ticket/boarding pass',
      'bus': 'Bus/coach ticket',
      'train': 'Train/metro ticket',
      'hotel': 'Hotel reservation',
      'visa': 'Visa/entry permit',
      'other': 'Other travel doc',
    },
    'education': {
      'diploma': 'Diploma/certificate',
      'transcript': 'Transcript/grade list',
      'exam': 'Exam paper/result',
      'homework': 'Homework/assignment',
      'lecture_notes': 'Lecture/study notes',
      'other': 'Other education material',
    },
    'work': {
      'cv': 'CV/résumé',
      'report': 'Business report/analysis',
      'presentation': 'Presentation/slides',
      'spreadsheet': 'Spreadsheet/table',
      'quote_order': 'Quote/offer/purchase order',
      'meeting': 'Meeting notes/agenda',
      'other': 'Other work material',
    },
    'manual': {
      'user_manual': 'User manual/guide',
      'warranty': 'Warranty card/cert',
      'installation': 'Installation/assembly guide',
      'other': 'Other manual',
    },
    'screenshot': {
      'map': 'Map/route',
      'shopping': 'Shopping app/product/cart',
      'social': 'Social media post/profile (not chat)',
      'settings': 'Phone/app settings',
      'game': 'Game',
      'ticket_qr': 'Ticket/QR/booking',
      'bank_app': 'Banking/payment/wallet app',
      'doc_page': 'Document/PDF/article page',
      'other': 'Other screenshot',
    },
    'event': {
      'wedding': 'Wedding/engagement invitation',
      'ceremony': 'Ceremony/opening/graduation invite',
      'announcement': 'Event poster/public announcement',
      'event_ticket': 'Concert/cinema/theatre/match/museum ticket',
      'other': 'Other event',
    },
    'photo_other': {
      'food': 'Food/drink',
      'landscape': 'Landscape/city/nature',
      'product': 'Product/object',
      'pet': 'Pet/animal',
      'vehicle': 'Car/vehicle',
      'other': 'Other photo',
    },
    package: {
      'installer': 'App installer package',
      'backup': 'Chat/app/phone backup archive',
      'download': 'Downloaded/shared archive',
      'other': 'Other',
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
    'other': 'Other language',
    'none': 'No speech (music/silence/noise)',
  };

  /// Ses kalitesi / gürültü.
  static const audioQualities = <String, String>{
    'clear': 'Clear speech/music, low noise',
    'noisy': 'Noisy background, still intelligible',
    'poor': 'Distorted, cut off, mostly silence or pocket recording',
  };

  /// Alt tür sorusu yalnız görselde sorulan kategoriler.
  static const _imageOnlySubs = {'screenshot', 'photo_other'};

  static const _subjects = {
    'invoice': 'invoice/bill',
    'receipt': 'receipt',
    'bank': 'banking doc',
    'tax_salary': 'tax/payroll doc',
    'contract': 'contract',
    'official': 'official doc',
    'health': 'medical doc',
    'id': 'ID/card',
    'insurance_vehicle': 'insurance/vehicle doc',
    'travel': 'travel doc',
    'education': 'education material',
    'work': 'work material',
    'manual': 'manual/warranty',
    'event': 'event/invite/ticket',
    'screenshot': 'screenshot',
    'photo_other': 'personal photo',
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
    '1': 'Jan', '2': 'Feb', '3': 'Mar', '4': 'Apr', '5': 'May',
    '6': 'Jun', '7': 'Jul', '8': 'Aug', '9': 'Sep',
    '10': 'Oct', '11': 'Nov', '12': 'Dec',
    'none': 'None',
  };

  /// Belgedeki yıl: son 8 yıl + daha eski + yok.
  static Map<String, String> years(int now) => {
        for (var y = now; y > now - 8; y--) '$y': '$y',
        'older': '<${now - 7}',
        'none': 'None',
      };

  /// Son ödeme tarihi — istekteki BUGÜNE göre aralık ([SmartDates.overdue]).
  static const dueBuckets = <String, String>{
    'past': 'Before today',
    'week': 'Today..+7d',
    'month': '+8..+31d',
    'later': '>31d',
    'none': 'None',
  };

  /// Geçerlilik / bitiş tarihi — istekteki bugüne göre aralık.
  static const validBuckets = <String, String>{
    'past': 'Expired (<today)',
    'month': 'Today..+31d',
    'year': '+32d..1y',
    'later': '>1y',
    'none': 'None',
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
    'lt100': '<100',
    '100_500': '100-500',
    '500_2000': '500-2000',
    'gt2000': '>2000',
    'none': 'None',
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
          'App package or archive metadata only. Most likely type?',
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
                ? 'Classify by content (any language), ignore filename.'
                : 'Document file. Classify by content (any language), ignore filename.') +
            tail,
        {
          ...docCategories,
          if (image) ...imageCategories,
          other: 'None',
        },
      ),
      for (final e in subtypes.entries)
        if (!fixedCategories.contains(e.key) && (image || !_imageOnlySubs.contains(e.key)))
          DecisionQuestion.choice(
            'sub_${e.key}',
            'sub_${e.key}',
            'If ${_subjects[e.key]}, subtype? Else "other".',
            e.value,
          ),
      const DecisionQuestion.choice(
        'bank_name',
        'bank_name',
        'If banking doc, issuing bank? Else "other".',
        banks,
      ),
      const DecisionQuestion.choice(
        'provider',
        'provider',
        'If utility/telecom bill, provider? Else "other".',
        providers,
      ),
      const DecisionQuestion.choice(
        'month',
        'month',
        'Printed document month (content date, not file date).',
        months,
      ),
      DecisionQuestion.choice(
        'year',
        'year',
        'Printed document year (content date, not file date).',
        years(year),
      ),
      DecisionQuestion.choice(
        'due',
        'due',
        'Today is $day. If bill has a payment due date, when vs today? Else "none".',
        dueBuckets,
      ),
      DecisionQuestion.choice(
        'valid',
        'valid',
        'Today is $day. If doc has an expiry/validity end date, when vs today? Else "none".',
        validBuckets,
      ),
      const DecisionQuestion.choice(
        'amount',
        'amount',
        'If bill/receipt/bank doc, grand total amount? Else "none".',
        amountBuckets,
      ),
      if (image) ...const [
        DecisionQuestion.yesNo(
          'blurry',
          'blurry',
          'Clearly blurry/out-of-focus so main subject is hard to see?',
        ),
        DecisionQuestion.yesNo(
          'accidental',
          'accidental',
          'Accidental shot (pocket, finger on lens, blank/dark, floor/ceiling)?',
        ),
      ],
    ];
  }

  /// Ses kaydı soruları (tek istek, 3 soru): tür, konuşma dili, kalite.
  static const audioQuestions = [
    DecisionQuestion.choice(
      'sub_$audio',
      'sub_$audio',
      'Audio recording type (by sound, ignore filename).',
      _audioSubs,
    ),
    DecisionQuestion.choice(
      'speech_lang',
      'speech_lang',
      'Main spoken language?',
      speechLanguages,
    ),
    DecisionQuestion.choice(
      'quality',
      'quality',
      'Audio quality?',
      audioQualities,
    ),
  ];

  /// Video soruları (yalnız ilk 60 sn, düşük çözünürlük): tür + yanlışlıkla.
  static const videoQuestions = [
    DecisionQuestion.choice(
      'sub_$video',
      'sub_$video',
      'Video type (by visual/audio, ignore filename).',
      _videoSubs,
    ),
    DecisionQuestion.yesNo(
      'accidental',
      'accidental',
      'Accidental/useless clip (pocket, dark/blank, floor/ceiling, 1-2s)?',
    ),
  ];

  // [subtypes] ve soru listeleri aynı sabit haritaları paylaşır.
  static const _audioSubs = {
    'voice_note': 'Personal voice note/memo (1 speaker to self)',
    'whatsapp_voice': 'Messaging voice message (short, informal)',
    'meeting_recording': 'Meeting/interview/group discussion',
    'lecture': 'Lesson, lecture, seminar, talk or podcast',
    'call_recording': 'Phone call recording (2 sides)',
    'music': 'Music, song or ringtone',
    'other': 'Other',
  };
  static const _videoSubs = {
    'family_video': 'Personal/family/trip/pet/daily life video',
    'screen_recording': 'Phone/PC screen recording',
    'lecture_video': 'Lesson, lecture, tutorial or course',
    'clip_meme': 'Forwarded clip, meme, viral/greeting/social video',
    'document_video': 'Document, whiteboard or slides video',
    'other': 'Other',
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
    'event': ['davetiye', 'davet', 'düğün', 'nişan', 'tören', 'etkinlik', 'afiş', 'duyuru', 'konser', 'invitation', 'event', 'دعوة'],
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

  /// Son ödeme tarihi yaklaşan fatura mı (henüz geçmemiş, 31 gün içinde)?
  static bool upcomingDue(String bucket, int asked, int today) {
    if (overdue(bucket, asked, today)) return false;
    return bucket == 'week' || bucket == 'month';
  }

  /// Geçerlilik tarihi [today] itibarıyla kesin dolmuş mu?
  static bool expired(String bucket, int asked, int today) => switch (bucket) {
        'past' => true,
        'month' => asked > 0 && today - asked > 31,
        'year' => asked > 0 && today - asked > 366,
        _ => false,
      };

  /// Geçerlilik tarihi yaklaşan belge mi (henüz dolmamış, ~31 gün içinde)?
  static bool expiringSoon(String bucket, int asked, int today) {
    if (expired(bucket, asked, today)) return false;
    if (bucket == 'month') return true;
    return bucket == 'year' && asked > 0 && today - asked >= 335;
  }
}
