import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/models/photo_group.dart';
import 'package:dosya_okuyucu/screens/fm/photos_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/drag_select.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_quick_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// **Niye bu test var:** Fotoğraflar ekranı bir sliver ağacı (yüzen
/// `SliverAppBar` + tek `SliverVariedExtentList`). Yanlış kurulmuş bir sliver
/// ağacı yalnız ÇİZİM anında patlar — bu ekran hiçbir testten pump edilmezse
/// hata ancak telefonda görülürdü.
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
    AppState? state,
  }) =>
      ChangeNotifierProvider<AppState>.value(
        value: state ?? AppState(),
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
      photo('c.jpg', today),
      photo('d.jpg', yesterday),
    ]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Dün'), findsOneWidget);
    // Satırı dolduran grubun başlığında sayı yazar (bugün 3). Satırı
    // dolduramayan "Dün" başka küçük gruplarla satır paylaşan kısa etiket.
    expect(find.text('3'), findsOneWidget);
  });

  /// Kullanıcının Videolar ekran görüntüsü: her gün 1-2 video vardı ve her
  /// gün kendi başlığıyla yarı boş bir satır kaplıyordu. Satırı dolduramayan
  /// ardışık günler artık AYNI satırı paylaşır, her birinin kısa etiketi
  /// kendi hücrelerinin üstünde (Google Foto'daki gibi).
  testWidgets('küçük günler aynı satırı paylaşır', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    await tester.pumpWidget(harness([
      photo('a.jpg', today),
      photo('b.jpg', today.subtract(const Duration(days: 1))),
      photo('c.jpg', today.subtract(const Duration(days: 9))),
    ]));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final icons = find.byType(FmEntryIcon);
    expect(icons, findsNWidgets(3));
    // Üçü de TEK satırda (aynı yükseklikte).
    final y0 = tester.getTopLeft(icons.at(0)).dy;
    expect(tester.getTopLeft(icons.at(1)).dy, y0);
    expect(tester.getTopLeft(icons.at(2)).dy, y0);
    // Etiketler hücrelerinin üstünde: "Dün" ikinci hücreyle aynı hizada.
    expect(find.text('Bugün'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Dün')).dx,
        greaterThan(tester.getTopLeft(icons.at(1)).dx));
    expect(tester.getTopLeft(find.text('Dün')).dx,
        lessThan(tester.getTopLeft(icons.at(2)).dx));

    // Seçimde her etiket kendi grubunu seçer.
    await tester.longPress(icons.at(0));
    await tester.pump();
    await tester.tap(find.text('Dün'));
    await tester.pump();
    expect(find.text('2 / 3 seçildi'), findsOneWidget);
  });

  testWidgets('ÇOK gruplu galeri TEK listede çizilir (donma kök nedeni)',
      (tester) async {
    // 2026-08-17 kullanıcı bulgusu: 6476 fotoğraflı galeride "yüklenme
    // sorunu, donma ve görülmeme". Her gün grubu İKİ sliver demekti ve
    // `CustomScrollView` slivers listesini kısaltmaz — binden fazla grupta
    // her yeniden çizim (her seçim dokunuşu!) iki binden fazla sliver kurup
    // yerleştiriyordu. 2026-09-26'dan beri grup sayısı NE OLURSA OLSUN tek
    // `SliverVariedExtentList` (satır yükseklikleri bilinir → hızlı tutamaç
    // doğrudan atlar); grup başına sliver hiç yok.
    final files = [
      for (var i = 0; i < 200; i++)
        photo('f$i.jpg', DateTime(2026, 1, 1).subtract(Duration(days: i))),
    ];
    await tester.pumpWidget(harness(files));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SliverVariedExtentList), findsOneWidget);
    expect(find.byType(SliverMainAxisGroup), findsNothing);
    expect(find.byType(FmEntryIcon), findsWidgets);

    // Kaydırma da patlamamalı (satır planı yanlışsa burada çöker).
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Listenin ORTASINA doğrudan atlama (hızlı tutamacın yaptığı): ara
    // satırlar kurulmadan hedefteki grup çizilir.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final position = scrollable.position;
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(FmEntryIcon), findsWidgets);
  });

  testWidgets('kaydırınca hızlı kaydırma tutamacı belirir', (tester) async {
    final files = [
      for (var i = 0; i < 300; i++)
        photo('f$i.jpg', DateTime(2026, 1, 1).subtract(Duration(days: i))),
    ];
    await tester.pumpWidget(harness(files));
    await tester.pump();
    double thumbOpacity() {
      final thumb = find.byIcon(Icons.unfold_more);
      if (thumb.evaluate().isEmpty) return 0;
      return tester
          .widget<AnimatedOpacity>(find
              .ancestor(of: thumb, matching: find.byType(AnimatedOpacity))
              .first)
          .opacity;
    }

    // Duran ekranda tutamaç görünmez (fotoğrafın üstünde kalıcı çubuk yok).
    expect(thumbOpacity(), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pump();
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    expect(thumbOpacity(), 1);

    // Tutamaç sürüklenince liste doğrudan o noktaya atlar ve balonda ay
    // yazar ("Ağustos 2025" gibi — yıl HER ZAMAN yazılır).
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = scrollable.position.pixels;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byIcon(Icons.unfold_more)));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(before + 200));
    expect(find.textContaining(RegExp(r'^[^ ]+ 20\d\d$')), findsWidgets);
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Hareketsiz 1,5 sn sonra söner (sayaç test bitmeden dolsun).
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(thumbOpacity(), 0);
  });

  testWidgets('ölçek pili menüsünden gün/ay/yıl seçilir', (tester) async {
    final state = AppState();
    await tester.pumpWidget(harness([
      photo('a.jpg', DateTime(2025, 3, 4)),
      photo('b.jpg', DateTime(2025, 3, 9)),
    ], state: state));
    await tester.pump();

    // Pil o anki ölçeği YAZAR; öteki ikisi menüde.
    expect(find.text('Gün'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    await tester.tap(find.text('Gün'));
    await tester.pumpAndSettle();
    expect(find.text('Ay'), findsOneWidget);
    expect(find.text('Yıl'), findsOneWidget);

    await tester.tap(find.text('Ay'));
    await tester.pumpAndSettle();
    expect(state.fmPhotoGroup, PhotoGroup.month);
    // İki gün TEK ay grubunda birleşti.
    expect(find.text('Mart 2025'), findsOneWidget);
    expect(find.textContaining('4 Mart'), findsNothing);
  });

  /// 2026-09-26 galeri turu: Google Foto'daki iki parmak jesti. Parmakları
  /// açmak bir basamak YAKLAŞTIRIR (daha az sütun), sıkıştırmak uzaklaştırır;
  /// 5 sütunda gruplama da aya geçer (her güne başlık, fotoğraftan çok başlık
  /// gösterirdi).
  testWidgets('iki parmakla yakınlaştırma sütun sayısını değiştirir',
      (tester) async {
    final state = AppState();
    final day = DateTime(2026, 3, 4, 10);
    final files = [
      for (var i = 0; i < 60; i++)
        photo('p$i.jpg', day.subtract(Duration(hours: i * 7))),
    ];
    await tester.pumpWidget(harness(files, state: state));
    await tester.pump();
    expect(state.fmPhotoLayout, FmLayout.grid3);

    // Aç (spread): 3 → 2 sütun.
    final center = tester.getCenter(find.byType(CustomScrollView));
    var a = await tester.startGesture(center - const Offset(40, 0));
    var b = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(state.fmPhotoLayout, FmLayout.grid2);
    expect(tester.takeException(), isNull);

    // Sıkıştır (pinch) iki kez: 2 → 3 → 4 sütun.
    a = await tester.startGesture(center - const Offset(150, 0));
    b = await tester.startGesture(center + const Offset(150, 0));
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await a.moveBy(const Offset(10, 0));
      await b.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(state.fmPhotoLayout.columns, greaterThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
  });

  /// **Kök neden testi (2026-09-26):** hücrede çift dokunuş dinleyicisi
  /// vardı; Flutter tek dokunuşu çift dokunuş süresi (~300 ms) dolana kadar
  /// bekletiyordu → her fotoğraf açılışı gecikiyordu. Dokunuş artık AYNI
  /// karede işlenir (burada dosya diskte yok → "bulunamadı" bildirimi).
  testWidgets('hücreye dokunmak beklemeden açar (çift dokunuş gecikmesi yok)',
      (tester) async {
    await tester.pumpWidget(harness([
      photo('a.jpg', DateTime(2026, 3, 4)),
      photo('b.jpg', DateTime(2026, 3, 4)),
    ]));
    await tester.pump();
    await tester.tap(find.byType(FmEntryIcon).first);
    await tester.pump(); // SIFIR süre: çift dokunuş zaman aşımı beklenmiyor
    expect(find.textContaining('Dosya bulunamadı'), findsOneWidget);
  });

  testWidgets('boş listede bilgilendirme gösterilir', (tester) async {
    await tester.pumpWidget(harness(const []));
    await tester.pump();
    expect(find.text('Burada gösterilecek dosya yok.'), findsOneWidget);
  });

  /// Kök neden testi (2026-07-29): pano önbelleği kategori başına 800 dosyayla
  /// sınırlı; ekran açıldıktan sonra EKSİKSİZ liste gelmeli.
  ///
  /// 2026-09-03'te davranış "yerine geç"ten "BİRLEŞTİR"e çevrildi: eksiksiz
  /// liste arama dizininden geliyor ve dizin bayatsa yeni dosyaları
  /// içermiyor. Yerine geçseydi az önce çekilen ekran görüntüsü gözün önünde
  /// kaybolurdu — kullanıcının bildirdiği *"görülüp geri gidiyor"* hatası.
  testWidgets('tam liste gelir ve elimizdekiyle BİRLEŞİR', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    final short = [photo('a.jpg', day)];
    final full = [
      for (var i = 0; i < 5; i++) photo('foto_$i.jpg', day),
    ];
    await tester.pumpWidget(harness(short, loadAll: () async => full));
    await tester.pump();
    // 5 (dizinden) + 1 (panodan gelen, dizinde olmayan taze dosya).
    // Hepsi görünüyorsa alt başlık "6 dosya · boyut" (eski "6 / 6 dosya"
    // tekrarı kalktı); süzgeç bir kısmını gizleyince "N / M dosya".
    expect(find.textContaining('6 dosya'), findsOneWidget);
    expect(find.textContaining('1 dosya'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kısa dönen liste elimizdekini EZMEZ', (tester) async {
    final day = DateTime(2026, 3, 4, 10);
    final short = [photo('a.jpg', day), photo('b.jpg', day)];
    await tester.pumpWidget(harness(short, loadAll: () async => const []));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('2 dosya'), findsOneWidget);
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
    expect(find.textContaining('4 dosya'), findsOneWidget);
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

    // Izgara şeridin hemen altında başlar: arada yalnız grup başlığı (52 dp)
    // var — üçüncü bir satır sıkışırsa bu fark büyür.
    final barBottom = tester.getBottomLeft(bar).dy;
    final gridTop = tester.getTopLeft(find.byType(FmEntryIcon).first).dy;
    expect(gridTop - barBottom, lessThan(60));
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
    // üstünde olmalı, yoksa seçim hiç başlamaz. Konum ise hücre KUTUSUNDAN
    // (DragSelectItem) ölçülür: seçilen önizleme bilinçli olarak içe küçülür
    // (Google Foto hissi, yalnız dönüşüm) — ölçülen şey ızgaranın kaymaması.
    final firstTile = find.byType(FmEntryIcon).first;
    final firstCell = find.byType(DragSelectItem).first;
    final before = tester.getTopLeft(firstCell);

    await tester.longPress(firstTile);
    await tester.pump();

    // Seçim kipi gerçekten açıldı mı?
    expect(find.textContaining('seçildi'), findsOneWidget);
    // ...ve karo yerinde mi?
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstCell), before);

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
