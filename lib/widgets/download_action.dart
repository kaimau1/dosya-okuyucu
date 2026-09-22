import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../screens/fm/browser_screen.dart';
import '../services/fm/fm_env.dart';
import '../services/fm/save_to_downloads.dart';

/// "İndir" düğmesi gösterilsin mi? Yalnız dosya kullanıcının göremediği bir
/// yerdeyse (başka uygulamadan açılmış önbellek kopyası) — bkz.
/// [SaveToDownloads.isPrivateCopy].
bool showDownloadAction(String path) =>
    SaveToDownloads.isPrivateCopy(path, FmEnv.volumeRoots);

/// [save]'i koşturur ve sonucu şeritle söyler; "Göster" İndirilenler
/// klasörünü açar. Görüntüleyici ve üç editör aynı akışı kullanıyor.
Future<void> runDownloadAction(
  BuildContext context,
  Future<SavedDownload> Function() save,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final strings = AppStrings.of(context);
  try {
    final saved = await save();
    final name = p.basename(saved.path);
    showSnackOn(
      messenger,
      strings.t(saved.alreadyThere ? 'dl.already_saved' : 'dl.saved',
          {'name': name}),
      action: SnackBarAction(
        label: strings.t('dl.show'),
        onPressed: () => navigator.push(MaterialPageRoute(
          builder: (_) => BrowserScreen(path: p.dirname(saved.path)),
        )),
      ),
    );
  } catch (e) {
    showSnackOn(messenger, strings.t('dl.save_failed', {'error': '$e'}));
  }
}
