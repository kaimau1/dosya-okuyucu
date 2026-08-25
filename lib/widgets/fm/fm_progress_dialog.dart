import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
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
Future<T> showFmProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(
    void Function(FmProgress) report,
    bool Function() isCancelled,
  ) task,
  bool cancellable = true,
  bool backgroundable = true,
}) async {
  final progress = ValueNotifier<FmProgress>(const FmProgress(0, 0, ''));
  var cancelled = false;
  // Pencerenin hâlâ ekranda olup olmadığı. `closed` KULLANICI ya da bitiş
  // tarafından senkron olarak işaretlenir; `showDialog`'un `.then`'ine
  // güvenmek yarış yaratırdı (geç gelen `pop` yanlış sayfayı kapatabilirdi).
  var closed = false;
  /// Arka plan şeridinin denetleyicisi — hem "şerit gösterildi mi?" bilgisi
  /// hem de onu (ve YALNIZ onu) kapatma yolu. Ayrı bir `backgrounded` bayrağı
  /// tutulmuyordu: iki gerçeği tek yerde tutmak ikisinin ayrışmasını önler.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? barController;
  BuildContext? dialogContext;
  // Ekrandan bağımsız yaşayan (MaterialApp seviyesindeki) messenger: arka
  // plana alınan iş için kalıcı şerit burada gösterilir, kullanıcı başka
  // sayfaya geçse bile görünür kalır.
  final messenger = ScaffoldMessenger.of(context);
  // Metin await'ten ÖNCE alınır: şerit asenkron boşluktan sonra kuruluyor ve
  // `context` o an geçerli olmayabilir (aynı dosyadaki diğer metinlerle aynı
  // kural).
  final stopLabel = AppStrings.of(context).t('common.stop');

  // Kapatma İSTEĞİ ile kapatma EYLEMİ ayrı tutulur. Eskiden tek bayrak vardı ve
  // eylemden önce yakılıyordu: iş pencere ilk karesini çizmeden biterse
  // (`dialogContext` hâlâ null) bayrak yanmış oluyor, pencere sonradan açılıp
  // bir daha ASLA kapanmıyordu. Sıkıştırma düzeldikten sonra küçük dosyalarda
  // iş anında bittiği için bu tuzak artık gerçekten tetikleniyordu.
  void closeDialog() {
    closed = true;
    final ctx = dialogContext;
    dialogContext = null;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
  }

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
                value.total > 0
                    ? '$title · ${value.done} / ${value.total}'
                    : '$title…',
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

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      // İş, pencere çizilmeden önce bittiyse hemen kapan.
      if (closed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return const SizedBox.shrink();
      }
      dialogContext = ctx;
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
                  if (value.total > 0)
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
  ));

  try {
    return await task((p) => progress.value = p, () => cancelled);
  } finally {
    closeDialog();
    // Kalıcı şerit yalnız bu iş için gösterildiyse kaldırılır; başka bir
    // bildirimi (ör. kullanıcının okumadığı bir sonuç mesajı) süpürmeyelim.
    barController?.close();
    progress.dispose();
  }
}
