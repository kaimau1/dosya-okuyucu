import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

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
      FmCategory.archive => ArchiveOps.canExtract(path)
          ? OpenRoute.archive
          : OpenRoute.external,
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

  /// [path]'i açar. [siblings] verilirse (aynı klasördeki dosyalar) görseller
  /// kaydırmalı galeride, medya dosyaları çalma listesiyle oynatıcıda açılır.
  static Future<void> open(
    BuildContext context,
    String path, {
    List<String>? siblings,
  }) async {
    if (!File(path).existsSync()) {
      _snack(context, 'Dosya bulunamadı (taşınmış ya da silinmiş olabilir).');
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
            path: doc.path, name: doc.name, plainText: doc.plainText);
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
      OpenRoute.audio => 'Ses dosyası',
      _ => 'Görsel',
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
            ? 'Bu dosya türünü açabilen bir uygulama bulunamadı.'
            : 'Dosya açılamadı: ${result.message}',
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Dosya açılamadı: $e');
    }
  }

  static void _showBusy(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
        title: Text('${widget.kind} neyle açılsın?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Uygulama içi oynatıcı'),
              subtitle: const Text('Hızlı açılır, uygulamadan çıkmazsın'),
              onTap: () => _pick(MediaOpenWith.inApp),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: const Text('Başka uygulama'),
              subtitle: const Text('Kendi medya oynatıcın / galerin'),
              onTap: () => _pick(MediaOpenWith.external),
            ),
            const SizedBox(height: Gap.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: const Text('Bunu hatırla'),
              subtitle: const Text('Ayarlardan değiştirebilirsin'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
        ],
      );
}
