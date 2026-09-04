/// Uygulamanın **sürüm numarası** — tek kaynak.
///
/// Kullanıcı isteği 2026-09-04: *"sürüm numaramız sürekli 0.1, bunu değiştir
/// ve her güncellemede ilerlesin"*. Numara üç yerde birden görünüyordu
/// (`pubspec.yaml`, hata kaydı başlığı, Hakkında metni) ve üçü de elle
/// yazılmış sabitlerdi; kimse güncellemediği için uygulama 340 derlemedir
/// "0.1.0" diyordu.
///
/// **Nasıl ilerliyor:** yama numarası CI'nın koşu sayacından gelir
/// (`.github/workflows/build-apk.yml`, "Sürüm numarasını belirle" adımı
/// [patch] satırını `sed` ile değiştirir). Yani her derleme bir öncekinden
/// büyük bir sürüm adı taşır ve o ad hem APK'nın `versionName`i, hem
/// Release etiketi, hem de uygulamanın içinde yazan numaradır — üçü BİREBİR
/// aynı.
///
/// **Niye `package_info_plus` değil:** APK'dan sürümü okuyan bir eklenti
/// eklemek CI'da `flutter create` ile üretilen Android iskeletine yeni bir
/// platform bağımlılığı sokardı (bu projede o iskelet en kırılgan yer, bkz.
/// HAFIZA). Sabit bir Dart dosyasını `sed`lemek hem testlerde belirlenimci
/// hem de masaüstünde bedava çalışıyor.
library;

/// Ana sürüm (elle artırılır — büyük değişiklikte).
const appVersionMajor = 1;

/// Ara sürüm (elle artırılır — yeni özellik kümesinde).
const appVersionMinor = 0;

/// Yama — **CI bu satırı değiştirir**, elle dokunulmaz.
/// Yerel derlemede 0 kalır ("1.0.0" = "geliştirici derlemesi").
const appVersionPatch = 0;

/// `versionCode` karşılığı; CI'da koşu sayacı, yerelde 1.
const appBuildNumber = 1;

/// Kullanıcıya gösterilen sürüm adı: `1.0.342`.
const appVersionName = '$appVersionMajor.$appVersionMinor.$appVersionPatch';

/// Sürüm + derleme: `1.0.342 (342)`. Hata raporunda tam künye gerekiyor.
const appVersionFull = '$appVersionName ($appBuildNumber)';
