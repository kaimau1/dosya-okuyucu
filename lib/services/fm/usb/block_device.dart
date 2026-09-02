import 'dart:typed_data';

/// **Blok aygıtı** — 512 (bazen 4096) baytlık sektörler dizisi.
///
/// Ham USB sürücüsünün tabanı: üstündeki her şey (bölüm tablosu, FAT, exFAT)
/// YALNIZ bu arayüzü görür. Böylece dosya sistemi çözümleyicilerinin tamamı
/// saf Dart ve **sahte bir bellek aygıtıyla test edilebilir** — oysa gerçek
/// USB'ye ancak cihazda dokunulabiliyor (CI yalnız derliyor).
abstract class BlockDevice {
  /// Sektör boyu (bayt).
  int get blockSize;

  /// Toplam sektör sayısı.
  int get blockCount;

  /// [lba] sektöründen başlayarak [count] sektör okur.
  ///
  /// Dönen dizi tam olarak `count * blockSize` bayttır; aygıt daha azını
  /// verirse gerçekleme hata fırlatır (eksik veriyle dosya sistemi
  /// çözümlemek sessiz bozulma demektir).
  Future<Uint8List> readBlocks(int lba, int count);

  /// Aygıta YAZILABİLİR mi? Varsayılan hayır: yazma yeteneği açıkça
  /// gerçeklenmeden hiçbir katman diske dokunamasın.
  bool get writable => false;

  /// [lba] sektöründen başlayarak [data]'yı yazar.
  ///
  /// [data] uzunluğu [blockSize]'ın katı olmalıdır — yarım sektör yazmak
  /// dosya sisteminde tanımsız bir durum bırakır.
  Future<void> writeBlocks(int lba, Uint8List data) =>
      throw const BlockDeviceException('Bu aygıt salt okunur');

  /// Aygıtı kapatır (kaynakları bırakır).
  Future<void> close() async {}
}

/// Bir aygıt okunamadığında fırlatılır — çağıran katman kullanıcıya
/// "bellek okunamadı" diyebilsin diye ayrı tür.
class BlockDeviceException implements Exception {
  final String message;
  const BlockDeviceException(this.message);

  @override
  String toString() => 'BlockDeviceException: $message';
}

/// Bellekte duran sahte aygıt — **testlerin tamamının tabanı**.
///
/// Gerçek bir USB belleğe CI'da dokunulamıyor; oysa bölüm tablosu ve dosya
/// sistemi çözümleyicileri hatanın en kolay saklandığı yer. Sentetik imaj
/// üretip buradan okutmak, o kodun tamamını cihazsız doğrulanabilir yapıyor.
class MemoryBlockDevice extends BlockDevice {
  final Uint8List bytes;

  @override
  final int blockSize;

  MemoryBlockDevice(this.bytes, {this.blockSize = 512});

  @override
  int get blockCount => bytes.length ~/ blockSize;

  @override
  Future<Uint8List> readBlocks(int lba, int count) async {
    final start = lba * blockSize;
    final end = start + count * blockSize;
    if (lba < 0 || count < 0 || end > bytes.length) {
      throw BlockDeviceException(
          'okuma aygıtın dışında: lba=$lba adet=$count (toplam $blockCount)');
    }
    // **Kopya döner.** Görünüm (`sublistView`) dönseydi çağıran, yazdığı
    // tamponu değiştirdiğinde imajı da değiştirirdi ve testler gerçeği
    // yansıtmazdı.
    return Uint8List.fromList(bytes.sublist(start, end));
  }

  @override
  bool get writable => true;

  @override
  Future<void> writeBlocks(int lba, Uint8List data) async {
    if (data.length % blockSize != 0) {
      throw const BlockDeviceException('yazma sektör katı değil');
    }
    final start = lba * blockSize;
    if (lba < 0 || start + data.length > bytes.length) {
      throw BlockDeviceException('yazma aygıtın dışında: lba=$lba');
    }
    bytes.setRange(start, start + data.length, data);
  }
}

/// Bir aygıtın **bir bölümünü** kendi başına aygıt gibi gösterir.
///
/// Dosya sistemi çözümleyicileri bölümün nerede başladığını bilmek zorunda
/// kalmasın diye: FAT'ın "0. sektör" dediği yer bölümün ilk sektörüdür.
class PartitionBlockDevice extends BlockDevice {
  final BlockDevice parent;
  final int firstLba;

  @override
  final int blockCount;

  PartitionBlockDevice(this.parent, this.firstLba, this.blockCount);

  @override
  int get blockSize => parent.blockSize;

  @override
  Future<Uint8List> readBlocks(int lba, int count) {
    if (lba < 0 || count < 0 || lba + count > blockCount) {
      throw BlockDeviceException(
          'okuma bölümün dışında: lba=$lba adet=$count (bölüm $blockCount)');
    }
    return parent.readBlocks(firstLba + lba, count);
  }

  @override
  bool get writable => parent.writable;

  @override
  Future<void> writeBlocks(int lba, Uint8List data) {
    final count = data.length ~/ blockSize;
    if (lba < 0 || lba + count > blockCount) {
      // Bölüm sınırının dışına yazmak KOMŞU BÖLÜMÜ bozar; bu denetim
      // olmadan bir hesap hatası bütün diski riske atardı.
      throw BlockDeviceException('yazma bölümün dışında: lba=$lba');
    }
    return parent.writeBlocks(firstLba + lba, data);
  }

  @override
  Future<void> close() => parent.close();
}

/// Küçük **okuma önbelleği** — aynı sektör art arda istenmesin.
///
/// Niye gerekli: FAT zincirini izlemek, her küme için FAT sektörünü yeniden
/// okumak demek. USB üzerinden her okuma bir SCSI komutu (milisaniyeler);
/// 4 MB'lık bir dosyayı 512 baytlık FAT girdilerini yeniden yeniden okuyarak
/// gezmek dakikalar sürerdi. LRU değil basit FIFO: erişim örüntüsü sıralı,
/// karmaşık bir politika kazanç getirmezdi.
class CachedBlockDevice extends BlockDevice {
  final BlockDevice inner;

  /// Kaç sektör saklansın (varsayılan 2048 × 512 B = 1 MB).
  final int capacity;

  final _cache = <int, Uint8List>{};
  final _order = <int>[];

  CachedBlockDevice(this.inner, {this.capacity = 2048});

  @override
  int get blockSize => inner.blockSize;

  @override
  int get blockCount => inner.blockCount;

  @override
  Future<Uint8List> readBlocks(int lba, int count) async {
    // Çok sektörlü okuma önbelleğe girmez (büyük dosya kopyalaması
    // önbelleği süpürürdü); yalnız tek sektörlük okumalar saklanıyor.
    if (count != 1) return inner.readBlocks(lba, count);
    final hit = _cache[lba];
    if (hit != null) return hit;
    final data = await inner.readBlocks(lba, 1);
    _cache[lba] = data;
    _order.add(lba);
    if (_order.length > capacity) _cache.remove(_order.removeAt(0));
    return data;
  }

  @override
  bool get writable => inner.writable;

  /// **Yazılan sektörler önbellekten DÜŞÜRÜLÜR.**
  ///
  /// Yoksa FAT tablosuna yazdıktan sonra eski kopyayı okur, boş sandığımız
  /// kümeyi ikinci kez dağıtır ve iki dosyayı birbirinin üstüne yazardık —
  /// sessiz veri kaybının en kötü türü.
  @override
  Future<void> writeBlocks(int lba, Uint8List data) async {
    final count = data.length ~/ blockSize;
    for (var i = 0; i < count; i++) {
      _cache.remove(lba + i);
      _order.remove(lba + i);
    }
    await inner.writeBlocks(lba, data);
  }

  @override
  Future<void> close() => inner.close();
}
