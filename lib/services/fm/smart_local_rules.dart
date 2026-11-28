import 'package:path/path.dart' as p;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import 'smart_learn.dart';
import 'smart_sort.dart';
import 'smart_sort_taxonomy.dart';

/// Sıfır kredili yerel akıllı sınıflandırma kuralları.
///
/// Yüksek doğruluklu yerel eşleşme üretir (`0.85`–`0.94`), Türkçe karakterleri
/// [asciiFold] ile katlar ve [SmartLearn.adjust] geçmiş düzeltmelerini uygular.
/// Emin olunmayan dosyalarda `null` döner ve işi AI kararına bırakır.
abstract final class SmartLocalRules {
  static const Set<String> _imageExts = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.bmp',
    '.gif',
  };

  static const Set<String> _avExts = {
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.wav',
    '.flac',
    '.mp4',
    '.m4v',
    '.mkv',
    '.mov',
    '.webm',
    '.3gp',
  };

  static bool isImagePath(String path) =>
      _imageExts.contains(p.extension(path).toLowerCase());

  static SmartRecord? classify(
    FsEntry entry, {
    String? textSnippet,
    bool applyLearn = true,
  }) {
    final ext = p.extension(entry.path).toLowerCase();
    // Ses ve videolar yalnız dosya adına bakılarak belge kategorilerine
    // atlanmaz; gerçek içeriği AI sınıflandırır.
    if (_avExts.contains(ext)) return null;
    final isImage = isImagePath(entry.path);
    final dirName = p.basename(p.dirname(entry.path));
    final folded = asciiFold('${entry.name} $dirName ${textSnippet ?? ''}');
    final tokens = folded
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toSet();

    bool hasAny(Iterable<String> words) {
      for (final w in words) {
        if (w.contains(' ')) {
          if (folded.contains(w)) return true;
        } else if (tokens.contains(w) ||
            (w.length >= 5 && folded.contains(w))) {
          return true;
        }
      }
      return false;
    }

    String cat = '';
    String sub = '';
    String provider = '';
    String bank = '';
    var conf = 0.0;

    if (ext == '.apk' || ext == '.xapk' || ext == '.apks') {
      cat = SmartTaxonomy.package;
      sub = 'installer';
      conf = 0.94;
    } else if (isImage &&
        hasAny(['whatsapp', 'telegram']) &&
        hasAny(['screenshot', 'screen', 'ekran'])) {
      cat = 'screenshot_chat';
      conf = 0.88;
    } else if (isImage &&
        (folded.contains('screenshot') ||
            folded.contains('ekran goruntusu') ||
            folded.contains('ekran_goruntusu') ||
            folded.contains('screen_shot'))) {
      cat = 'screenshot';
      conf = 0.88;
    } else if (hasAny([
      'fatura',
      'invoice',
      'enerjisa',
      'igdas',
      'iski',
      'turkcell',
      'vodafone',
      'telekom',
    ])) {
      cat = 'invoice';
      conf = 0.90;
      if (hasAny(['enerjisa', 'elektrik', 'electricity'])) {
        sub = 'electricity';
        if (hasAny(['enerjisa'])) provider = 'enerjisa';
      } else if (hasAny(['igdas', 'dogalgaz', 'natural gas'])) {
        sub = 'natural_gas';
        if (hasAny(['igdas'])) provider = 'igdas';
      } else if (hasAny(['iski', 'su faturasi', 'water'])) {
        sub = 'water';
        if (hasAny(['iski'])) provider = 'iski';
      } else if (hasAny(['turkcell', 'vodafone', 'telekom', 'mobil', 'gsm'])) {
        sub = 'mobile_phone';
        if (hasAny(['turkcell'])) provider = 'turkcell';
        if (hasAny(['vodafone'])) provider = 'vodafone';
      }
      if (provider.isNotEmpty &&
          !SmartTaxonomy.providerFits(provider, 'invoice', sub)) {
        provider = '';
      }
    } else if (hasAny([
      'dekont',
      'ekstre',
      'iban',
      'hesap ozeti',
      'bank statement',
      'havale',
      'eft',
      'ziraat',
      'garanti',
      'isbank',
      'akbank',
      'yapikredi',
      'vakifbank',
      'halkbank',
      'enpara',
    ])) {
      cat = 'bank';
      conf = 0.89;
      if (hasAny(['ekstre', 'hesap ozeti', 'statement'])) {
        sub = 'account_statement';
      } else if (hasAny(['dekont', 'havale', 'eft', 'transfer', 'iban'])) {
        sub = 'transfer';
      }
      for (final b in SmartTaxonomy.banks.keys) {
        if (b != SmartTaxonomy.other && hasAny([b])) {
          bank = b;
          break;
        }
      }
    } else if (hasAny([
      'bordro',
      'maas',
      'payslip',
      'vergi',
      'beyanname',
      'muhtasar',
      'sgk hizmet',
      'tax return',
    ])) {
      cat = 'tax_salary';
      conf = 0.89;
      if (hasAny(['bordro', 'maas', 'payslip'])) {
        sub = 'payslip';
      } else if (hasAny(['vergi', 'beyanname', 'tax'])) {
        sub = 'tax_certificate';
      }
    } else if (hasAny([
      'edevlet',
      'e devlet',
      'ikametgah',
      'sabika',
      'adli sicil',
      'nufus kayit',
      'tapu',
      'mahkeme',
      'noter',
      'dilekce',
    ])) {
      cat = 'official';
      conf = 0.89;
      if (hasAny(['edevlet', 'e devlet', 'ikametgah', 'sabika', 'nufus'])) {
        sub = 'e_government';
      } else if (hasAny(['noter'])) {
        sub = 'notary';
      } else if (hasAny(['tapu'])) {
        sub = 'land_registry';
      } else if (hasAny(['dilekce'])) {
        sub = 'petition';
      }
    } else if (hasAny([
          'recete',
          'tahlil',
          'kan testi',
          'enabiz',
          'e nabiz',
          'epikriz',
          'rapor',
          'prescription',
          'lab result',
        ]) &&
        hasAny([
          'recete',
          'tahlil',
          'kan testi',
          'enabiz',
          'e nabiz',
          'epikriz',
          'hastane',
          'doktor',
          'prescription',
          'lab result',
        ])) {
      cat = 'health';
      conf = 0.88;
      if (hasAny(['tahlil', 'kan testi', 'lab result'])) {
        sub = 'lab_result';
      } else if (hasAny(['recete', 'prescription'])) {
        sub = 'prescription';
      } else if (hasAny(['epikriz'])) {
        sub = 'discharge';
      }
    } else if (hasAny([
      'kimlik',
      'pasaport',
      'passport',
      'ehliyet',
      'driving licence',
      'national id',
    ])) {
      cat = 'id';
      conf = 0.88;
      if (hasAny(['pasaport', 'passport'])) {
        sub = 'passport';
      } else if (hasAny(['ehliyet', 'driving licence'])) {
        sub = 'driving_licence';
      } else {
        sub = 'id_card';
      }
    } else if (hasAny([
      'kasko',
      'trafik sigorta',
      'ruhsat',
      'muayene',
      'trafik cezasi',
    ])) {
      cat = 'insurance_vehicle';
      conf = 0.87;
      if (hasAny(['kasko'])) {
        sub = 'casco';
      } else if (hasAny(['ruhsat'])) {
        sub = 'vehicle_registration';
      }
    } else if (hasAny([
      'sozlesme',
      'kira kontrati',
      'kontrat',
      'taahhutname',
      'contract',
      'rental agreement',
    ])) {
      cat = 'contract';
      conf = 0.87;
      if (hasAny(['kira', 'rental'])) sub = 'rental';
    } else if (hasAny([
      'ucak bileti',
      'boarding pass',
      'pnr',
      'otel rezervasyon',
      'vize',
      'otobus bileti',
      'tren bileti',
      'flight ticket',
      'hotel reservation',
    ])) {
      cat = 'travel';
      conf = 0.87;
      if (hasAny(['ucak', 'boarding', 'flight'])) {
        sub = 'flight';
      } else if (hasAny(['otel', 'hotel'])) {
        sub = 'hotel';
      } else if (hasAny(['vize'])) {
        sub = 'visa';
      }
    } else if (hasAny([
      'market fis',
      'yazar kasa',
      'pos slib',
      'akaryakit',
      'eczane fisi',
      'makbuz',
      'receipt',
    ])) {
      cat = 'receipt';
      conf = 0.86;
    } else if (hasAny([
      'ders notu',
      'transkript',
      'diploma',
      'sinav',
      'vize sorulari',
      'final sorulari',
      'odev',
      'lecture notes',
    ])) {
      cat = 'education';
      conf = 0.86;
      if (hasAny(['diploma'])) {
        sub = 'diploma';
      } else if (hasAny(['transkript'])) {
        sub = 'transcript';
      } else if (hasAny(['odev'])) {
        sub = 'homework';
      }
    }

    if (cat.isEmpty) return null;

    if (applyLearn) {
      final adjusted = SmartLearn.adjust(entry.path, cat, image: isImage);
      if (adjusted != null && adjusted != cat) {
        cat = adjusted;
        sub = '';
        provider = '';
        bank = '';
        conf = 0.90;
      }
    }

    return SmartRecord(
      path: entry.path,
      size: entry.sizeBytes,
      modifiedMs: entry.modifiedMs,
      cat: cat,
      conf: conf,
      sub: sub,
      bank: bank,
      provider: provider,
    );
  }
}
