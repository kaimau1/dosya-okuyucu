import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/file_service.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/pdf_thumbnail.dart';
import '../../services/fm/thumbnail_cache.dart';
import '../file_type_icon.dart';

/// Dosya yöneticisi ikon paleti. Office dörtlüsü [OfficeColors]'tan gelir
/// (liste ve şerit aynı tonu kullansın diye — bkz. HAFIZA 2026-07-24 tutarsızlık
/// bulgusu); yeni kategoriler burada tanımlanır.
abstract final class FmColors {
  // Kağıt teması (2026-08-04): kağıt zeminde parlak renkler bağırıyordu —
  // hepsi bir kademe koyulaştırıldı (koyu temada aşağıdaki beyaza doğru
  // lerp mantığı korunuyor).
  static const folder = Color(0xFFB07C2A); // klasör okrası
  static const image = Color(0xFF7A4A93);
  static const video = Color(0xFFA6382F);
  static const audio = Color(0xFF1E6F66);
  static const archive = Color(0xFF6B4B39);
  static const apk = Color(0xFF3E7A3C);
  static const other = Color(0xFF6E6555);

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

  static IconData iconFor(FmCategory c) => switch (c) {
        FmCategory.folder => Icons.folder_rounded,
        FmCategory.image => Icons.image_rounded,
        FmCategory.video => Icons.movie_rounded,
        FmCategory.audio => Icons.music_note_rounded,
        FmCategory.archive => Icons.folder_zip_rounded,
        FmCategory.apk => Icons.android_rounded,
        FmCategory.document => Icons.description_rounded,
        FmCategory.other => Icons.insert_drive_file_rounded,
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

  /// Uzantıya özel glif + renk (yoksa null → kategori glifi kullanılır).
  static (IconData, Color)? forExtension(String ext) => switch (ext) {
        'apk' || 'xapk' || 'apks' || 'aab' => (Icons.android_rounded, apk),
        'zip' || 'rar' || '7z' || 'tar' || 'gz' || 'bz2' || 'xz' || 'zst' =>
          (Icons.folder_zip_rounded, archive),
        'epub' || 'mobi' || 'azw' || 'azw3' || 'fb2' =>
          (Icons.menu_book_rounded, const Color(0xFF8D5524)),
        'ttf' || 'otf' || 'woff' || 'woff2' =>
          (Icons.font_download_rounded, const Color(0xFF5C4B8A)),
        'json' || 'xml' || 'yaml' || 'yml' || 'html' || 'htm' || 'css' ||
        'js' || 'ts' || 'dart' || 'py' || 'java' || 'kt' || 'c' || 'cpp' ||
        'sh' =>
          (Icons.code_rounded, const Color(0xFF3A6EA5)),
        'iso' || 'img' || 'dmg' => (Icons.album_rounded, const Color(0xFF5B6670)),
        'torrent' => (Icons.swap_vert_circle_rounded, const Color(0xFF2E7D5B)),
        'db' || 'sqlite' || 'sql' =>
          (Icons.storage_rounded, const Color(0xFF6E6555)),
        'log' || 'ini' || 'cfg' || 'conf' =>
          (Icons.receipt_long_rounded, other),
        'vcf' => (Icons.contact_page_rounded, const Color(0xFF3A6EA5)),
        'ics' => (Icons.event_note_rounded, const Color(0xFFB07C2A)),
        _ => null,
      };

  /// Bilinen klasörün kendi glifi (yoksa null → düz klasör).
  ///
  /// Ad karşılaştırması küçük harfe indirilmiş TAM ad üzerinden yapılır:
  /// "Download" klasörü ile "Download Manager Logs" farklı şeyler, ikincisine
  /// indirme oku çizmek yanıltıcı olurdu.
  static IconData? forFolderName(String name) => switch (name.toLowerCase()) {
        'download' || 'downloads' || 'indirilenler' =>
          Icons.download_rounded,
        'dcim' || 'camera' || 'kamera' => Icons.photo_camera_rounded,
        'pictures' || 'images' || 'resimler' || 'görüntüler' =>
          Icons.photo_library_rounded,
        'movies' || 'video' || 'videos' || 'videolar' =>
          Icons.video_library_rounded,
        'music' || 'müzik' || 'audio' || 'ses' => Icons.library_music_rounded,
        'documents' || 'belgeler' => Icons.folder_copy_rounded,
        'whatsapp' || 'telegram' || 'signal' => Icons.forum_rounded,
        'android' || 'system' || 'data' => Icons.settings_rounded,
        'screenshots' || 'ekran görüntüleri' => Icons.screenshot_rounded,
        'backup' || 'backups' || 'yedek' => Icons.backup_rounded,
        'fonts' => Icons.font_download_rounded,
        _ => null,
      };
}

/// Bir girdinin ikonu. Görsellerde gerçek küçük resim (thumbnail) gösterilir;
/// belgelerde mevcut [FileTypeIcon] (Word mavisi / Excel yeşili …).
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

  @override
  Widget build(BuildContext context) {
    final category = entry.category;
    // Kullanıcı ayarlardan küçük resimleri kapatabilir (yavaş cihaz).
    final thumbsOn =
        thumbnails && (context.select<AppState, bool>((s) => s.fmThumbnails));

    if (category == FmCategory.document) {
      final icon = FileTypeIcon(
        // Simge türü: .xls/.doc gibi ESKİ biçimler de kendi markalarıyla
        // görünsün (editör yönlendirmesi ayrı bir soru — bkz.
        // `iconKindForExtension`).
        kind: FileService.iconKindForExtension(entry.extension),
        size: size,
      );
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
      return icon;
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(entry.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Bellek koruması: 4000px'lik bir fotoğrafı 44dp'lik kutuya tam
          // çözünürlükte açmak listeyi şişirir (cacheWidth = decode boyutu).
          cacheWidth: (size * 3).round(),
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          // Açılamayan resim: dosya silinmiş olabilir (Galeri/WhatsApp
          // temizliği). Bildir — gerçekten yoksa listeden düşürülür, duruyorsa
          // (bozuk dosya) rozet kalır. Bkz. FsEvents.reportUnreadable.
          errorBuilder: (_, __, ___) {
            FsEvents.reportUnreadable(entry.path);
            return _badge(context, category);
          },
        ),
      );
    }

    return _badge(context, category);
  }

  /// Kategori glifinden **daha özel** bir glif varsa onu kullanır: uzantıya
  /// özel (apk/zip/epub/font/kod…) ya da bilinen klasör adı (İndirilenler,
  /// DCIM, WhatsApp…). Bkz. [FmColors.forExtension] / [FmColors.forFolderName].
  Widget _badge(BuildContext context, FmCategory category) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var icon = FmColors.iconFor(category);
    var base = FmColors.forCategory(category);
    if (entry.isDir) {
      icon = FmColors.forFolderName(entry.name) ?? icon;
    } else {
      final special = FmColors.forExtension(entry.extension);
      if (special != null) {
        icon = special.$1;
        base = special.$2;
      }
    }
    final tint = dark ? Color.lerp(base, Colors.white, 0.25)! : base;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, color: tint, size: size * 0.92),
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

  const _PdfThumb({
    required this.path,
    required this.size,
    required this.fallback,
    this.radius = Radii.control,
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
    final result = await PdfThumbnail.forPdf(path,
        size: (widget.size * 2).round().clamp(96, 512));
    if (!mounted || path != widget.path) return;
    setState(() => _thumb = result);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb;
    if (thumb == null) return widget.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image.file(
        File(thumb),
        width: widget.size,
        height: widget.size,
        // `contain`: sayfa oranı korunsun, kırpılmasın — kırpılmış bir kapak
        // yanlış belgeymiş gibi görünür.
        fit: BoxFit.contain,
        cacheWidth: (widget.size * 3).round(),
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.fallback,
      ),
    );
  }
}

/// Video küçük resmi: önbellekten gelir, yoksa arka planda üretilir.
/// Üretim bitene kadar (ve üretilemezse) [fallback] ikonu görünür — liste
/// asla boş kutu göstermez.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoThumb old) {
    super.didUpdateWidget(old);
    // Liste öğesi geri dönüştürülüp başka videoya bağlanabilir.
    if (old.path != widget.path) {
      _thumb = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final result = await ThumbnailCache.forVideo(path,
        size: (widget.size * 2).round().clamp(96, 512));
    if (!mounted || path != widget.path) return;
    // Küçük resim üretilemedi: dosya silinmiş olabilir (bkz. FsEvents).
    if (result == null) FsEvents.reportUnreadable(path);
    setState(() => _thumb = result);
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
          Image.file(
            File(thumb),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: (widget.size * 3).round(),
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => widget.fallback,
          ),
          // **Oynat rozeti KÖŞEDE, ortada değil** (kullanıcı 2026-08-09:
          // *"videolarda üstteki oynat butonu görüntüyü bozuyor"*). Ortadaki
          // %42'lik daire küçük resmin tam da anlamlı yerini — yüzü, sahneyi —
          // kapatıyordu; ızgarada video seçmek imkânsızlaşıyordu. Rozetin işi
          // "bu bir video" demek; bunun için köşede %18 yetiyor.
          //
          // `PositionedDirectional`: Arapça (sağdan sola) arayüzde kendiliğinden
          // karşı köşeye geçer.
          PositionedDirectional(
            start: widget.size * 0.05,
            bottom: widget.size * 0.05,
            child: Icon(
              Icons.play_circle_fill,
              size: (widget.size * 0.18).clamp(12.0, 28.0),
              color: Colors.white.withValues(alpha: 0.92),
              // Açık zeminli karede beyaz rozet kaybolmasın.
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
