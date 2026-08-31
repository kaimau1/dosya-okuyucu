import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/fm/remote/ftp_service.dart';
import '../../../services/fm/remote/ftp_tree.dart';
import '../../../services/fm/remote/share_scope.dart';

/// **Paylaşılacak klasörler** — ağ paylaşımının kapsamını seçme ekranı.
///
/// Kullanıcı isteği (2026-08-31): *"ağ paylaşımında hangi klasörlerin
/// paylaşılacağını seçelim, bir de ayrı olarak paylaşılan klasörü olsun, kişi
/// göndermek istediği şeyi oraya atsın ve sadece o klasör paylaşır … klasör
/// seçimi tümünü seç kaldır seçeneği olmalı."*
///
/// ## Ekranın şekli
/// - **Üstte iki kip:** *Seçtiğim klasörler* (varsayılan) ve *Yalnız
///   Paylaşılan klasörü*. İkisi radyo düğmesi: aynı anda ikisi olamaz ve
///   hangisinin geçerli olduğu tek bakışta görünür.
/// - **Altta kutu listesi**, başında **"Tümünü seç"** satırı. Üç durumlu
///   (`tristate`) kutu bilinçli: hepsi/hiçbiri/bir kısmı ayrı görünüyor ve
///   tek dokunuşla hepsi seçilip hepsi kaldırılabiliyor.
/// - "Yalnız Paylaşılan" kipinde liste **sönük ve dokunulamaz**: gizlemek
///   yerine sönükleştirmek, kipin ne yaptığını gösteriyor.
///
/// ## Değişiklik ANINDA geçerli
/// Kaydet düğmesi yok: her dokunuş [FtpService.setShareScope]'a gidiyor,
/// paylaşım açıksa sunucuya da anında yansıyor. Gerekçe: kullanıcı bir
/// klasörü paylaşımdan çıkarmak için paylaşımı kapatıp açmak — yani süren bir
/// kopyalamayı kesmek — zorunda kalmamalı.
///
/// Kutu adları listede **çevrilmiş** görünüyor, altında ise bilgisayarda
/// görünecek ASCII ad yazıyor ("Bilgisayarda: Ekran Goruntuleri"): kullanıcı
/// PC'deki klasörle telefondakini eşleştirebilsin (adların niye aksansız
/// olduğu [FtpTree]'nin başında).
class ShareFoldersScreen extends StatefulWidget {
  const ShareFoldersScreen({super.key});

  @override
  State<ShareFoldersScreen> createState() => _ShareFoldersScreenState();
}

class _ShareFoldersScreenState extends State<ShareFoldersScreen> {
  final _service = FtpService.instance;

  /// Kutu adı → arayüz metni anahtarı. Kutu adları dosya sisteminde/ağda
  /// kullanılan SABİT değerler; burada yalnız gösterilecek adları eşliyoruz.
  static const _labels = <String, String>{
    ShareScope.sharedBox: 'ftpd.box_shared',
    FtpTree.storageFolder: 'ftpd.box_storage',
    'Indirilenler': 'ftpd.box_downloads',
    'Kamera': 'ftpd.box_camera',
    'Ekran Goruntuleri': 'ftpd.box_screenshots',
    'Resimler': 'ftpd.box_images',
    'Videolar': 'ftpd.box_videos',
    'Ses': 'ftpd.box_audio',
    'Belgeler': 'ftpd.box_documents',
    'Arsivler': 'ftpd.box_archives',
    'Uygulamalar': 'ftpd.box_apps',
  };

  static const _icons = <String, IconData>{
    ShareScope.sharedBox: Icons.folder_shared_outlined,
    FtpTree.storageFolder: Icons.smartphone,
    'Indirilenler': Icons.download_outlined,
    'Kamera': Icons.photo_camera_outlined,
    'Ekran Goruntuleri': Icons.screenshot_outlined,
    'Resimler': Icons.image_outlined,
    'Videolar': Icons.movie_outlined,
    'Ses': Icons.audiotrack_outlined,
    'Belgeler': Icons.description_outlined,
    'Arsivler': Icons.folder_zip_outlined,
    'Uygulamalar': Icons.android_outlined,
  };

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _service.load();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  ShareScope get _scope => _service.shareScope;

  /// Seçili kutular — `null` (hepsi) burada AÇIK listeye çevriliyor ki
  /// arayüz tek bir gösterimle çalışsın.
  Set<String> get _selected =>
      _scope.boxes?.toSet() ?? FtpTree.allBoxes.toSet();

  Future<void> _setMode(ShareMode mode) =>
      _service.setShareScope(_scope.copyWith(mode: mode));

  Future<void> _toggleBox(String box, bool value) async {
    final next = _selected;
    if (value) {
      next.add(box);
    } else {
      next.remove(box);
    }
    await _service.setShareScope(
        ShareScope(mode: ShareMode.boxes, boxes: next));
  }

  /// "Tümünü seç" / "Seçimi kaldır" — kullanıcının açıkça istediği tek
  /// dokunuşluk toptan işlem.
  Future<void> _selectAll(bool value) => _service.setShareScope(ShareScope(
        mode: ShareMode.boxes,
        boxes: value ? FtpTree.allBoxes.toSet() : const <String>{},
      ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sharedOnly = _scope.mode == ShareMode.sharedOnly;
    final selected = _selected;
    final all = FtpTree.allBoxes;
    final allSelected = selected.length == all.length;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('ftpd.folders_title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          _modeTile(
            context,
            mode: ShareMode.boxes,
            title: context.t('ftpd.mode_boxes'),
            subtitle: context.t('ftpd.mode_boxes_desc'),
          ),
          _modeTile(
            context,
            mode: ShareMode.sharedOnly,
            title: context.t('ftpd.mode_shared'),
            subtitle: context.t('ftpd.mode_shared_desc'),
          ),
          const Divider(height: 1),
          // Toptan seçim: üç durumlu kutu — hepsi / hiçbiri / bir kısmı.
          CheckboxListTile(
            value: allSelected ? true : (selected.isEmpty ? false : null),
            tristate: true,
            onChanged: sharedOnly ? null : (_) => _selectAll(!allSelected),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.t(allSelected ? 'ftpd.clear_all' : 'ftpd.select_all'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          for (final box in all)
            _boxTile(context, box,
                enabled: !sharedOnly, value: selected.contains(box)),
          if (!sharedOnly && selected.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
              child: Text(
                context.t('ftpd.folders_none_warning'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Text(
              context.t('ftpd.shared_folder_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTile(
    BuildContext context, {
    required ShareMode mode,
    required String title,
    required String subtitle,
  }) =>
      RadioListTile<ShareMode>(
        value: mode,
        groupValue: _scope.mode,
        onChanged: (v) => v == null ? null : _setMode(v),
        title: Text(title),
        subtitle: Text(subtitle),
        controlAffinity: ListTileControlAffinity.leading,
      );

  Widget _boxTile(BuildContext context, String box,
      {required bool enabled, required bool value}) {
    final label = _labels[box];
    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (v) => _toggleBox(box, v ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(_icons[box] ?? Icons.folder_outlined),
      title: Text(label == null ? box : context.t(label)),
      subtitle: Text(context.t('ftpd.box_on_pc', {'name': box})),
    );
  }
}
