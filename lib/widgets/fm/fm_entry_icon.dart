import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../services/fm/fm_colors_store.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/app_state.dart';
import '../../core/state/focused_states.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/apk_icon.dart';
import '../../services/fm/image_sniff.dart';
import '../../services/fm/important_files.dart';
import '../../services/fm/media_duration.dart';
import '../../services/fm/office_thumbnail.dart';
import '../../services/fm/pdf_thumbnail.dart';
import '../../services/fm/thumbnail_cache.dart';
import 'fm_file_image.dart';
import 'fm_glyph.dart';
import '../../services/fm/storage_stats.dart';
import '../../core/app_colors.dart';

/// Dosya yöneticisi ikon paleti. Office dörtlüsü [OfficeColors]'tan gelir
/// (liste ve şerit aynı tonu kullansın diye — bkz. HAFIZA 2026-07-24 tutarsızlık
/// bulgusu); yeni kategoriler burada tanımlanır.
abstract final class FmColors {
  // Kağıt teması (2026-08-04): kağıt zeminde parlak renkler bağırıyordu —
  // hepsi bir kademe koyulaştırıldı (koyu temada aşağıdaki beyaza doğru
  // lerp mantığı korunuyor).
  //
  // **2026-09-23 tasarım turu:** kağıt zemin iki turda neredeyse beyaza
  // çekildikten sonra (2026-08-17) koyulaştırılmış palet çamurlu kalıyordu —
  // klasör okrası kahverengi, video kiremit, arşiv toprak rengi görünüyordu
  // (kullanıcı: *"klasörler ve simgeleri gelişebilir"*). Renkler bugünün dosya
  // uygulamalarının doygunluğuna çekildi; klasör kahverengi-okradan sıcak
  // KEHRİBARA geçti. Koyu temadaki beyaza lerp kuralı aynı.
  static const folder = Color(0xFFE39B2E); // klasör kehribarı
  static const image = Color(0xFF8B4FD1);
  static const video = Color(0xFFD9433B);
  static const audio = Color(0xFF12998A);
  static const archive = Color(0xFF9C6B45);

  // Arşiv biçimlerinin kendi renkleri (2026-09-27): hepsi aynı toprak
  // rengindeydi, ZIP ile RAR ayırt edilmiyordu.
  static const zip = Color(0xFFD08A1E);
  static const rar = Color(0xFF8250C4);
  static const sevenZip = Color(0xFF3F5566);
  static const tarball = Color(0xFF8D6246);
  static const apk = Color(0xFF3A9A4A);
  static const other = Color(0xFF76808C);

  static Color forCategory(FmCategory c) => switch (c) {
        FmCategory.folder => folder,
        FmCategory.image => image,
        FmCategory.video => video,
        FmCategory.audio => audio,
        FmCategory.archive => archive,
        FmCategory.apk => apk,
        FmCategory.document => OfficeColors.neutral,
        FmCategory.other => other,
      };

  /// Kategori glifi (tema ailesinden bağımsız; çizim dili [FmTintedIcon]'da).
  static IconData iconFor(FmCategory c) => switch (c) {
        FmCategory.folder => AppIcons.folder,
        FmCategory.image => AppIcons.image,
        FmCategory.video => AppIcons.video,
        FmCategory.audio => AppIcons.audio,
        FmCategory.archive => AppIcons.archiveView,
        FmCategory.apk => AppIcons.android,
        FmCategory.document => AppIcons.newWord,
        FmCategory.other => AppIcons.insertDriveFile,
      };

  // ── uzantıya ve klasör adına özel simgeler ────────────────────────────────
  //
  // Kullanıcı isteği (2026-08-17): *"APK dosyaları vs hepsinin simgesi
  // görülmeli, ne kadar görünebilirse o kadar iyi"* ve *"klasörlerde de
  // simgeleri daha güzel yap … bize özgü yap"*.
  //
  // Kategori simgesi kaba bir ayrım yapıyordu: bir `.zip`, bir `.apk` ve bir
  // `.epub` "Diğer"in ya da "Arşiv"in aynı gliftiyle görünüyordu. Aşağıdaki
  // tablo sık karşılaşılan türleri kendi glifine ve kendi rengine ayırır.
  // Taklit DEĞİL: başka bir dosya yöneticisinin çizimleri kopyalanmadı,
  // Material glif ailesinden bu uygulamanın paletine oturan bir eşleme
  // kuruldu.

  static const _archiveExt = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'zst'
  };

  /// Uzantıya özel glif + renk (yoksa null → kategori glifi kullanılır).
  static (IconData, Color)? forExtension(String ext) => switch (ext) {
        'apk' || 'xapk' || 'apks' || 'aab' => (AppIcons.android, apk),
        // Arşivler biçime göre renk alır (2026-09-27): hepsi aynı toprak
        // rengindeydi, ZIP ile RAR ayırt edilmiyordu.
        'zip' => (AppIcons.archiveView, zip),
        'rar' => (AppIcons.archiveView, rar),
        '7z' => (AppIcons.archiveView, sevenZip),
        'tar' || 'gz' || 'tgz' || 'bz2' || 'xz' || 'zst' =>
          (AppIcons.archiveView, tarball),
        'epub' || 'mobi' || 'azw' || 'azw3' || 'fb2' =>
          (AppIcons.menuBook, const Color(0xFF8D5524)),
        'ttf' || 'otf' || 'woff' || 'woff2' =>
          (AppIcons.fontDownload, const Color(0xFF5C4B8A)),
        'json' || 'xml' || 'yaml' || 'yml' || 'html' || 'htm' || 'css' ||
        'js' || 'ts' || 'dart' || 'py' || 'java' || 'kt' || 'c' || 'cpp' ||
        'sh' =>
          (AppIcons.code, const Color(0xFF3A6EA5)),
        'iso' || 'img' || 'dmg' => (AppIcons.album, const Color(0xFF5B6670)),
        'torrent' => (AppIcons.swapVertCircle, const Color(0xFF2E7D5B)),
        'db' || 'sqlite' || 'sql' =>
          (AppIcons.database, const Color(0xFF6E6555)),
        'log' || 'ini' || 'cfg' || 'conf' =>
          (AppIcons.receiptLong, other),
        'vcf' => (AppIcons.contactPage, const Color(0xFF3A6EA5)),
        'ics' => (AppIcons.eventNote, const Color(0xFFB07C2A)),
        _ => null,
      };

  /// Bilinen klasörün kendi glifi (yoksa null → düz klasör).
  ///
  /// Ad karşılaştırması küçük harfe indirilmiş TAM ad üzerinden yapılır:
  /// "Download" klasörü ile "Download Manager Logs" farklı şeyler, ikincisine
  /// indirme oku çizmek yanıltıcı olurdu.
  static IconData? forFolderName(String name) => switch (name.toLowerCase()) {
        'download' || 'downloads' || 'indirilenler' =>
          AppIcons.download,
        'dcim' || 'camera' || 'kamera' => AppIcons.photoCamera,
        'pictures' || 'images' || 'resimler' || 'görüntüler' =>
          AppIcons.layoutGallery,
        'movies' || 'video' || 'videos' || 'videolar' =>
          AppIcons.videoLibrary,
        'music' || 'müzik' || 'audio' || 'ses' => AppIcons.libraryMusic,
        'documents' || 'belgeler' => AppIcons.folderCopy,
        'whatsapp' || 'telegram' || 'signal' => AppIcons.forum,
        'android' || 'system' || 'data' => AppIcons.settings,
        'screenshots' || 'ekran görüntüleri' => AppIcons.screenshot,
        'backup' || 'backups' || 'yedek' => AppIcons.backup,
        'fonts' => AppIcons.fontDownload,
        _ => null,
      };

  // ── çizilen simgeler (2026-08-29) ─────────────────────────────────────────
  //
  // Kullanıcı bulgusu: *"dosya ve klasör simgeleri çok daha iyi olmalı, şu an
  // çok yapmacık."* Yukarıdaki tablolar (renk + glif) DURUYOR; değişen, o
  // bilginin nasıl çizildiği: tek renk düz Material glifi yerine gerçek klasör
  // gövdesi / kıvrık köşeli kağıt ([FmGlyph]). Tablolar korundu çünkü pano
  // kutucukları ve süzgeç çipleri hâlâ düz glif kullanıyor — orada bir kağıt
  // çizimi değil, kategori işareti gerekiyor.

  /// Uzantıdan **şerit yazısı**: `PDF`, `DOCX`, `ZIP`…
  ///
  /// Boş dönerse şerit hiç çizilmez (kağıdın ortasına glif konur). Uzun ya da
  /// harf-dışı karakter içeren "uzantılar" (`backup2024`, `part-001`) gerçek
  /// tür değildir; şeride yazılırsa bilgi değil gürültü olurlar.
  static String labelForExtension(String ext) {
    final e = ext.trim().toLowerCase();
    if (e.isEmpty || e.length > 8) return '';
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(e)) return '';
    return (e.length <= 4 ? e : e.substring(0, 3)).toUpperCase();
  }

  /// Bir girdinin çizim reçetesi. Renk/glif seçimi yukarıdaki tablolardan
  /// gelir; burada yalnız hangisinin kazandığı ve kağıda ne yazılacağı
  /// kararlaştırılır.
  static FmGlyphSpec glyphFor(
    FsEntry entry, {
    bool classic = false,
    bool dark = false,
    Color? folderColor,
  }) {
    if (entry.isDir) {
      return FmGlyphSpec(
        folder: true,
        // Tema ailesi klasör rengini değiştirebilir (2026-10-18).
        color: folderColor ?? folder,
        // Bilinen klasörün glifi klasörün YERİNE geçmez, gövdesine biner.
        overlay: forFolderName(entry.name),
        classic: classic,
        dark: dark,
      );
    }
    final ext = entry.extension.toLowerCase();
    final special = forExtension(ext);
    final Color color;
    IconData? overlay;
    if (special != null) {
      color = special.$2;
      overlay = special.$1;
    } else if (entry.category == FmCategory.document) {
      // Belge markası şeritle AYNI tonu kullanır (Word mavisi, Excel yeşili,
      // PDF kırmızısı) — liste ile editör başlığı aynı rengi konuşsun.
      color = OfficeColors.forKind(FileService.iconKindForExtension(ext));
    } else {
      color = forCategory(entry.category);
      overlay = iconFor(entry.category);
    }
    final label = labelForExtension(ext);
    return FmGlyphSpec(
      folder: false,
      zipper: entry.category == FmCategory.archive || _archiveExt.contains(ext),
      color: color,
      // Uzantı şeride yazıldığında glif GEREKSİZ: aynı bilgiyi iki kez
      // söyleyip kağıdı kalabalıklaştırırdı. Glif yalnız uzantısız dosyada.
      overlay: label.isEmpty ? overlay : null,
      label: label,
      classic: classic,
      dark: dark,
    );
  }
}

/// Bir girdinin ikonu. Görsellerde gerçek küçük resim (thumbnail) gösterilir;
/// üretilemeyen/üretilmemiş her şeyde uygulamanın kendi çizilmiş simgesi
/// ([FmGlyph]: klasör gövdesi ya da uzantısı yazılı kağıt).
///
/// **Çerçeve YOKTUR** (kullanıcı isteği 2026-07-25: "dış çerçeve olmasın direkt
/// simge olsun"): glif kutunun ~%92'sini kaplar, arkasında dolgu/kenarlık
/// bulunmaz. Aynı boyutta çok daha büyük ve daha temiz görünür.
class FmEntryIcon extends StatelessWidget {
  final FsEntry entry;
  final double size;

  /// Küçük resim üretilsin mi? (Hızlı kaydırmada kapatılabilir.)
  final bool thumbnails;

  /// Küçük resmin köşe yarıçapı. Izgarada hücre büyüdükçe büyütülür;
  /// Google Fotoğraflar tarzı dolu ızgarada 0 verilir.
  final double radius;

  const FmEntryIcon({
    super.key,
    required this.entry,
    this.size = 44,
    this.thumbnails = true,
    this.radius = Radii.control,
  });

  /// **Önemli dosya yıldızı** (kullanıcı isteği 2026-11-04: *"önemli
  /// dosyalara kopyalanmış her türlü dosyanın üzerinde yıldız simgesi olsun,
  /// her nerede olursa olsun"*). Bütün listeler, ızgaralar, son açılanlar,
  /// arama ve fotoğraflar simgeyi buradan aldığı için rozet de tek yerde.
  @override
  Widget build(BuildContext context) {
    final icon = _content(context);
    if (!ImportantFiles.isImportant(entry.path)) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        PositionedDirectional(
          top: 2,
          end: 2,
          child: FmImportantBadge(size: (size * 0.32).clamp(14.0, 24.0)),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final category = entry.category;
    // Kullanıcı ayarlardan küçük resimleri kapatabilir (yavaş cihaz).
    context.dependOnBrowse();
    final thumbsOn =
        thumbnails && (context.select<AppState, bool>((s) => s.fmThumbnails));

    if (category == FmCategory.document) {
      // Belgeler de aynı ÇİZİLMİŞ kağıdı kullanır (2026-08-29): marka rengi
      // `iconKindForExtension`'dan gelir (.xls/.doc gibi eski biçimler de
      // kendi tonuyla görünür), şeritte uzantı yazar — "DOCX" yazan mavi
      // kağıt, Word glifinden daha kesin bilgi veriyor.
      final icon = _badge(context, category);
      // PDF: **kapak sayfası** küçük resmi. On tane faturanın hangisinin
      // hangisi olduğu eskiden yalnız dosya adından anlaşılıyordu; hepsi aynı
      // kırmızı simgeyle görünüyordu. Üretilene kadar (ve üretilemezse —
      // parolalı/bozuk belge) simge kalır.
      if (thumbsOn && entry.extension.toLowerCase() == 'pdf') {
        return _PdfThumb(
          path: entry.path,
          size: size,
          radius: radius,
          fallback: icon,
        );
      }
      // Slayt / Excel / Word: dosyanın içindeki hazır önizleme resmi
      // (PowerPoint ilk slaytı yazar — 2026-11-04, bkz. [OfficeThumbnail]).
      if (thumbsOn && OfficeThumbnail.supports(entry.extension)) {
        return _PdfThumb(
          path: entry.path,
          size: size,
          radius: radius,
          fallback: icon,
          loader: (path, _) => OfficeThumbnail.forOffice(path),
        );
      }
      return icon;
    }

    // APK: **uygulamanın kendi simgesi** (kullanıcı 2026-08-17). Çıkarılana
    // kadar (ve çıkarılamazsa — bozuk/uyarlanabilir-simgeli kurulum dosyası)
    // Android glifi kalır. Bkz. `services/fm/apk_icon.dart`.
    if (thumbsOn && category == FmCategory.apk) {
      return _ApkIconImage(
        path: entry.path,
        size: size,
        radius: radius,
        fallback: _badge(context, category),
      );
    }

    // Video: native küçük resim (film karesi) — üretilene kadar/olmazsa ikon.
    if (thumbsOn && category == FmCategory.video) {
      return _VideoThumb(
        path: entry.path,
        size: size,
        radius: radius,
        fallback: _badge(context, category),
      );
    }

    if (thumbsOn && category == FmCategory.image) {
      final original = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image(
          // [FmFileImage] (Image.file DEĞİL): tam boyutlu fotoğraf Dart
          // yığınına kopyalanmadan çözülür — 6 bin fotoğraflık galeride
          // donmanın ve boş kalan hücrelerin kök nedeni buydu (bkz. sınıfın
          // başındaki not, 2026-08-17).
          image: FmFileImage(
            entry.path,
            // Bellek koruması: 4000px'lik bir fotoğrafı 44dp'lik kutuya tam
            // çözünürlükte açmak listeyi şişirir (= decode boyutu). Genişlik
            // KADEMELİ (bkz. `fmThumbWidth`): görüntüleyici aynı kaydı
            // önbellekte bulup ilk kareyi anında çizebilsin.
            cacheWidth: fmThumbWidth(
                size, MediaQuery.maybeDevicePixelRatioOf(context) ?? 3),
            cover: true,
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          // Çözülene kadar hücre BOŞ kalmasın: soluk bir zemin, sonra resim
          // yumuşak geçişle gelir. Bomboş beyaz kare kullanıcıya "yüklenmedi"
          // değil "burada bir şey yok" diyordu.
          frameBuilder: _placeholder(size),
          // Açılamayan resim: dosya silinmiş olabilir (Galeri/WhatsApp
          // temizliği). Bildir — gerçekten yoksa listeden düşürülür, duruyorsa
          // (bozuk dosya) rozet kalır. Bkz. FsEvents.reportUnreadable.
          errorBuilder: (_, _, _) {
            FsEvents.reportUnreadable(entry.path);
            return _badge(context, category);
          },
        ),
      );
      // Android'de hazır küçük resim dosyası (bkz. [ThumbnailCache.forImage]);
      // üretilemezse (ve testte) yukarıdaki özgün dosya yolu.
      if (!Platform.isAndroid) return original;
      return _PhotoThumb(
        entry: entry,
        size: size,
        radius: radius,
        fallback: original,
      );
    }

    // **Uzantısız görseller** (kullanıcı 2026-08-17: *"burada görselleri
    // göremiyorum"*). WhatsApp önbelleğinden gelen kopyaların adında nokta
    // yok → `FmCategory.other` → küçük resim hiç denenmiyordu. İmza baytlarına
    // bakıp gerçekten görselse küçük resim gösteriliyor (bkz. `ImageSniff`).
    if (thumbsOn &&
        category == FmCategory.other &&
        entry.extension.isEmpty &&
        !entry.isDir) {
      return _SniffedImage(
        path: entry.path,
        size: size,
        radius: radius,
        fallback: _badge(context, category),
      );
    }

    return _badge(context, category);
  }

  /// Girdinin **çizilmiş** simgesi: gerçek klasör gövdesi ya da kıvrık köşeli,
  /// uzantısı yazılı kağıt (bkz. [FmGlyph], 2026-08-29 — *"simgeler çok
  /// yapmacık"*). Renk/glif seçimi [FmColors.glyphFor]'da.
  Widget _badge(BuildContext context, FmCategory category) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FmGlyph(
      size: size,
      spec: FmColors.glyphFor(
        entry,
        classic: context.fmClassicIcons,
        dark: dark,
        // Faz 41 / 6: kullanıcının verdiği klasör rengi temanınkini ezer.
        folderColor:
            FmColorsStore.folderColor(entry.path) ?? context.fmFolderColor,
      ),
    );
  }
}

/// Küçük resim çözülene kadar **soluk bir kare** çizer.
///
/// Çözme anlık değil (özellikle ilk kaydırmada, on binlerce fotoğrafta): yer
/// tutucu olmadan hücre bomboş kalıyor ve kullanıcı bunu "resimler
/// görünmüyor" diye okuyor (2026-08-17 bildirimi).
///
/// **Ölçü dışarıdan verilir, `SizedBox.expand` DEĞİL:** `Image`ın `width`/
/// `height`'ı yalnız asıl kareye uygulanır, `frameBuilder`ın döndürdüğü
/// parçaya değil. Kendi başına genişleyen bir yer tutucu, `ListTile`ın
/// `leading` yuvası gibi yüksekliği SINIRSIZ bir yerde çizim hatası verirdi.
///
/// **Yumuşak geçiş** (2026-11-12 galeri turu, kullanıcı: *"akıcı, göze hitap
/// eden"*): kare ilk kez çözüldüğünde soluk zeminin üstünde kısa bir
/// belirmeyle gelir (Google Foto/Samsung Galeri'deki his). Maliyeti düşük
/// tutan iki kural: önbellekten EŞZAMANLI gelen kare (geri kaydırma) hiç
/// sarılmaz, ve `AnimatedOpacity` tam opakken katman açmaz — yalnız
/// belirme süresince (~120 ms) çalışır. Cihazda "animasyonları kaldır"
/// açıksa süre 0'dır ([Motion.of]).
ImageFrameBuilder _placeholder(double size) => (
      BuildContext context,
      Widget child,
      int? frame,
      bool wasSynchronouslyLoaded,
    ) {
      if (wasSynchronouslyLoaded) return child;
      return SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: Motion.of(context, Motion.short),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      );
    };

/// Seçim modunda satırın başındaki öğe: **önizleme + üzerinde onay rozeti**.
///
/// Kullanıcı isteği (2026-08-17, ekran görüntüsü): *"yanlış seçim yaparken
/// önizlemeler görülmeli"*. Eskiden seçim açılınca [FmEntryIcon] yerine düz bir
/// [Checkbox] konuyordu — yani seçim yapılırken, yani dosyaların birbirinden
/// AYIRT EDİLMESİNİN en çok gerektiği anda, PDF kapağı / fotoğraf / APK simgesi
/// kayboluyor ve geriye yalnız ad kalıyordu. Aynı adlı iki dosyada (bir `.pdf`
/// bir `.doc`) hangisinin seçildiği gözle doğrulanamıyordu.
///
/// Rozet ızgara hücresindekiyle ([FmEntryCard]) aynı dili konuşur: seçili
/// dolu daire, seçilmemiş boş halka; ikisi de gölgeli çünkü altında koyu bir
/// fotoğraf olabilir.
class FmSelectableIcon extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final bool selecting;
  final bool selected;

  /// Rozete/önizlemeye dokunma. Null ise dokunuş üst satıra geçer.
  final VoidCallback? onCheck;
  final double radius;

  /// Küçük resim çıkarılsın mı? Diskte düz içeriği olmayan girdilerde
  /// (arşiv içi, şifreli kasa) kapalı — tür simgesi gösterilir.
  final bool thumbnails;

  const FmSelectableIcon({
    super.key,
    required this.entry,
    required this.selecting,
    required this.selected,
    this.size = 44,
    this.onCheck,
    this.radius = Radii.control,
    this.thumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    final icon = FmEntryIcon(
        entry: entry, size: size, radius: radius, thumbnails: thumbnails);
    if (!selecting) return icon;
    final scheme = Theme.of(context).colorScheme;
    // Rozet önizlemenin en çok %42'sini kaplar ve köşede durur: ortada
    // dursaydı tam da ayırt edici ayrıntının (kapak sayfasının başlığı,
    // fotoğraftaki yüz) üstüne otururdu.
    final badge = (size * 0.42).clamp(16.0, 24.0);
    return GestureDetector(
      onTap: onCheck,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(child: icon),
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Icon(
                selected ? AppIcons.checkCircle : AppIcons.dot,
                size: badge,
                color: selected ? scheme.primary : AppColors.onMedia,
                shadows: const [Shadow(blurRadius: 4, color: AppColors.mediaScrim)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uzantısı olmayan bir dosyayı, **imzası görsel diyorsa** küçük resim olarak
/// çizer; demiyorsa (ya da bakılana kadar) [fallback] glifi kalır.
class _SniffedImage extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _SniffedImage({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_SniffedImage> createState() => _SniffedImageState();
}

class _SniffedImageState extends State<_SniffedImage> {
  // Önbellekte varsa İLK karede doğru çizilir (kaydırırken yanıp sönme olmaz).
  late bool? _isImage = ImageSniff.cached(widget.path);

  @override
  void initState() {
    super.initState();
    if (_isImage == null) _check();
  }

  @override
  void didUpdateWidget(covariant _SniffedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _isImage = ImageSniff.cached(widget.path);
      if (_isImage == null) _check();
    }
  }

  Future<void> _check() async {
    final path = widget.path;
    final result = await ImageSniff.check(path);
    if (!mounted || path != widget.path) return;
    setState(() => _isImage = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage != true) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: FmFileImage(widget.path,
            cover: true,
            cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        frameBuilder: _placeholder(widget.size),
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

/// APK'nın kendi uygulama simgesi: önbellekten gelir, yoksa arka planda
/// çıkarılır. [_PdfThumb] / [_VideoThumb] ile aynı kalıp — üretim bitene kadar
/// (ve çıkarılamazsa) [fallback] görünür, liste asla boş kutu göstermez.
class _ApkIconImage extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _ApkIconImage({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_ApkIconImage> createState() => _ApkIconImageState();
}

class _ApkIconImageState extends State<_ApkIconImage> {
  String? _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ApkIconImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _icon = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final result = await ApkIcon.forApk(path);
    if (!mounted || path != widget.path) return;
    setState(() => _icon = result);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: FmFileImage(icon, cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
        width: widget.size,
        height: widget.size,
        // `contain`: uygulama simgeleri kare ama kenar boşluklu olabiliyor;
        // `cover` onları kırpıp gliften bir parça koparırdı.
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

/// PDF kapak küçük resmi: önbellekten gelir, yoksa arka planda üretilir.
///
/// [_VideoThumb] ile aynı kalıp — üretim bitene kadar (ve üretilemezse)
/// [fallback] simgesi görünür, liste asla boş kutu göstermez.
class _PdfThumb extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  /// Kapak üreticisi (yol, piksel boyu); verilmezse PDF'in ilk sayfası.
  /// Office belgeleri aynı "kâğıt" çerçevesini kullanır.
  final Future<String?> Function(String path, int size)? loader;

  const _PdfThumb({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
    this.loader,
  });

  @override
  State<_PdfThumb> createState() => _PdfThumbState();
}

class _PdfThumbState extends State<_PdfThumb> {
  String? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PdfThumb old) {
    super.didUpdateWidget(old);
    // Liste öğesi geri dönüştürülüp başka belgeye bağlanabilir.
    if (old.path != widget.path) {
      _thumb = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final size = (widget.size * 2).round().clamp(96, 512);
    final loader = widget.loader;
    final result = loader != null
        ? await loader(path, size)
        : await PdfThumbnail.forPdf(path, size: size);
    if (!mounted || path != widget.path) return;
    setState(() => _thumb = result);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    if (thumb == null) return widget.fallback;
    // **Kağıt sayfası gibi çizilir** (2026-09-23 tasarım turu, kullanıcı
    // ekran görüntüsü: Belgeler listesi). Kapak kutuya `contain` ile
    // oturuyordu ama çerçevesi yoktu: beyaz sayfa beyaz zeminde eriyor,
    // listede yalnız yüzen birkaç yazı satırı görünüyordu. Artık sayfanın
    // KENDİ boyunda ince kenarlık + hafif gölge: satırda gerçek bir belge
    // kapağı duruyor. Kutu kare kalıyor (satır hizası bozulmaz); sayfa
    // oranı korunuyor (kırpılmış kapak yanlış belgeymiş gibi görünür).
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.onMedia,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.outlineVariant, width: 0.8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.5),
            child: Image(
              image: FmFileImage(thumb, cacheWidth: fmThumbWidth(widget.size,
                MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => widget.fallback,
            ),
          ),
        ),
      ),
    );
  }
}

/// Video küçük resmi: önbellekten gelir, yoksa arka planda üretilir.
/// Üretim bitene kadar (ve üretilemezse) [fallback] ikonu görünür — liste
/// asla boş kutu göstermez.
/// Fotoğraf hücresi: Android'in ürettiği küçük JPEG'i gösterir (2026-11-03
/// kaydırma takılması — kök neden [ThumbnailCache.forImage] notunda).
class _PhotoThumb extends StatefulWidget {
  final FsEntry entry;
  final double size;
  final double radius;
  final Widget fallback;

  const _PhotoThumb({
    required this.entry,
    required this.size,
    required this.radius,
    required this.fallback,
  });

  @override
  State<_PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<_PhotoThumb> {
  String? _thumb;

  /// Başka ölçüde hazır duran küçük resim (bkz.
  /// [ThumbnailCache.anyKnownImage]): keskini gelene kadar gösterilir.
  String? _preview;
  bool _failed = false;
  int _width = 0;

  String get _path => widget.entry.path;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = fmThumbWidth(
        widget.size, MediaQuery.maybeDevicePixelRatioOf(context) ?? 3);
    if (w == _width) return;
    _width = w;
    _start();
  }

  @override
  void didUpdateWidget(covariant _PhotoThumb old) {
    super.didUpdateWidget(old);
    if (old.entry.path != _path ||
        old.entry.modifiedMs != widget.entry.modifiedMs) {
      _start();
    }
  }

  void _start() {
    _failed = false;
    // Diskte olduğu biliniyorsa EŞZAMANLI: geri kaydırınca boş kare yok.
    _thumb = ThumbnailCache.knownImage(_path, widget.entry.modifiedMs, _width);
    if (_thumb == null) {
      _preview =
          ThumbnailCache.anyKnownImage(_path, widget.entry.modifiedMs);
      _load();
    }
  }

  Future<void> _load() async {
    final path = _path;
    // Hızlı savurmada bekle (aynı kural: [_VideoThumbState._load]).
    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() {
          if (mounted && path == _path && _thumb == null && !_failed) _load();
        });
      });
      return;
    }
    final result = await ThumbnailCache.forImage(path,
        modifiedMs: widget.entry.modifiedMs,
        size: _width,
        wanted: () => mounted && path == _path);
    if (!mounted || path != _path) return;
    setState(() {
      _thumb = result;
      _failed = result == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    final exact = _thumb;
    final thumb = exact ?? _preview;
    if (thumb == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest),
      );
    }
    // Küçük resim dosyası zaten hücre ölçüsünde (kısa kenarı [_width]):
    // ikinci kez küçültülmez. Eskiden `cacheWidth` GENİŞLİĞİ kısıtlıyordu —
    // yatay fotoğrafta yükseklik hücrenin altına düşüp `cover` ile yeniden
    // büyütülüyordu (bulanıklığın ikinci kaynağı, 2026-11-04).
    final provider = FmFileImage(thumb);
    if (exact != null) fmRememberThumb(_path, provider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image(
        image: provider,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        // Orta: küçültürken kenarlar tırtıklanmaz (küçük resim ≤ 768 px,
        // maliyeti ihmal edilir).
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: _placeholder(widget.size),
        errorBuilder: (_, _, _) => widget.fallback,
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  final String path;
  final double size;
  final double radius;
  final Widget fallback;

  const _VideoThumb({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
  });

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  String? _thumb;

  /// Süre rozeti (kullanıcı isteği 2026-08-28: *"videolarda dk ve sn'si
  /// önizlemedeyken sağ alt köşesinde yazmalı"*). Küçük resimden AYRI
  /// yükleniyor: ikisi farklı native çağrı ve süre gelmeden küçük resmi
  /// bekletmek listeyi geciktirirdi.
  String? _duration;
  bool _started = false;

  /// İlk yükleme `initState`te DEĞİL: [_load] kaydırma hızını soruyor
  /// (`Scrollable.recommendDeferredLoadingForContext` → `View.of`) ve
  /// `initState` içinde kalıtılan widget'a bağımlılık kurmak yasak — hata
  /// ayıklama derlemesinde kırmızı ekran, yayında sessizce eskiyen değer.
  /// (2026-10-18 görsel denetimde dosya işlem menüsünün başlığındaki video
  /// simgesiyle yakalandı.)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoThumb old) {
    super.didUpdateWidget(old);
    // Liste öğesi geri dönüştürülüp başka videoya bağlanabilir.
    if (old.path != widget.path) {
      _thumb = null;
      _duration = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    // **Hızlı savurmada bekle** (2026-09-26): 748 videoluk ızgarada parmakla
    // savurunca saniyede onlarca hücre bir anlığına kuruluyor ve her biri
    // yerel küçük resim + süre çağrısı başlatıyordu; kuyruk dolunca durduğun
    // yerdeki videolar en son geliyordu. Flutter'ın görsellerde yaptığının
    // aynısı (`ScrollAwareImageProvider`): kaydırma hızı "ertele" diyorsa bir
    // sonraki kareye kadar bekle; hücre o arada ekrandan çıkarsa iş hiç
    // başlamaz.
    if (Scrollable.recommendDeferredLoadingForContext(context)) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() {
          if (mounted && path == widget.path && _thumb == null) _load();
        });
      });
      return;
    }
    unawaited(_loadDuration(path));
    final result = await ThumbnailCache.forVideo(path,
        size: (widget.size * 2).round().clamp(96, 512),
        // Sırası geldiğinde hücre ekrandan çıkmışsa kare hiç çözülmez.
        wanted: () => mounted && path == widget.path);
    if (!mounted || path != widget.path) return;
    // Küçük resim üretilemedi: dosya silinmiş olabilir (bkz. FsEvents).
    if (result == null) FsEvents.reportUnreadable(path);
    setState(() => _thumb = result);
  }

  Future<void> _loadDuration(String path) async {
    final duration = await MediaDuration.forVideo(path);
    if (!mounted || path != widget.path || duration == null) return;
    setState(() => _duration = MediaDuration.format(duration));
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    if (thumb == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Image(
            image: FmFileImage(thumb,
                cover: true,
                cacheWidth: fmThumbWidth(widget.size,
                    MediaQuery.maybeDevicePixelRatioOf(context) ?? 3)),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
          // **Tek rozet: ▶ + süre, SAĞ ALT köşe** (2026-09-26 galeri turu).
          // Eskiden iki ayrı rozet vardı — sol altta oynat dairesi, sağ altta
          // süre kutusu — ve küçük hücrede ikisi birlikte karenin alt
          // şeridini kaplıyordu. Google Foto/Samsung Galeri'deki gibi tek hap:
          // "bu bir video" ve "ne kadar sürüyor" aynı yerde okunur.
          // Süre sağ altta KALDI (kullanıcı isteği 2026-08-28: *"videolarda
          // dk ve sn'si önizlemedeyken sağ alt köşesinde yazmalı"*); oynat
          // rozeti köşede kaldı (2026-08-09: ortadaki daire yüzü kapatıyordu).
          //
          // `PositionedDirectional`: Arapça (sağdan sola) arayüzde kendiliğinden
          // karşı köşeye geçer.
          PositionedDirectional(
            end: widget.size * 0.05,
            bottom: widget.size * 0.05,
            child: _VideoBadge(
              size: widget.size,
              // Küçük hücrelerde (liste satırı, 44 px) yazı okunmaz ve karenin
              // yarısını kaplardı; eşik altında yalnız ▶ çizilir.
              duration: widget.size >= 56 ? _duration : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Video rozeti: yarı saydam hap içinde ▶ ve (biliniyorsa) süre.
class _VideoBadge extends StatelessWidget {
  final double size;
  final String? duration;

  const _VideoBadge({required this.size, this.duration});

  @override
  Widget build(BuildContext context) {
    final font = (size * 0.12).clamp(9.0, 12.5);
    final icon = (size * 0.13).clamp(11.0, 16.0);
    final text = duration;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.shade.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: text == null ? 2 : 5,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.play, size: icon, color: AppColors.onMedia),
            if (text != null) ...[
              const SizedBox(width: 1),
              Text(
                text,
                // Kullanıcının uygulama içi yazı ölçeği rozeti taşırmasın.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppColors.onMedia,
                  fontSize: font,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bir depolama biriminin simgesi (ana bellek · SD kart · USB).
///
/// Tek yerde: eskiden üç ekran "birincil değilse SD kart" diyordu ve takılan
/// bir USB bellek SD kart simgesiyle görünüyordu (kullanıcı bulgusu
/// 2026-09-01).
IconData volumeIcon(StorageVolume volume) => switch (volume.iconName) {
      'smartphone' => AppIcons.device,
      'usb' => AppIcons.external,
      _ => AppIcons.sdCard,
    };

/// Önemli dosya rozeti: koyu daire üstünde sarı yıldız (her zeminde okunur).
class FmImportantBadge extends StatelessWidget {
  final double size;
  const FmImportantBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.t('important.badge'),
        child: Container(
          key: const ValueKey<String>('fm-important-badge'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.mediaSurface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(AppIcons.star,
              size: size * 0.78, color: AppHues.amberBright),
        ),
      );
}
