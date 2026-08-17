import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var (kullanıcı ekran görüntüsü 2026-08-17):** seçim modunda
/// satırın başındaki önizleme yerine düz bir [Checkbox] konuyordu. Yani
/// dosyaların birbirinden ayırt edilmesinin EN ÇOK gerektiği anda — hangisini
/// sileceğine karar verirken — PDF kapağı, fotoğraf ve APK simgesi
/// kayboluyordu. Aynı adlı `tk_Riad_righteous.pdf` ve `tk_Riad_righteous.doc`
/// arasında hangisinin seçildiği gözle doğrulanamıyordu.
///
/// Kilitlenen davranış: seçim açıkken de [FmEntryIcon] ağaçta DURUR ve
/// üzerinde onay rozeti görünür.
void main() {
  const entry = FsEntry(
    path: '/depo/İndirilenler/tk_Riad_righteous.pdf',
    name: 'tk_Riad_righteous.pdf',
    isDir: false,
    sizeBytes: 6200000,
    modifiedMs: 0,
  );

  Widget harness({
    required bool selecting,
    required bool selected,
    VoidCallback? onCheck,
  }) =>
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                FmEntryListTile(
                  entry: entry,
                  selected: selected,
                  selecting: selecting,
                  subtitle: '6,2 MB',
                  layout: FmLayout.list,
                  onTap: () {},
                  onCheck: onCheck,
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('seçim KAPALIYKEN önizleme görünür', (tester) async {
    await tester.pumpWidget(harness(selecting: false, selected: false));
    expect(find.byType(FmEntryIcon), findsOneWidget);
  });

  testWidgets('seçim AÇIKKEN önizleme yerini onay kutusuna BIRAKMAZ',
      (tester) async {
    await tester.pumpWidget(harness(selecting: true, selected: false));
    expect(find.byType(FmEntryIcon), findsOneWidget);
    // Eski davranışın nöbetçisi: düz onay kutusu önizlemeyi yutmamalı.
    expect(find.byType(Checkbox), findsNothing);
    // Seçilmemiş rozet: boş halka.
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });

  testWidgets('seçiliyken dolu rozet çizilir, önizleme yine durur',
      (tester) async {
    await tester.pumpWidget(harness(selecting: true, selected: true));
    expect(find.byType(FmEntryIcon), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('rozete dokunmak seçimi değiştirir', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(
      selecting: true,
      selected: false,
      onCheck: () => taps++,
    ));
    await tester.tap(find.byType(FmSelectableIcon));
    expect(taps, 1);
  });
}
