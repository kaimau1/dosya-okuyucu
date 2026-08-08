import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bir ses dosyasından okunan etiket bilgisi.
class AudioTags {
  /// Parça adı (`TIT2` / `©nam`). Boşsa dosya adı kullanılır.
  final String title;

  /// Sanatçı (`TPE1` / `©ART`).
  final String artist;

  /// Albüm (`TALB` / `©alb`).
  final String album;

  /// Gömülü kapak resmi ham baytları (`APIC` / `covr`); yoksa null.
  final Uint8List? cover;

  const AudioTags({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.cover,
  });

  static const empty = AudioTags();

  bool get isEmpty =>
      title.isEmpty && artist.isEmpty && album.isEmpty && cover == null;

  /// "Sanatçı · Albüm" — ikisi de boşsa boş dize.
  String get subtitle =>
      [artist, album].where((s) => s.isNotEmpty).join(' · ');
}

/// Ses dosyalarının etiketlerini okur — **saf Dart, bağımlılık yok**.
///
/// **Niye kendi ayrıştırıcımız:** ekranda yalnız dört alan gösteriliyor
/// (başlık, sanatçı, albüm, kapak). Bunun için tam bir etiket kütüphanesi
/// (ve APK'da birkaç yüz kilobayt daha) eklemek "sade/hızlı/ücretsiz"
/// konumlandırmasıyla çelişirdi. Okunamayan bir etiket sessizce boş döner ve
/// ekran eskisi gibi dosya adını gösterir — yani en kötü durum, bu iş
/// yapılmadan önceki durumdur.
///
/// Desteklenen: **ID3v2.2/2.3/2.4** (mp3 ve etiketi başa koyan diğerleri) ve
/// **MP4/M4A `ilst` atomları** (`m4a`, `mp4`, `m4b`). FLAC'ın Vorbis
/// yorumları ve ID3v1 bilinçli olarak DIŞARIDA: ikisi de bu iki biçimin
/// yanında pratikte azınlık, ve her biçim ayrı bir hata yüzeyi.
abstract final class AudioTagReader {
  /// Dosyanın başından en çok bu kadarı okunur.
  ///
  /// Kapak resmi genelde etiketin içinde ve etiket dosyanın başındadır;
  /// 40 MB'lık bir albümün tamamını belleğe almak için hiçbir sebep yok.
  /// Etiket bundan büyükse (çok büyük kapak) kapak alınamaz ama METİN
  /// alanları yine okunur — hepsi etiketin başında durur.
  static const maxHeaderBytes = 2 * 1024 * 1024;

  /// [path] dosyasının etiketlerini okur. Okunamazsa [AudioTags.empty].
  static Future<AudioTags> read(String path) async {
    try {
      final file = File(path);
      final length = await file.length();
      final take = length < maxHeaderBytes ? length : maxHeaderBytes;
      final bytes = Uint8List.fromList(
          await file.openRead(0, take).expand((c) => c).toList());
      return parse(bytes);
    } catch (_) {
      return AudioTags.empty;
    }
  }

  /// Ham baytlardan etiket çözer (saf → birim testli).
  static AudioTags parse(Uint8List bytes) {
    try {
      if (_startsWith(bytes, 'ID3')) return _parseId3(bytes);
      final mp4 = _parseMp4(bytes);
      if (mp4 != null) return mp4;
    } catch (_) {
      // Bozuk/eksik etiket: dosya adına düşülür.
    }
    return AudioTags.empty;
  }

  // ── ID3v2 ──────────────────────────────────────────────────────────────

  static AudioTags _parseId3(Uint8List b) {
    if (b.length < 10) return AudioTags.empty;
    final major = b[3];
    // Boyut "senkron-güvenli": her baytın yalnız 7 biti kullanılır (0x80
    // biti çerçeve senkronuyla karışmasın diye ayrılmıştır).
    final tagSize = _synchsafe(b, 6);
    final end = (10 + tagSize).clamp(0, b.length);

    // v2.2'de çerçeve kimliği 3, uzunluk 3 bayt; v2.3+'ta 4 ve 4.
    final idLen = major <= 2 ? 3 : 4;
    final headerLen = major <= 2 ? 6 : 10;
    final ids = major <= 2
        ? const {'title': 'TT2', 'artist': 'TP1', 'album': 'TAL', 'cover': 'PIC'}
        : const {
            'title': 'TIT2',
            'artist': 'TPE1',
            'album': 'TALB',
            'cover': 'APIC',
          };

    var title = '', artist = '', album = '';
    Uint8List? cover;

    var offset = 10;
    while (offset + headerLen <= end) {
      final id = String.fromCharCodes(b.sublist(offset, offset + idLen));
      if (id.trim().isEmpty || id.codeUnitAt(0) == 0) break; // dolgu alanı
      final size = major <= 2
          ? (b[offset + 3] << 16) | (b[offset + 4] << 8) | b[offset + 5]
          // v2.4 senkron-güvenli, v2.3 düz 32 bit. Yanlış okumak çerçeve
          // zincirini kaydırır ve etiketin kalanı çöpe döner.
          : (major >= 4
              ? _synchsafe(b, offset + 4)
              : (b[offset + 4] << 24) |
                  (b[offset + 5] << 16) |
                  (b[offset + 6] << 8) |
                  b[offset + 7]);
      if (size <= 0) break;
      final start = offset + headerLen;
      final stop = start + size;
      if (stop > end) break;
      final data = b.sublist(start, stop);

      if (id == ids['title']) {
        title = _decodeTextFrame(data);
      } else if (id == ids['artist']) {
        artist = _decodeTextFrame(data);
      } else if (id == ids['album']) {
        album = _decodeTextFrame(data);
      } else if (id == ids['cover']) {
        cover = _decodePicture(data, major);
      }
      offset = stop;
    }
    return AudioTags(
        title: title, artist: artist, album: album, cover: cover);
  }

  /// Metin çerçevesi: ilk bayt kodlama, kalanı metin.
  /// 0 = ISO-8859-1, 1 = UTF-16 (BOM'lu), 2 = UTF-16BE, 3 = UTF-8.
  static String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final body = data.sublist(1);
    return _trimNul(switch (encoding) {
      0 => latin1.decode(body, allowInvalid: true),
      1 || 2 => _decodeUtf16(body, bigEndianDefault: encoding == 2),
      _ => utf8.decode(body, allowMalformed: true),
    });
  }

  /// APIC/PIC çerçevesinden görüntü baytlarını çıkarır.
  ///
  /// Yapı: kodlama · MIME (v2.2'de 3 harflik tür) · resim türü · açıklama ·
  /// **görüntü**. Açıklama kodlamaya göre 1 ya da 2 bayt NUL ile biter —
  /// UTF-16'da tek bayt aramak görüntünün ilk baytını yutardı.
  static Uint8List? _decodePicture(Uint8List data, int major) {
    if (data.length < 4) return null;
    final encoding = data[0];
    var i = 1;
    if (major <= 2) {
      i += 3; // 'JPG' / 'PNG'
    } else {
      while (i < data.length && data[i] != 0) {
        i++;
      }
      i++; // MIME sonundaki NUL
    }
    if (i >= data.length) return null;
    i++; // resim türü baytı
    // Açıklama
    if (encoding == 1 || encoding == 2) {
      while (i + 1 < data.length && !(data[i] == 0 && data[i + 1] == 0)) {
        i += 2;
      }
      i += 2;
    } else {
      while (i < data.length && data[i] != 0) {
        i++;
      }
      i++;
    }
    if (i >= data.length) return null;
    return Uint8List.sublistView(data, i);
  }

  // ── MP4 / M4A ──────────────────────────────────────────────────────────

  /// `moov > udta > meta > ilst` altındaki atomları arar.
  ///
  /// Atom ağacını baştan yürümek yerine `ilst`i doğrudan aramak yeterli:
  /// dört harfli kimlik + geçerli uzunluk sınaması yanlış pozitifi pratikte
  /// dışarıda bırakıyor ve kod onda biri kadar.
  static AudioTags? _parseMp4(Uint8List b) {
    final ilst = _indexOfAscii(b, 'ilst');
    if (ilst < 0) return null;
    var title = '', artist = '', album = '';
    Uint8List? cover;

    var offset = ilst + 4;
    while (offset + 8 <= b.length) {
      final size = _uint32(b, offset);
      if (size < 8 || offset + size > b.length) break;
      final name = String.fromCharCodes(b.sublist(offset + 4, offset + 8));
      // Veri `data` alt atomunda: 8 bayt başlık + 4 bayt tür + 4 bayt yerel.
      final dataStart = offset + 8 + 16;
      if (dataStart < offset + size) {
        final value = Uint8List.sublistView(b, dataStart, offset + size);
        switch (name) {
          case '©nam':
            title = utf8.decode(value, allowMalformed: true);
          case '©ART':
            artist = utf8.decode(value, allowMalformed: true);
          case '©alb':
            album = utf8.decode(value, allowMalformed: true);
          case 'covr':
            cover = value;
        }
      }
      offset += size;
    }
    final tags =
        AudioTags(title: title, artist: artist, album: album, cover: cover);
    return tags.isEmpty ? null : tags;
  }

  // ── yardımcılar ────────────────────────────────────────────────────────

  static bool _startsWith(Uint8List b, String ascii) {
    if (b.length < ascii.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (b[i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  static int _indexOfAscii(Uint8List b, String ascii) {
    final needle = ascii.codeUnits;
    outer:
    for (var i = 0; i + needle.length <= b.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (b[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static int _synchsafe(Uint8List b, int at) =>
      (b[at] << 21) | (b[at + 1] << 14) | (b[at + 2] << 7) | b[at + 3];

  static int _uint32(Uint8List b, int at) =>
      (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  static String _decodeUtf16(Uint8List body, {required bool bigEndianDefault}) {
    var data = body;
    var bigEndian = bigEndianDefault;
    if (data.length >= 2) {
      if (data[0] == 0xFF && data[1] == 0xFE) {
        bigEndian = false;
        data = Uint8List.sublistView(data, 2);
      } else if (data[0] == 0xFE && data[1] == 0xFF) {
        bigEndian = true;
        data = Uint8List.sublistView(data, 2);
      }
    }
    final units = <int>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      units.add(bigEndian
          ? (data[i] << 8) | data[i + 1]
          : (data[i + 1] << 8) | data[i]);
    }
    return String.fromCharCodes(units);
  }

  /// Metin alanları NUL ile sonlanır (ve v2.4'te NUL'la ayrılmış çoklu değer
  /// taşıyabilir). İlk NUL'dan sonrası atılır — yoksa ekranda
  /// "Sanatçı<NUL>Ad" gibi görünürdü.
  static String _trimNul(String s) {
    final end = s.indexOf('\u0000');
    return (end < 0 ? s : s.substring(0, end)).trim();
  }
}
