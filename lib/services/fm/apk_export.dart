import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_storage_service.dart';
import 'archive_ops.dart';
import 'file_ops.dart';

/// **Yüklü bir uygulamayı APK olarak dışa aktarır** — paylaşmak ya da
/// saklamak için.
///
/// Kullanıcı isteği (2026-08-29): *"yüklü olan bir uygulamayı — Google Play'den
/// olur başka bir kaynaktan olur — APK'ya dönüştürüp başka birisine
/// yükleyebilmesi için paylaşma özelliği getirelim."*
///
/// ## "Dönüştürme" diye bir şey yok — APK zaten cihazda
/// Kurulu her uygulama diskte APK olarak duruyor
/// (`/data/app/~~xxx/<paket>-yyy/base.apk`). Yaptığımız iş onu **bulmak,
/// okunur bir ada kopyalamak ve paylaşmak**. Yeniden paketleme ya da imza
/// üretme YOK: kopyalanan dosya bit bit özgün APK'dır, imzası geçerlidir ve
/// karşı tarafta kurulur.
///
/// ## Parçalı kurulumlar (App Bundle) — bu akışın asıl inceliği
/// Play'den kurulan uygulamaların çoğu **App Bundle**dır: cihazda `base.apk`
/// yanında `split_config.arm64_v8a.apk`, `split_config.xxhdpi.apk`,
/// `split_config.tr.apk` gibi parçalar durur. Kod `base.apk`ta, ama **native
/// kütüphaneler ve ekran/dil kaynakları parçalarda.** Yalnız `base.apk`
/// paylaşmak karşı tarafta ya "Uygulama yüklenmedi" ya da açılır açılmaz
/// çöken bir kurulum demektir.
///
/// Bu yüzden parçalı uygulamalarda varsayılan çıktı **`.apks`** — bütün
/// parçaları içeren bir ZIP. Bu, "Split APKs Installer" gibi araçların
/// beklediği biçimdir. Kullanıcı yine de yalnız `base.apk`ı isteyebilir
/// (bazı uygulamalar tek başına kurulur); arayüz farkı açıkça yazıyor.
abstract final class ApkExport {
  /// Dosya adında en az bir harf ya da rakam var mı?
  static final _meaningful = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Paylaşılacak dosyanın adı: `WhatsApp 2.24.1.apk`.
  ///
  /// **Saf fonksiyon** — ad üretimi telefon olmadan doğrulanabilsin diye.
  /// Kurallar:
  /// - Ad dosya sistemi için temizlenir ([FileOps.sanitizeName]); ayrıca
  ///   nokta ve boşluk yığınları teke iner (uygulama adları emoji ve nokta
  ///   taşıyabiliyor: "Google Play Hizmetleri.").
  /// - Sürüm biliniyorsa ada eklenir; boşsa hiç yazılmaz ("Ad .apk" olmasın).
  /// - Ad tamamen eriyip boş kalırsa paket adına düşülür — adsız dosya
  ///   üretmek yerine kullanıcının tanıyacağı bir şey.
  static String fileNameFor({
    required String appName,
    required String versionName,
    required String packageName,
    required bool split,
  }) {
    var base = FileOps.sanitizeName(appName)
        .replaceAll(RegExp(r'[.\s]+'), ' ')
        .trim();
    // "Anlamlı" ölçüt harf/rakam: `sanitizeName` eğik çizgiyi `_` yaptığı için
    // yalnız `isEmpty` bakmak yetmiyordu — "///" adlı bir uygulama karşı
    // tarafa `___.apk` olarak gidiyordu (test bunu yakaladı).
    if (!_meaningful.hasMatch(base)) base = FileOps.sanitizeName(packageName);
    if (!_meaningful.hasMatch(base)) base = 'uygulama';
    final version = versionName.trim().replaceAll(RegExp(r'[\s/\\]+'), '');
    final suffix = version.isEmpty ? '' : ' $version';
    return '$base$suffix.${split ? 'apks' : 'apk'}';
  }

  /// [source] uygulamasının APK'sını [destDir] içine çıkarır; oluşan dosyanın
  /// yolunu döner.
  ///
  /// [includeSplits] yalnız parçalı kurulumlarda anlamlı: `false` verilirse
  /// tek `base.apk` kopyalanır (bkz. sınıf notu — kurulmama riski kullanıcıya
  /// söylenmiş olmalı).
  ///
  /// Var olan bir dosyanın üstüne YAZMAZ ([FileOps.uniquePath]).
  static Future<String> extract(
    ApkSource source,
    String destDir, {
    bool includeSplits = true,
    String appName = '',
    String packageName = '',
  }) async {
    final dir = Directory(destDir);
    if (!dir.existsSync()) await dir.create(recursive: true);

    final split = source.isSplit && includeSplits;
    final name = fileNameFor(
      appName: appName.isEmpty ? source.label : appName,
      versionName: source.versionName,
      packageName: packageName,
      split: split,
    );

    if (!split) {
      final target = FileOps.uniquePath(p.join(destDir, name));
      await File(source.sourcePath).copy(target);
      return target;
    }

    // Parçalı: hepsi tek ZIP'e. `ArchiveOps.zip` .zip uzantısı üretir; dosya
    // sonra `.apks`e alınıyor — uzantı beklenen kurulum aracının aradığı şey,
    // içerik yine düz bir ZIP.
    final zipPath = await ArchiveOps.zip(
      source.allPaths,
      destDir,
      archiveName: p.basenameWithoutExtension(name),
    );
    final target = FileOps.uniquePath(p.join(destDir, name));
    return (await File(zipPath).rename(target)).path;
  }
}
