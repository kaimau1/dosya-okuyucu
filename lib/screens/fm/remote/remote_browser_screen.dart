import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_icons.dart';
import '../../../core/busy_dialog.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/fs_entry.dart';
import '../../../models/remote_connection.dart';
import '../../../services/file_service.dart';
import '../../../services/fm/entry_opener.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/fs_scan.dart';
import '../../../services/fm/remote/remote_fs.dart';
import '../../../services/fm/remote/remote_fs_factory.dart';
import '../../../services/fm/remote/usb_fs.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/fm/fm_entry_icon.dart';
import '../browser_screen.dart';
import 'remote_edit_screen.dart';
import '../../../core/snack.dart';
import '../../../widgets/motion.dart';

part 'remote_browser/actions.dart';
part 'remote_browser/views.dart';

/// Uzak sunucu gezgini: listeler, indirip açar, yükler, siler.
///
/// **Açma yolu indir-önbelleğe-aç.** Uzak dosya uygulamanın kendi klasörüne
/// iner, sonra mevcut [EntryOpener] zinciriyle açılır: PDF/Word/Excel/slayt/
/// video/arşiv desteğinin tamamı ilk günden çalışıyor ve `FileOps`un saf
/// `dart:io` değişmezi bozulmuyor.
class RemoteBrowserScreen extends StatefulWidget {
  final RemoteConnection connection;

  /// Testte sahte dosya sistemi takmak için.
  final RemoteFs? fs;

  const RemoteBrowserScreen({super.key, required this.connection, this.fs});

  @override
  State<RemoteBrowserScreen> createState() => _RemoteBrowserScreenState();
}

class _RemoteBrowserScreenState extends State<RemoteBrowserScreen> {
  late final RemoteFs _fs = widget.fs ?? createRemoteFs(widget.connection);

  late String _path = widget.connection.rootPath;
  List<RemoteEntry> _entries = const [];
  bool _busy = true;
  String? _error;
  bool _connected = false;

  /// **Seçili girdilerin yolları.** Kullanıcı isteği 2026-09-02 (dışarıdan
  /// bakış): USB'den "şu 30 fotoğrafı telefona kopyala" yapılamıyordu —
  /// çoklu seçim yoktu ve tek dosya için bile "kopyala" eylemi yoktu.
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  /// Klasör içi süzme metni (boşsa süzme yok).
  String _filter = '';
  bool _searching = false;

  /// Sıralama ölçütü ve yönü.
  _RemoteSort _sort = _RemoteSort.name;
  bool _ascending = true;

  /// Toplu iş sürerken ilerleme ("3/12"); yoksa null.
  String? _progress;

  /// Ham USB'de birimin doluluğu ("47,4 GB / 62 GB"); bilinmiyorsa boş.
  String _usage = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _fs.close();
    super.dispose();
  }

  /// **Saf sıralama** (testli).
  static List<RemoteEntry> sortEntries(
    List<RemoteEntry> entries,
    _RemoteSort sort, {
    required bool ascending,
  }) {
    final out = [...entries];
    out.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final int c;
      switch (sort) {
        case _RemoteSort.name:
          c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _RemoteSort.size:
          c = a.sizeBytes.compareTo(b.sizeBytes);
        case _RemoteSort.date:
          c = a.modifiedMs.compareTo(b.modifiedMs);
      }
      if (c != 0) return ascending ? c : -c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Geri tuşu önce KLASÖR hiyerarşisinde yukarı çıkar; ekrandan çıkmaz.
    // Aksi hâlde kullanıcı beş klasör derinken tek dokunuşla dışarı atılırdı.
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _up();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionAppBar()
            : AppBar(
          title: _searching
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: context.t('nas.filter_hint'),
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                )
              : Text(widget.connection.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: 16, end: 16, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    // Yol her zaman görünür; uyarı ve doluluk yanına ekleniyor.
                    [
                      _path,
                      if (_usage.isNotEmpty) _usage,
                      if (_readOnlyNote.isNotEmpty) _readOnlyNote,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: context.t('nas.filter_hint'),
              icon: Icon(_searching ? AppIcons.searchOff : AppIcons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _filter = '';
              }),
            ),
            IconButton(
              tooltip: context.t('common.refresh'),
              icon: const Icon(AppIcons.refresh),
              onPressed: _busy ? null : () => _load(_path),
            ),
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (_) => [
                // Sıralama HER protokolde var (salt okunur bellekte de):
                // 4000 dosyalı bir USB'de sırasız liste kullanılamaz.
                for (final sort in _RemoteSort.values)
                  CheckedPopupMenuItem(
                    value: 'sort_${sort.name}',
                    checked: _sort == sort,
                    child: Text(context.t('nas.sort_${sort.name}')),
                  ),
                CheckedPopupMenuItem(
                  value: 'asc',
                  checked: _ascending,
                  child: Text(context.t('nas.sort_ascending')),
                ),
                if (_connected && _fs.canWrite) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'upload',
                      child: Text(context.t('nas.upload_here'))),
                  PopupMenuItem(
                      value: 'mkdir',
                      child: Text(context.t('nas.new_folder'))),
                ],
                // **Güvenle çıkar YALNIZ ham USB'de.** Android'in bağladığı
                // bir birimi uygulama çıkaramaz; oraya düğme koymak
                // çalışmayan bir söz vermek olurdu.
                if (_fs is UsbFs) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'eject', child: Text(context.t('usb.eject'))),
                ],
              ],
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  /// Aynı adlı dosyanın ÜSTÜNE YAZMAZ: `ad (2).jpg` üretir.
  static String _uniquePath(String dir, String name) {
    var candidate = p.join(dir, name);
    if (!File(candidate).existsSync()) return candidate;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    for (var i = 2; i < 1000; i++) {
      candidate = p.join(dir, '$base ($i)$ext');
      if (!File(candidate).existsSync()) return candidate;
    }
    return candidate;
  }


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}

/// İndirilen kopyayı uygulamanın görüntüleyici/editör zincirinde açar.
///
/// Değiştirilebilir bir işlev: widget testinde gerçek görüntüleyici
/// açılamaz (dosya ayrıştırma + platform kanalı ister), testler bunu
/// sahtesiyle değiştirip "kullanıcı düzenledi" durumunu taklit ediyor.
/// **Bağlantı kimliğini klasör adı yapar** — saf, testli.
///
/// Kullanıcı hatası 2026-09-02 (ekran görüntüsü): ham USB'den bir mp3
/// açılınca *"Bu ses dosyası çalınamadı: MEDIA_ERROR_UNKNOWN"* çıkıyordu.
/// Kök neden dosya değil, YOL: indirilen kopya `…/remote/<bağlantı kimliği>/`
/// altına yazılıyor ve kimlik `usb:USB` (SAF'ta `saf:content://…`) gibi
/// **iki nokta ve eğik çizgi** içeriyor. Android'in MediaPlayer'ı böyle bir
/// yolu adres (URI) sanıp reddediyor; SAF'ta ise eğik çizgiler yolu
/// beklenmedik alt klasörlere bölüyordu.
///
/// Harf, rakam, `.`, `-` ve `_` dışındaki her şey `_` oluyor; ad boş kalırsa
/// `baglanti` deniyor (boş klasör adı yol birleştirmeyi bozardı).
String safeCacheName(String id) {
  final cleaned = id
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      // Art arda gelenler tek alt çizgiye iner: `content://` üç karakter,
      // üç alt çizgi olarak kalsaydı ad gereksiz çirkin olurdu.
      .replaceAll(RegExp(r'_{2,}'), '_');
  final trimmed = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'baglanti' : trimmed;
}

Future<void> Function(BuildContext context, String path) openLocalFile =
    (context, path) => EntryOpener.open(context, path);

/// Yüklenecek yerel dosyayı sistem seçicisiyle sorar.
///
/// Değiştirilebilir bir işlev: widget testinde dosya seçici açılamaz
/// (platform kanalı yok), testler bunu sahtesiyle değiştiriyor.
Future<String?> Function() pickLocalFile =
    () => FileService().pickFilePath();


/// Uzak/USB gezgininde sıralama ölçütü.
enum _RemoteSort { name, size, date }
