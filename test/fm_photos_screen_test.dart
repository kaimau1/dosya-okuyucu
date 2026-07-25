import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/photos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var:** Fotoğraflar ekranı yapışkan başlıklı sliver
/// gruplarından (`SliverMainAxisGroup` + `SliverPersistentHeader`) oluşuyor.
/// Yanlış kurulmuş bir sliver ağacı yalnız ÇİZİM anında patlar — bu ekran
/// hiçbir testten pump edilmezse hata ancak telefonda görülürdü.
void main() {
  FsEntry photo(String name, DateTime when) => FsEntry(
        path: '/depo/DCIM/$name',
        name: name,
        isDir: false,
        sizeBytes: 1000,
        modifiedMs: when.millisecondsSinceEpoch,
      );

  Widget harness(List<FsEntry> files) => ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: PhotosScreen(title: 'Görüntüler', files: files),
        ),
      );

  testWidgets('gün başlıkları yazılır ve gruplar ayrılır', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    final yesterday = today.subtract(const Duration(days: 1));
    await tester.pumpWidget(harness([
      photo('a.jpg', today),
      photo('b.jpg', today),
      photo('c.jpg', yesterday),
    ]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Dün'), findsOneWidget);
    // Başlık sayacı: bugün 2, dün 1.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('gruplama çipleri ve arama düğmesi görünür', (tester) async {
    await tester.pumpWidget(harness([photo('a.jpg', DateTime(2026, 3, 4))]));
    await tester.pump();

    expect(find.text('Gün'), findsOneWidget);
    expect(find.text('Ay'), findsOneWidget);
    expect(find.text('Yıl'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('boş listede bilgilendirme gösterilir', (tester) async {
    await tester.pumpWidget(harness(const []));
    await tester.pump();
    expect(find.text('Burada gösterilecek dosya yok.'), findsOneWidget);
  });
}
