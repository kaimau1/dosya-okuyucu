import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/open_history.dart';
import '../../services/fm/storage_stats.dart';

/// Süzgeç satırının **tek ve sabit** yüksekliği (dp).
///
/// KÖK NEDEN (2026-08-09 kullanıcı, ekran görüntüsüyle: *"görüntüler ve
/// videolardaki işaretli üst alan çok yer kaplıyor, kompaktlaşmalı"*):
/// Fotoğraflar ekranında üst üste **dört** satır vardı — gün/ay/yıl ölçeği,
/// kaynak çipleri, hızlı süzgeçler ve "kopya gizlendi" uyarısı — ve birlikte
/// ~180 dp yiyorlardı. Artık hepsi **tek** yatay satırda.
///
/// 2026-09-26 (kullanıcı: *"üstteki filtreler tüm alanlarda pek güzel
/// değil"*): 38 → 46 dp. Çipler çerçeveli kutucuktan TONLU hapa döndü ve
/// aralarına nefes payı kondu; tek satır kuralı aynen duruyor.
const double kFmFilterBarHeight = 46;

/// Çip (ve pil) yüksekliği — şeritten 12 dp kısa, üstte/altta 6 dp pay.
const double kFmChipHeight = 34;

/// Çipler arası boşluk.
const double _kChipGap = 8;

/// Süzgeç satırının tek çipi: **tonlu hap** (2026-09-26 tasarım turu).
///
/// Eski çip Material'ın `FilterChip`iydi: gri çerçeve, 11 dp köşeli kutu,
/// seçiliyken açık mavi dolgu — yan yana dizilince "form alanı" gibi
/// duruyordu ve seçili olanı bir bakışta ayırt etmek zordu. Bugünün galeri
/// uygulamalarının (Google Foto, Samsung Galeri, YouTube) dili:
/// * tam yuvarlak hap, **çerçevesiz**, soluk yüzey tonunda;
/// * seçili olan **dolu birincil renk** — tek bakışta hangisinin açık olduğu
///   anlaşılır;
/// * sayı etiketin yanında ama SOLUK: göz önce adı okur, sayı ikincil bilgi.
///
/// Metin düz hâliyle `"Etiket · 12"` kalır (Text.rich) — testler ve ekran
/// okuyucular aynı dizeyi görür.
class FmChip extends StatelessWidget {
  final String label;

  /// Etiketin yanına ` · 12` diye eklenen sayı. 0/`null` ise yazılmaz.
  final int? count;

  final bool selected;
  final VoidCallback onTap;

  /// Etiketin solundaki küçük simge (ör. kopya uyarısı).
  final IconData? icon;

  const FmChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = count ?? 0;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kChipGap),
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: kFmChipHeight,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: _ChipBody(
                icon: icon,
                label: label,
                count: n > 0 ? n : null,
                fg: fg,
                bold: selected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Çip ve pilin ortak içi: simge + ad + soluk sayı (+ isteğe bağlı ok).
class _ChipBody extends StatelessWidget {
  final IconData? icon;
  final String label;
  final int? count;
  final Color fg;
  final bool bold;
  final bool dropdown;

  const _ChipBody({
    required this.icon,
    required this.label,
    required this.count,
    required this.fg,
    this.bold = false,
    this.dropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      height: 1.1,
      color: fg,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: icon == null ? 14 : 10,
        end: dropdown ? 8 : 14,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (count != null)
                  TextSpan(
                    text: ' · $count',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            style: style,
            maxLines: 1,
          ),
          if (dropdown) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 20, color: fg),
          ],
        ],
      ),
    );
  }
}

/// [FmChip] ile **aynı görünüşte** ama dokunmayı YUTMAYAN pil.
///
/// `PopupMenuButton`ın çocuğu olarak kullanılır: çipin kendi dokunma
/// tanıyıcısı üstteki menü düğmesinin dokunuşunu yutar ve menü hiç açılmaz.
/// [dropdown] sağa küçük bir ok koyar ("dokununca seçenek açılır").
class FmPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Soluk çizilsin mi (ör. seçim sürerken pasif duran uyarı pili).
  final bool disabled;

  /// Açılır menü oku.
  final bool dropdown;

  /// Vurgulu (seçili çiple aynı dolgu) — ör. süzgeç etkinken.
  final bool highlighted;

  const FmPill({
    super.key,
    required this.label,
    this.icon,
    this.disabled = false,
    this.dropdown = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color fg;
    if (disabled) {
      fg = Paper.faint(context);
    } else if (highlighted) {
      fg = scheme.onSecondaryContainer;
    } else {
      fg = scheme.onSurface;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _kChipGap),
      child: Container(
        height: kFmChipHeight,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: highlighted
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHighest,
        ),
        child: _ChipBody(
          icon: icon,
          label: label,
          count: null,
          fg: fg,
          dropdown: dropdown,
        ),
      ),
    );
  }
}

/// Liste/galeri ekranlarının üstündeki **tek satırlık** süzgeç şeridi.
///
/// Sabit yükseklikli (`kFmFilterBarHeight`) yatay kaydırmalı bir satır: içine
/// ne konursa konsun ekranın üstünden aldığı yer değişmez. Seçim başlayınca
/// gizlenmez — gizlenirse altındaki ızgara yukarı zıplıyordu (2026-07-29).
class FmFilterBar extends StatelessWidget {
  final List<Widget> children;

  const FmFilterBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: kFmFilterBarHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // Kenar payı ızgaranın/listenin metin hizasıyla aynı (12 dp);
        // sondaki pay son çipin ekrana yapışmasını önler.
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        children: [
          for (final child in children)
            Align(alignment: Alignment.center, child: child),
        ],
      ),
    );
  }
}

/// Liste ekranlarının üstündeki **tek dokunuşluk süzgeç çipleri**.
///
/// Süzgeç sayfası (`showFmFilterSheet`) her şeyi yapabiliyordu ama üç dokunuş
/// uzaktaydı; kullanıcının en sık istediği süzmeler (WhatsApp'tan gelenler,
/// büyük dosyalar, uzun zamandır açılmayanlar, son altı ayda açılanlar) burada
/// bir dokunuşa indi.
///
/// **Kaynak çipleri veriden türetilir, sabit değildir:** listede WhatsApp
/// dosyası yoksa WhatsApp çipi hiç çizilmez ve her çipin üstünde kaç dosyaya
/// denk geldiği yazar. Sabit bir kaynak listesi, boş çiplere dokunup "hiçbir
/// şey yok" görmeye yol açardı.
///
/// **Sayılar ÖTEKİ ölçütlere bağlıdır (2026-08-09).** Eskiden her çip ham
/// listeyi sayıyordu: "Büyük dosyalar · 312" yazan çipe, WhatsApp çipi zaten
/// seçiliyken dokununca 4 dosya çıkıyordu. Kullanıcının "filtreler doğru
/// çalışmıyor" demesinin bir sebebi buydu — çipin sayısı verdiği sonucu değil,
/// başka bir soruyu yanıtlıyordu. Artık her sayı **"dokunursam kaç dosya
/// kalır"**ın karşılığı.
class FmQuickFilters extends StatefulWidget {
  /// Çiplerin sayıları ve hangi kaynakların görüneceği bu listeden çıkar.
  /// Süzülmemiş (ham) liste verilmelidir.
  final List<FsEntry> source;

  final FmFilter filter;
  final ValueChanged<FmFilter> onChanged;

  /// "Şu kadar gündür açılmamış" / "son şu kadar günde açılmış" eşiği.
  final int untouchedDays;

  /// Kaynak çipleri çizilsin mi? Kendi kaynak satırı olan ekranlar (galeri)
  /// bunu kapatır — aynı çip iki kez görünmesin.
  final bool showBuckets;

  /// Süzgeç çiplerinden **önce** aynı satıra çizilen ekrana özel bileşenler
  /// (ör. gün/ay/yıl ölçeği, kaynak çipleri, belge türü çipleri).
  ///
  /// **Niye burada:** bunların her biri eskiden KENDİ satırındaydı; galeride
  /// dört satır birlikte ~180 dp yiyor, telefon ekranında listeye kalan yeri
  /// gözle görülür daraltıyordu (kullanıcı 2026-08-09: *"üst alan çok yer
  /// kaplıyor, kompaktlaşmalı"*). Tek satır, yatay kaydırmalı.
  final List<Widget> leading;

  /// Süzgeç çiplerinden **sonra** çizilenler (ör. "N kopya gizlendi" uyarısı).
  /// Süzgeçler önce gelir: satırın başı en sık kullanılan şeye ayrılmıştır.
  final List<Widget> trailing;

  const FmQuickFilters({
    super.key,
    required this.source,
    required this.filter,
    required this.onChanged,
    this.untouchedDays = 180,
    this.showBuckets = true,
    this.leading = const [],
    this.trailing = const [],
  });

  @override
  State<FmQuickFilters> createState() => _FmQuickFiltersState();
}

/// Bir çizim için hesaplanmış çip sayıları.
class _Counts {
  final List<(MediaBucket, int)> buckets;
  final int untouched;
  final int openedWithin;
  final int large;

  /// Birim çipleri: (birim, o birimdeki dosya sayısı). Tek birim varsa boş —
  /// "Ana bellek" tek başına hiçbir şey süzmez, yalnız yer kaplardı.
  final List<(StorageVolume, int)> volumes;

  const _Counts(this.buckets, this.untouched, this.openedWithin, this.large,
      this.volumes);
}

class _FmQuickFiltersState extends State<FmQuickFilters> {
  _Counts? _cache;
  String? _cacheKey;

  /// Sayım anahtarı: liste ya da süzgeç değişmedikçe yeniden sayılmaz.
  ///
  /// Sayılar artık öteki ölçütlere bağlı olduğu için her çip listeyi bir kez
  /// geziyor; 20 bin dosyalı bir kategoride bunu HER karede yapmak ekranı
  /// kastırırdı (aynı ders: `category_screen._sorted` önbelleği).
  String get _key => '${identityHashCode(widget.source)}|'
      '${widget.source.length}|${widget.filter.signature}|'
      '${widget.untouchedDays}|${widget.showBuckets}|'
      // Birim listesi takma/çıkarmayla değişir; çipler o an tazelenmeli.
      '${FmEnv.volumes.map((v) => v.path).join(',')}|'
      '${OpenHistory.revision}';

  _Counts get _counts {
    final key = _key;
    final cached = _cache;
    if (cached != null && _cacheKey == key) return cached;
    final computed = _compute();
    _cache = computed;
    _cacheKey = key;
    return computed;
  }

  /// [probe] ölçütü eklenmiş süzgeçten kaç dosya geçer?
  int _countWith(FmFilter probe) {
    var n = 0;
    for (final e in widget.source) {
      if (e.isDir) continue;
      if (probe.matches(e, openedAtOf: OpenHistory.forPath)) n++;
    }
    return n;
  }

  _Counts _compute() {
    final f = widget.filter;
    // Kaynak çipleri: hangi kaynaklar VAR (ham listeden) — çipin çizilip
    // çizilmeyeceği listenin içeriğine bakar, sayısı ise süzgece.
    final present = <MediaBucket>{};
    if (widget.showBuckets) {
      for (final e in widget.source) {
        if (e.isDir) continue;
        final b = bucketForPath(e.path);
        if (b == MediaBucket.other) continue; // "Diğer" çipinin bilgi değeri yok
        present.add(b);
      }
    }
    final buckets = <(MediaBucket, int)>[];
    for (final b in present) {
      // Seçili çipin sayısı "şu an kaç tane görünüyor"; seçili değilse
      // "dokunursam kaç tane kalır". İkisi de aynı hesap.
      final probe = f.buckets.contains(b) ? f : f.toggleBucket(b);
      buckets.add((b, _countWith(probe)));
    }
    buckets.sort((a, b) => b.$2.compareTo(a.$2));

    // **Birim çipleri** (kullanıcı isteği 2026-09-02: *"SD kart takılı
    // olduğunda Görüntüler, Videolar, Belgeler içeriğinde SD karttakileri
    // göster seçeneği ve filtresi de olmalı"*).
    //
    // Yalnız BİRDEN ÇOK birim varken çizilir: tek birimli bir telefonda
    // "Ana bellek" çipi hiçbir şey süzmez, sadece satırda yer kaplardı.
    // Sayısı sıfır olan birim de çizilmez (SD kartta hiç video yoksa
    // "Videolar"da SD kart çipi çıkmasın) — ama SEÇİLİYSE kalır, yoksa
    // kullanıcı seçtiği çipi kaybedip listeyi boş görürdü.
    final volumes = <(StorageVolume, int)>[];
    if (FmEnv.volumes.length > 1) {
      for (final v in FmEnv.volumes) {
        final selected = f.volumeRoots.contains(v.path);
        final probe = selected ? f : f.toggleVolumeRoot(v.path);
        final n = _countWith(probe);
        if (n > 0 || selected) volumes.add((v, n));
      }
    }

    return _Counts(
      buckets,
      _countWith(f.untouchedDays == null
          ? f.withUntouchedDays(widget.untouchedDays)
          : f),
      _countWith(f.openedWithinDays == null
          ? f.withOpenedWithinDays(widget.untouchedDays)
          : f),
      _countWith(f.sizeRange == FmSizeRange.large
          ? f
          : f.withSizeRange(FmSizeRange.large)),
      volumes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final f = widget.filter;
    final months = widget.untouchedDays ~/ 30;
    if (counts.buckets.isEmpty &&
        counts.volumes.isEmpty &&
        counts.untouched == 0 &&
        counts.openedWithin == 0 &&
        counts.large == 0 &&
        widget.leading.isEmpty &&
        widget.trailing.isEmpty) {
      return const SizedBox.shrink();
    }

    return FmFilterBar(
      children: [
        ...widget.leading,
        // **Birim çipleri EN BAŞTA** (ekrana özel bileşenlerden hemen sonra):
        // "bu dosyalar nerede duruyor" sorusu, "ne zaman açıldı"dan önce
        // gelir — SD kart takan kullanıcının ilk yaptığı ayrım budur.
        for (final (volume, count) in counts.volumes)
          FmChip(
            label: volume.displayLabel(context.t),
            count: count,
            selected: f.volumeRoots.contains(volume.path),
            onTap: () =>
                widget.onChanged(widget.filter.toggleVolumeRoot(volume.path)),
          ),
        // "Son 6 ayda açılanlar" ÖNCE: kullanıcının aradığı dosya çoğunlukla
        // yakında dokunduğu dosyadır; "açılmamışlar" yer açma işidir.
        if (counts.openedWithin > 0 || f.openedWithinDays != null)
          FmChip(
            label: context.t('fm.quick_opened_within', {'n': months}),
            count: counts.openedWithin,
            selected: f.openedWithinDays != null,
            onTap: () => widget.onChanged(widget.filter.withOpenedWithinDays(
                f.openedWithinDays == null ? widget.untouchedDays : null)),
          ),
        if (counts.untouched > 0 || f.untouchedDays != null)
          FmChip(
            label: context.t('fm.quick_untouched', {'n': months}),
            count: counts.untouched,
            selected: f.untouchedDays != null,
            onTap: () => widget.onChanged(widget.filter.withUntouchedDays(
                f.untouchedDays == null ? widget.untouchedDays : null)),
          ),
        if (counts.large > 0 || f.sizeRange == FmSizeRange.large)
          FmChip(
            label: context.t(FmSizeRange.large.labelKey),
            count: counts.large,
            selected: f.sizeRange == FmSizeRange.large,
            onTap: () => widget.onChanged(widget.filter.withSizeRange(
                f.sizeRange == FmSizeRange.large
                    ? FmSizeRange.any
                    : FmSizeRange.large)),
          ),
        for (final (bucket, count) in counts.buckets)
          FmChip(
            // Çeviri anahtarı: `bucket.label` Türkçe SABİT ("Kamera",
            // "İndirilenler"), ekranda gösterilen ad ondan bağımsız olmalı.
            label: context.t(bucket.labelKey),
            count: count,
            selected: f.buckets.contains(bucket),
            onTap: () => widget.onChanged(widget.filter.toggleBucket(bucket)),
          ),
        ...widget.trailing,
      ],
    );
  }
}
