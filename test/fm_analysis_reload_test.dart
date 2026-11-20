import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/analysis_screen.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/search_index.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'support/temp_dir.dart';

/// U4 (g): Bellek Analizi açılıştaki taramayı tutuyordu; dosya silinince tür
/// çubukları ve sayılar eski kalıyordu. Artık arama dizini değişince
/// ([SearchIndex.revision]) indeks yeniden kurulur.
void main() {
  testWidgets('silme sonrası dizin değişince tür çubukları yenilenir',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('fm_analysis_reload');
    addTearDown(() => removeTempDir(tmp));
    final photo = File(p.join(tmp.path, 'foto.jpg'))
      ..writeAsBytesSync(List.filled(2000, 1));
    final clip = File(p.join(tmp.path, 'klip.mp4'))
      ..writeAsBytesSync(List.filled(5000, 1));

    final before = (await tester.runAsync(() => FsScan.index([tmp.path])))!;
    clip.deleteSync();
    final after = (await tester.runAsync(() => FsScan.index([tmp.path])))!;
    expect(photo.existsSync(), isTrue);

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AnalysisScreen(
          index: before,
          volumes: [StorageVolume(path: tmp.path, isPrimary: true)],
          reloadIndex: () async => after,
        ),
      ),
    ));
    await tester.pump();

    const strings = AppStrings(AppLanguage.tr);
    final videos = strings.t(FmCategory.video.labelKey);
    expect(find.text(videos), findsWidgets, reason: 'video çubuğu çizilmeli');

    // Silme yolu (`SearchIndex.forget`) dizini günceller → olay.
    SearchIndex.revision.value++;
    await tester.pump();
    await tester.pump();

    expect(find.text(videos), findsNothing,
        reason: 'silinen videonun çubuğu eski taramadan kalmamalı');
    expect(find.text(strings.t(FmCategory.image.labelKey)), findsWidgets);
    expect(tester.takeException(), isNull);
    // Boş yer okuması (`usageOf`) zaman aşımlı bir süreç bekliyor: ağacı
    // kaldırıp o zamanlayıcıyı doldur.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
