import 'dart:io';

import 'package:path/path.dart' as p;

/// Yapıştırmadan önce hedefte çakışan adları bulur.
///
/// **Niye gerekli (KALANLAR maddesi):** yapıştırma her zaman sessizce
/// `FmConflict.rename` uyguluyordu — `rapor.pdf` hedefte varsa
/// `rapor (1).pdf` oluşuyordu. Veri kaybı yok (bilinçli, güvenli varsayılan)
/// ama kullanıcının niyeti çoğu zaman **güncelleme**: aynı dosyanın yeni
/// sürümünü yapıştırıp klasörde iki kopya bulmak ve hangisinin yeni olduğunu
/// bilememek gerçek bir karışıklık kaynağı.
///
/// Artık çakışma VARSA soruluyor, yoksa hiçbir şey sorulmuyor — çakışma
/// olmadığı halde çıkan bir soru penceresi saf gürültü olurdu.
abstract final class PasteConflict {
  /// [sources] içinden adı [destDir]'de zaten var olanların **adlarını**
  /// döndürür (yol değil: kullanıcıya gösterilecek olan ad).
  ///
  /// Bir kaynak kendi klasörüne yapıştırılıyorsa (kopyala → aynı yere yapıştır)
  /// çakışma sayılır; kullanıcı orada gerçekten bir kopya istiyor olabilir ve
  /// "üzerine yaz" seçerse dosyayı kendisiyle değiştirmiş olur — zararsız.
  static List<String> collisions(List<String> sources, String destDir) {
    final names = <String>[];
    for (final source in sources) {
      final name = p.basename(source);
      final target = p.join(destDir, name);
      if (_exists(target)) names.add(name);
    }
    return names;
  }

  /// Saf sürüm: var olan adlar zaten biliniyorsa (test, uzak depolama).
  static List<String> collisionsIn(
    List<String> sources,
    Set<String> existingNames,
  ) =>
      [
        for (final source in sources)
          if (existingNames.contains(p.basename(source))) p.basename(source),
      ];

  static bool _exists(String path) =>
      File(path).existsSync() || Directory(path).existsSync();
}
