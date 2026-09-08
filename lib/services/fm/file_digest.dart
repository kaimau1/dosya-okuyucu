import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// **Dosya özeti (SHA-256 / MD5)** — "indirdiğim dosya bozuk mu?" sorusunun
/// tek dürüst cevabı.
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulama bir indirme yöneticisi, bir ağ paylaşımı ve bir "yakındaki
/// cihaza gönder" taşıyor; üçünde de dosya bir yerden bir yere gidiyor.
/// Karşılaştırılacak bir özet yoksa "aktarım tamamlandı" yazısı bir
/// TEMENNİDİR: yarım inen bir APK da, bir baytı bozulmuş bir yedek de aynı
/// yazıyı gösterir. Yayıncılar (GitHub Releases dahil) SHA-256 yayımlıyor;
/// kullanıcının elinde onunla karşılaştıracak bir sayı yoktu.
///
/// MD5 de var çünkü eski dosya sunucuları ve pek çok Türk kamu sitesi hâlâ
/// MD5 yayımlıyor. **Güvenlik için değil, eşleştirme için**: MD5 çakışmaya
/// açıktır ve bir dosyanın "kurcalanmadığını" kanıtlamaz; ekranda da bu
/// ayrım için SHA-256 önce ve varsayılan.
///
/// **Akış hâlinde okur.** 4 GB'lık bir video için `readAsBytes` demek
/// belleğe 4 GB almak, yani çökmek demekti; `openRead` parça parça besliyor.
abstract final class FileDigest {
  /// Bir seferde okunan blok. 1 MB, iki uç arasında bilinçli bir orta yol:
  /// daha küçüğü sistem çağrısı sayısını, daha büyüğü bellek tepe noktasını
  /// artırıyor.
  static const chunkBytes = 1 << 20;

  /// [path]'in SHA-256 özeti (küçük harf onaltılık).
  static Future<String> sha256Of(String path,
          {void Function(int done, int total)? onProgress,
          bool Function()? isCancelled}) =>
      _digest(path, sha256, onProgress: onProgress, isCancelled: isCancelled);

  /// [path]'in MD5 özeti (küçük harf onaltılık).
  static Future<String> md5Of(String path,
          {void Function(int done, int total)? onProgress,
          bool Function()? isCancelled}) =>
      _digest(path, md5, onProgress: onProgress, isCancelled: isCancelled);

  /// İki özetin aynı olup olmadığı — boşluk ve büyük/küçük harf farkını yok
  /// sayar. Kullanıcı özeti bir siteden **kopyalayıp yapıştırıyor**; araya
  /// karışan boşluk ya da büyük harf yüzünden "eşleşmedi" demek yanlış olur.
  static bool sameDigest(String a, String b) =>
      a.replaceAll(RegExp(r'\s'), '').toLowerCase() ==
      b.replaceAll(RegExp(r'\s'), '').toLowerCase();

  static Future<String> _digest(
    String path,
    Hash algorithm, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final file = File(path);
    final total = await file.length();
    var done = 0;
    final output = _DigestSink();
    final input = algorithm.startChunkedConversion(output);
    try {
      await for (final chunk in file.openRead()) {
        if (isCancelled?.call() ?? false) return '';
        input.add(chunk);
        done += chunk.length;
        onProgress?.call(done, total);
      }
    } finally {
      input.close();
    }
    return output.value?.toString() ?? '';
  }
}

/// `crypto`nun parça parça (chunked) arayüzü sonucu bir `Sink`e yazıyor.
///
/// Paketin kendi `AccumulatorSink`i `convert` paketinde; onu içe aktarmak
/// için pubspec'e DOLAYLI bir bağımlılığı daha açıkça eklemek gerekirdi.
/// Tek bir değer tutan bu üç satır aynı işi görüyor.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
