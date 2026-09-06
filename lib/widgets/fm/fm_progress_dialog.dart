import 'package:flutter/material.dart';

import '../../core/busy_dialog.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/file_ops.dart';

/// Uzun süren bir dosya işlemini ilerleme penceresiyle çalıştırır.
///
/// [task] iki şey alır: ilerlemeyi bildireceği bir [ValueNotifier] ve
/// kullanıcının iptal edip etmediğini soran bir fonksiyon. İş bitince pencere
/// kendiliğinden kapanır ve sonucu döner.
///
/// [backgroundable] ise pencerede **"Arka plana al"** düğmesi çıkar: pencere
/// kapanır, iş sürmeye devam eder ve kullanıcı bu sırada başka işlem yapabilir
/// (2026-07-26 bulgusu: "çöp kutusu boşaltılırken başka işlem yapamıyorum").
/// Sonuç yine çağırana döner — çağıran bildirimi kendi gösterir.
///
/// [describe] verilirse sayaç satırı ("3 / 12") onun döndürdüğü metinle
/// yazılır. Gerekçe: [FmProgress.done]/[FmProgress.total] her işte "dosya"
/// saymıyor — indirmede **bayt** sayıyor ve "12345678 / 29000000" diye bir
/// satır kimseye bir şey anlatmaz ("11,8 MB / 27,7 MB · %42" anlatır).
Future<T> showFmProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(
    void Function(FmProgress) report,
    bool Function() isCancelled,
  ) task,
  bool cancellable = true,
  bool backgroundable = true,
  String Function(FmProgress)? describe,
}) async {
  final progress = ValueNotifier<FmProgress>(const FmProgress(0, 0, ''));
  var cancelled = false;
  /// Arka plan şeridinin denetleyicisi — hem "şerit gösterildi mi?" bilgisi
  /// hem de onu (ve YALNIZ onu) kapatma yolu. Ayrı bir `backgrounded` bayrağı
  /// tutulmuyordu: iki gerçeği tek yerde tutmak ikisinin ayrışmasını önler.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? barController;
  // Ekrandan bağımsız yaşayan (MaterialApp seviyesindeki) messenger: arka
  // plana alınan iş için kalıcı şerit burada gösterilir, kullanıcı başka
  // sayfaya geçse bile görünür kalır.
  final messenger = ScaffoldMessenger.of(context);
  // Metin await'ten ÖNCE alınır: şerit asenkron boşluktan sonra kuruluyor ve
  // `context` o an geçerli olmayabilir (aynı dosyadaki diğer metinlerle aynı
  // kural).
  final stopLabel = AppStrings.of(context).t('common.stop');

  // Pencereyi **kimliğiyle** kapatan tutamak (bkz. `core/busy_dialog.dart`).
  //
  // Eskiden pencere `showDialog` ile açılıyor, kapatmak için de o pencerenin
  // `context`inde `Navigator.pop()` çağrılıyordu. İki ayrı tuzak vardı ve
  // ikisi de kullanıcının bildirdiği **kararan ekranı** üretiyordu:
  //
  // 1. İş, pencere ilk karesini çizmeden biterse (küçük dosyada kopyalama
  //    milisaniyeler sürüyor) kapatacak `context` henüz yoktu; pencere
  //    sonradan açılıp bir kare sonra KENDİNİ kapatıyordu. O gecikmiş `pop`
  //    araya giren bir başka pencereye — ya da sayfanın kendisine —
  //    denk gelebiliyordu.
  // 2. `Navigator.pop` "şu pencereyi kapat" demek değildir, "en üsttekini
  //    kapat" demektir. Pencere gitmişse arkadaki SAYFA kapanır; sayfa
  //    yığındaki tek sayfaysa `Navigator` boşalır ve ekran kararır.
  //
  // [BusyDialog] rotanın kendisini tuttuğu için ikisi de imkânsız: rota
  // gitmişse hiçbir şey yapmaz, üstünde başka rota varsa yalnız kendini
  // yığından çeker.
  BusyDialog? dialog;
  void closeDialog() => dialog?.close();

  /// Arka plana alındığında ekranın altında kalan **kalıcı** ilerleme şeridi.
  ///
  /// Süresi bir güne ayarlı: SnackBar'ın kendiliğinden kaybolması istenmiyor,
  /// iş bitince `finally` içinde elle kaldırılıyor. Böylece "arka plana aldım
  /// ama iş sürüyor mu, bitti mi?" belirsizliği kalmıyor.
  void showBackgroundBar() {
    // Denetleyici SAKLANIR: iş bitince `hideCurrentSnackBar()` çağırmak
    // "o an ne gösteriliyorsa onu kapat" demekti. SnackBar'lar sırayla
    // gösterildiği için bizim şerit araya giren bir sonuç mesajının (ör.
    // "5 öğe taşındı · Geri al") arkasına düşebiliyor ya da kullanıcı bizim
    // şeridi kaydırıp kapattıysa `finally` BAŞKASININ mesajını süpürüyordu
    // (2026-07-29 sadakat denetimi, 4. tur). `controller.close()` yalnız bu
    // şeridi kapatır.
    // Kalıcı şerit: kısa bildirimler bunu SÜPÜRMESİN (bkz. core/snack.dart —
    // yeni bildirim normalde bekleyenin yerine geçer).
    beginStickySnack();
    barController = messenger.showSnackBar(SnackBar(
      duration: const Duration(days: 1),
      content: ValueListenableBuilder<FmProgress>(
        valueListenable: progress,
        builder: (_, value, __) => Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                switch ((describe?.call(value), value.total)) {
                  (final String d, _) when d.isNotEmpty => '$title · $d',
                  (_, final int t) when t > 0 =>
                    '$title · ${value.done} / ${value.total}',
                  _ => '$title…',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      action: cancellable
          ? SnackBarAction(
              label: stopLabel, onPressed: () => cancelled = true)
          : null,
    ));
  }

  dialog = showBusyDialog(
    context,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          // **SABİT GENİŞLİK** (kullanıcı hatası 2026-08-25: *"işlemler
          // yapılırken çıkan popup yazıda silinen şeylerin ad uzunlukları
          // farklı olduğu için 'arka plana al' butonunun yeri sürekli
          // kayıyor"*).
          //
          // KÖK NEDEN: `AlertDialog` genişliğini İÇERİĞİNDEN alır ve içerikteki
          // en geniş şey o an işlenen dosyanın ADI. Ad her dosyada değiştiği
          // için pencere her karede yeniden ölçülüyor, düğmeler de onunla
          // birlikte sağa sola kayıyordu — kullanıcı düğmeye basmaya
          // çalışırken düğme yerinden gidiyor.
          //
          // `Text`e `maxLines: 1` koymak yetmiyordu: tek satır da olsa
          // İSTENEN genişlik adın uzunluğu kadardır, kırpma ancak sığmayınca
          // devreye girer. Çözüm genişliği içerikten bağımsız sabitlemek:
          // ekranın %78'i (küçük telefonda taşmasın), en çok 420 dp (tablette
          // pencere gereksiz uzamasın). Artık ad ne olursa olsun pencere aynı
          // genişlikte, düğmeler aynı yerde.
          content: SizedBox(
            width: (MediaQuery.sizeOf(ctx).width * 0.78).clamp(240.0, 420.0),
            child: ValueListenableBuilder<FmProgress>(
              valueListenable: progress,
              builder: (_, value, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // ClipRRect ile yuvarlatılır: `LinearProgressIndicator.borderRadius`
                // Flutter sürümüne duyarlı, CI 3.29.3'te riske girmiyoruz.
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: LinearProgressIndicator(
                    value: value.total > 0 ? value.fraction : null,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  value.currentName.isEmpty
                      ? context.t('pd.preparing')
                      : value.currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                  if (describe != null)
                    Text(describe(value),
                        style: Theme.of(ctx).textTheme.bodySmall)
                  else if (value.total > 0)
                    Text('${value.done} / ${value.total}',
                        style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          actions: [
            if (backgroundable)
              TextButton(
                onPressed: () {
                  closeDialog();
                  showBackgroundBar();
                },
                child: Text(ctx.t('fm.to_background')),
              ),
            if (cancellable)
              TextButton(
                onPressed: () {
                  cancelled = true;
                  closeDialog();
                },
                child: Text(context.t('pd.cancel')),
              ),
          ],
        ),
      );
    },
  );

  try {
    return await task((p) => progress.value = p, () => cancelled);
  } finally {
    closeDialog();
    // Kalıcı şerit yalnız bu iş için gösterildiyse kaldırılır; başka bir
    // bildirimi (ör. kullanıcının okumadığı bir sonuç mesajı) süpürmeyelim.
    final bar = barController;
    if (bar != null) {
      bar.close();
      endStickySnack();
    }
    progress.dispose();
  }
}
