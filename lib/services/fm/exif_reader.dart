import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// **JPEG EXIF okuyucu** — fotoğrafın "künyesi".
///
/// ## Niye (2026-09-06 denetim turu)
/// Dosya özellikleri penceresi bir fotoğraf için yalnız boyutu ve tarihi
/// gösteriyordu — ve o tarih **dosyanın** tarihi, yani WhatsApp'tan gelen bir
/// fotoğrafta "bugün". Kullanıcının aradığı bilgi (bu fotoğraf ne zaman,
/// hangi telefonla çekildi) dosyanın içinde duruyor ve hiç okunmuyordu.
///
/// ## Niye yeni paket YOK
/// `exif` diye bir paket var; ama ihtiyacımız olan kısım (birkaç etiket)
/// 150 satır ve bu depoda her yeni paket bir sürüm duvarı riski
/// (bkz. HAFIZA "sürüm cehennemi").
///
/// ## Kapsam — bilinçli olarak dar
/// Okunanlar: çekim tarihi, üretici/model, çözünürlük, ISO, poz, diyafram,
/// odak uzaklığı, yönelim, flaş, yazılım. **GPS OKUNMUYOR**: konum KVKK
/// kapsamında kişisel veridir; ekranda göstermek, kullanıcının paylaştığı bir
/// ekran görüntüsüne evinin konumunu da eklemek olurdu.
///
/// Yalnız JPEG (APP1/Exif). PNG/WebP/HEIC'te EXIF ya yok ya da başka bir
/// kapsayıcıda; oralarda boş dönülür ve arayüz o bölümü hiç göstermez.
class ExifData {
  /// Çekim tarihi (`DateTimeOriginal`), okunabildiyse.
  final DateTime? taken;
  final String? make;
  final String? model;
  final String? lens;
  final int? width;
  final int? height;
  final int? iso;

  /// Poz süresi saniye cinsinden (1/250 → 0.004).
  final double? exposureSeconds;
  final double? aperture;
  final double? focalLength;

  /// EXIF yönelim kodu (1..8). 1 = düz.
  final int? orientation;
  final bool? flash;
  final String? software;

  const ExifData({
    this.taken,
    this.make,
    this.model,
    this.lens,
    this.width,
    this.height,
    this.iso,
    this.exposureSeconds,
    this.aperture,
    this.focalLength,
    this.orientation,
    this.flash,
    this.software,
  });

  static const empty = ExifData();

  bool get isEmpty =>
      taken == null &&
      make == null &&
      model == null &&
      lens == null &&
      width == null &&
      iso == null &&
      exposureSeconds == null &&
      aperture == null &&
      focalLength == null &&
      orientation == null &&
      flash == null &&
      software == null;

  /// Kamera adı: markayı iki kez yazmadan. Pek çok cihazda model zaten
  /// markayla başlıyor ("Apple iPhone 13" değil "iPhone 13").
  String? get camera {
    final mk = make?.trim();
    final md = model?.trim();
    if (md == null || md.isEmpty) return mk;
    if (mk == null || mk.isEmpty) return md;
    if (md.toLowerCase().startsWith(mk.toLowerCase())) return md;
    return '$mk $md';
  }

  /// "1/250 sn" biçiminde poz; 1 saniyeden uzunsa "2,5 sn".
  String? get exposureLabel {
    final e = exposureSeconds;
    if (e == null || e <= 0) return null;
    if (e >= 1) return '${e.toStringAsFixed(1).replaceAll('.', ',')} sn';
    return '1/${(1 / e).round()} sn';
  }
}

abstract final class ExifReader {
  /// Dosyanın başından okunacak en fazla bayt. EXIF bloğu JPEG'in ilk birkaç
  /// KB'sindedir; 12 MB'lık bir fotoğrafın tamamını belleğe almak gereksiz.
  static const headerBytes = 256 * 1024;

  static Future<ExifData> read(String path) async {
    try {
      final file = File(path);
      final length = await file.length();
      final take = length < headerBytes ? length : headerBytes;
      final chunks = await file.openRead(0, take).toList();
      return parse(Uint8List.fromList(chunks.expand((c) => c).toList()));
    } catch (_) {
      return ExifData.empty;
    }
  }

  /// JPEG baytlarını çözümler. Testler doğrudan bunu çağırıyor.
  static ExifData parse(Uint8List bytes) {
    try {
      final app1 = _findApp1(bytes);
      if (app1 == null) return ExifData.empty;
      return _parseTiff(bytes, app1);
    } catch (_) {
      // Bozuk/kısmi EXIF bir hata değil, bir yokluk: fotoğraf yine açılıyor.
      return ExifData.empty;
    }
  }

  /// "Exif" imzasından sonraki TIFF başlığının konumu.
  static int? _findApp1(Uint8List b) {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null; // SOI yok
    var i = 2;
    while (i + 4 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      if (marker == 0xDA) return null; // görüntü verisi başladı
      final size = (b[i + 2] << 8) | b[i + 3];
      if (size < 2) return null;
      if (marker == 0xE1 && i + 10 <= b.length) {
        final tag = String.fromCharCodes(b.sublist(i + 4, i + 8));
        // İmza "Exif" + iki dolgu baytı; TIFF başlığı hemen ardından.
        if (tag == 'Exif') return i + 10;
      }
      i += 2 + size;
    }
    return null;
  }

  static ExifData _parseTiff(Uint8List b, int tiff) {
    if (tiff + 8 > b.length) return ExifData.empty;
    final little = b[tiff] == 0x49 && b[tiff + 1] == 0x49;
    final data = ByteData.sublistView(b);
    final endian = little ? Endian.little : Endian.big;

    int u16(int at) => data.getUint16(at, endian);
    int u32(int at) => data.getUint32(at, endian);

    final values = <int, Object>{};

    void readIfd(int offset, int depth) {
      if (depth > 2 || offset < 0 || offset + 2 > b.length) return;
      final count = u16(offset);
      // Bozuk dosyada `count` uçuk çıkabiliyor; sınırla.
      if (count > 512) return;
      for (var i = 0; i < count; i++) {
        final entry = offset + 2 + i * 12;
        if (entry + 12 > b.length) return;
        final tag = u16(entry);
        final type = u16(entry + 2);
        final num = u32(entry + 4);
        final size = _typeSize(type) * num;
        // Alt IFD'ler (Exif, Interop) kendi etiketlerini taşıyor.
        if (tag == 0x8769 || tag == 0xA005) {
          readIfd(tiff + u32(entry + 8), depth + 1);
          continue;
        }
        final valueAt = size <= 4 ? entry + 8 : tiff + u32(entry + 8);
        if (valueAt < 0 || valueAt + size > b.length) continue;
        switch (type) {
          case 2: // ASCII
            final raw = b.sublist(valueAt, valueAt + size);
            final end = raw.indexOf(0);
            values[tag] = utf8.decode(end == -1 ? raw : raw.sublist(0, end),
                allowMalformed: true);
          case 3: // SHORT
            values[tag] = u16(valueAt);
          case 4: // LONG
            values[tag] = u32(valueAt);
          case 5: // RATIONAL
          case 10: // SRATIONAL
            final n = u32(valueAt);
            final d = u32(valueAt + 4);
            values[tag] = d == 0 ? 0.0 : n / d;
        }
      }
    }

    readIfd(tiff + u32(tiff + 4), 0);

    String? str(int tag) {
      final v = values[tag];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    int? integer(int tag) {
      final v = values[tag];
      if (v is int) return v;
      if (v is double) return v.round();
      return null;
    }

    double? real(int tag) {
      final v = values[tag];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return null;
    }

    final flashRaw = integer(0x9209);
    return ExifData(
      taken: _parseExifDate(str(0x9003) ?? str(0x0132)),
      make: str(0x010F),
      model: str(0x0110),
      lens: str(0xA434),
      width: integer(0xA002),
      height: integer(0xA003),
      iso: integer(0x8827),
      exposureSeconds: real(0x829A),
      aperture: real(0x829D),
      focalLength: real(0x920A),
      orientation: integer(0x0112),
      flash: flashRaw == null ? null : (flashRaw & 1) == 1,
      software: str(0x0131),
    );
  }

  static int _typeSize(int type) => switch (type) {
        1 || 2 || 6 || 7 => 1,
        3 || 8 => 2,
        4 || 9 || 11 => 4,
        5 || 10 || 12 => 8,
        _ => 1,
      };

  /// EXIF tarihi `2026:09:06 14:32:10` biçiminde — `DateTime.parse` bunu
  /// okuyamaz (tarih ayırıcısı iki nokta).
  static DateTime? _parseExifDate(String? raw) {
    if (raw == null || raw.length < 19) return null;
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
        .firstMatch(raw);
    if (match == null) return null;
    int g(int i) => int.parse(match.group(i)!);
    try {
      final date = DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
      // Saati ayarsız cihazlarda 1970/0000 gibi değerler çıkıyor; onları
      // göstermek "bilinmiyor" demekten daha yanıltıcı.
      if (date.year < 1990 || date.year > 2100) return null;
      return date;
    } catch (_) {
      return null;
    }
  }
}
