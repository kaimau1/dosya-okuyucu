import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/archive_ops.dart';
import '../../services/file_service.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/hidden_vault.dart';
import '../../services/fm/home_shortcuts.dart';
import '../../services/fm/content_search.dart';
import '../../services/fm/exif_reader.dart';
import '../../services/fm/file_digest.dart';
import '../../services/fm/file_split.dart';
import '../../services/fm/image_rotate.dart';
import '../../services/text_decode.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/remote/ftp_tree.dart';
import '../../services/fm/remote/share_scope.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/volume_watcher.dart';
import '../../widgets/fm/archive_password_dialog.dart';
import '../../widgets/fm/compress_sheet.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/tag_picker_sheet.dart';
import 'ai_actions.dart';
import 'archive_screen.dart';
import 'drive_screen.dart';
import 'folder_picker_screen.dart';
import 'remote/peer_share_screen.dart';
import 'important_screen.dart';
import 'resize_actions.dart';
import 'vault_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';
import '../audiobook/audiobook_screen.dart';
import '../qr_share_screen.dart' show QrShareScreen;

part 'entry_actions/sheet.dart';
part 'entry_actions/file_ops.dart';
part 'entry_actions/properties.dart';


// ── Tek tek işlemler (çoklu seçim araç çubuğu da bunları çağırır) ───────────


