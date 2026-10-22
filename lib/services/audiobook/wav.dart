import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';

/// **Basit WAV (PCM 16 bit) araçları** — sesli kitap üretimi için.
///
/// Konuşma motorları (cihazın TTS'i ve yapay sinir ağı sesleri) metni
/// parça parça üretiyor; bir bölüm tek dosya olsun diye parçalar burada
/// uç uca eklenir ve başlık bilgisi (`LIST/INFO`: ad, sanatçı, albüm, parça
/// no) yazılır — Android'in medya tarayıcısı ve oynatıcılar bunu okur.
class WavFormat {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  const WavFormat(this.sampleRate, this.channels, this.bitsPerSample);

  @override
  bool operator ==(Object other) =>
      other is WavFormat &&
      other.sampleRate == sampleRate &&
      other.channels == channels &&
      other.bitsPerSample == bitsPerSample;

  @override
  int get hashCode => Object.hash(sampleRate, channels, bitsPerSample);
}

/// Bir WAV'ın biçimi ve PCM verisinin konumu.
class WavInfo {
  final WavFormat format;
  final int dataOffset;
  final int dataLength;
  const WavInfo(this.format, this.dataOffset, this.dataLength);
}

abstract final class Wav {
  /// Başlığı çözer; PCM değilse ya da bozuksa null.
  static WavInfo? parse(Uint8List b) {
    if (b.length < 44) return null;
    String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    final d = ByteData.sublistView(b);
    WavFormat? fmt;
    var o = 12;
    while (o + 8 <= b.length) {
      final id = tag(o);
      var size = d.getUint32(o + 4, Endian.little);
      final body = o + 8;
      if (id == 'fmt ') {
        final audioFormat = d.getUint16(body, Endian.little);
        if (audioFormat != 1 && audioFormat != 0xFFFE) return null;
        fmt = WavFormat(d.getUint32(body + 4, Endian.little),
            d.getUint16(body + 2, Endian.little), d.getUint16(body + 14, Endian.little));
      } else if (id == 'data') {
        if (fmt == null) return null;
        // Akışla yazılmış dosyalarda boy 0/0xFFFFFFFF olabilir: dosya sonu.
        if (size == 0 || body + size > b.length) size = b.length - body;
        return WavInfo(fmt, body, size);
      }
      o = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  /// PCM verisini başlık + isteğe bağlı INFO etiketleriyle WAV'a sarar.
  static Uint8List build(
    Uint8List pcm,
    WavFormat f, {
    String? title,
    String? artist,
    String? album,
    int? track,
  }) {
    final info = _infoChunk({
      if (title != null && title.isNotEmpty) 'INAM': title,
      if (artist != null && artist.isNotEmpty) 'IART': artist,
      if (album != null && album.isNotEmpty) 'IPRD': album,
      if (track != null) 'ITRK': '$track',
    });
    final out = BytesBuilder(copy: false);
    final header = ByteData(44);
    void str(int o, String s) {
      for (var i = 0; i < 4; i++) {
        header.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    final blockAlign = f.channels * f.bitsPerSample ~/ 8;
    str(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length + info.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, f.channels, Endian.little);
    header.setUint32(24, f.sampleRate, Endian.little);
    header.setUint32(28, f.sampleRate * blockAlign, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, f.bitsPerSample, Endian.little);
    str(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    out.add(header.buffer.asUint8List());
    out.add(pcm);
    if (pcm.length.isOdd) out.addByte(0);
    out.add(info);
    return out.toBytes();
  }

  /// `LIST` → `INFO` alt parçası (UTF-8, sıfır sonlu, çift hizalı).
  static Uint8List _infoChunk(Map<String, String> tags) {
    if (tags.isEmpty) return Uint8List(0);
    final body = BytesBuilder();
    body.add('INFO'.codeUnits);
    tags.forEach((id, value) {
      final v = [...utf8.encode(value), 0];
      if (v.length.isOdd) v.add(0);
      final len = ByteData(4)..setUint32(0, v.length, Endian.little);
      body
        ..add(id.codeUnits)
        ..add(len.buffer.asUint8List())
        ..add(v);
    });
    final b = body.toBytes();
    final head = ByteData(8);
    for (var i = 0; i < 4; i++) {
      head.setUint8(i, 'LIST'.codeUnitAt(i));
    }
    head.setUint32(4, b.length, Endian.little);
    return Uint8List.fromList([...head.buffer.asUint8List(), ...b]);
  }

  /// [parts] WAV dosyalarını uç uca ekleyip [target]'a yazar; parçalar
  /// arasına [gapMs] sessizlik konur. Biçimi farklı parça atlanır (aynı motor
  /// aynı biçimi verir; ayrışan, bozuk bir parçadır). Yazılan biçim ya da
  /// hiç parça okunamadıysa null.
  static Future<WavFormat?> concat(
    List<String> parts,
    String target, {
    String? title,
    String? artist,
    String? album,
    int? track,
    int gapMs = 250,
  }) async {
    WavFormat? fmt;
    final pcm = BytesBuilder(copy: false);
    for (final path in parts) {
      final bytes = await File(path).readAsBytes();
      final info = parse(bytes);
      if (info == null) continue;
      fmt ??= info.format;
      if (info.format != fmt) continue;
      if (pcm.length > 0 && gapMs > 0) {
        final block = fmt.channels * fmt.bitsPerSample ~/ 8;
        pcm.add(Uint8List(fmt.sampleRate * gapMs ~/ 1000 * block));
      }
      pcm.add(Uint8List.sublistView(
          bytes, info.dataOffset, info.dataOffset + info.dataLength));
    }
    if (fmt == null) return null;
    await File(target).writeAsBytes(
        build(pcm.toBytes(), fmt,
            title: title, artist: artist, album: album, track: track),
        flush: true);
    return fmt;
  }

  /// Süre (ms) — başlıktan.
  static int durationMs(WavInfo info) {
    final f = info.format;
    final bytesPerSec = f.sampleRate * f.channels * f.bitsPerSample ~/ 8;
    return bytesPerSec == 0 ? 0 : info.dataLength * 1000 ~/ bytesPerSec;
  }
}
