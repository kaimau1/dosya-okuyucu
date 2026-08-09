import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/photos_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
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
    // Uyarı 2026-08-09'dan beri kendi satırında değil, süzgeç şeridindeki
    // bir pilde (üst alan ~180 dp'den 38 dp'ye indi).
    expect(find.text('2 / 4 dosya'), findsOneWidget);
    expect(find.text('2 kopya gizli'), findsOneWidget);

    // "Göster" hepsini geri getirir — gizleme kalıcı bir kayıp değil.
    await tester.tap(find.text('2 kopya gizli'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Göster'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4 dosya'), findsOneWidget);
    expect(find.text('2 kopya gizli'), findsNothing);
  });

  /// **Kök neden testi (2026-08-09):** kullanıcı ekran görüntüsünde galerinin
  /// üstündeki alanı işaretleyip *"çok yer kaplıyor, kompaktlaşmalı"* dedi.
  /// Orada üst üste DÖRT satır vardı (gün/ay/yıl · kaynaklar · hızlı süzgeçler
  /// · kopya uyarısı) ve birlikte ~180 dp yiyorlardı. Bu test dördünün de TEK
  /// şeritte olduğunu ve şeridin sabit yüksekliğini bekler; biri yeniden kendi
  /// satırına çıkarsa kırmızı yanar.
  testWidgets('üst süzgeç alanı TEK ve kompakt bir şerittir', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
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

    // Tek şerit, sabit yükseklik.
    expect(find.byType(FmFilterBar), findsOneWidget);
    expect(tester.getSize(find.byType(FmFilterBar)).height,
        kFmFilterBarHeight);

    // Ölçek, kaynak çipi ve kopya uyarısı AYNI şeridin içinde.
    final bar = find.byType(FmFilterBar);
    expect(find.descendant(of: bar, matching: find.text('Gün')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.textContaining('WhatsApp')),
        findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('1 kopya gizli')),
        findsOneWidget);

    // Izgara şeridin hemen altında başlar: arada yalnız yapışkan grup başlığı
    // (44 dp) var — üçüncü bir satır sıkışırsa bu fark büyür.
    final barBottom = tester.getBottomLeft(bar).dy;
    final gridTop = tester.getTopLeft(find.byType(FmEntryIcon).first).dy;
    expect(gridTop - barBottom, lessThan(50));
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
  /// başlayınca kaybolup ızgarayı yukarı çekmesiydi. (2026-08-09'dan beri üçü
  /// de TEK şeritte; şerit yine seçim sırasında da yerinde durur.) İlk karonun
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
    expect(find.text('1 kopya gizli'), findsOneWidget);

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
    expect(find.text('1 kopya gizli'), findsOneWidget);
  });


  /// Kullanıcı isteği (2026-07-29): *"tümünü seç butonuna ek olarak... 1
  /// görüntü seçtim, onun altında kalanları seç, onun üstünde kalanları seç
  /// butonu olsun"*. "Üstünde/altında" ekrandaki (görünen) sıraya göredir.
  testWidgets('tek dosya seçiliyken üstündekileri/altındakileri de seçilebilir',
      (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    // p0 en yeni (indeks 0), p4 en eski (indeks 4) — varsayılan azalan tarih
    // sıralamasında bu tam olarak bildirim sırasıyla eşleşir.
    final files = [
      for (var i = 0; i < 5; i++)
        photo('p$i.jpg', day.subtract(Duration(minutes: i))),
    ];
    await tester.pumpWidget(harness(files));
    await tester.pump();

    final icons = find.byType(FmEntryIcon);
    expect(icons, findsNWidgets(5));

    // Ortadaki (indeks 2) dosyayı seç.
    await tester.longPress(icons.at(2));
    await tester.pump();
    expect(find.text('1 / 5 seçildi'), findsOneWidget);

    // "Üstündekileri de seç" → indeks 0, 1, 2 (3 dosya).
    await tester.tap(find.byTooltip('Üstündekileri de seç'));
    await tester.pump();
    expect(find.text('3 / 5 seçildi'), findsOneWidget);

    // Seçimi temizle, tekrar ortadakini seç, bu kez altını seç.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.longPress(icons.at(2));
    await tester.pump();
    await tester.tap(find.byTooltip('Altındakileri de seç'));
    await tester.pump();
    // indeks 2, 3, 4 (3 dosya).
    expect(find.text('3 / 5 seçildi'), findsOneWidget);
  });

  testWidgets(
      'birden fazla dosya seçiliyken üstündekileri/altındakileri düğmeleri '
      'KAYBOLUR (anchor belirsizleşir)', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    final files = [
      for (var i = 0; i < 3; i++)
        photo('p$i.jpg', day.subtract(Duration(minutes: i))),
    ];
    await tester.pumpWidget(harness(files));
    await tester.pump();

    final icons = find.byType(FmEntryIcon);
    await tester.longPress(icons.at(0));
    await tester.pump();
    expect(find.byTooltip('Üstündekileri de seç'), findsOneWidget);

    // İkinci dosyaya dokunmak (seçim kipindeyken tap = toggle) seçim
    // sayısını 2'ye çıkarır → anchor artık belirsiz, düğmeler kaybolmalı.
    await tester.tap(icons.at(1));
    await tester.pump();
    expect(find.text('2 / 3 seçildi'), findsOneWidget);
    expect(find.byTooltip('Üstündekileri de seç'), findsNothing);
    expect(find.byTooltip('Altındakileri de seç'), findsNothing);
  });
}
