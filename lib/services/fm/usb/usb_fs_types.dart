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
}

/// Dosya sistemi tanınamadığında/bozuk olduğunda.
class UsbFsException implements Exception {
  final String message;
  const UsbFsException(this.message);

  @override
  String toString() => 'UsbFsException: $message';
}
