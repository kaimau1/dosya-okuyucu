import 'package:archive/archive.dart';

/// Açılmış bir zip girdisini başka bir arşive **içeriğiyle** taşır.
///
/// archive 4'te çözülmüş girdiyi olduğu gibi `addFile` ile yeni arşive
/// eklemek bozuk bayt üretiyor (sıkıştırılmış ham veri bir daha işleniyor;
/// 2026-11-02 A3.1). Açık içerikten yeni girdi kurulur, sıkıştırma türü korunur.
ArchiveFile carryEntry(ArchiveFile f) {
  final data = f.content as List<int>;
  return ArchiveFile(f.name, data.length, data)..compression = f.compression;
}
