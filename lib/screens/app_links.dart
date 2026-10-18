import 'package:flutter/material.dart';

import '../widgets/scan_flow.dart';
import '../services/fm/entry_opener.dart';
import 'fm/bills_screen.dart';
import 'fm/cleanup_screen.dart';
import 'fm/search_screen.dart';
import '../core/l10n/app_strings.dart';

/// **Uygulama içi bağlantılar** (2026-10-18): ana ekran widget'ları ve yerel
/// iş bildirimleri uygulamayı bir bağlantıyla açar. Biçim:
/// - `app:scan` belge tara · `app:search` ara · `app:clean` yer aç ·
///   `app:bills` faturalar
/// - `file:/tam/yol` o dosyayı açar.
///
/// Tanınmayan bağlantı sessizce yok sayılır (eski bir widget sürümü).
Future<void> openAppLink(BuildContext context, String link) async {
  Future<void> push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  if (link.startsWith('file:')) {
    final path = link.substring(5);
    if (path.isNotEmpty) await EntryOpener.open(context, path);
    return;
  }
  switch (link) {
    case 'app:scan':
      await ScanFlow.run(context);
    case 'app:search':
      await push(SearchScreen(rootLabel: context.t('fm.all_files')));
    case 'app:clean':
      await push(const CleanupScreen());
    case 'app:bills':
      await push(const BillsScreen());
  }
}
