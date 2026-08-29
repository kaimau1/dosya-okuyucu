import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_glyph.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_layout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var:** ızgara hücresinin yüksekliği bir en-boy oranından,
/// ikonun boyu ise gerçek kısıtlardan gelir. İkisi kayarsa `RenderFlex
/// overflowed` çıkar ve bu yalnız telefonda görünürdü. Burada her yerleşim
/// (2-5 sütun) ve büyütülmüş yazı tipi ölçeğiyle çizilip taşma olmadığı
/// doğrulanır.
void main() {
  const entry = FsEntry(
    path: '/depo/Çok Uzun Bir Klasör Adı Buraya Sığmaz',
    name: 'Çok Uzun Bir Klasör Adı Buraya Sığmaz',
    isDir: true,
    sizeBytes: 0,
    modifiedMs: 0,
  );

  Widget harness(FmLayout layout, {double textScale = 1.0}) =>
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  gridDelegate: fmGridDelegate(layout, constraints.maxWidth),
                  itemCount: 12,
                  itemBuilder: (_, __) => FmEntryGridTile(
                    entry: entry,
                    layout: layout,
                    selected: false,
                    selecting: false,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  for (final layout in FmLayout.values.where((l) => l.isGrid)) {
    testWidgets('${layout.label} ızgarası taşmadan çizilir', (tester) async {
      await tester.pumpWidget(harness(layout));
      expect(tester.takeException(), isNull);
      expect(find.byType(FmEntryGridTile), findsWidgets);
    });

    testWidgets('${layout.label} büyük yazı tipinde de taşmaz', (tester) async {
      await tester.pumpWidget(harness(layout, textScale: 1.6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ikon hücrenin büyük bölümünü kaplar (3 sütun)', (tester) async {
    await tester.pumpWidget(harness(FmLayout.grid3));
    final tileSize = tester.getSize(find.byType(FmEntryGridTile).first);
    // 2026-08-29: düz Material glifi yerine ÇİZİLEN simge ([FmGlyph]);
    // ölçülen şey değişmedi — simgenin hücreye göre büyüklüğü.
    final iconBox = tester.getSize(find.byType(FmGlyph).first);
    // Eski sabit 56 dp'lik ikona karşılık artık hücrenin yarısından büyük.
    expect(iconBox.width, greaterThan(tileSize.width * 0.5));
  });
}
