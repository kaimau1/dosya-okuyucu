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
abstract final class SmartTaxonomy {
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

  static const other = 'other';

  /// Bütün kategori kimlikleri (sıralı: belge → görsel → diğer).
  static List<String> get categoryIds =>
      [...docCategories.keys, ...imageCategories.keys, other];

  static bool isDoc(String cat) => docCategories.containsKey(cat);

  /// Kişisel fotoğraf: ikinci ad almaz.
  static bool isPersonalPhoto(String cat) =>
      cat == 'photo_people' || cat == 'photo_other';

  /// Hassas kategoriler (kilit açıkken görünür).
  static const sensitive = {'id', 'health', 'bank', 'tax_salary'};

  /// Gereksiz sayılan kategoriler (Ayıkla).
  static const clutterCategories = {'greeting', 'meme'};

  /// Alt türler: kategori → (kimlik → İngilizce açıklama). Her listede
  /// `other` kaçışı var.
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
    'bank': {
      'transfer': 'A money transfer / payment receipt (EFT, wire, FAST, '
          'remittance).',
      'account_statement': 'A bank account statement.',
      'card_statement': 'A credit card statement.',
      'loan': 'A loan, mortgage or installment document.',
      'other': 'Another banking document.',
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
  };

  static const _subjects = {
    'invoice': 'an invoice or bill',
    'bank': 'a banking document',
    'health': 'a medical document',
    'id': 'an identity document or card',
    'travel': 'a travel document',
    'education': 'school or education material',
  };

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
    'other': 'Another bank or not stated.',
  };

  static String bankName(String id) => id == 'other' ? '' : (banks[id] ?? '');

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

  /// Görsel kategorisi mi (ekran görüntüsü, fotoğraf, kutlama, caps)?
  static bool isImageCat(String cat) => imageCategories.containsKey(cat);

  /// Tek istekte sorulan sorular. [image] görsel mi (bulanıklık soruları ve
  /// görsel kategorileri yalnız görselde — PDF/belgeye "ekran görüntüsü"
  /// seçeneği sunulmaz; kök 2026-11-18: Gmail'den yazdırılan e-posta PDF'i
  /// "Ekran görüntüsü" çıkıyordu), [nowYear] yıl seçenekleri için.
  static List<DecisionQuestion> questions({required bool image, int? nowYear}) {
    final year = nowYear ?? DateTime.now().year;
    return [
      DecisionQuestion.choice(
        'cat',
        'cat',
        image
            ? 'What kind of file is this? Judge by its content (whatever its '
                'language), not by the file name.'
            : 'This is a document file (PDF or text). What kind of document '
                'is it? Judge by its content (whatever its language), not by '
                'the file name or how the pages look.',
        {
          ...docCategories,
          if (image) ...imageCategories,
          other: 'None of the above.',
        },
      ),
      for (final e in subtypes.entries)
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
  };
}
