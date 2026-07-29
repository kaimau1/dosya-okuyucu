import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/photos_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
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

  Widget harness(
    List<FsEntry> files, {
    Future<List<FsEntry>> Function()? loadAll,
  }) =>
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: PhotosScreen(
              title: 'Görüntüler', files: files, loadAll: loadAll),
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

  /// Kök neden testi (2026-07-29): pano önbelleği kategori başına 800 dosyayla
  /// sınırlı; ekran açıldıktan sonra EKSİKSİZ liste gelip yerine geçmeli.
  testWidgets('tam liste gelince kırpılmış liste değişir', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    final short = [photo('a.jpg', day)];
    final full = [
      for (var i = 0; i < 5; i++) photo('foto_$i.jpg', day),
    ];
    await tester.pumpWidget(harness(short, loadAll: () async => full));
    // Yükleyici tamamlanınca kırpılmış liste yerini tam listeye bırakır.
    await tester.pump();
    expect(find.text('5 / 5 dosya'), findsOneWidget);
    expect(find.text('1 / 1 dosya'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kısa dönen liste elimizdekini EZMEZ', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    final short = [photo('a.jpg', day), photo('b.jpg', day)];
    await tester.pumpWidget(harness(short, loadAll: () async => const []));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 / 2 dosya'), findsOneWidget);
  });

  /// WhatsApp aynı görseli birkaç klasöre yazıyor; galeride "aynı resimden
  /// 3 tane" görünüyordu (kullanıcı hatası 2026-07-29).
  testWidgets('yinelenen kopyalar gizlenir ve kaç tane olduğu yazılır',
      (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    FsEntry copy(String dir) => FsEntry(
          path: '/depo/$dir/IMG-WA0001.jpg',
          name: 'IMG-WA0001.jpg',
          isDir: false,
          sizeBytes: 500,
          modifiedMs: day.millisecondsSinceEpoch,
        );
    await tester.pumpWidget(harness([
      copy('WhatsApp Images'),
      copy('WhatsApp Images/Sent'),
      copy('Android/media/com.whatsapp'),
      photo('tatil.jpg', day),
    ]));
    await tester.pump();

    // 4 dosyanın 2'si gösterilir (3 kopya → 1), gizlenen sayısı yazılır.
    expect(find.text('2 / 4 dosya'), findsOneWidget);
    expect(find.text('2 yinelenen kopya gizlendi'), findsOneWidget);

    // "Göster" hepsini geri getirir — gizleme kalıcı bir kayıp değil.
    await tester.tap(find.text('Göster'));
    await tester.pump();
    expect(find.text('4 / 4 dosya'), findsOneWidget);
    expect(find.text('2 yinelenen kopya gizlendi'), findsNothing);
  });

  testWidgets('süzgeç düğmesi var ve tarih/boyut seçenekleri açılır',
      (tester) async {
    await tester.pumpWidget(harness([photo('a.jpg', DateTime(2026, 3, 4))]));
    await tester.pump();
    expect(find.byIcon(Icons.tune), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Filtrele ve sırala'), findsOneWidget);
    expect(find.text('Son 7 gün'), findsOneWidget);
    expect(find.text('100 MB üzeri'), findsOneWidget);
    expect(find.text('Ada göre'), findsOneWidget);
  });

  /// **Kök neden testi (2026-07-29, ikinci rapor):** *"video basılı tutup
  /// seçtiğimde zıplama oluyor alt panel çıktığı için"*. Alt panel aslında
  /// bindirmeli çiziliyordu ve zıplatmıyordu; asıl neden ÜSTTEKİ satırların
  /// (gün/ay/yıl çipleri, kaynak çipleri, "kopya gizlendi" şeridi) seçim
  /// başlayınca kaybolup ızgarayı yukarı çekmesiydi. Bu test ilk karonun
  /// ekrandaki yerini seçim öncesi/sonrası karşılaştırır: bir piksel kayarsa
  /// düşer.
  testWidgets('uzun basıp seçim başlayınca ızgara ZIPLAMAZ', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    // Kaynak çiplerinin çıkması için iki farklı kaynak (kamera + WhatsApp)
    // ve gizlenen kopya şeridi için aynı adlı iki dosya.
    FsEntry at(String dir, String name) => FsEntry(
          path: '/depo/$dir/$name',
          name: name,
          isDir: false,
          sizeBytes: 500,
          modifiedMs: day.millisecondsSinceEpoch,
        );
    await tester.pumpWidget(harness([
      at('DCIM/Camera', 'IMG_0001.jpg'),
      at('WhatsApp Images', 'IMG-WA0001.jpg'),
      at('WhatsApp Images/Sent', 'IMG-WA0001.jpg'),
    ]));
    await tester.pump();

    // Üst satırların üçü de görünüyor olmalı (yoksa test bir şeyi ölçmez).
    expect(find.text('Gün'), findsOneWidget);
    expect(find.textContaining('Kamera'), findsOneWidget);
    expect(find.text('1 yinelenen kopya gizlendi'), findsOneWidget);

    // Karonun kendisi (özel sınıf) yerine içindeki önizleme aranıyor:
    // uzun basış DragSelectArea'da yakalanıyor ve basılan NOKTA karonun
    // üstünde olmalı, yoksa seçim hiç başlamaz.
    final firstTile = find.byType(FmEntryIcon).first;
    final before = tester.getTopLeft(firstTile);

    await tester.longPress(firstTile);
    await tester.pump();

    // Seçim kipi gerçekten açıldı mı?
    expect(find.textContaining('seçildi'), findsOneWidget);
    // ...ve karo yerinde mi?
    expect(tester.getTopLeft(firstTile), before);

    // Üst satırlar seçim sırasında da DURUR (kaybolan satır = zıplama).
    expect(find.text('Gün'), findsOneWidget);
    expect(find.textContaining('Kamera'), findsOneWidget);
    expect(find.text('1 yinelenen kopya gizlendi'), findsOneWidget);
  });
}
