import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/document.dart';
import '../../models/fs_entry.dart';
import '../../models/recent_file.dart';
import '../../screens/editors/slides_editor_screen.dart';
import '../../screens/editors/spreadsheet_editor_screen.dart';
import '../../screens/editors/word_editor_screen.dart';
import '../../screens/fm/image_gallery_screen.dart';
import '../../screens/fm/media_player_screen.dart';
import '../../screens/viewer_screen.dart';
import '../file_service.dart';

/// Bir dosyanın hangi ekranda açılacağı. Saf karar fonksiyonu
/// ([EntryOpener.routeFor]) olduğu için birim testiyle sabitlenir.
enum OpenRoute {
  /// Belge/metin/PDF → mevcut görüntüleyici-editörler.
  document,

  /// Görsel → kaydırmalı galeri (tek görselde görüntüleyici).
  gallery,

  /// Video/ses → uygulama içi oynatıcı.
  player,

  /// APK/arşiv/bilinmeyen ikili → sistemin uygulaması.
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
      FmCategory.video || FmCategory.audio => OpenRoute.player,
      FmCategory.document || FmCategory.other => OpenRoute.document,
      FmCategory.apk || FmCategory.archive || FmCategory.folder =>
        OpenRoute.external,
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
      return;
    }
    final route = routeFor(path);
    final group = siblings == null ? <String>[path] : siblingsFor(path, siblings);

    if (route == OpenRoute.external) {
      await openExternally(context, path);
      return;
    }
    if (route == OpenRoute.player) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MediaPlayerScreen(path: path, playlist: group),
      ));
      return;
    }
    if (route == OpenRoute.gallery && group.length > 1) {
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

  /// Sistemin varsayılan uygulamasına devreder (video, ses, apk, bilinmeyen).
  static Future<void> openExternally(BuildContext context, String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type == ResultType.done) return;
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
