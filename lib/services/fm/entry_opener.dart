import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../models/media_open_with.dart';
import '../../models/recent_file.dart';
import '../../screens/editors/slides_editor_screen.dart';
import '../../screens/editors/spreadsheet_editor_screen.dart';
import '../../screens/editors/word_editor_screen.dart';
import '../../screens/fm/archive_screen.dart';
import '../../screens/fm/audio_player_screen.dart';
import '../../screens/fm/image_gallery_screen.dart';
import '../../screens/fm/media_player_screen.dart';
import '../../screens/viewer_screen.dart';
import '../file_service.dart';
import 'archive_ops.dart';
import 'fs_events.dart';
import 'open_history.dart';
import '../../core/snack.dart';

/// Bir dosyanın hangi ekranda açılacağı. Saf karar fonksiyonu
/// ([EntryOpener.routeFor]) olduğu için birim testiyle sabitlenir.
enum OpenRoute {
  /// Belge/metin/PDF → mevcut görüntüleyici-editörler.
  document,

  /// Görsel → kaydırmalı galeri (tek görselde görüntüleyici).
  gallery,

  /// Video → uygulama içi video oynatıcı.
  player,

  /// Ses → müzik çalar (ayrı motor: ekran kapansa da çalar).
  audio,

  /// Arşiv (zip/rar/7z/tar…) → uygulama içi arşiv ekranı.
  archive,

  /// APK/bilinmeyen ikili → sistemin uygulaması.
  external,
}

/// Bir dosyayı "doğru" şekilde açar: görsel → galeri, video/ses → oynatıcı,
/// belge → görüntüleyici/editör, kalanı → sistemin uygulaması.
///
/// Tek kapı olması önemli: son belgeler listesi, dosya yöneticisi, kategori
/// ekranları ve arama sonuçları aynı davranışı paylaşır (eskiden açma mantığı
/// yalnız `home_screen` içindeydi).
abstract final class EntryOpener {
  static final _fileService = FileService();

  /// Dosya hangi ekrana gider?
  ///
  /// `other` (tanınmayan uzantı) belge yoluna gider: içeriği metin olabilir
  /// (`FileService` imza/metin tanıması yapar). Açamazsak görüntüleyici
  /// "Başka uygulamayla aç" düğmesini gösterir — kullanıcı uygulamadan atılmaz.
  static OpenRoute routeFor(String path) {
    final cat = FsEntry.categoryForExtension(_ext(path));
    return switch (cat) {
      FmCategory.image => OpenRoute.gallery,
      FmCategory.video => OpenRoute.player,
      FmCategory.audio => OpenRoute.audio,
      FmCategory.document || FmCategory.other => OpenRoute.document,
      // Açabildiğimiz arşivler kendi ekranımıza gider; okuyamadığımız biçim
      // (ör. .iso) sisteme düşer.
      FmCategory.archive =>
        ArchiveOps.canExtract(path) ? OpenRoute.archive : OpenRoute.external,
      FmCategory.apk || FmCategory.folder => OpenRoute.external,
    };
  }

  /// [paths] içinden [path] ile aynı yola giden dosyalar (galeri/çalma listesi).
  static List<String> siblingsFor(String path, List<String> paths) {
    final route = routeFor(path);
    final same = paths.where((x) => routeFor(x) == route).toList();
    if (!same.contains(path)) same.insert(0, path);
    return same;
  }

  static String _ext(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Dosyayı **açmadan** "Son belgeler"e ve açılma geçmişine yazar.
  ///
  /// Niye ayrı bir yol (2026-08-06 kullanıcı bulgusu: *"oluşturduğumuz
  /// taranmış belgelerin PDF'i son dosyalara düşmüyor"*): kayıt şimdiye kadar
  /// yalnız [open] içinde yapılıyordu, yani belge ancak GÖRÜNTÜLEYİCİDE
  /// açılırsa listeye giriyordu. Tarama akışı kendi sonuç ekranına gittiği
  /// için üretilen PDF hiçbir listeye düşmüyordu — kullanıcının gözünde
  /// "kaydedildi ama kayboldu". Uygulamanın kendi ürettiği belgeler
  /// (tarama, boş belge, dönüştürme) artık bu yoldan kaydediliyor.
  ///
  /// [eskiYol] verilirse (yeniden adlandırma/taşıma) o kayıt düşürülür.
  static Future<void> rememberFile(
    BuildContext context,
    String path, {
    String? previousPath,
  }) async {
    final appState = context.read<AppState>();
    final file = File(path);
    if (!file.existsSync()) return;
    if (previousPath != null && previousPath != path) {
      await appState.removeRecent(previousPath);
    }
    unawaited(OpenHistory.record(path));
    await appState.addRecent(RecentFile(
      path: path,
      name: p.basename(path),
      sizeBytes: file.lengthSync(),
      openedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// [path]'i açar. [siblings] verilirse (aynı klasördeki dosyalar) görseller
  /// kaydırmalı galeride, medya dosyaları çalma listesiyle oynatıcıda açılır.
  static Future<void> open(
    BuildContext context,
    String path, {
    List<String>? siblings,
  }) async {
    if (!File(path).existsSync()) {
      _snack(context, context.t('open.not_found'));
      // Listede kalan hayalet kaydı düşür — kullanıcı bir daha görmesin.
      FsEvents.reportUnreadable(path);
      return;
    }
    final route = routeFor(path);
    final group =
        siblings == null ? <String>[path] : siblingsFor(path, siblings);

    if (route == OpenRoute.external) {
      await openExternally(context, path);
      return;
    }

    if (route == OpenRoute.archive) {
      unawaited(OpenHistory.record(path));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveScreen(path: path),
      ));
      return;
    }

    // Medya (video / ses / görsel): kullanıcı kendi oynatıcısını tercih
    // edebilir. Tercih yoksa İLK açılışta sorulur ve hatırlanır.
    if (isMediaRoute(route)) {
      final choice = await _resolveMediaChoice(context, route);
      if (!context.mounted) return;
      if (choice == null) return; // kullanıcı vazgeçti
      if (choice == MediaOpenWith.external) {
        await openExternally(context, path);
        return;
      }
    }

    if (route == OpenRoute.player) {
      unawaited(OpenHistory.record(path));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(path: path, playlist: group),
      ));
      return;
    }
    if (route == OpenRoute.audio) {
      unawaited(OpenHistory.record(path));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AudioPlayerScreen(path: path, playlist: group),
      ));
      return;
    }
    if (route == OpenRoute.gallery && group.length > 1) {
      unawaited(OpenHistory.record(path));
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ImageGalleryScreen(
          paths: group,
          initialIndex: group.indexOf(path),
        ),
      ));
      return;
    }

    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    _showBusy(context);
    LoadedDoc doc;
    try {
      doc = await _fileService.load(path);
    } catch (e) {
      if (context.mounted) navigator.pop(); // yükleniyor penceresini kapat
      if (context.mounted) _snack(context, 'Dosya açılamadı: $e');
      return;
    }
    if (!context.mounted) return;
    navigator.pop();

    unawaited(OpenHistory.record(path));
    await appState.addRecent(RecentFile(
      path: path,
      name: doc.name,
      sizeBytes: _fileService.sizeOf(path),
      openedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!context.mounted) return;
    await navigator.push(MaterialPageRoute(builder: (_) => screenFor(doc)));
  }

  /// Yüklenmiş belgeye uygun ekran. (Salt-okunur içerik OOXML editörlerine
  /// gitmez — bkz. HAFIZA 2026-07-21 legacy notu.)
  static Widget screenFor(LoadedDoc doc) {
    if (doc.readOnly) return ViewerScreen(doc: doc);
    switch (doc.kind) {
      case DocKind.spreadsheet:
        return SpreadsheetEditorScreen(
          path: doc.path,
          name: doc.name,
          plainText: doc.plainText,
          savePath: doc.savePath,
        );
      case DocKind.word:
        return WordEditorScreen(
            path: doc.path, name: doc.name, plainText: doc.plainText);
      case DocKind.slides:
        return SlidesEditorScreen(
            path: doc.path, name: doc.name, plainText: doc.plainText);
      default:
        return ViewerScreen(doc: doc);
    }
  }

  /// Bu rota "kendi oynatıcım açılsın mı" sorusunun anlamlı olduğu bir medya
  /// rotası mı? (Video, ses ve görsel — belge/arşiv değil.)
  static bool isMediaRoute(OpenRoute route) =>
      route == OpenRoute.player ||
      route == OpenRoute.audio ||
      route == OpenRoute.gallery;

  /// Medya tercihini çözer: ayarda seçim varsa onu kullanır, "sor" ise
  /// kullanıcıya sorar. Kullanıcı pencereyi kapatırsa null döner (dosya
  /// açılmaz — yanlışlıkla bir uygulamaya atılmasındansa hiçbir şey yapma).
  static Future<MediaOpenWith?> _resolveMediaChoice(
    BuildContext context,
    OpenRoute route,
  ) async {
    final appState = context.read<AppState>();
    final saved = appState.fmMediaOpenWith;
    if (saved != MediaOpenWith.ask) return saved;

    final kind = switch (route) {
      OpenRoute.player => 'Video',
      OpenRoute.audio => context.t('open.kind_audio'),
      _ => context.t('open.kind_image'),
    };
    return showDialog<MediaOpenWith>(
      context: context,
      builder: (ctx) => _MediaChoiceDialog(kind: kind, appState: appState),
    );
  }

  /// Sistemin varsayılan uygulamasına devreder (video, ses, apk, bilinmeyen).
  static Future<void> openExternally(BuildContext context, String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done) {
        unawaited(OpenHistory.record(path));
        return;
      }
      if (!context.mounted) return;
      _snack(
        context,
        result.type == ResultType.noAppToOpen
            ? context.t('open.no_app')
            : context.t('home.open_error', {'error': result.message}),
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Dosya açılamadı: $e');
    }
  }

  /// Yükleniyor penceresi — çıplak spinner değil, NE olduğunu söyleyen bir
  /// kart (2026-08-06 kullanıcı bulgusu: "açılıyor mu ne oluyor belli değil").
  static void _showBusy(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 16),
                Text(ctx.t('open.opening')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String message) {
    showSnack(context, message);
  }
}

/// "Bu dosyayı neyle açalım?" penceresi.
///
/// Kullanıcı isteği (2026-07-25): "kişi videoları veya fotoğrafları kendi
/// media player'ından oynatmak isteyebilir; hem ayarlarda hem ilk kez
/// oynatılacağı zaman soralım."
///
/// "Bunu hatırla" işaretliyse seçim kalıcı olur (ayarlardan değiştirilebilir);
/// işaretli değilse yalnız bu açılış için geçerlidir.
class _MediaChoiceDialog extends StatefulWidget {
  final String kind;
  final AppState appState;
  const _MediaChoiceDialog({required this.kind, required this.appState});

  @override
  State<_MediaChoiceDialog> createState() => _MediaChoiceDialogState();
}

class _MediaChoiceDialogState extends State<_MediaChoiceDialog> {
  bool _remember = true;

  Future<void> _pick(MediaOpenWith choice) async {
    if (_remember) await widget.appState.setFmMediaOpenWith(choice);
    if (mounted) Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.t('open.with_what', {'kind': widget.kind})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(context.t('open.in_app_player')),
              subtitle: Text(context.t('open.in_app_hint')),
              onTap: () => _pick(MediaOpenWith.inApp),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: Text(context.t('open.other_app')),
              subtitle: Text(context.t('open.other_app_hint')),
              onTap: () => _pick(MediaOpenWith.external),
            ),
            const SizedBox(height: Gap.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text(context.t('open.remember')),
              subtitle: Text(context.t('open.remember_hint')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.cancel')),
          ),
        ],
      );
}
