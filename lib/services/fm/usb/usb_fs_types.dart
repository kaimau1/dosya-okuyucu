import 'dart:typed_data';

/// Ham USB belleğindeki bir dosya/klasör.
///
/// [id] dosya sisteminin kendi tutamağıdır (FAT'ta ilk küme, exFAT'ta ilk
/// küme + "zincir yok" bayrağı). Üst katman onu YORUMLAMAZ, yalnız geri
/// verir — böylece FAT ve exFAT aynı arayüzün arkasında durabiliyor.
class UsbEntry {
  final String name;
  final bool isDir;
  final int sizeBytes;

  /// Değiştirilme zamanı (epoch ms); bilinmiyorsa 0.
  final int modifiedMs;

  /// Dosya sistemine özel tutamak.
  final Object id;

  const UsbEntry({
    required this.name,
    required this.isDir,
    required this.id,
    this.sizeBytes = 0,
    this.modifiedMs = 0,
  });
}

/// Ham bellekteki **salt okunur** dosya sistemi.
///
/// Yazma bilerek YOK (ilk tur): bir FAT/exFAT tablosunu yanlış yazmak
/// kullanıcının bütün belleğini kaybettirir. Okuma yanlışsa en fazla dosya
/// açılmaz. Yazma ancak okuma cihazda doğrulandıktan sonra düşünülür.
abstract class UsbFileSystem {
  /// Birimin etiketi ("TYPEC 64"); yoksa boş.
  String get label;

  /// Kök klasörün tutamağı.
  Object get rootId;

  /// Bir klasörün girdileri.
  Future<List<UsbEntry>> listDir(Object dirId);

  /// Bir dosyanın içeriği — parça parça (büyük video belleğe sığmaz).
  Stream<Uint8List> openRead(UsbEntry entry);

  // ── Yazma (gerçekleyen dosya sistemlerinde) ────────────────────────────
  //
  // Varsayılan "hayır": yazma yeteneği açıkça gerçeklenmeden hiçbir katman
  // diske dokunamasın. NTFS bilerek salt okunur (bkz. `NtfsFileSystem`);
  // bir NTFS tablosunu yanlış yazmak diskin tamamını kaybettirir ve doğru
  // yazmak günlük (journal) tutmayı gerektirir.

  /// Bu dosya sistemine yazılabilir mi?
  bool get writable => false;

  /// [dirId] altında [name] adlı dosyayı [data] içeriğiyle oluşturur
  /// (aynı adlı varsa üzerine yazar) ve girdisini döner.
  Future<UsbEntry> writeFile(Object dirId, String name, Uint8List data) =>
      throw const UsbFsException('Bu biçimde yazma desteklenmiyor');

  /// Akıştan yazar — **büyük dosyanın tek yolu**.
  ///
  /// 2 GB'lık bir videoyu [writeFile] ile yazmak, önce onu tümüyle belleğe
  /// almak demektir: telefon uygulamayı öldürür. Burada küme küme
  /// tüketiliyor. [totalLength] önceden bilinmeli (yer ayırmak için).
  Future<UsbEntry> writeFileStream(
    Object dirId,
    String name,
    Stream<List<int>> data,
    int totalLength,
  ) =>
      throw const UsbFsException('Bu biçimde yazma desteklenmiyor');

  /// [dirId] altında klasör açar; yeni klasörün tutamağını döner.
  Future<UsbEntry> createDirectory(Object dirId, String name) =>
      throw const UsbFsException('Bu biçimde yazma desteklenmiyor');

  /// [entry]'yi siler ([dirId] onun bulunduğu klasör).
  Future<void> deleteEntry(Object dirId, UsbEntry entry) =>
      throw const UsbFsException('Bu biçimde yazma desteklenmiyor');

  /// [entry]'yi yeniden adlandırır (veri taşınmaz, yalnız girdi değişir).
  Future<void> renameEntry(Object dirId, UsbEntry entry, String newName) =>
      throw const UsbFsException('Bu biçimde yazma desteklenmiyor');
}

/// Dosya sistemi tanınamadığında/bozuk olduğunda.
class UsbFsException implements Exception {
  final String message;
  const UsbFsException(this.message);

  @override
  String toString() => 'UsbFsException: $message';
}
