@Tags(['perf'])
library;

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/fm_filter.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 42 — süzgeç şeridi 20 bin dosyalı kategoride: ilk sayım bir kez,
/// sonraki çizimler (aynı liste + süzgeç) önbellekten. Eşikler debug/JIT ×3.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final source = [
    for (var i = 0; i < 20000; i++)
      FsEntry(
        path: switch (i % 4) {
          0 => '/depo/WhatsApp/Media/WhatsApp Images/f$i.jpg',
          1 => '/depo/DCIM/Camera/f$i.jpg',
          2 => '/depo/Download/f$i.pdf',
          _ => '/depo/Belgeler/f$i.docx',
        },
        name: 'f$i',
        isDir: false,
        sizeBytes: (i % 50) << 20,
        modifiedMs: now - i * 3600 * 1000,
      ),
  ];

  testWidgets('20 bin dosya: ilk çizim ≤ 1,5 sn, yeniden çizim ≤ 60 ms',
      (tester) async {
    var bump = 0;
    late StateSetter set;
    Widget app() => MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: StatefulBuilder(builder: (context, s) {
              set = s;
              return Column(children: [
                Text('$bump'),
                FmQuickFilters(
                    source: source, filter: const FmFilter(), onChanged: (_) {}),
              ]);
            }),
          ),
        );
    final sw = Stopwatch()..start();
    await tester.pumpWidget(app());
    final first = sw.elapsedMilliseconds;
    sw
      ..reset()
      ..start();
    for (var i = 0; i < 10; i++) {
      set(() => bump++);
      await tester.pump();
    }
    final again = sw.elapsedMilliseconds / 10;
    // ignore: avoid_print
    print('PERF filter_bar_20k_first_ms=$first rebuild_avg_ms=$again');
    expect(first, lessThan(1500));
    expect(again, lessThan(60), reason: 'sayım önbellekten gelmeli');
  });

  // G1b (2026-11-20): galerinin yüzen başlığı ilk savurmada şeridi yeniden
  // kuruyor ve anahtar değişmişse 5.300 fotoğrafta tam sayım 155–170 ms'lik
  // tek kare veriyordu. Şerit artık yalnız "var mı" sorar (ilk eşleşmede
  // durur); anahtar HER çizimde değişse de çizim ucuz kalmalı.
  testWidgets('20 bin dosya, her çizimde yeni liste: ortalama ≤ 60 ms',
      (tester) async {
    var list = List<FsEntry>.of(source);
    late StateSetter set;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: StatefulBuilder(builder: (context, s) {
          set = s;
          return FmQuickFilters(
              source: list, filter: const FmFilter(), onChanged: (_) {});
        }),
      ),
    ));
    expect(find.byKey(const ValueKey('source-pill')), findsOneWidget);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      set(() => list = List<FsEntry>.of(source));
      await tester.pump();
    }
    final avg = sw.elapsedMilliseconds / 10;
    // ignore: avoid_print
    print('PERF filter_bar_20k_new_list_avg_ms=$avg');
    expect(avg, lessThan(60), reason: 'şerit tam sayım yapmamalı');
  });
}
