import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:path/path.dart' as p;

/// Pakete giren tek dosya: diskteki yol + arşivdeki ad (`Tatil/a.jpg`).
class ZipStreamEntry {
  final String path;
  final String name;
  final int size;
  final DateTime modified;

  const ZipStreamEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });
}

/// **Tek akış ZIP paketi** — çok sayıda küçük dosyayı ya da bir klasörü
/// aktarırken (2026-10-29 kullanıcı isteği: *"çoklu küçük dosya veya klasör
/// gönderimlerinde veriyi arka planda zipleyip tek bir veri akışı olarak
/// gönderin"*).
///
/// ## Niye diske ZIP yazmadan, niye sıkıştırmasız ("store")
/// * Yüz küçük fotoğrafı yüz ayrı istekle göndermek her biri için el sıkışma
///   + onay + dosya açma demek; asıl yavaşlık buradan geliyor, veriden değil.
///   Tek akış bunu ortadan kaldırıyor.
/// * Deflate saf Dart'ta telefonda Wi-Fi'den YAVAŞ (fotoğraf/video zaten
///   sıkıştırılmış, kazanç ~%0) — sıkıştırmak aktarımı hızlandırmaz,
///   yavaşlatır. Store ZIP'in boyutu ÖNCEDEN bilinir → `Content-Length`
///   verilebilir, ilerleme yüzdesi doğru olur.
/// * Geçici dosya yok: paket akarken üretilir, telefonda iki kat yer
///   gerekmez.
/// * **Kaldığı yerden devam**: akış belirlenimcidir (aynı dosyalar → aynı
///   baytlar), [open] istenen bayttan başlatılabilir.
///
/// Sınır: ZIP64 yazılmaz — 4 GB'tan büyük paket ya da 65 535'ten çok dosya
/// [ZipStream.of]'ta reddedilir; çağıran o durumda dosyaları tek tek yollar.
class ZipStream {
  final List<ZipStreamEntry> entries;
  final List<Uint8List> _names;

  ZipStream._(this.entries)
      : _names = [for (final e in entries) utf8.encode(e.name)];

  static const _limit = 0xFFFFFFFF;

  /// [roots] dosya ya da klasör olabilir; klasörler adıyla birlikte girer
  /// (`Tatil/` → `Tatil/a.jpg`). Boş klasörler atlanır. ZIP64 gerekiyorsa
  /// null.
  static Future<ZipStream?> of(List<String> roots) async {
    final out = <ZipStreamEntry>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (await dir.exists()) {
        final base = p.dirname(root);
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          final st = await e.stat();
          out.add(ZipStreamEntry(
            path: e.path,
            name: p.relative(e.path, from: base).replaceAll('\\', '/'),
            size: st.size,
            modified: st.modified,
          ));
        }
      } else {
        final f = File(root);
        final st = await f.stat();
        out.add(ZipStreamEntry(
            path: root,
            name: p.basename(root),
            size: st.size,
            modified: st.modified));
      }
    }
    final zip = ZipStream._(out);
    if (out.length > 0xFFFF || zip.length > _limit) return null;
    return zip;
  }

  int get totalFileBytes => entries.fold(0, (a, e) => a + e.size);

  /// Paketin bayt cinsinden tam boyu (başlıklar + veri + dizin).
  int get length {
    var n = 22; // EOCD
    for (var i = 0; i < entries.length; i++) {
      n += 30 + _names[i].length + entries[i].size + 16; // yerel + veri + tanım
      n += 46 + _names[i].length; // merkez dizin
    }
    return n;
  }

  /// Paketi [start]. bayttan itibaren akıtır. Atlanan dosyaların CRC'si yine
  /// hesaplanır (merkez dizin ister) ama bayt gönderilmez.
  Stream<List<int>> open({int start = 0}) async* {
    var pos = 0;
    final crcs = List<int>.filled(entries.length, 0);
    final offsets = List<int>.filled(entries.length, 0);

    // [bytes] akışın [pos]'unda duruyor: [start]'tan önceki kısmı kırp.
    Iterable<List<int>> emit(List<int> bytes) sync* {
      final end = pos + bytes.length;
      if (end > start) {
        yield pos >= start ? bytes : bytes.sublist(start - pos);
      }
      pos = end;
    }

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      offsets[i] = pos;
      yield* Stream.fromIterable(emit(_localHeader(i)));
      var crc = 0;
      final dataEnd = pos + e.size;
      if (dataEnd <= start) {
        // Tümü atlanıyor: yalnız CRC.
        await for (final chunk in File(e.path).openRead(0, e.size)) {
          crc = getCrc32(chunk, crc);
        }
        pos = dataEnd;
      } else {
        await for (final chunk in File(e.path).openRead(0, e.size)) {
          crc = getCrc32(chunk, crc);
          for (final part in emit(chunk)) {
            yield part;
          }
        }
        // Dosya okunurken küçüldüyse paket boyu tutmaz: sıfırla doldur
        // (alıcı CRC'den bozulduğunu anlar, akış uzunluğu sapmaz).
        if (pos < dataEnd) {
          for (final part in emit(Uint8List(dataEnd - pos))) {
            yield part;
          }
        }
      }
      crcs[i] = crc;
      yield* Stream.fromIterable(emit(_descriptor(crc, e.size)));
    }
    final cdStart = pos;
    final cd = BytesBuilder(copy: false);
    for (var i = 0; i < entries.length; i++) {
      cd.add(_centralHeader(i, crcs[i], offsets[i]));
    }
    final cdBytes = cd.takeBytes();
    yield* Stream.fromIterable(emit(cdBytes));
    yield* Stream.fromIterable(emit(_eocd(cdBytes.length, cdStart)));
  }

  // ── ZIP yapıları (PKWARE APPNOTE 4.3) ───────────────────────────────────

  /// Bit 3: boyut/CRC veri tanımında; bit 11: ad UTF-8.
  static const _flags = 0x0808;

  (int, int) _dos(DateTime t) {
    final y = t.year < 1980 ? 1980 : t.year;
    final date = ((y - 1980) << 9) | (t.month << 5) | t.day;
    final time = (t.hour << 11) | (t.minute << 5) | (t.second ~/ 2);
    return (time, date);
  }

  Uint8List _localHeader(int i) {
    final name = _names[i];
    final b = ByteData(30);
    final (time, date) = _dos(entries[i].modified);
    b
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, _flags, Endian.little)
      ..setUint16(8, 0, Endian.little) // store
      ..setUint16(10, time, Endian.little)
      ..setUint16(12, date, Endian.little)
      ..setUint32(14, 0, Endian.little)
      ..setUint32(18, 0, Endian.little)
      ..setUint32(22, 0, Endian.little)
      ..setUint16(26, name.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    return Uint8List.fromList([...b.buffer.asUint8List(), ...name]);
  }

  static Uint8List _descriptor(int crc, int size) {
    final b = ByteData(16)
      ..setUint32(0, 0x08074b50, Endian.little)
      ..setUint32(4, crc, Endian.little)
      ..setUint32(8, size, Endian.little)
      ..setUint32(12, size, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List _centralHeader(int i, int crc, int offset) {
    final name = _names[i];
    final size = entries[i].size;
    final (time, date) = _dos(entries[i].modified);
    final b = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 0x0314, Endian.little) // Unix, 2.0
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, _flags, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, time, Endian.little)
      ..setUint16(14, date, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, size, Endian.little)
      ..setUint32(24, size, Endian.little)
      ..setUint16(28, name.length, Endian.little)
      ..setUint16(30, 0, Endian.little)
      ..setUint16(32, 0, Endian.little)
      ..setUint16(34, 0, Endian.little)
      ..setUint16(36, 0, Endian.little)
      ..setUint32(38, 0x81A40000, Endian.little) // -rw-r--r--
      ..setUint32(42, offset, Endian.little);
    return Uint8List.fromList([...b.buffer.asUint8List(), ...name]);
  }

  Uint8List _eocd(int cdSize, int cdStart) {
    final b = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint16(8, entries.length, Endian.little)
      ..setUint16(10, entries.length, Endian.little)
      ..setUint32(12, cdSize, Endian.little)
      ..setUint32(16, cdStart, Endian.little)
      ..setUint16(20, 0, Endian.little);
    return b.buffer.asUint8List();
  }
}
